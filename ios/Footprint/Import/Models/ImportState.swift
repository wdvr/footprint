import Foundation

/// Represents the current state of the import flow
enum ImportFlowState {
    case intro
    case connecting
    case scanningGmail
    case scanningCalendar(gmailCandidates: [ImportCandidate], emailCount: Int)
    case reviewing(candidates: [ImportCandidate], emailCount: Int, eventCount: Int)
    case confirming
    case success(Int)
    case error(String)
}

/// Progress during async scanning
struct ScanProgress {
    var jobId: String?
    var status: JobStatus = .pending
    var progress: ImportJobProgress?

    var displayText: String {
        progress?.description ?? "Starting scan..."
    }

    var detailText: String? {
        guard let p = progress else { return nil }

        var details: [String] = []

        if p.emailsScanned > 0 || p.emailsTotal > 0 {
            details.append("\(p.emailsScanned) emails scanned")
        }

        if p.eventsScanned > 0 || p.eventsTotal > 0 {
            details.append("\(p.eventsScanned) events scanned")
        }

        return details.isEmpty ? nil : details.joined(separator: " • ")
    }
}

/// Selection state for import candidates
@Observable
class ImportSelection {
    var selectedCountries: Set<String> = []

    func toggleSelection(for countryCode: String) {
        if selectedCountries.contains(countryCode) {
            selectedCountries.remove(countryCode)
        } else {
            selectedCountries.insert(countryCode)
        }
    }

    func selectAll(from candidates: [ImportCandidate]) {
        selectedCountries = Set(candidates.map { $0.countryCode })
    }

    func deselectAll() {
        selectedCountries.removeAll()
    }

    func isSelected(_ countryCode: String) -> Bool {
        selectedCountries.contains(countryCode)
    }
}
