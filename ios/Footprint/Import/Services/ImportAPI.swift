import Foundation

// MARK: - Import API Extension

extension APIClient {

    // MARK: - Scan Gmail/Calendar (Sync - deprecated)

    /// Start scanning Gmail and Calendar for travel history (synchronous, may timeout)
    func scanGoogleImports() async throws -> ImportScanResponse {
        try await request(
            path: "/import/google/scan",
            method: .post
        )
    }

    // MARK: - Async Scan (Recommended)

    /// Start an async import scan job
    func startAsyncScan() async throws -> StartImportResponse {
        try await request(
            path: "/import/google/scan/start",
            method: .post
        )
    }

    /// Get the status of an async import scan job
    func getScanStatus(jobId: String) async throws -> JobStatusResponse {
        try await request(
            path: "/import/google/scan/status/\(jobId)",
            method: .get
        )
    }

    /// Get the results of a completed import scan job
    func getScanResults(jobId: String) async throws -> ImportScanResponse {
        try await request(
            path: "/import/google/scan/results/\(jobId)",
            method: .get
        )
    }

    /// Confirm import of selected countries
    func confirmGoogleImport(countryCodes: [String]) async throws -> ImportConfirmResponse {
        let body = ImportConfirmRequest(countryCodes: countryCodes)
        return try await request(
            path: "/import/google/confirm",
            method: .post,
            body: body
        )
    }

    // MARK: - Push Notifications

    /// Register device token for push notifications
    func registerDeviceToken(_ token: String, platform: String = "ios") async throws -> DeviceTokenResponse {
        let body = DeviceTokenRequest(deviceToken: token, platform: platform)
        return try await request(
            path: "/import/google/notifications/register",
            method: .post,
            body: body
        )
    }
}

// MARK: - Request/Response Models

struct ImportScanResponse: Decodable {
    let candidates: [ImportCandidate]
    let scannedEmails: Int
    let scannedEvents: Int
    let scanDurationSeconds: Double
}

struct ImportCandidate: Decodable, Identifiable {
    let countryCode: String
    let countryName: String
    let emailCount: Int
    let calendarEventCount: Int
    let sampleSources: [SourceSample]
    let confidence: Double

    var id: String { countryCode }

    var totalSources: Int {
        emailCount + calendarEventCount
    }
}

struct SourceSample: Decodable, Identifiable {
    let id: String
    let sourceType: SourceType
    let title: String
    let date: Date?
    let snippet: String?

    enum SourceType: String, Decodable {
        case email
        case calendar
    }
}

struct ImportConfirmRequest: Encodable {
    let countryCodes: [String]
}

struct ImportConfirmResponse: Decodable {
    let imported: Int
    let countries: [ImportedCountry]
}

struct ImportedCountry: Decodable {
    let countryCode: String
    let countryName: String
    let regionType: String
}

// MARK: - Async Import Models

struct StartImportResponse: Decodable {
    let jobId: String
    let status: JobStatus
    let message: String
}

struct JobStatusResponse: Decodable {
    let jobId: String
    let status: JobStatus
    let progress: ImportJobProgress
    let createdAt: String
    let updatedAt: String
    let completedAt: String?
    let errorMessage: String?
    let candidatesCount: Int
}

struct ImportJobProgress: Decodable {
    let emailsScanned: Int
    let emailsTotal: Int
    let eventsScanned: Int
    let eventsTotal: Int
    let calendarYear: Int?
    let currentStep: String

    var description: String {
        switch currentStep {
        case "scanning_emails":
            if emailsTotal > 0 {
                return "Scanning emails (\(emailsScanned)/\(emailsTotal))"
            }
            return "Scanning emails..."
        case "scanning_calendar":
            if let year = calendarYear {
                return "Scanning calendar (\(year))"
            }
            if eventsTotal > 0 {
                return "Scanning calendar (\(eventsScanned)/\(eventsTotal))"
            }
            return "Scanning calendar..."
        case "processing", "aggregating_results":
            return "Processing results..."
        default:
            return "Initializing..."
        }
    }
}

enum JobStatus: String, Decodable {
    case pending
    case scanningEmails = "scanning_emails"
    case scanningCalendar = "scanning_calendar"
    case processing
    case completed
    case failed

    var isInProgress: Bool {
        switch self {
        case .pending, .scanningEmails, .scanningCalendar, .processing:
            return true
        case .completed, .failed:
            return false
        }
    }
}

// MARK: - Push Notification Models

struct DeviceTokenRequest: Encodable {
    let deviceToken: String
    let platform: String
}

struct DeviceTokenResponse: Decodable {
    let registered: Bool
    let message: String
}
