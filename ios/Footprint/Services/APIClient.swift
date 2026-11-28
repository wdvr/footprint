import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case serverError(Int, String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to parse response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            // Try to extract detail from JSON error response
            if let data = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = json["detail"] as? String {
                return "Error \(code): \(detail)"
            }
            return "Error \(code): \(message)"
        case .unauthorized:
            return "Not authenticated. Please sign in again."
        }
    }

    /// Error code for debugging (shown to user)
    var errorCode: String {
        switch self {
        case .invalidURL: return "URL_INVALID"
        case .noData: return "NO_DATA"
        case .decodingError: return "DECODE_FAIL"
        case .networkError: return "NETWORK"
        case .serverError(let code, _): return "HTTP_\(code)"
        case .unauthorized: return "UNAUTH"
        }
    }
}

actor APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let urlSession: URLSession
    private let sessionStore: AuthSessionStore
    private let now: @Sendable () -> Date

    private var session: AuthSession?
    /// In-flight refresh shared by every caller, so concurrent requests rotate the
    /// refresh token exactly once.
    private var refreshTask: Task<AuthSession, Error>?
    private var onSessionRevoked: (@Sendable () async -> Void)?

    init(
        baseURL: String = "https://api.footprintmaps.com",
        urlSession: URLSession = .shared,
        sessionStore: AuthSessionStore = KeychainAuthSessionStore(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.sessionStore = sessionStore
        self.now = now
        // Load synchronously so callers (e.g. launch sync) see the stored session
        // immediately, before AuthManager's background restore runs.
        self.session = sessionStore.load()
    }

    // MARK: - Session Management

    /// Called when the server rejects the refresh token (revoked, expired, or the
    /// account is gone) and the stored session has been wiped.
    func setSessionRevokedHandler(_ handler: (@Sendable () async -> Void)?) {
        onSessionRevoked = handler
    }

    /// Synchronous Keychain check so launch can show the signed-in UI immediately.
    nonisolated func hasStoredSession() -> Bool {
        sessionStore.load() != nil
    }

    func setTokens(access: String, refresh: String, expiresIn: Int? = nil) {
        storeSession(AuthSession(accessToken: access, refreshToken: refresh, expiresIn: expiresIn, now: now()))
    }

    private func storeSession(_ newSession: AuthSession) {
        session = newSession
        sessionStore.save(newSession)
        Log.api.debug("Session stored")
    }

    func loadStoredTokens() {
        session = sessionStore.load()
        if session != nil {
            Log.api.debug("Loaded stored session")
        } else {
            Log.api.debug("No stored session found")
        }
    }

    func clearTokens() {
        session = nil
        sessionStore.clear()
        Log.api.debug("Session cleared")
    }

    var isAuthenticated: Bool {
        session != nil
    }

    /// Current stored session, for tests and diagnostics.
    var currentSession: AuthSession? {
        session
    }

    /// Wipes the local session, then best-effort revokes it server-side.
    func logout() async {
        guard let refreshToken = session?.refreshToken else {
            clearTokens()
            return
        }
        clearTokens()
        struct LogoutRequest: Encodable {
            let refreshToken: String
        }
        do {
            let _: EmptyResponse = try await _request(
                "/auth/logout",
                method: "POST",
                body: LogoutRequest(refreshToken: refreshToken),
                timeout: 10
            )
        } catch {
            Log.api.info("Server-side logout failed (session already wiped locally): \(error)")
        }
    }

    /// Refreshes the access token if it is expired or close to expiry.
    func refreshIfNeeded() async {
        guard let session, session.needsRefresh(now: now()) else { return }
        _ = try? await refreshSession(rejecting: session.accessToken)
    }

    /// Returns an access token that is not about to expire, refreshing first if needed.
    /// A transient refresh failure falls back to the current token while it is still valid.
    private func validAccessToken() async throws -> String {
        guard let session else { throw APIError.unauthorized }
        guard session.needsRefresh(now: now()) else { return session.accessToken }
        do {
            return try await refreshSession(rejecting: session.accessToken).accessToken
        } catch APIError.unauthorized {
            throw APIError.unauthorized
        } catch {
            if !session.isAccessTokenExpired(now: now()) { return session.accessToken }
            throw error
        }
    }

    /// Exchanges the refresh token for a new session. `rejecting` is the access token
    /// the caller found unusable; if another caller already replaced it, that newer
    /// session is returned without another round trip.
    private func refreshSession(rejecting staleAccessToken: String) async throws -> AuthSession {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard let current = session else { throw APIError.unauthorized }
        if current.accessToken != staleAccessToken, !current.needsRefresh(now: now()) {
            return current
        }
        let task = Task { try await self.performRefresh(using: current.refreshToken) }
        refreshTask = task
        return try await task.value
    }

    private func performRefresh(using refreshToken: String) async throws -> AuthSession {
        defer { refreshTask = nil }
        struct RefreshRequest: Encodable {
            let refreshToken: String
        }
        Log.api.debug("Performing token refresh...")
        do {
            let tokens: TokensResponse = try await _request(
                "/auth/refresh",
                method: "POST",
                body: RefreshRequest(refreshToken: refreshToken)
            )
            // Signed out while the refresh was in flight: don't resurrect the session.
            guard session?.refreshToken == refreshToken else { throw APIError.unauthorized }
            let refreshed = AuthSession(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                expiresIn: tokens.expiresIn,
                now: now()
            )
            storeSession(refreshed)
            Log.api.info("Token refresh completed successfully")
            return refreshed
        } catch APIError.unauthorized {
            if session?.refreshToken == refreshToken {
                Log.auth.info("Refresh token rejected by server - session ended")
                clearTokens()
                await onSessionRevoked?()
            }
            throw APIError.unauthorized
        }
    }

    // MARK: - HTTP Methods

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    /// Public request method for API calls with automatic token refresh
    func request<T: Decodable>(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        authenticated: Bool = true,
        timeout: TimeInterval = 60
    ) async throws -> T {
        return try await _requestWithRetry(
            path,
            method: method.rawValue,
            body: body,
            authenticated: authenticated,
            timeout: timeout
        )
    }

    /// Sends a request, refreshing the access token up front when it is near expiry
    /// and once more on a 401. Only a rejected refresh token ends the session;
    /// network and server errors leave the user signed in.
    private func _requestWithRetry<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        authenticated: Bool = false,
        timeout: TimeInterval = 60
    ) async throws -> T {
        guard authenticated else {
            return try await _request(path, method: method, body: body, timeout: timeout)
        }
        let token = try await validAccessToken()
        do {
            return try await _request(path, method: method, body: body, accessToken: token, timeout: timeout)
        } catch APIError.unauthorized {
            Log.api.info("401 received, attempting token refresh...")
            let refreshed = try await refreshSession(rejecting: token)
            return try await _request(
                path, method: method, body: body, accessToken: refreshed.accessToken, timeout: timeout
            )
        }
    }

    private func _request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        accessToken: String? = nil,
        timeout: TimeInterval = 60
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            request.httpBody = try encoder.encode(body)
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "Invalid response", code: 0))
        }

        Log.api.debug("\(method) \(path) - Response: \(httpResponse.statusCode)")
        switch httpResponse.statusCode {
        case 204:
            if let empty = EmptyResponse() as? T { return empty }
            fallthrough
        case 200...299:
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        case 401:
            Log.api.error("\(method) \(path) - 401 Unauthorized!")
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            Log.api.error("\(method) \(path) - Error: \(httpResponse.statusCode)")
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }

    // MARK: - Auth Endpoints

    struct AppleAuthRequest: Encodable {
        let identityToken: String
        let authorizationCode: String
    }

    struct AuthResponse: Decodable {
        let user: UserResponse
        let tokens: TokensResponse
    }

    struct TokensResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let tokenType: String
        let expiresIn: Int
    }

    struct UserResponse: Decodable {
        let userId: String
        let appleUserId: String?
        let email: String?
        let displayName: String?
        let authProvider: String?
        let createdAt: Date?
        let countriesVisited: Int?
        let usStatesVisited: Int?
        let canadianProvincesVisited: Int?
    }

    func authenticateWithApple(identityToken: String, authorizationCode: String) async throws -> AuthResponse {
        let body = AppleAuthRequest(identityToken: identityToken, authorizationCode: authorizationCode)
        let response: AuthResponse = try await _request("/auth/apple", method: "POST", body: body)
        setTokens(access: response.tokens.accessToken, refresh: response.tokens.refreshToken, expiresIn: response.tokens.expiresIn)
        return response
    }

    struct GoogleAuthRequest: Encodable {
        let idToken: String
    }

    func authenticateWithGoogle(idToken: String) async throws -> AuthResponse {
        let body = GoogleAuthRequest(idToken: idToken)
        let response: AuthResponse = try await _request("/auth/google", method: "POST", body: body)
        setTokens(access: response.tokens.accessToken, refresh: response.tokens.refreshToken, expiresIn: response.tokens.expiresIn)
        return response
    }

    /// Forces a refresh. `/auth/refresh` returns a bare token pair (no user).
    func refreshAccessToken() async throws {
        guard let session else { throw APIError.unauthorized }
        _ = try await refreshSession(rejecting: session.accessToken)
    }

    func getCurrentUser() async throws -> UserResponse {
        try await _requestWithRetry("/auth/me", authenticated: true)
    }

    func deleteAccount() async throws {
        let _: EmptyResponse = try await request(path: "/auth/me", method: .delete, authenticated: true)
        // The server deleted every session; drop ours too.
        clearTokens()
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
        let status: String?
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
        let response: PlacesListResponse = try await request(path: "/places", authenticated: true)
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
        return try await request(path: "/places", method: .post, body: body, authenticated: true)
    }

    func deleteVisitedPlace(regionType: String, regionCode: String) async throws {
        let _: EmptyResponse = try await request(path: "/places/\(regionType)/\(regionCode)", method: .delete, authenticated: true)
    }

    func deleteAllPlaces() async throws {
        let _: EmptyResponse = try await request(path: "/places/all", method: .delete, authenticated: true)
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
        let status: String
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
        return try await request(path: "/sync/simple", method: .post, body: body, authenticated: true)
    }

    // MARK: - Stats Endpoints

    struct StatsResponse: Decodable {
        let totalPlaces: Int
        let countriesCount: Int
        let usStatesCount: Int
        let canadianProvincesCount: Int
    }

    func getStats() async throws -> StatsResponse {
        try await request(path: "/places/stats", authenticated: true)
    }

    // MARK: - Health Check

    struct HealthResponse: Decodable {
        let status: String
        let service: String
    }

    func healthCheck() async throws -> HealthResponse {
        try await request(path: "/health", authenticated: false)
    }
}

// Empty response for DELETE operations
private struct EmptyResponse: Decodable {}

// MARK: - Keychain Helper

enum KeychainHelper {
    static let defaultService = "com.wouterdevriendt.footprint"

    static func save(key: String, value: String, service: String = defaultService) {
        guard let data = value.data(using: .utf8) else {
            Log.keychain.error("Failed to convert value to data for key: \(key)")
            return
        }

        // First, try to delete any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Now add the new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Log.keychain.error("Failed to save key '\(key)': \(status)")
        } else {
            Log.keychain.debug("Successfully saved key: \(key)")
        }
    }

    static func load(key: String, service: String = defaultService) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            Log.keychain.debug("Successfully loaded key: \(key)")
            return String(data: data, encoding: .utf8)
        } else if status == errSecItemNotFound {
            Log.keychain.debug("Key not found: \(key)")
        } else {
            Log.keychain.error("Failed to load key '\(key)': \(status)")
        }
        return nil
    }

    static func delete(key: String, service: String = defaultService) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            Log.keychain.debug("Deleted key: \(key)")
        } else {
            Log.keychain.error("Failed to delete key '\(key)': \(status)")
        }
    }
}
