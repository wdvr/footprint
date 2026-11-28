import XCTest
@testable import Footprint

// MARK: - Test doubles

/// Routes every request of an injected URLSession to `handler`, recording what was sent.
final class AuthMockURLProtocol: URLProtocol {
    struct Recorded {
        let method: String
        let path: String
        let authorization: String?
        let body: [String: Any]
    }

    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (Int, String)) = { _ in (500, "") }
    nonisolated(unsafe) static var recorded: [Recorded] = []
    private static let lock = NSLock()

    static func reset() {
        lock.withLock {
            handler = { _ in (500, "") }
            recorded = []
        }
    }

    static var requests: [Recorded] { lock.withLock { recorded } }

    static func paths() -> [String] { requests.map(\.path) }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.readBody(request)
        let handler = Self.lock.withLock {
            Self.recorded.append(Recorded(
                method: request.httpMethod ?? "GET",
                path: request.url?.path ?? "",
                authorization: request.value(forHTTPHeaderField: "Authorization"),
                body: body
            ))
            return Self.handler
        }
        do {
            let (status, json) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(json.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func readBody(_ request: URLRequest) -> [String: Any] {
        var data = request.httpBody ?? Data()
        if data.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}

final class InMemoryAuthSessionStore: AuthSessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: AuthSession?

    init(_ session: AuthSession? = nil) { stored = session }

    func load() -> AuthSession? { lock.withLock { stored } }
    func save(_ session: AuthSession) { lock.withLock { stored = session } }
    func clear() { lock.withLock { stored = nil } }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_800_000_000)
    var now: Date {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}

final class RevocationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.withLock { value += 1 } }
    var count: Int { lock.withLock { value } }
}

enum AuthFixtures {
    static let userJSON = """
    {"user_id": "usr-1", "email": "owner@example.com", "display_name": "Owner", \
    "auth_provider": "apple", "countries_visited": 3, "us_states_visited": 2, "canadian_provinces_visited": 1}
    """

    static func tokensJSON(access: String, refresh: String, expiresIn: Int = 3600) -> String {
        """
        {"access_token": "\(access)", "refresh_token": "\(refresh)", "token_type": "bearer", "expires_in": \(expiresIn)}
        """
    }

