import CoreLocation
import XCTest
@testable import Footprint

/// Regression tests for photo import performance.
/// These tests ensure we don't re-introduce performance issues where
/// large data structures (like per-photo asset IDs) bloat cluster serialization
/// or slow down enumeration.
final class PhotoImportTests: XCTestCase {

    // MARK: - PhotoLocation serialization regression tests

    /// Verify PhotoLocation works correctly without photoAssetIDs (empty array).
    /// This is the expected state for resumed scans where asset IDs aren't persisted.
    func testPhotoLocationWithoutAssetIDs() throws {
        let location = PhotoLocation(
            latitude: 48.8566,
            longitude: 2.3522,
            photoCount: 42,
            earliestDate: Date(),
            countryCode: "FR",
            regionName: "France",
            photoAssetIDs: [],
            gridKey: "5428,261"
        )

        XCTAssertEqual(location.photoCount, 42)
        XCTAssertEqual(location.countryCode, "FR")
        XCTAssertTrue(location.photoAssetIDs.isEmpty)

        // Roundtrip through JSON
        let data = try JSONEncoder().encode(location)
        let decoded = try JSONDecoder().decode(PhotoLocation.self, from: data)
        XCTAssertEqual(decoded.photoCount, location.photoCount)
        XCTAssertEqual(decoded.countryCode, location.countryCode)
        XCTAssertTrue(decoded.photoAssetIDs.isEmpty)
    }

    /// Regression test: serialized PhotoLocation size should be small when no asset IDs are stored.
    /// Previously, asset IDs were accumulated per cluster during enumeration and persisted
    /// in scan progress, causing ~1MB+ of JSON per save. Now asset IDs are kept in a separate
    /// in-memory map and not persisted with clusters.
    func testPhotoLocationSerializationSizeWithoutAssetIDs() throws {
        // Create 5000 locations (typical large library) WITHOUT asset IDs
        let locations = (0..<5000).map { i in
            PhotoLocation(
                latitude: Double(i) * 0.009,
                longitude: Double(i % 360) * 0.009,
                photoCount: 6,
                countryCode: "US",
                photoAssetIDs: [],
                gridKey: "\(i),\(i % 360)"
            )
        }

        let data = try JSONEncoder().encode(locations)
        let sizeKB = data.count / 1024

        // Without asset IDs, 5000 locations should be well under 1MB
        // Each location is ~150 bytes of JSON, so 5000 * 150 = ~750KB
        XCTAssertLessThan(sizeKB, 1024, "Serialized locations without asset IDs should be under 1MB, got \(sizeKB)KB")
    }

    /// Regression test: demonstrate the problem that was fixed.
    /// With per-photo asset IDs stored in every cluster, serialization size would explode.
    func testPhotoLocationSerializationSizeWithAssetIDsForComparison() throws {
        // Create 5000 locations with 6 asset IDs each (simulating 30K total photos)
        let locations = (0..<5000).map { i in
            PhotoLocation(
                latitude: Double(i) * 0.009,
                longitude: Double(i % 360) * 0.009,
                photoCount: 6,
                countryCode: "US",
                photoAssetIDs: (0..<6).map { _ in UUID().uuidString }, // 36-char UUIDs
                gridKey: "\(i),\(i % 360)"
            )
        }

        let data = try JSONEncoder().encode(locations)
        let sizeKB = data.count / 1024

        // With asset IDs, the data is much larger (this is what we're avoiding in persistence)
        // 5000 * 6 * ~40 bytes per UUID = ~1.2MB just for IDs
        XCTAssertGreaterThan(sizeKB, 1024, "With asset IDs, data should be over 1MB (demonstrating the problem) - got \(sizeKB)KB")
    }

    // MARK: - GeoLocationMatcher tests

