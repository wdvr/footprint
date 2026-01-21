import Foundation

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case serverError(Int, String)
    case unauthorized
}

actor APIClient {
    static let shared = APIClient()

    #if DEBUG
    private let baseURL = "https://66sdbasq7k.execute-api.us-east-1.amazonaws.com/dev"
    #else
    private let baseURL = "https://66sdbasq7k.execute-api.us-east-1.amazonaws.com/prod"
    #endif

    private var accessToken: String?
    private var refreshToken: String?

    private init() {}

    // MARK: - Token Management

    func setTokens(access: String, refresh: String) {
        self.accessToken = access
        self.refreshToken = refresh
        // Store in Keychain for persistence
        KeychainHelper.save(key: "accessToken", value: access)
        KeychainHelper.save(key: "refreshToken", value: refresh)
    }

    func loadStoredTokens() {
        self.accessToken = KeychainHelper.load(key: "accessToken")
        self.refreshToken = KeychainHelper.load(key: "refreshToken")
    }

    func clearTokens() {
        self.accessToken = nil
        self.refreshToken = nil
        KeychainHelper.delete(key: "accessToken")
        KeychainHelper.delete(key: "refreshToken")
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

    // MARK: - HTTP Methods

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authenticated: Bool = false
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        switch httpResponse.statusCode {
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }

    // MARK: - Auth Endpoints

    struct AppleAuthRequest: Encodable {
        let identityToken: String
        let authorizationCode: String
    }

    struct AuthResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let tokenType: String
        let expiresIn: Int
        let user: UserResponse
    }

    struct UserResponse: Decodable {
        let id: String
        let appleUserId: String
        let email: String?
        let displayName: String?
        let createdAt: Date?
    }

    func authenticateWithApple(identityToken: String, authorizationCode: String) async throws -> AuthResponse {
        let body = AppleAuthRequest(identityToken: identityToken, authorizationCode: authorizationCode)
        let response: AuthResponse = try await request("/auth/apple", method: "POST", body: body)
        setTokens(access: response.accessToken, refresh: response.refreshToken)
        return response
    }

    func refreshAccessToken() async throws -> AuthResponse {
        guard let token = refreshToken else {
            throw APIError.unauthorized
        }

        struct RefreshRequest: Encodable {
            let refreshToken: String
        }

        let body = RefreshRequest(refreshToken: token)
        let response: AuthResponse = try await request("/auth/refresh", method: "POST", body: body)
        setTokens(access: response.accessToken, refresh: response.refreshToken)
        return response
    }

    func getCurrentUser() async throws -> UserResponse {
        try await request("/auth/me", authenticated: true)
    }

    // MARK: - Places Endpoints

    struct VisitedPlaceRequest: Encodable {
        let regionType: String
        let regionCode: String
        let regionName: String
        let visitedDate: Date?
        let notes: String?
    }

    struct VisitedPlaceResponse: Decodable {
        let id: String
        let regionType: String
        let regionCode: String
        let regionName: String
        let visitedDate: Date?
        let notes: String?
        let createdAt: Date
        let updatedAt: Date
    }

    struct PlacesListResponse: Decodable {
        let places: [VisitedPlaceResponse]
        let count: Int
    }

    func getVisitedPlaces() async throws -> [VisitedPlaceResponse] {
        let response: PlacesListResponse = try await request("/places", authenticated: true)
        return response.places
    }

    func createVisitedPlace(
        regionType: String,
        regionCode: String,
        regionName: String,
        visitedDate: Date? = nil,
        notes: String? = nil
    ) async throws -> VisitedPlaceResponse {
        let body = VisitedPlaceRequest(
            regionType: regionType,
            regionCode: regionCode,
            regionName: regionName,
            visitedDate: visitedDate,
            notes: notes
        )
        return try await request("/places", method: "POST", body: body, authenticated: true)
    }

    func deleteVisitedPlace(regionType: String, regionCode: String) async throws {
        let _: EmptyResponse = try await request("/places/\(regionType)/\(regionCode)", method: "DELETE", authenticated: true)
    }

    // MARK: - Sync Endpoints

    struct SyncRequest: Encodable {
        let lastSyncAt: Date?
        let changes: [PlaceChange]
    }

    struct PlaceChange: Encodable {
        let regionType: String
        let regionCode: String
        let regionName: String
        let isDeleted: Bool
        let lastModifiedAt: Date
    }

    struct SyncResponse: Decodable {
        let serverChanges: [VisitedPlaceResponse]
        let syncedAt: Date
        let conflictsResolved: Int
    }

    func syncPlaces(lastSyncAt: Date?, changes: [PlaceChange]) async throws -> SyncResponse {
        let body = SyncRequest(lastSyncAt: lastSyncAt, changes: changes)
        return try await request("/sync", method: "POST", body: body, authenticated: true)
    }

    // MARK: - Stats Endpoints

    struct StatsResponse: Decodable {
        let totalPlaces: Int
        let countriesCount: Int
        let usStatesCount: Int
        let canadianProvincesCount: Int
    }

    func getStats() async throws -> StatsResponse {
        try await request("/places/stats", authenticated: true)
    }

    // MARK: - Health Check

    struct HealthResponse: Decodable {
        let status: String
        let service: String
    }

    func healthCheck() async throws -> HealthResponse {
        try await request("/health")
    }
}

// Empty response for DELETE operations
private struct EmptyResponse: Decodable {}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)

        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
