import XCTest
@testable import Footprint

/// Tests for automatic token refresh functionality
final class TokenRefreshTests: XCTestCase {
    
    override func setUp() async throws {
        await APIClient.shared.clearTokens()
    }
    
    override func tearDown() async throws {
        await APIClient.shared.clearTokens()
    }
    
    // MARK: - Token Storage Tests
    
    func testTokenStorage() async {
        // Test setting and retrieving tokens
        await APIClient.shared.setTokens(
            access: "test-access-token",
            refresh: "test-refresh-token"
        )
        
        let isAuth = await APIClient.shared.isAuthenticated
        XCTAssertTrue(isAuth, "Should be authenticated after setting tokens")
        
        // Test loading stored tokens
        await APIClient.shared.clearTokens()
        XCTAssertFalse(await APIClient.shared.isAuthenticated, "Should not be authenticated after clearing")
        
        await APIClient.shared.loadStoredTokens()
        XCTAssertTrue(await APIClient.shared.isAuthenticated, "Should be authenticated after loading stored tokens")
    }
    
    func testTokenClear() async {
        await APIClient.shared.setTokens(
            access: "test-access",
            refresh: "test-refresh"
        )
        
        XCTAssertTrue(await APIClient.shared.isAuthenticated)
        
        await APIClient.shared.clearTokens()
        XCTAssertFalse(await APIClient.shared.isAuthenticated)
    }
    
    // MARK: - API Error Handling Tests
    
