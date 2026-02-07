import SwiftUI
import SwiftData

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var flowState: ImportFlowState = .intro
    @State private var selection = ImportSelection()

    private let googleAuth = GoogleAuthManager.shared

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import Travel History")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch flowState {
        case .intro:
            ImportIntroView(onConnect: startConnection)

        case .connecting:
            ProgressView("Connecting to Google...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .scanningGmail:
            ScanProgressView(
                icon: "envelope.fill",
                title: "Scanning Gmail",
                subtitle: "Looking for flight bookings, hotel reservations, train tickets..."
            )

        case .scanningCalendar(let gmailCandidates, let emailCount):
            ScanProgressView(
                icon: "calendar",
                title: "Scanning Calendar",
                subtitle: "Found \(gmailCandidates.count) countries in \(emailCount) emails.\nNow checking calendar events..."
            )

        case .reviewing(let candidates, let emailCount, let eventCount):
            ImportReviewView(
                candidates: candidates,
                scannedEmails: emailCount,
                scannedEvents: eventCount,
                selection: selection,
                onConfirm: confirmImport
            )

        case .confirming:
            ProgressView("Importing countries...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .success(let count):
            ImportSuccessView(count: count) {
                dismiss()
            }

        case .error(let message):
            ImportErrorView(message: message) {
                flowState = .intro
            }
        }
    }

    private func startConnection() {
        flowState = .connecting

        Task {
            do {
                if !googleAuth.isConnected {
                    try await googleAuth.signIn()
                }
                await startSplitScan()
            } catch GoogleAuthError.cancelled {
                flowState = .intro
            } catch {
                flowState = .error(error.localizedDescription)
            }
        }
    }

    private func startSplitScan() async {
        // Step 1: Scan Gmail
        flowState = .scanningGmail

        var gmailCandidates: [ImportCandidate] = []
        var emailCount = 0

        do {
            let gmailResponse = try await APIClient.shared.scanGmail()
            gmailCandidates = gmailResponse.candidates
            emailCount = gmailResponse.scannedEmails
        } catch {
            // Continue even if Gmail fails
            Log.importFlow.error("Gmail scan failed: \(error)")
        }

        // Step 2: Scan Calendar
        flowState = .scanningCalendar(gmailCandidates: gmailCandidates, emailCount: emailCount)

        var calendarCandidates: [ImportCandidate] = []
        var eventCount = 0

        do {
            let calendarResponse = try await APIClient.shared.scanCalendar()
            calendarCandidates = calendarResponse.candidates
            eventCount = calendarResponse.scannedEvents
        } catch {
            // Continue even if Calendar fails
            Log.importFlow.error("Calendar scan failed: \(error)")
        }

        // Step 3: Merge results
        let mergedCandidates = mergeCandidates(gmail: gmailCandidates, calendar: calendarCandidates)

        if mergedCandidates.isEmpty && emailCount == 0 && eventCount == 0 {
            flowState = .error("Could not scan Gmail or Calendar. Please try again.")
            return
        }

        selection.selectAll(from: mergedCandidates)
        flowState = .reviewing(candidates: mergedCandidates, emailCount: emailCount, eventCount: eventCount)
    }

    private func mergeCandidates(gmail: [ImportCandidate], calendar: [ImportCandidate]) -> [ImportCandidate] {
        var merged: [String: ImportCandidate] = [:]

        // Add Gmail candidates
        for candidate in gmail {
            merged[candidate.countryCode] = candidate
        }

        // Merge Calendar candidates
        for candidate in calendar {
            if let existing = merged[candidate.countryCode] {
                // Combine counts and samples
                var combinedSamples = existing.sampleSources
                combinedSamples.append(contentsOf: candidate.sampleSources.prefix(2))

                merged[candidate.countryCode] = ImportCandidate(
                    countryCode: candidate.countryCode,
                    countryName: candidate.countryName,
                    emailCount: existing.emailCount,
                    calendarEventCount: candidate.calendarEventCount,
                    sampleSources: combinedSamples,
                    confidence: max(existing.confidence, candidate.confidence)
                )
            } else {
                merged[candidate.countryCode] = candidate
            }
        }

        // Sort by total evidence
        return merged.values.sorted { $0.totalSources > $1.totalSources }
    }

    private func confirmImport() {
        guard !selection.selectedCountries.isEmpty else { return }

        flowState = .confirming

        Task {
            do {
                let response = try await APIClient.shared.confirmGoogleImport(
                    countryCodes: Array(selection.selectedCountries)
                )

                // Add imported countries to local SwiftData
                for country in response.countries {
                    let place = VisitedPlace(
                        regionType: .country,
                        regionCode: country.countryCode,
                        regionName: country.countryName
                    )
                    modelContext.insert(place)
                }

                try modelContext.save()

                // Save last imported dates
                let now = Date()
                UserDefaults.standard.set(now, forKey: "lastGmailImport")
                UserDefaults.standard.set(now, forKey: "lastCalendarImport")

                flowState = .success(response.imported)
            } catch {
                flowState = .error("Failed to import: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Scan Progress View

private struct ScanProgressView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .modifier(RotatingModifier())

                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(.blue)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title) in progress")

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Text("This may take a minute for large mailboxes.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom)
        }
    }
}

// MARK: - Scanning Progress View

private struct ImportScanningView: View {
    let progress: ScanProgress

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated scanning indicator
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .modifier(RotatingModifier())

                Image(systemName: scanIcon)
                    .font(.system(size: 30))
                    .foregroundStyle(.blue)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Scanning in progress")

            VStack(spacing: 8) {
                Text(progress.displayText)
                    .font(.headline)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: progress.displayText)

                if let detail = progress.detailText {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut, value: detail)
                }
            }

            // Progress bars
            VStack(spacing: 12) {
                if let p = progress.progress {
                    if p.emailsTotal > 0 {
                        ProgressRow(
                            icon: "envelope.fill",
                            label: "Emails",
                            current: p.emailsScanned,
                            total: p.emailsTotal
                        )
                    }

                    if p.eventsTotal > 0 {
                        ProgressRow(
                            icon: "calendar",
                            label: "Events",
                            current: p.eventsScanned,
                            total: p.eventsTotal
                        )
                    }

                    if let year = p.calendarYear {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            Text("Scanning \(year)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            Text("This may take a few minutes for large mailboxes.\nYou'll be notified when complete.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom)
        }
    }

    private var scanIcon: String {
        switch progress.status {
        case .scanningEmails:
            return "envelope.fill"
        case .scanningCalendar:
            return "calendar"
        case .processing:
            return "gearshape.fill"
        default:
            return "magnifyingglass"
        }
    }
}

private struct ProgressRow: View {
    let icon: String
    let label: String
    let current: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(current)/\(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: Double(current), total: Double(max(total, 1)))
                .tint(.blue)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(current) of \(total)")
        .accessibilityValue("\(total > 0 ? (current * 100 / total) : 0) percent")
    }
}

private struct RotatingModifier: ViewModifier {
    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Intro View

private struct ImportIntroView: View {
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Import from Gmail & Calendar")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                Text("We'll scan your emails and calendar events to find countries you've visited based on flight bookings, hotel reservations, train tickets, and travel events.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Flight confirmations", systemImage: "airplane")
                Label("Hotel bookings", systemImage: "building.2")
                Label("Train tickets", systemImage: "tram")
                Label("Car rentals", systemImage: "car")
                Label("Calendar events with locations", systemImage: "calendar")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onConnect) {
                    HStack {
                        Image(systemName: "link")
                        Text("Connect Google Account")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                Text("We only read emails and events to find travel destinations. We don't store your email content.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Success View

private struct ImportSuccessView: View {
    let count: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Import Complete!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                Text("\(count) \(count == 1 ? "country" : "countries") added to your travel history")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

// MARK: - Error View

private struct ImportErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Button("Try Again", action: onRetry)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom)
        }
    }
}

#Preview {
    ImportView()
}
