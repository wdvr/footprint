import SwiftUI
import SwiftData

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var flowState: ImportFlowState = .intro
    @State private var selection = ImportSelection()
    @State private var pollTask: Task<Void, Never>?

    private let googleAuth = GoogleAuthManager.shared

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import Travel History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            pollTask?.cancel()
                            dismiss()
                        }
                    }
                }
        }
        .onDisappear {
            pollTask?.cancel()
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

        case .scanning(let progress):
            ImportScanningView(progress: progress)

        case .reviewing(let response):
            ImportReviewView(
                response: response,
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
            // First verify we're authenticated with Footprint API
            let isAuth = await APIClient.shared.isAuthenticated
            print("[ImportView] startConnection: APIClient.isAuthenticated = \(isAuth)")

            guard isAuth else {
                flowState = .error("Please sign in to your Footprint account first. Go to Settings and sign in, then try again.")
                return
            }

            do {
                if !googleAuth.isConnected {
                    try await googleAuth.signIn()
                }
                await startAsyncScan()
            } catch GoogleAuthError.cancelled {
                flowState = .intro
            } catch {
                flowState = .error(error.localizedDescription)
            }
        }
    }

    private func startAsyncScan() async {
        flowState = .scanning(ScanProgress())

        do {
            // Start the async job
            let startResponse = try await APIClient.shared.startAsyncScan()
            let progress = ScanProgress(jobId: startResponse.jobId, status: startResponse.status)
            flowState = .scanning(progress)

            // Start polling for status
            pollTask = Task {
                await pollJobStatus(jobId: startResponse.jobId)
            }
        } catch {
            flowState = .error("Failed to start scan: \(error.localizedDescription)")
        }
    }

    private func pollJobStatus(jobId: String) async {
        let pollInterval: UInt64 = 1_500_000_000 // 1.5 seconds

        while !Task.isCancelled {
            do {
                let status = try await APIClient.shared.getScanStatus(jobId: jobId)

                // Update progress in UI
                let progress = ScanProgress(
                    jobId: jobId,
                    status: status.status,
                    progress: status.progress
                )
                flowState = .scanning(progress)

                // Check if done
                if status.status == .completed {
                    // Fetch results
                    let results = try await APIClient.shared.getScanResults(jobId: jobId)
                    selection.selectAll(from: results.candidates)
                    flowState = .reviewing(results)
                    return
                } else if status.status == .failed {
                    flowState = .error(status.errorMessage ?? "Scan failed")
                    return
                }

                // Wait before next poll
                try await Task.sleep(nanoseconds: pollInterval)
            } catch {
                if !Task.isCancelled {
                    flowState = .error("Failed to check scan status: \(error.localizedDescription)")
                }
                return
            }
        }
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

                flowState = .success(response.imported)
            } catch {
                flowState = .error("Failed to import: \(error.localizedDescription)")
            }
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
    }
}

private struct RotatingModifier: ViewModifier {
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
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

            VStack(spacing: 12) {
                Text("Import from Gmail & Calendar")
                    .font(.title2)
                    .fontWeight(.semibold)

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

            VStack(spacing: 8) {
                Text("Import Complete!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(count) \(count == 1 ? "country" : "countries") added to your travel history")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done", action: onDone)
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

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.semibold)

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
