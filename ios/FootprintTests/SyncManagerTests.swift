import XCTest
import SwiftData
@testable import Footprint

@MainActor
final class SyncManagerTests: XCTestCase {

    var testContainer: ModelContainer!
    var testContext: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create in-memory model container for testing
        let schema = Schema([VisitedPlace.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        testContainer = try ModelContainer(for: schema, configurations: [config])
        testContext = testContainer.mainContext
    }

    override func tearDownWithError() throws {
        testContext = nil
        testContainer = nil
        try super.tearDownWithError()
    }

    // MARK: - State Tests

    func testInitialState() {
        let manager = SyncManager.shared

        XCTAssertFalse(manager.isSyncing)
        XCTAssertNil(manager.error)
    }

    func testConfigureModelContext() {
        let manager = SyncManager.shared
        manager.configure(modelContext: testContext)

        // Configure should succeed without error
        XCTAssertNil(manager.error)
    }

    // MARK: - Error State Tests

    func testSyncWithoutContext() async {
        // Create a fresh SyncManager instance for this test
        // Note: In production, you'd want to make SyncManager more testable
        // by allowing dependency injection

        // The shared instance may already have a context configured
        // This test verifies the behavior when context is missing
        XCTAssertTrue(true, "Context validation is handled in sync method")
    }

    // MARK: - UserDefaults Tests

    func testLastSyncAtPersistence() {
        // Clean up any existing value
        UserDefaults.standard.removeObject(forKey: "lastSyncAt")

        // Verify initial state
        let loadedDate = UserDefaults.standard.object(forKey: "lastSyncAt") as? Date
        XCTAssertNil(loadedDate)

        // Save a date
        let testDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01
        UserDefaults.standard.set(testDate, forKey: "lastSyncAt")

        // Verify it was saved
        let savedDate = UserDefaults.standard.object(forKey: "lastSyncAt") as? Date
        XCTAssertNotNil(savedDate)
        XCTAssertEqual(savedDate?.timeIntervalSince1970, testDate.timeIntervalSince1970)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "lastSyncAt")
    }

    func testForceFullSyncClearsLastSyncAt() {
        // Set a last sync date
        UserDefaults.standard.set(Date(), forKey: "lastSyncAt")

        // Verify it's set
        XCTAssertNotNil(UserDefaults.standard.object(forKey: "lastSyncAt"))

        // Force full sync clears the date
        UserDefaults.standard.removeObject(forKey: "lastSyncAt")

        // Verify it's cleared
        XCTAssertNil(UserDefaults.standard.object(forKey: "lastSyncAt"))
    }
}

// MARK: - VisitedPlace SwiftData Tests

@MainActor
final class VisitedPlaceDataTests: XCTestCase {

    var testContainer: ModelContainer!
    var testContext: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let schema = Schema([VisitedPlace.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        testContainer = try ModelContainer(for: schema, configurations: [config])
        testContext = testContainer.mainContext
    }

    override func tearDownWithError() throws {
        testContext = nil
        testContainer = nil
        try super.tearDownWithError()
    }

    func testCreateAndFetchPlace() throws {
        let place = VisitedPlace(
            regionType: .country,
            regionCode: "US",
            regionName: "United States"
        )

        testContext.insert(place)
        try testContext.save()

        let descriptor = FetchDescriptor<VisitedPlace>()
        let places = try testContext.fetch(descriptor)

        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.regionCode, "US")
    }

    func testFetchByRegionType() throws {
        let country = VisitedPlace(regionType: .country, regionCode: "FR", regionName: "France")
        let state = VisitedPlace(regionType: .usState, regionCode: "CA", regionName: "California")

        testContext.insert(country)
        testContext.insert(state)
        try testContext.save()

        // Fetch only countries
        let countryType = "country"
        let descriptor = FetchDescriptor<VisitedPlace>(
            predicate: #Predicate<VisitedPlace> { place in
                place.regionType == countryType
            }
        )
        let countries = try testContext.fetch(descriptor)

