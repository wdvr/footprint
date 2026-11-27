import XCTest
@testable import Footprint

final class SamplingPolicyTests: XCTestCase {
    private let policy = SamplingPolicy()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testEverythingOffWithoutConsent() {
        XCTAssertEqual(policy.mode(for: SamplingInputs(automaticTrackingEnabled: false, motion: .automotive)), .off)
    }

    func testIdleDeviceUsesOnlyLowPowerLayers() {
        let mode = policy.mode(for: SamplingInputs(automaticTrackingEnabled: true))
        XCTAssertTrue(mode.significantChanges)
        XCTAssertTrue(mode.visitMonitoring)
        XCTAssertEqual(mode.geofenceRadiusMeters, 2_000)
        XCTAssertFalse(mode.standardUpdates)
    }

    func testGeofenceExitEscalatesToStandardUpdates() {
        XCTAssertTrue(policy.mode(for: SamplingInputs(automaticTrackingEnabled: true, exitedGeofence: true)).standardUpdates)
    }

    func testDrivingUses100MeterFilter() {
        let mode = policy.mode(for: SamplingInputs(automaticTrackingEnabled: true, motion: .automotive))
        XCTAssertTrue(mode.standardUpdates)
        XCTAssertEqual(mode.distanceFilterMeters, 100)
        XCTAssertEqual(mode.desiredAccuracyMeters, 100)
    }

    func testFormingStayUsesTenMeterAccuracy() {
        let inputs = SamplingInputs(automaticTrackingEnabled: true, motion: .stationary,
                                    stationarySince: now, stayForming: true, now: now.addingTimeInterval(5 * 60))
        let mode = policy.mode(for: inputs)
        XCTAssertTrue(mode.standardUpdates)
        XCTAssertEqual(mode.desiredAccuracyMeters, 10)
    }

    func testNoContinuousGPSAfterFifteenStationaryMinutes() {
        let inputs = SamplingInputs(automaticTrackingEnabled: true, motion: .stationary, stationarySince: now,
                                    exitedGeofence: true, stayForming: true, now: now.addingTimeInterval(16 * 60))
        XCTAssertFalse(policy.mode(for: inputs).standardUpdates)
    }

    func testFlightIsCountryLevelOnlyWithoutGPS() {
        let mode = policy.mode(for: SamplingInputs(automaticTrackingEnabled: true, motion: .flight))
        XCTAssertTrue(mode.countryLevelOnly)
        XCTAssertFalse(mode.standardUpdates)
        XCTAssertTrue(mode.significantChanges)
    }
}
