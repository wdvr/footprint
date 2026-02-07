import XCTest
@testable import Footprint

/// Regression tests for account reset / "Clear All Data".
/// Ensures that clearing data also resets all photo import persistent state,
/// so a fresh photo scan finds all places again instead of showing "no new places".
final class AccountResetTests: XCTestCase {

    // MARK: - UserDefaults keys that must be cleared

    /// All UserDefaults keys that PhotoImportManager uses for persistent state.
    /// If a new key is added to PhotoImportManager, add it here too.
    private let photoImportKeys = [
        "lastScannedPhotoDate",
        "processedPhotoAssetIDs",
        "PhotoImportScanProgress",
        "lastPhotoSync",
    ]

    private let photoLocationKeys = [
        "photoLocations",
    ]

    private let syncKeys = [
        "lastSyncAt",
    ]

    // MARK: - PhotoImportManager clearAllPersistentState Tests

    /// After clearAllPersistentState, all photo import UserDefaults keys should be removed.
    @MainActor
    func testClearAllPersistentStateRemovesUserDefaults() {
        let defaults = UserDefaults.standard

        // Simulate state that would exist after a completed photo scan
        defaults.set(Date(), forKey: "lastScannedPhotoDate")
        defaults.set(Date(), forKey: "lastPhotoSync")
        defaults.set("fake-progress".data(using: .utf8), forKey: "PhotoImportScanProgress")
        // Set some processed photo IDs
        let fakeIDs: Set<String> = ["photo1", "photo2", "photo3"]
        if let data = try? JSONEncoder().encode(fakeIDs) {
            defaults.set(data, forKey: "processedPhotoAssetIDs")
        }

        // Verify they're set
        XCTAssertNotNil(defaults.object(forKey: "lastScannedPhotoDate"))
        XCTAssertNotNil(defaults.object(forKey: "lastPhotoSync"))
        XCTAssertNotNil(defaults.data(forKey: "processedPhotoAssetIDs"))

        // Clear
        PhotoImportManager.shared.clearAllPersistentState()

        // All keys should be gone
        XCTAssertNil(defaults.object(forKey: "lastScannedPhotoDate"),
                     "lastScannedPhotoDate must be cleared on reset")
        XCTAssertNil(defaults.object(forKey: "lastPhotoSync"),
                     "lastPhotoSync must be cleared on reset")
        XCTAssertNil(defaults.data(forKey: "PhotoImportScanProgress"),
                     "PhotoImportScanProgress must be cleared on reset")

        // Processed photo IDs should be empty (cleared to empty set, then saved)
        if let data = defaults.data(forKey: "processedPhotoAssetIDs"),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            XCTAssertTrue(ids.isEmpty, "processedPhotoAssetIDs must be empty after reset, got \(ids.count)")
        }
        // If the key is removed entirely, that's also fine
    }

    /// After clearAllPersistentState, PhotoImportManager state should be idle.
    @MainActor
    func testClearAllPersistentStateResetsManagerState() {
        let manager = PhotoImportManager.shared

        // Clear
        manager.clearAllPersistentState()

        // State should be idle
        XCTAssertEqual(manager.state, .idle)
        XCTAssertEqual(manager.newPhotosAvailable, 0)
        XCTAssertNil(manager.lastScannedPhotoDate)
        XCTAssertEqual(manager.processedPhotoCount, 0)
    }

    /// After clearAllPersistentState, PhotoLocationStore should be empty.
    @MainActor
    func testClearAllPersistentStateClearsPhotoLocations() {
        // Add a fake photo location
        let location = PhotoLocation(
            latitude: 48.8566,
            longitude: 2.3522,
            photoCount: 10,
            countryCode: "FR",
            regionName: "France",
            photoAssetIDs: [],
            gridKey: "5428,261"
        )
        PhotoLocationStore.shared.merge([location])
        XCTAssertGreaterThan(PhotoLocationStore.shared.locationCount, 0, "Precondition: should have locations")

        // Clear
        PhotoImportManager.shared.clearAllPersistentState()

        // Photo locations should be gone
        XCTAssertEqual(PhotoLocationStore.shared.locationCount, 0,
                       "PhotoLocationStore must be cleared on reset")
    }

    // MARK: - SyncManager reset tests

    /// forceResetSyncState should clear the sync timestamp.
    @MainActor
    func testForceResetSyncStateClearsTimestamp() {
        // Set a fake sync date
        UserDefaults.standard.set(Date(), forKey: "lastSyncAt")

        SyncManager.shared.forceResetSyncState()

        XCTAssertNil(SyncManager.shared.lastSyncAt)
        XCTAssertNil(UserDefaults.standard.object(forKey: "lastSyncAt"))
    }

    // MARK: - Integration: simulate the full clear-all-data flow

    /// Simulate what happens when user taps "Clear All Data" then re-imports photos.
    /// The photo import manager should not remember any previous scan state.
    @MainActor
    func testFullClearAllDataResetsCycle() {
        let defaults = UserDefaults.standard

        // 1. Simulate completed photo scan state
        defaults.set(Date(), forKey: "lastScannedPhotoDate")
        defaults.set(Date(), forKey: "lastPhotoSync")
        defaults.set(Date(), forKey: "lastSyncAt")
        let fakeIDs: Set<String> = Set((0..<100).map { "photo-\($0)" })
        if let data = try? JSONEncoder().encode(fakeIDs) {
            defaults.set(data, forKey: "processedPhotoAssetIDs")
        }

        // 2. Simulate "Clear All Data" (the parts we can test without modelContext)
        PhotoImportManager.shared.clearAllPersistentState()
        SyncManager.shared.forceResetSyncState()

        // 3. Verify everything is clean
        XCTAssertNil(defaults.object(forKey: "lastScannedPhotoDate"))
        XCTAssertNil(defaults.object(forKey: "lastPhotoSync"))
        XCTAssertNil(defaults.object(forKey: "lastSyncAt"))
        XCTAssertEqual(PhotoImportManager.shared.processedPhotoCount, 0,
                       "After clear all data, photo import should not remember any processed photos")
        XCTAssertNil(PhotoImportManager.shared.lastScannedPhotoDate,
                     "After clear all data, last scanned date should be nil")

        // 4. hasPendingScan should be false (no resume state)
        XCTAssertFalse(PhotoImportManager.shared.hasPendingScan,
                       "After clear all data, there should be no pending scan to resume")
    }
}
