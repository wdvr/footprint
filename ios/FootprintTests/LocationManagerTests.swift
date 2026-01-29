import XCTest
import CoreLocation
@testable import Footprint

@MainActor
final class LocationManagerTests: XCTestCase {
    var locationManager: LocationManager!

    override func setUpWithError() throws {
        locationManager = LocationManager.shared
    }

    override func tearDownWithError() throws {
        locationManager = nil
    }

    func testLocationManagerInitialization() {
        XCTAssertNotNil(locationManager)
    }

    func testLocationManagerSingleton() {
        let manager1 = LocationManager.shared
        let manager2 = LocationManager.shared
        XCTAssertTrue(manager1 === manager2, "LocationManager should be a singleton")
    }

    func testBackgroundTrackingToggle() {
        // Test that we can enable/disable background tracking
        locationManager.enableBackgroundTracking()
        locationManager.disableBackgroundTracking()
        // These methods should not crash
        XCTAssertTrue(true)
    }
}