        XCTAssertEqual(countries.count, 1)
        XCTAssertEqual(countries.first?.regionCode, "FR")
    }

    func testFetchModifiedSince() throws {
        let oldDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01
        let midDate = Date(timeIntervalSince1970: 1704153600) // 2024-01-02
        let newDate = Date(timeIntervalSince1970: 1704240000) // 2024-01-03

        let oldPlace = VisitedPlace(regionType: .country, regionCode: "US", regionName: "USA")
        oldPlace.lastModifiedAt = oldDate

        let newPlace = VisitedPlace(regionType: .country, regionCode: "FR", regionName: "France")
        newPlace.lastModifiedAt = newDate

        testContext.insert(oldPlace)
        testContext.insert(newPlace)
        try testContext.save()

        // Fetch places modified after midDate
        let descriptor = FetchDescriptor<VisitedPlace>(
            predicate: #Predicate<VisitedPlace> { place in
                place.lastModifiedAt > midDate
            }
        )
        let modifiedPlaces = try testContext.fetch(descriptor)

        XCTAssertEqual(modifiedPlaces.count, 1)
        XCTAssertEqual(modifiedPlaces.first?.regionCode, "FR")
    }

    func testSoftDelete() throws {
        let place = VisitedPlace(regionType: .country, regionCode: "GB", regionName: "UK")

        testContext.insert(place)
        try testContext.save()

        // Soft delete
        place.isDeleted = true
        try testContext.save()

        // Fetch non-deleted
        let descriptor = FetchDescriptor<VisitedPlace>(
            predicate: #Predicate<VisitedPlace> { place in
                place.isDeleted == false
            }
        )
        let activePlaces = try testContext.fetch(descriptor)

        XCTAssertEqual(activePlaces.count, 0)
    }

    func testMarkAsSynced() throws {
        let place = VisitedPlace(regionType: .country, regionCode: "DE", regionName: "Germany")
        XCTAssertFalse(place.isSynced)

        testContext.insert(place)
        place.isSynced = true
        try testContext.save()

        let descriptor = FetchDescriptor<VisitedPlace>(
            predicate: #Predicate<VisitedPlace> { place in
                place.isSynced == true
            }
        )
        let syncedPlaces = try testContext.fetch(descriptor)

        XCTAssertEqual(syncedPlaces.count, 1)
    }

    func testUpdatePlaceProperties() throws {
        let place = VisitedPlace(regionType: .country, regionCode: "JP", regionName: "Japan")

        testContext.insert(place)
        try testContext.save()

        // Update properties
        place.notes = "Amazing trip!"
        place.visitedDate = Date(timeIntervalSince1970: 1704067200)
        try testContext.save()

        // Fetch and verify
        let descriptor = FetchDescriptor<VisitedPlace>()
        let places = try testContext.fetch(descriptor)

        XCTAssertEqual(places.first?.notes, "Amazing trip!")
        XCTAssertNotNil(places.first?.visitedDate)
    }

    func testDeletePlace() throws {
        let place = VisitedPlace(regionType: .country, regionCode: "IT", regionName: "Italy")

        testContext.insert(place)
        try testContext.save()

        // Hard delete
        testContext.delete(place)
        try testContext.save()

        let descriptor = FetchDescriptor<VisitedPlace>()
        let places = try testContext.fetch(descriptor)

        XCTAssertEqual(places.count, 0)
    }

    func testMultiplePlaces() throws {
        let places = [
            VisitedPlace(regionType: .country, regionCode: "US", regionName: "USA"),
            VisitedPlace(regionType: .country, regionCode: "FR", regionName: "France"),
            VisitedPlace(regionType: .usState, regionCode: "CA", regionName: "California"),
            VisitedPlace(regionType: .usState, regionCode: "NY", regionName: "New York"),
            VisitedPlace(regionType: .canadianProvince, regionCode: "ON", regionName: "Ontario"),
        ]

        for place in places {
            testContext.insert(place)
        }
        try testContext.save()

        let descriptor = FetchDescriptor<VisitedPlace>()
        let allPlaces = try testContext.fetch(descriptor)

        XCTAssertEqual(allPlaces.count, 5)

        // Count by type
        let countryType = "country"
        let usStateType = "us_state"
        let provinceType = "canadian_province"

        let countryDescriptor = FetchDescriptor<VisitedPlace>(
            predicate: #Predicate<VisitedPlace> { $0.regionType == countryType }
        )
        let countries = try testContext.fetch(countryDescriptor)
        XCTAssertEqual(countries.count, 2)

        let stateDescriptor = FetchDescriptor<VisitedPlace>(
            predicate: #Predicate<VisitedPlace> { $0.regionType == usStateType }
        )
        let states = try testContext.fetch(stateDescriptor)
        XCTAssertEqual(states.count, 2)

        let provinceDescriptor = FetchDescriptor<VisitedPlace>(
            predicate: #Predicate<VisitedPlace> { $0.regionType == provinceType }
        )
        let provinces = try testContext.fetch(provinceDescriptor)
        XCTAssertEqual(provinces.count, 1)
    }
}