    static func makeClient(store: AuthSessionStore, clock: TestClock) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthMockURLProtocol.self]
        return APIClient(
            baseURL: "https://api.test",
            urlSession: URLSession(configuration: config),
            sessionStore: store,
            now: { clock.now }
        )
    }

    /// Serves `/auth/refresh` (rotating to new-access/new-refresh) and `/auth/me`
    /// (200 only for `acceptedToken`, otherwise 401).
    static func serveRefreshAndMe(refreshStatus: Int = 200, acceptedToken: String = "new-access") {
        AuthMockURLProtocol.handler = { request in
            switch request.url?.path {
            case "/auth/refresh":
                return refreshStatus == 200
                    ? (200, tokensJSON(access: "new-access", refresh: "new-refresh"))
                    : (refreshStatus, #"{"detail": "Invalid or expired refresh token"}"#)
            case "/auth/me":
                let auth = request.value(forHTTPHeaderField: "Authorization")
                return auth == "Bearer \(acceptedToken)" ? (200, userJSON) : (401, #"{"detail": "expired"}"#)
            case "/auth/logout":
                return (204, "")
            default:
                return (404, "")
            }
        }
    }
}

// MARK: - Session persistence, refresh, revocation, logout

final class AuthSessionTests: XCTestCase {
    private var clock: TestClock!

    override func setUp() {
        super.setUp()
        AuthMockURLProtocol.reset()
        clock = TestClock()
    }

    override func tearDown() {
        AuthMockURLProtocol.reset()
        super.tearDown()
    }

    private func session(expiresIn seconds: TimeInterval?) -> AuthSession {
        AuthSession(
            accessToken: "old-access",
            refreshToken: "old-refresh",
            accessTokenExpiresAt: seconds.map { clock.now.addingTimeInterval($0) }
        )
    }

    // MARK: Restore on launch

    func testRestoreOnLaunchLoadsStoredSession() async {
        let stored = session(expiresIn: 3000)
        let client = AuthFixtures.makeClient(store: InMemoryAuthSessionStore(stored), clock: clock)

        XCTAssertTrue(client.hasStoredSession())
        await client.loadStoredTokens()

        let isAuthenticated = await client.isAuthenticated
        let current = await client.currentSession
        XCTAssertTrue(isAuthenticated)
        XCTAssertEqual(current, stored)
        XCTAssertTrue(AuthMockURLProtocol.requests.isEmpty, "Restoring must not hit the network")
    }

    func testRestoreOnLaunchWithoutStoredSessionStaysSignedOut() async {
        let client = AuthFixtures.makeClient(store: InMemoryAuthSessionStore(), clock: clock)

        XCTAssertFalse(client.hasStoredSession())
        await client.loadStoredTokens()

        let isAuthenticated = await client.isAuthenticated
        XCTAssertFalse(isAuthenticated)
        XCTAssertTrue(AuthMockURLProtocol.requests.isEmpty)
    }

    func testSignInPersistsSessionWithServerExpiry() async throws {
        let store = InMemoryAuthSessionStore()
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        AuthMockURLProtocol.handler = { _ in
            (200, #"{"user": \#(AuthFixtures.userJSON), "tokens": \#(AuthFixtures.tokensJSON(access: "a1", refresh: "r1"))}"#)
        }

        _ = try await client.authenticateWithApple(identityToken: "id", authorizationCode: "code")

        XCTAssertEqual(store.load(), AuthSession(
            accessToken: "a1", refreshToken: "r1", accessTokenExpiresAt: clock.now.addingTimeInterval(3600)
        ))
    }

    // MARK: Refresh on expiry

    func testExpiredAccessTokenIsRefreshedBeforeRequest() async throws {
        let store = InMemoryAuthSessionStore(session(expiresIn: -60))
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        await client.loadStoredTokens()
        AuthFixtures.serveRefreshAndMe()

        let user = try await client.getCurrentUser()

        XCTAssertEqual(user.userId, "usr-1")
        let requests = AuthMockURLProtocol.requests
        XCTAssertEqual(requests.map(\.path), ["/auth/refresh", "/auth/me"])
        XCTAssertEqual(requests[0].body["refresh_token"] as? String, "old-refresh")
        XCTAssertNil(requests[0].authorization)
        XCTAssertEqual(requests[1].authorization, "Bearer new-access")
        XCTAssertEqual(store.load(), AuthSession(
            accessToken: "new-access", refreshToken: "new-refresh",
            accessTokenExpiresAt: clock.now.addingTimeInterval(3600)
        ), "Rotated tokens must be persisted")
    }

    func testAccessTokenNearExpiryIsRefreshedProactively() async throws {
        let client = AuthFixtures.makeClient(store: InMemoryAuthSessionStore(session(expiresIn: 60)), clock: clock)
        await client.loadStoredTokens()
        AuthFixtures.serveRefreshAndMe()

        _ = try await client.getCurrentUser()

        XCTAssertEqual(AuthMockURLProtocol.paths(), ["/auth/refresh", "/auth/me"])
    }

    func testFreshAccessTokenIsNotRefreshed() async throws {
        let client = AuthFixtures.makeClient(store: InMemoryAuthSessionStore(session(expiresIn: 3000)), clock: clock)
        await client.loadStoredTokens()
        AuthFixtures.serveRefreshAndMe(acceptedToken: "old-access")

        _ = try await client.getCurrentUser()

        XCTAssertEqual(AuthMockURLProtocol.paths(), ["/auth/me"])
    }

    func testRefreshIfNeededRefreshesInBackground() async {
        let store = InMemoryAuthSessionStore(session(expiresIn: 30))
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        await client.loadStoredTokens()
        AuthFixtures.serveRefreshAndMe()

        await client.refreshIfNeeded()

        XCTAssertEqual(AuthMockURLProtocol.paths(), ["/auth/refresh"])
        XCTAssertEqual(store.load()?.accessToken, "new-access")
    }

    func testUnauthorizedResponseTriggersRefreshAndRetry() async throws {
        let store = InMemoryAuthSessionStore(session(expiresIn: nil))
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        await client.loadStoredTokens()
        AuthFixtures.serveRefreshAndMe()

        let user = try await client.getCurrentUser()

        XCTAssertEqual(user.userId, "usr-1")
        XCTAssertEqual(AuthMockURLProtocol.paths(), ["/auth/me", "/auth/refresh", "/auth/me"])
        XCTAssertEqual(store.load()?.refreshToken, "new-refresh")
    }

    func testConcurrentRequestsShareASingleRefresh() async throws {
        let client = AuthFixtures.makeClient(store: InMemoryAuthSessionStore(session(expiresIn: -1)), clock: clock)
        await client.loadStoredTokens()
        AuthFixtures.serveRefreshAndMe()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { _ = try await client.getCurrentUser() }
            }
            try await group.waitForAll()
        }

        let refreshes = AuthMockURLProtocol.paths().filter { $0 == "/auth/refresh" }
        XCTAssertEqual(refreshes.count, 1, "A rotating refresh token must only be spent once")
    }

    // MARK: Fallback to login on revoked refresh

    func testRevokedRefreshTokenWipesSessionAndReportsRevocation() async {
        let store = InMemoryAuthSessionStore(session(expiresIn: -60))
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        let revocations = RevocationCounter()
        await client.setSessionRevokedHandler { revocations.increment() }
        await client.loadStoredTokens()
        AuthFixtures.serveRefreshAndMe(refreshStatus: 401)

        do {
            _ = try await client.getCurrentUser()
            XCTFail("Expected unauthorized")
        } catch APIError.unauthorized {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let isAuthenticated = await client.isAuthenticated
        XCTAssertFalse(isAuthenticated)
        XCTAssertNil(store.load(), "Revoked session must be wiped from the Keychain")
        XCTAssertEqual(revocations.count, 1)
    }

    func testServerErrorDuringRefreshKeepsSession() async {
        let stored = session(expiresIn: -60)
        let store = InMemoryAuthSessionStore(stored)
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        let revocations = RevocationCounter()
        await client.setSessionRevokedHandler { revocations.increment() }
        await client.loadStoredTokens()
        AuthFixtures.serveRefreshAndMe(refreshStatus: 503)

        do {
            _ = try await client.getCurrentUser()
            XCTFail("Expected server error")
        } catch APIError.serverError(let code, _) {
            XCTAssertEqual(code, 503)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let isAuthenticated = await client.isAuthenticated
        XCTAssertTrue(isAuthenticated)
        XCTAssertEqual(store.load(), stored)
        XCTAssertEqual(revocations.count, 0)
    }

    func testOfflineRefreshKeepsSessionAndUsesStillValidToken() async throws {
        let stored = session(expiresIn: 60) // inside the refresh leeway but not expired
        let store = InMemoryAuthSessionStore(stored)
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        await client.loadStoredTokens()
        AuthMockURLProtocol.handler = { request in
            if request.url?.path == "/auth/refresh" { throw URLError(.notConnectedToInternet) }
            return (200, AuthFixtures.userJSON)
        }

        let user = try await client.getCurrentUser()

        XCTAssertEqual(user.userId, "usr-1")
        XCTAssertEqual(AuthMockURLProtocol.requests.last?.authorization, "Bearer old-access")
        XCTAssertEqual(store.load(), stored)
    }

    // MARK: Logout / account deletion

    func testLogoutWipesSessionAndRevokesItServerSide() async {
        let store = InMemoryAuthSessionStore(session(expiresIn: 3000))
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        await client.loadStoredTokens()
        AuthFixtures.serveRefreshAndMe()

        await client.logout()

        let isAuthenticated = await client.isAuthenticated
        XCTAssertFalse(isAuthenticated)
        XCTAssertNil(store.load())
        let requests = AuthMockURLProtocol.requests
        XCTAssertEqual(requests.map(\.path), ["/auth/logout"])
        XCTAssertEqual(requests.first?.body["refresh_token"] as? String, "old-refresh")
    }

    func testLogoutWipesSessionEvenWhenOffline() async {
        let store = InMemoryAuthSessionStore(session(expiresIn: 3000))
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        await client.loadStoredTokens()
        AuthMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        await client.logout()

        XCTAssertNil(store.load())
    }

    func testDeleteAccountWipesSession() async throws {
        let store = InMemoryAuthSessionStore(session(expiresIn: 3000))
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        await client.loadStoredTokens()
        AuthMockURLProtocol.handler = { _ in (204, "") }

        try await client.deleteAccount()

        XCTAssertEqual(AuthMockURLProtocol.requests.first?.method, "DELETE")
        XCTAssertNil(store.load())
        let isAuthenticated = await client.isAuthenticated
        XCTAssertFalse(isAuthenticated)
    }

    // MARK: AuthSession

    func testJWTExpiryIsParsed() {
        // {"sub":"u","exp":1800003600,"type":"access"}
        let payload = Data(#"{"sub":"u","exp":1800003600,"type":"access"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        let token = "eyJhbGciOiJIUzI1NiJ9.\(payload).signature"

        XCTAssertEqual(AuthSession.jwtExpiry(token), Date(timeIntervalSince1970: 1_800_003_600))
        XCTAssertNil(AuthSession.jwtExpiry("not-a-jwt"))
    }

    func testNeedsRefreshHonorsLeeway() {
        XCTAssertFalse(session(expiresIn: AuthSession.refreshLeeway + 1).needsRefresh(now: clock.now))
        XCTAssertTrue(session(expiresIn: AuthSession.refreshLeeway - 1).needsRefresh(now: clock.now))
        XCTAssertTrue(session(expiresIn: -1).isAccessTokenExpired(now: clock.now))
        XCTAssertFalse(session(expiresIn: nil).needsRefresh(now: clock.now))
    }
}
