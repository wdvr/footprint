import SwiftUI

struct ImportReviewView: View {
    let candidates: [ImportCandidate]
    let scannedEmails: Int
    let scannedEvents: Int
    @Bindable var selection: ImportSelection
    let onConfirm: () -> Void

    @State private var expandedCountry: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header stats - subtle styling
            scanStats
                .padding(.vertical, 12)
                .padding(.horizontal)

            // Disclaimer
            disclaimer
                .padding(.horizontal)
                .padding(.top, 4)

            // Country list
            List {
                ForEach(sortedCandidates) { candidate in
                    ImportCandidateRow(
                        candidate: candidate,
                        isSelected: selection.isSelected(candidate.countryCode),
                        isExpanded: expandedCountry == candidate.countryCode,
                        onToggleSelection: {
                            selection.toggleSelection(for: candidate.countryCode)
                        },
                        onToggleExpand: {
                            withAnimation {
                                if expandedCountry == candidate.countryCode {
                                    expandedCountry = nil
                                } else {
                                    expandedCountry = candidate.countryCode
                                }
                            }
                        }
                    )
                }
            }
            .listStyle(.plain)

            // Selection controls and confirm button
            bottomBar
        }
    }

    private var sortedCandidates: [ImportCandidate] {
        candidates.sorted { $0.totalSources > $1.totalSources }
    }

    private var scanStats: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("\(scannedEmails)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Emails")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 30)

            VStack(spacing: 4) {
                Text("\(scannedEvents)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 30)

            VStack(spacing: 4) {
                Text("\(candidates.count)")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Countries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var disclaimer: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.blue)

            Text("Results may not be 100% accurate. Review and deselect any incorrect matches.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Divider()

            HStack {
                Button(action: {
                    if selection.selectedCountries.count == candidates.count {
                        selection.deselectAll()
                    } else {
                        selection.selectAll(from: candidates)
                    }
                }) {
                    Text(selection.selectedCountries.count == candidates.count ? "Deselect All" : "Select All")
                        .font(.subheadline)
                }

                Spacer()

                Text("\(selection.selectedCountries.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if selection.selectedCountries.isEmpty {
                Button(action: { dismiss() }) {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            } else {
                Button(action: onConfirm) {
                    Text("Import \(selection.selectedCountries.count) \(selection.selectedCountries.count == 1 ? "Country" : "Countries")")
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
        .background(Color(.systemBackground))
    }
}

// MARK: - Candidate Row

struct ImportCandidateRow: View {
    let candidate: ImportCandidate
    let isSelected: Bool
    let isExpanded: Bool
    let onToggleSelection: () -> Void
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Selection checkbox
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isSelected ? .blue : .gray)
                }
                .buttonStyle(.plain)

                // Country flag and name
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(flag(for: candidate.countryCode))
                            .font(.title3)
                        Text(candidate.countryName)
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    // Source counts
                    HStack(spacing: 12) {
                        if candidate.emailCount > 0 {
                            Label("\(candidate.emailCount) emails", systemImage: "envelope")
                        }
                        if candidate.calendarEventCount > 0 {
                            Label("\(candidate.calendarEventCount) events", systemImage: "calendar")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Expand button
                if !candidate.sampleSources.isEmpty {
                    Button(action: onToggleExpand) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)

            // Expanded samples
            if isExpanded && !candidate.sampleSources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(candidate.sampleSources.prefix(5)) { sample in
                        HStack(spacing: 8) {
                            Image(systemName: sample.sourceType == .email ? "envelope" : "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(sample.title)
                                    .font(.caption)
                                    .lineLimit(1)

                                if let snippet = sample.snippet {
                                    Text(snippet)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 44)
                .padding(.bottom, 8)
            }
        }
    }

    /// Convert country code to flag emoji
    private func flag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                flag.append(String(unicode))
            }
        }
        return flag
    }
}

#Preview {
    ImportReviewView(
        candidates: [],
        scannedEmails: 1500,
        scannedEvents: 200,
        selection: ImportSelection(),
        onConfirm: {}
    )
}