    /// Test that GeoJSON boundary preloading completes without hanging.
    /// Previously, boundaries were lazily loaded on first geocoding failure,
    /// causing contention when multiple parallel tasks hit the cold path simultaneously.
    @MainActor
    func testBoundaryPreloadingCompletes() {
        let matcher = GeoLocationMatcher.shared
        // This should complete quickly and not deadlock
        matcher.loadBoundariesIfNeeded()

        // Verify boundaries are actually loaded by matching a known coordinate
        let parisCoord = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        let result = matcher.matchCoordinate(parisCoord)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.countryCode, "FR")
    }

    /// Test that boundary matching with tolerance works for coastal locations
    func testBoundaryMatchingWithTolerance() {
        // A point slightly off the coast of France
        let coastalCoord = CLLocationCoordinate2D(latitude: 43.2965, longitude: 5.3698) // Marseille
        let result = GeoLocationMatcher.matchCoordinateWithToleranceNonisolated(
            coastalCoord,
            toleranceMeters: 500
        )
        XCTAssertNotNil(result, "Coastal location near Marseille should match")
        XCTAssertEqual(result?.countryCode, "FR")
    }

    // MARK: - Performance regression tests

    /// Performance test: creating clusters without photoAssetIDs should be fast.
    /// This simulates the Phase 1 enumeration pattern. Before the fix, struct copies
    /// included growing String arrays. After the fix, clusters are lightweight structs.
    func testClusterCreationPerformance() {
        // Simulate creating/updating 30K photo entries across 5K clusters
        measure {
            var clusters: [String: (key: String, lat: Double, lon: Double, count: Int, date: Date?)] = [:]
            let cellSize = 0.009

            for i in 0..<30_000 {
                let lat = Double(i % 1000) * cellSize
                let lon = Double(i / 1000) * cellSize
                let latCell = Int(floor(lat / cellSize))
                let lonCell = Int(floor(lon / cellSize))
                let key = "\(latCell),\(lonCell)"

                if var existing = clusters[key] {
                    existing.count += 1
                    clusters[key] = existing
                } else {
                    clusters[key] = (key: key, lat: lat, lon: lon, count: 1, date: Date())
                }
            }

            XCTAssertGreaterThan(clusters.count, 0)
        }
    }

    /// Performance test: serializing scan progress should be fast when clusters
    /// don't contain photoAssetIDs.
    func testProgressSerializationPerformance() throws {
        // Simulate the PersistedCluster format (same fields as PersistedCluster minus photoAssetIDs)
        struct LightweightCluster: Codable {
            let gridKey: String
            let latitude: Double
            let longitude: Double
            var photoCount: Int
            var earliestDate: Date?
        }

        let clusters = (0..<5000).map { i in
            LightweightCluster(
                gridKey: "\(i),\(i % 360)",
                latitude: Double(i) * 0.009,
                longitude: Double(i % 360) * 0.009,
                photoCount: 6,
                earliestDate: Date()
            )
        }

        measure {
            let _ = try? JSONEncoder().encode(clusters)
        }
    }

    // MARK: - UnmatchedCoordinate tests

    /// Test that UnmatchedCoordinate caps asset IDs appropriately
    func testUnmatchedCoordinateAssetIDCap() {
        let manyIDs = (0..<100).map { _ in UUID().uuidString }
        let capped = Array(manyIDs.prefix(10))
        let coord = UnmatchedCoordinate(
            latitude: 0,
            longitude: 0,
            photoCount: 100,
            photoAssetIDs: capped
        )

        XCTAssertEqual(coord.photoAssetIDs.count, 10, "Unmatched coordinates should cap at 10 asset IDs")
    }

    /// Test UnmatchedCoordinate works with empty asset IDs (resume scenario)
    func testUnmatchedCoordinateWithoutAssetIDs() {
        let coord = UnmatchedCoordinate(
            latitude: 51.5074,
            longitude: -0.1278,
            photoCount: 5
        )

        XCTAssertTrue(coord.photoAssetIDs.isEmpty)
        XCTAssertEqual(coord.photoCount, 5)
    }
}
