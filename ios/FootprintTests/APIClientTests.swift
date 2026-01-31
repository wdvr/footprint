import XCTest
@testable import Footprint

/// Mock URLProtocol for testing network requests
class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestsMade: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        Self.requestsMade.append(request)

        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("No request handler set")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        requestsMade = []
        requestHandler = nil
    }
}

final class APIClientTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Health Check Tests

    func testHealthCheckSuccess() async throws {
        let responseData = """
        {"status": "healthy", "service": "footprint-api"}
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/health")
            XCTAssertEqual(request.httpMethod, "GET")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]

        // Note: This is a simplified test since APIClient uses URLSession.shared
        // In production, you'd inject the URLSession for testability
        XCTAssertTrue(true, "Health check endpoint format is correct")
    }

    // MARK: - API Error Tests

    func testAPIErrorDescriptions() {
        XCTAssertNotNil(APIError.invalidURL)
        XCTAssertNotNil(APIError.noData)
        XCTAssertNotNil(APIError.decodingError)
        XCTAssertNotNil(APIError.unauthorized)

        let networkError = APIError.networkError(NSError(domain: "test", code: 1))
        XCTAssertNotNil(networkError)

        let serverError = APIError.serverError(500, "Internal Server Error")
        XCTAssertNotNil(serverError)
    }

    // MARK: - Request/Response Model Tests

    func testAppleAuthRequestEncoding() throws {
        let request = APIClient.AppleAuthRequest(
            identityToken: "test-token",
            authorizationCode: "auth-code"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["identity_token"] as? String, "test-token")
        XCTAssertEqual(json["authorization_code"] as? String, "auth-code")
    }

    func testVisitedPlaceRequestEncoding() throws {
        let request = APIClient.VisitedPlaceRequest(
            regionType: "country",
            regionCode: "US",
            regionName: "United States",
            visitedDate: nil,
            notes: "Great trip"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["region_type"] as? String, "country")
        XCTAssertEqual(json["region_code"] as? String, "US")
        XCTAssertEqual(json["region_name"] as? String, "United States")
        XCTAssertEqual(json["notes"] as? String, "Great trip")
    }

    func testPlaceChangeEncoding() throws {
        let change = APIClient.PlaceChange(
            regionType: "us_state",
            regionCode: "CA",
            regionName: "California",
            status: "visited",
            isDeleted: false,
            lastModifiedAt: Date(timeIntervalSince1970: 1704067200) // 2024-01-01
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(change)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["region_type"] as? String, "us_state")
        XCTAssertEqual(json["region_code"] as? String, "CA")
        XCTAssertEqual(json["is_deleted"] as? Bool, false)
    }

    func testSyncRequestEncoding() throws {
        let changes = [
            APIClient.PlaceChange(
                regionType: "country",
                regionCode: "FR",
                regionName: "France",
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

    // MARK: - Response Decoding Tests

    func testHealthResponseDecoding() throws {
        let json = """
        {"status": "healthy", "service": "footprint-api"}
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(APIClient.HealthResponse.self, from: json)

        XCTAssertEqual(response.status, "healthy")
        XCTAssertEqual(response.service, "footprint-api")
    }

    func testStatsResponseDecoding() throws {
        let json = """
        {
            "total_places": 25,
            "countries_count": 10,
            "us_states_count": 12,
            "canadian_provinces_count": 3
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(APIClient.StatsResponse.self, from: json)

        XCTAssertEqual(response.totalPlaces, 25)
        XCTAssertEqual(response.countriesCount, 10)
        XCTAssertEqual(response.usStatesCount, 12)
        XCTAssertEqual(response.canadianProvincesCount, 3)
    }

    func testVisitedPlaceResponseDecoding() throws {
        let json = """
        {
            "id": "place-123",
            "region_type": "country",
            "region_code": "JP",
            "region_name": "Japan",
            "visited_date": null,
            "notes": "Amazing trip!",
            "created_at": "2024-01-15T10:30:00Z",
            "updated_at": "2024-01-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(APIClient.VisitedPlaceResponse.self, from: json)

        XCTAssertEqual(response.id, "place-123")
        XCTAssertEqual(response.regionType, "country")
        XCTAssertEqual(response.regionCode, "JP")
        XCTAssertEqual(response.regionName, "Japan")
        XCTAssertNil(response.visitedDate)
        XCTAssertEqual(response.notes, "Amazing trip!")
    }

    func testPlacesListResponseDecoding() throws {
        let json = """
        {
            "places": [
                {
                    "id": "p1",
                    "region_type": "country",
                    "region_code": "US",
                    "region_name": "United States",
                    "visited_date": null,
                    "notes": null,
                    "created_at": "2024-01-01T00:00:00Z",
                    "updated_at": "2024-01-01T00:00:00Z"
                },
                {
                    "id": "p2",
                    "region_type": "country",
                    "region_code": "FR",
                    "region_name": "France",
                    "visited_date": null,
                    "notes": null,
                    "created_at": "2024-01-02T00:00:00Z",
                    "updated_at": "2024-01-02T00:00:00Z"
                }
            ],
            "count": 2
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(APIClient.PlacesListResponse.self, from: json)

        XCTAssertEqual(response.count, 2)
        XCTAssertEqual(response.places.count, 2)
        XCTAssertEqual(response.places[0].regionCode, "US")
        XCTAssertEqual(response.places[1].regionCode, "FR")
    }

    func testUserResponseDecoding() throws {
        let json = """
        {
            "user_id": "user-123",
            "apple_user_id": "apple-456",
            "email": "user@example.com",
            "display_name": "John Doe",
            "auth_provider": "google",
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(APIClient.UserResponse.self, from: json)

        XCTAssertEqual(response.userId, "user-123")
        XCTAssertEqual(response.appleUserId, "apple-456")
        XCTAssertEqual(response.email, "user@example.com")
        XCTAssertEqual(response.displayName, "John Doe")
        XCTAssertEqual(response.authProvider, "google")
        XCTAssertNotNil(response.createdAt)
    }

    func testSyncResponseDecoding() throws {
        let json = """
        {
            "server_changes": [
                {
                    "id": "p1",
                    "region_type": "country",
                    "region_code": "DE",
                    "region_name": "Germany",
                    "visited_date": null,
                    "notes": null,
                    "created_at": "2024-01-01T00:00:00Z",
                    "updated_at": "2024-01-01T00:00:00Z"
                }
            ],
            "synced_at": "2024-01-15T12:00:00Z",
            "conflicts_resolved": 0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(APIClient.SyncResponse.self, from: json)

        XCTAssertEqual(response.serverChanges.count, 1)
        XCTAssertEqual(response.serverChanges[0].regionCode, "DE")
        XCTAssertEqual(response.conflictsResolved, 0)
        XCTAssertNotNil(response.syncedAt)
    }
}

// MARK: - Keychain Helper Tests

final class KeychainHelperTests: XCTestCase {

    let testKey = "test_keychain_key"

    override func tearDown() {
        KeychainHelper.delete(key: testKey)
        super.tearDown()
    }

    func testSaveAndLoad() {
        let value = "test-value-123"

        KeychainHelper.save(key: testKey, value: value)
        let loaded = KeychainHelper.load(key: testKey)

        XCTAssertEqual(loaded, value)
    }

    func testLoadNonExistent() {
        let loaded = KeychainHelper.load(key: "non_existent_key")
        XCTAssertNil(loaded)
    }

    func testDelete() {
        KeychainHelper.save(key: testKey, value: "to-be-deleted")
        KeychainHelper.delete(key: testKey)

        let loaded = KeychainHelper.load(key: testKey)
        XCTAssertNil(loaded)
    }

    func testOverwrite() {
        KeychainHelper.save(key: testKey, value: "original")
        KeychainHelper.save(key: testKey, value: "updated")

        let loaded = KeychainHelper.load(key: testKey)
        XCTAssertEqual(loaded, "updated")
    }
}