    func testAPIErrorProperties() {
        let errors: [APIError] = [
            .invalidURL,
            .noData,
            .decodingError,
            .unauthorized,
            .networkError(NSError(domain: "test", code: 1)),
            .serverError(500, "Internal Server Error"),
            .serverError(400, #"{"detail": "Bad Request"}"#)
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description")
            XCTAssertNotNil(error.errorCode, "Error should have code")
        }
        
        // Test JSON error extraction
        let jsonError = APIError.serverError(400, #"{"detail": "Validation failed"}"#)
        XCTAssertTrue(jsonError.errorDescription?.contains("Validation failed") == true, 
                      "Should extract detail from JSON error")
    }
    
    // MARK: - Authentication Flow Tests
    
    func testAppleAuthRequestEncoding() throws {
        let request = APIClient.AppleAuthRequest(
            identityToken: "test.identity.token",
            authorizationCode: "auth123"
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: String]
        
        XCTAssertEqual(json["identity_token"], "test.identity.token")
        XCTAssertEqual(json["authorization_code"], "auth123")
    }
    
    func testGoogleAuthRequestEncoding() throws {
        let request = APIClient.GoogleAuthRequest(idToken: "test.google.token")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: String]
        
        XCTAssertEqual(json["id_token"], "test.google.token")
    }
    
    func testAuthResponseDecoding() throws {
        let json = """
        {
            "user": {
                "user_id": "usr123",
                "email": "test@example.com",
                "display_name": "Test User",
                "auth_provider": "apple",
                "created_at": "2024-01-01T00:00:00Z"
            },
            "tokens": {
                "access_token": "access.token.here",
                "refresh_token": "refresh.token.here",
                "token_type": "Bearer",
                "expires_in": 3600
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode(APIClient.AuthResponse.self, from: json)
        
        XCTAssertEqual(response.user.userId, "usr123")
        XCTAssertEqual(response.user.email, "test@example.com")
        XCTAssertEqual(response.user.authProvider, "apple")
        XCTAssertEqual(response.tokens.accessToken, "access.token.here")
        XCTAssertEqual(response.tokens.refreshToken, "refresh.token.here")
        XCTAssertEqual(response.tokens.tokenType, "Bearer")
        XCTAssertEqual(response.tokens.expiresIn, 3600)
    }
    
    // MARK: - HTTP Method Tests
    
    func testHTTPMethods() {
        XCTAssertEqual(APIClient.HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(APIClient.HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(APIClient.HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(APIClient.HTTPMethod.delete.rawValue, "DELETE")
    }
    
    // MARK: - Places API Model Tests
    
    func testVisitedPlaceRequestEncoding() throws {
        let request = APIClient.VisitedPlaceRequest(
            regionType: "country",
            regionCode: "JP",
            regionName: "Japan",
            visitedDate: Date(timeIntervalSince1970: 1704067200), // 2024-01-01
            notes: "Amazing culture!"
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["region_type"] as? String, "country")
        XCTAssertEqual(json["region_code"] as? String, "JP")
        XCTAssertEqual(json["region_name"] as? String, "Japan")
        XCTAssertEqual(json["notes"] as? String, "Amazing culture!")
        XCTAssertNotNil(json["visited_date"])
    }
    
    func testVisitedPlaceResponseDecoding() throws {
        let json = """
        {
            "id": "place456",
            "region_type": "us_state",
            "region_code": "CA",
            "region_name": "California",
            "status": "visited",
            "visited_date": "2024-06-15T12:00:00Z",
            "notes": "Beautiful coast",
            "created_at": "2024-06-15T12:00:00Z",
            "updated_at": "2024-06-15T12:00:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode(APIClient.VisitedPlaceResponse.self, from: json)
        
        XCTAssertEqual(response.id, "place456")
        XCTAssertEqual(response.regionType, "us_state")
        XCTAssertEqual(response.regionCode, "CA")
        XCTAssertEqual(response.regionName, "California")
        XCTAssertEqual(response.status, "visited")
        XCTAssertEqual(response.notes, "Beautiful coast")
        XCTAssertNotNil(response.visitedDate)
        XCTAssertNotNil(response.createdAt)
        XCTAssertNotNil(response.updatedAt)
    }
    
    // MARK: - Sync Model Tests
    
    func testPlaceChangeEncoding() throws {
        let change = APIClient.PlaceChange(
            regionType: "canadian_province",
            regionCode: "BC",
            regionName: "British Columbia",
            status: "visited",
            isDeleted: false,
            lastModifiedAt: Date(timeIntervalSince1970: 1704067200)
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(change)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["region_type"] as? String, "canadian_province")
        XCTAssertEqual(json["region_code"] as? String, "BC")
        XCTAssertEqual(json["region_name"] as? String, "British Columbia")
        XCTAssertEqual(json["status"] as? String, "visited")
        XCTAssertEqual(json["is_deleted"] as? Bool, false)
        XCTAssertNotNil(json["last_modified_at"])
    }
    
    func testSyncRequestEncoding() throws {
        let changes = [
            APIClient.PlaceChange(
                regionType: "country",
                regionCode: "IT",
                regionName: "Italy",
                status: "visited",
                isDeleted: false,
                lastModifiedAt: Date()
            )
        ]
        
        let request = APIClient.SyncRequest(
            lastSyncAt: Date(timeIntervalSince1970: 1704067200),
            changes: changes
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertNotNil(json["last_sync_at"])
        XCTAssertEqual((json["changes"] as? [[String: Any]])?.count, 1)
    }
    
    func testSyncResponseDecoding() throws {
        let json = """
        {
            "server_changes": [
                {
                    "id": "srv1",
                    "region_type": "country",
                    "region_code": "ES",
                    "region_name": "Spain",
                    "visited_date": null,
                    "notes": null,
                    "created_at": "2024-01-01T00:00:00Z",
                    "updated_at": "2024-01-01T00:00:00Z"
                }
            ],
            "synced_at": "2024-01-15T15:30:00Z",
            "conflicts_resolved": 2
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode(APIClient.SyncResponse.self, from: json)
        
        XCTAssertEqual(response.serverChanges.count, 1)
        XCTAssertEqual(response.serverChanges[0].regionCode, "ES")
        XCTAssertEqual(response.conflictsResolved, 2)
        XCTAssertNotNil(response.syncedAt)
    }
    
    // MARK: - Stats Model Tests
    
    func testStatsResponseDecoding() throws {
        let json = """
        {
            "total_places": 42,
            "countries_count": 15,
            "us_states_count": 20,
            "canadian_provinces_count": 7
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = try decoder.decode(APIClient.StatsResponse.self, from: json)
        
        XCTAssertEqual(response.totalPlaces, 42)
        XCTAssertEqual(response.countriesCount, 15)
        XCTAssertEqual(response.usStatesCount, 20)
        XCTAssertEqual(response.canadianProvincesCount, 7)
    }
    
    // MARK: - Health Check Tests
    
    func testHealthResponseDecoding() throws {
        let json = """
        {
            "status": "healthy",
            "service": "footprint-api-v2"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let response = try decoder.decode(APIClient.HealthResponse.self, from: json)
        
        XCTAssertEqual(response.status, "healthy")
        XCTAssertEqual(response.service, "footprint-api-v2")
    }
}

// MARK: - AuthManager Tests

final class AuthManagerTests: XCTestCase {
    
    var authManager: AuthManager!
    
    @MainActor
    override func setUp() async throws {
        authManager = AuthManager()
        await authManager.signOut() // Reset state
    }
    
    @MainActor
    override func tearDown() async throws {
        await authManager.signOut()
        authManager = nil
    }
    
    @MainActor
    func testInitialState() {
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertFalse(authManager.isLoading)
        XCTAssertFalse(authManager.isOfflineMode)
        XCTAssertNil(authManager.user)
        XCTAssertNil(authManager.error)
    }
    
    @MainActor
    func testOfflineMode() {
        authManager.continueWithoutAccount()
        
        XCTAssertTrue(authManager.isOfflineMode)
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "offline_mode"))
    }
    
    @MainActor
    func testSignOut() async {
        // Set up offline mode
        authManager.continueWithoutAccount()
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertTrue(authManager.isOfflineMode)
        
        // Sign out
        await authManager.signOut()
        
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertFalse(authManager.isOfflineMode)
        XCTAssertNil(authManager.user)
        XCTAssertNil(authManager.error)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "offline_mode"))
    }
    
    @MainActor
    func testAuthenticationValidation() async {
        // Test without tokens
        let isValidWithoutTokens = await authManager.validateAuthentication()
        XCTAssertFalse(isValidWithoutTokens)
        
        // Note: We can't easily test with valid tokens without mocking the API
        // This would require dependency injection or a test configuration
    }
    
    @MainActor
    func testHandleAuthenticationError() {
        authManager.handleAuthenticationError()
        // This method triggers async validation, but we can't easily test the result
        // without mocking the API calls
    }
}

// MARK: - Google Sign In Configuration Tests

final class GoogleSignInConfigTests: XCTestCase {
    
    func testGoogleSignInConfiguration() {
        XCTAssertFalse(GoogleSignInConfig.clientId.isEmpty)
        XCTAssertFalse(GoogleSignInConfig.callbackScheme.isEmpty)
        XCTAssertFalse(GoogleSignInConfig.redirectUri.isEmpty)
        XCTAssertFalse(GoogleSignInConfig.scopes.isEmpty)
        
        // Validate format
        XCTAssertTrue(GoogleSignInConfig.clientId.contains("apps.googleusercontent.com"))
        XCTAssertTrue(GoogleSignInConfig.callbackScheme.contains("com.googleusercontent.apps"))
        XCTAssertTrue(GoogleSignInConfig.redirectUri.contains("oauth2callback"))
        
        // Validate required scopes
        XCTAssertTrue(GoogleSignInConfig.scopes.contains("openid"))
        XCTAssertTrue(GoogleSignInConfig.scopes.contains("email"))
        XCTAssertTrue(GoogleSignInConfig.scopes.contains("profile"))
    }
}

// MARK: - Google Sign In Error Tests

final class GoogleSignInErrorTests: XCTestCase {
    
    func testGoogleSignInErrors() {
        let errors: [GoogleSignInError] = [
            .cancelled,
            .invalidURL,
            .noIdToken,
            .sessionFailed,
            .tokenExchangeFailed("Test error details")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description")
        }
        
        // Test specific error message
        let exchangeError = GoogleSignInError.tokenExchangeFailed("Network timeout")
        XCTAssertTrue(exchangeError.errorDescription?.contains("Network timeout") == true,
                      "Should include error details")
    }
}
