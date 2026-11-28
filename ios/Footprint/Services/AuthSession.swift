import Foundation

/// A signed-in backend session: the bearer token plus the rotating refresh token.
struct AuthSession: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    /// When the access token stops being accepted. `nil` if unknown, in which case
    /// the client relies on a 401 to trigger a refresh.
    var accessTokenExpiresAt: Date?

    /// Refresh this long before the access token actually expires, so requests
    /// never go out with a token that dies in flight.
    static let refreshLeeway: TimeInterval = 5 * 60

    init(accessToken: String, refreshToken: String, accessTokenExpiresAt: Date?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
    }

    /// Builds a session from a token response. Prefers the server's `expires_in`
    /// (measured from local receipt, so immune to device clock skew) over the JWT `exp`.
    init(accessToken: String, refreshToken: String, expiresIn: Int?, now: Date) {
        let expiresAt = expiresIn.map { now.addingTimeInterval(TimeInterval($0)) }
            ?? Self.jwtExpiry(accessToken)
        self.init(accessToken: accessToken, refreshToken: refreshToken, accessTokenExpiresAt: expiresAt)
    }

    func needsRefresh(now: Date) -> Bool {
        guard let accessTokenExpiresAt else { return false }
        return now >= accessTokenExpiresAt.addingTimeInterval(-Self.refreshLeeway)
    }

    func isAccessTokenExpired(now: Date) -> Bool {
        guard let accessTokenExpiresAt else { return false }
        return now >= accessTokenExpiresAt
    }

    /// Reads the `exp` claim of a JWT without verifying it.
    static func jwtExpiry(_ token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? NSNumber
        else { return nil }
        return Date(timeIntervalSince1970: exp.doubleValue)
    }
}

/// Persistence for the signed-in session.
protocol AuthSessionStore: Sendable {
    func load() -> AuthSession?
    func save(_ session: AuthSession)
    func clear()
}

/// Stores the session as a single Keychain item (never UserDefaults), readable
/// after first unlock so background refreshes and launches work.
struct KeychainAuthSessionStore: AuthSessionStore {
    static let sessionKey = "authSession"
    // Pre-session builds stored the two tokens as separate items.
    static let legacyAccessTokenKey = "accessToken"
    static let legacyRefreshTokenKey = "refreshToken"

    var service: String = KeychainHelper.defaultService

    func load() -> AuthSession? {
        if let json = KeychainHelper.load(key: Self.sessionKey, service: service),
           let data = json.data(using: .utf8),
           let session = try? JSONDecoder().decode(AuthSession.self, from: data)
        {
            return session
        }
        return migrateLegacyTokens()
    }

    func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session),
              let json = String(data: data, encoding: .utf8)
        else {
            Log.keychain.error("Failed to encode auth session")
            return
        }
        KeychainHelper.save(key: Self.sessionKey, value: json, service: service)
    }

    func clear() {
        KeychainHelper.delete(key: Self.sessionKey, service: service)
        KeychainHelper.delete(key: Self.legacyAccessTokenKey, service: service)
        KeychainHelper.delete(key: Self.legacyRefreshTokenKey, service: service)
    }

    private func migrateLegacyTokens() -> AuthSession? {
        guard let access = KeychainHelper.load(key: Self.legacyAccessTokenKey, service: service),
              let refresh = KeychainHelper.load(key: Self.legacyRefreshTokenKey, service: service)
        else { return nil }
        let session = AuthSession(
            accessToken: access,
            refreshToken: refresh,
            accessTokenExpiresAt: AuthSession.jwtExpiry(access)
        )
        save(session)
        KeychainHelper.delete(key: Self.legacyAccessTokenKey, service: service)
        KeychainHelper.delete(key: Self.legacyRefreshTokenKey, service: service)
        Log.keychain.info("Migrated legacy Keychain tokens to auth session")
        return session
    }
}
