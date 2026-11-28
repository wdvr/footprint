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
/// The detection callbacks keep their contract, now driven by the visit pipeline.
@MainActor
final class LocationManagerCallbackTests: XCTestCase {
    private var manager: LocationManager { LocationManager.shared }

    override func tearDown() {
        manager.onCountryDetected = nil
        manager.onStateDetected = nil
        super.tearDown()
    }

    func testNewCountryFiresCountryCallback() {
        var countries: [String] = []
        manager.onCountryDetected = { countries.append($0) }
        manager.deliver([VisitPipeline.NewPlace(countryCode: "FR", subdivisionCode: nil)])
        XCTAssertEqual(countries, ["FR"])
    }

    func testNewUSStateOrCanadianProvinceFiresStateCallback() {
        var states: [String] = []
        manager.onStateDetected = { states.append("\($0)-\($1)") }
        manager.deliver([
            VisitPipeline.NewPlace(countryCode: "US", subdivisionCode: "CA"),
            VisitPipeline.NewPlace(countryCode: "CA", subdivisionCode: "BC"),
        ])
        XCTAssertEqual(states, ["US-CA", "CA-BC"])
    }

    func testOtherSubdivisionsDoNotFireStateCallback() {
        var fired = false
        manager.onStateDetected = { _, _ in fired = true }
        manager.onCountryDetected = { _ in fired = true }
        manager.deliver([VisitPipeline.NewPlace(countryCode: "FR", subdivisionCode: "75")])
        XCTAssertFalse(fired)
    }

    func testNothingNewFiresNothing() {
        var fired = false
        manager.onCountryDetected = { _ in fired = true }
        manager.deliver([])
        XCTAssertFalse(fired)
    }

    func testSamplingIsOffWithoutAutomaticTracking() {
        manager.disableBackgroundTracking()
        XCTAssertEqual(manager.samplingMode, .off)
    }
}
