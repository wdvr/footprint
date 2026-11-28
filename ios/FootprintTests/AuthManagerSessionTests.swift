import XCTest
@testable import Footprint

/// App-level sign-in durability: what the user sees on launch, on a revoked
/// refresh token, and after signing out.
@MainActor
final class AuthManagerSessionTests: XCTestCase {
    private var clock: TestClock!

    override func setUp() async throws {
        AuthMockURLProtocol.reset()
        UserDefaults.standard.removeObject(forKey: "offline_mode")
        clock = TestClock()
    }

    override func tearDown() async throws {
        AuthMockURLProtocol.reset()
        UserDefaults.standard.removeObject(forKey: "offline_mode")
    }

    private func makeManager(stored: AuthSession?) -> (AuthManager, InMemoryAuthSessionStore) {
        let store = InMemoryAuthSessionStore(stored)
        let client = AuthFixtures.makeClient(store: store, clock: clock)
        return (AuthManager(api: client, restoreSessionOnInit: false), store)
    }

    private func storedSession(expiresIn seconds: TimeInterval) -> AuthSession {
        AuthSession(
            accessToken: "old-access",
            refreshToken: "old-refresh",
            accessTokenExpiresAt: clock.now.addingTimeInterval(seconds)
        )
    }

    func testRestoreOnLaunchOpensSignedInWithoutLoginScreen() async {
        let (manager, _) = makeManager(stored: storedSession(expiresIn: 3000))

        XCTAssertTrue(manager.isAuthenticated, "A stored session must skip the login screen from the first frame")

        AuthFixtures.serveRefreshAndMe(acceptedToken: "old-access")
        await manager.restoreSession()

        XCTAssertTrue(manager.isAuthenticated)
        XCTAssertEqual(manager.user?.userId, "usr-1")
        XCTAssertNil(manager.error)
    }

    func testRestoreOnLaunchRefreshesExpiredAccessToken() async {
        let (manager, store) = makeManager(stored: storedSession(expiresIn: -3600))
        AuthFixtures.serveRefreshAndMe()

        await manager.restoreSession()

        XCTAssertTrue(manager.isAuthenticated)
        XCTAssertEqual(manager.user?.userId, "usr-1")
        XCTAssertEqual(store.load()?.refreshToken, "new-refresh")
    }

    func testRestoreWhileOfflineStaysSignedIn() async {
        let stored = storedSession(expiresIn: -3600)
        let (manager, store) = makeManager(stored: stored)
        AuthMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        await manager.restoreSession()

        XCTAssertTrue(manager.isAuthenticated)
        XCTAssertNil(manager.error)
        XCTAssertEqual(store.load(), stored)
    }

    func testRevokedRefreshTokenFallsBackToLogin() async {
        let (manager, store) = makeManager(stored: storedSession(expiresIn: -3600))
        AuthFixtures.serveRefreshAndMe(refreshStatus: 401)

        await manager.restoreSession()

        XCTAssertFalse(manager.isAuthenticated)
        XCTAssertNil(manager.user)
        XCTAssertEqual(manager.error, AuthManager.sessionExpiredMessage)
        XCTAssertNil(store.load())
    }

    func testSignOutWipesKeychainSession() async {
        let (manager, store) = makeManager(stored: storedSession(expiresIn: 3000))
        AuthFixtures.serveRefreshAndMe(acceptedToken: "old-access")
        await manager.restoreSession()

        await manager.signOut()

        XCTAssertFalse(manager.isAuthenticated)
        XCTAssertNil(manager.user)
        XCTAssertNil(store.load())
        XCTAssertEqual(AuthMockURLProtocol.paths().last, "/auth/logout")
    }

    func testSignedOutUserStillSeesLogin() async {
        let (manager, _) = makeManager(stored: nil)

        XCTAssertFalse(manager.isAuthenticated)
        await manager.restoreSession()

        XCTAssertFalse(manager.isAuthenticated)
        XCTAssertNil(manager.error)
        XCTAssertTrue(AuthMockURLProtocol.requests.isEmpty)
    }
}

/// Keychain-backed persistence (real Keychain, isolated service name).
final class KeychainAuthSessionStoreTests: XCTestCase {
    private let store = KeychainAuthSessionStore(service: "com.wouterdevriendt.footprint.tests")

    override func setUp() {
        super.setUp()
        store.clear()
    }

    override func tearDown() {
        store.clear()
        super.tearDown()
    }

    func testSessionRoundTripsThroughKeychain() {
        let session = AuthSession(
            accessToken: "a", refreshToken: "r", accessTokenExpiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        store.save(session)

        XCTAssertEqual(store.load(), session)
        XCTAssertNil(UserDefaults.standard.object(forKey: KeychainAuthSessionStore.sessionKey))
    }

    func testClearRemovesSession() {
        store.save(AuthSession(accessToken: "a", refreshToken: "r", accessTokenExpiresAt: nil))

        store.clear()

        XCTAssertNil(store.load())
    }

    func testLegacyTokensAreMigratedSoExistingInstallsStaySignedIn() {
        KeychainHelper.save(key: KeychainAuthSessionStore.legacyAccessTokenKey, value: "legacy-a", service: store.service)
        KeychainHelper.save(key: KeychainAuthSessionStore.legacyRefreshTokenKey, value: "legacy-r", service: store.service)

        let migrated = store.load()

        XCTAssertEqual(migrated?.accessToken, "legacy-a")
        XCTAssertEqual(migrated?.refreshToken, "legacy-r")
        XCTAssertNil(KeychainHelper.load(key: KeychainAuthSessionStore.legacyAccessTokenKey, service: store.service))
        XCTAssertEqual(store.load(), migrated)
    }
}
