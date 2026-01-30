import XCTest
@testable import Footprint

final class TokenRefreshTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        Task {
            // Clear any existing tokens
            await APIClient.shared.clearTokens()
        }
    }
    
    override func tearDown() {
        Task {
            // Clean up after tests
            await APIClient.shared.clearTokens()
        }
        super.tearDown()
    }
    
    func testTokenRefreshFlow() async throws {
        // Test initial state - should not be authenticated
        let client = APIClient.shared
        let isAuthenticatedInitial = await client.isAuthenticated
        XCTAssertFalse(isAuthenticatedInitial, "Should not be authenticated after clearing")
        
        // Set some test tokens
        await client.setTokens(access: "test-access-token", refresh: "test-refresh-token")
        
        let isAuthenticatedAfterTokens = await client.isAuthenticated 
        XCTAssertTrue(isAuthenticatedAfterTokens, "Should be authenticated after setting tokens")
        
        // Clear tokens to test unauthenticated state
        await client.clearTokens()
        let isAuthenticatedAfterClear = await client.isAuthenticated
        XCTAssertFalse(isAuthenticatedAfterClear, "Should not be authenticated after clearing tokens")
    }
    
    func testTokenStorage() async throws {
        let client = APIClient.shared
        
        // Test setting tokens
        await client.setTokens(access: "access123", refresh: "refresh456")
        let isAuthenticated = await client.isAuthenticated
        XCTAssertTrue(isAuthenticated, "Should be authenticated after setting valid tokens")
        
        // Test clearing tokens
        await client.clearTokens()
        let isAuthenticatedAfterClear = await client.isAuthenticated
        XCTAssertFalse(isAuthenticatedAfterClear, "Should not be authenticated after clearing")
    }
}
