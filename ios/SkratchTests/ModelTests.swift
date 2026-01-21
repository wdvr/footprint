import XCTest
import SwiftData
@testable import Skratch

final class ModelTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            User.self,
            VisitedPlace.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
    }

    func testUserCreation() throws {
        // Given
        let user = User(
            id: "test-user-123",
            authProvider: "apple",
            authProviderID: "apple-user-456",
            email: "test@example.com",
            displayName: "Test User"
        )

        // When
        modelContext.insert(user)
        try modelContext.save()

        // Then
        XCTAssertEqual(user.id, "test-user-123")
        XCTAssertEqual(user.authProvider, "apple")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.countriesVisited, 0)
        XCTAssertEqual(user.usStatesVisited, 0)
        XCTAssertEqual(user.canadianProvincesVisited, 0)
        XCTAssertEqual(user.syncVersion, 1)
    }

    func testVisitedPlaceCreation() throws {
        // Given
        let visitedPlace = VisitedPlace(
            userID: "test-user-123",
            regionType: VisitedPlace.RegionType.country.rawValue,
            regionCode: "US",
            regionName: "United States",
            visitedDate: Date(),
            notes: "Great trip!"
        )

        // When
        modelContext.insert(visitedPlace)
        try modelContext.save()

        // Then
        XCTAssertEqual(visitedPlace.userID, "test-user-123")
        XCTAssertEqual(visitedPlace.regionType, "country")
        XCTAssertEqual(visitedPlace.regionCode, "US")
        XCTAssertEqual(visitedPlace.regionName, "United States")
        XCTAssertEqual(visitedPlace.notes, "Great trip!")
        XCTAssertFalse(visitedPlace.isDeleted)
        XCTAssertEqual(visitedPlace.syncVersion, 1)
    }

    func testVisitedPlaceCompositeKey() throws {
        // Given
        let visitedPlace = VisitedPlace(
            userID: "user-123",
            regionType: "country",
            regionCode: "CA",
            regionName: "Canada"
        )

        // When
        let compositeKey = visitedPlace.compositeKey

        // Then
        XCTAssertEqual(compositeKey, "user-123_country_CA")
    }

    func testRegionTypeEnum() throws {
        // Test all region types
        XCTAssertEqual(VisitedPlace.RegionType.country.rawValue, "country")
        XCTAssertEqual(VisitedPlace.RegionType.usState.rawValue, "us_state")
        XCTAssertEqual(VisitedPlace.RegionType.canadianProvince.rawValue, "canadian_province")

        // Test display names
        XCTAssertEqual(VisitedPlace.RegionType.country.displayName, "Country")
        XCTAssertEqual(VisitedPlace.RegionType.usState.displayName, "US State")
        XCTAssertEqual(VisitedPlace.RegionType.canadianProvince.displayName, "Canadian Province")
    }

    func testUserSyncVersionUpdates() throws {
        // Given
        let user = User(
            id: "sync-test-user",
            authProvider: "email",
            authProviderID: "email-user-789"
        )
        modelContext.insert(user)
        try modelContext.save()

        let originalVersion = user.syncVersion
        let originalUpdateTime = user.updatedAt

        // When - simulate an update
        user.displayName = "Updated Name"
        user.syncVersion += 1
        user.updatedAt = Date()
        try modelContext.save()

        // Then
        XCTAssertEqual(user.syncVersion, originalVersion + 1)
        XCTAssertGreaterThan(user.updatedAt, originalUpdateTime)
        XCTAssertEqual(user.displayName, "Updated Name")
    }

    func testMultipleVisitedPlacesQuery() throws {
        // Given
        let places = [
            VisitedPlace(userID: "user-1", regionType: "country", regionCode: "US", regionName: "United States"),
            VisitedPlace(userID: "user-1", regionType: "us_state", regionCode: "CA", regionName: "California"),
            VisitedPlace(userID: "user-1", regionType: "canadian_province", regionCode: "BC", regionName: "British Columbia"),
            VisitedPlace(userID: "user-2", regionType: "country", regionCode: "FR", regionName: "France")
        ]

        // When
        places.forEach { modelContext.insert($0) }
        try modelContext.save()

        // Then
        let descriptor = FetchDescriptor<VisitedPlace>(
            predicate: #Predicate { $0.userID == "user-1" }
        )
        let userPlaces = try modelContext.fetch(descriptor)

        XCTAssertEqual(userPlaces.count, 3)
        XCTAssertTrue(userPlaces.allSatisfy { $0.userID == "user-1" })
    }
}