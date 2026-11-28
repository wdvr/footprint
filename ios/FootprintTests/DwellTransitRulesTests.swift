import XCTest
@testable import Footprint

/// Boundary cases of the §3.3 dwell / accuracy gates that decide visited versus transit.
final class DwellTransitRulesTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15 08:00 UTC
    private let degreesPerMeter = 1.0 / 111_320
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// The spec's original default: sub-dwell presence is transit.
    private var specDefault: VisitDetectionConfig {
        var config = VisitDetectionConfig()
        config.passThroughCountsAsVisit = false
        return config
    }

    /// Longitude < 0 is country AA, else BB; latitude < 0 is subdivision S, else N.
    private let world: VisitDetector.Resolver = { lat, lon in
        PlaceKey(countryCode: lon < 0 ? "AA" : "BB", subdivisionCode: lat < 0 ? "S" : "N")
    }

    private func sample(_ minute: Double, metersNorth: Double = 0, accuracy: Double = 20) -> EvidenceSample {
        EvidenceSample(timestamp: t0.addingTimeInterval(minute * 60),
                       latitude: 10 + metersNorth * degreesPerMeter, longitude: 10, horizontalAccuracy: accuracy)
    }

    /// One fix per minute for `minutes`, jittering within 20 m.
    private func stay(minutes: Int, from start: Double = 0, accuracy: Double = 20) -> [EvidenceSample] {
        (0...minutes).map { sample(start + Double($0), metersNorth: Double($0 % 3) * 10, accuracy: accuracy) }
    }

    /// Moving at `metersPerMinute`, one fix per minute.
    private func drive(minutes: Int, metersPerMinute: Double = 1_000) -> [EvidenceSample] {
        (0...minutes).map { sample(Double($0), metersNorth: Double($0) * metersPerMinute) }
    }

    private func kinds(_ samples: [EvidenceSample], _ config: VisitDetectionConfig) -> [DetectedVisitKind] {
        VisitDetector.detect(samples, resolve: world, config: config, calendar: utc).map(\.kind)
    }

    func testStayOfExactlyTheDwellThresholdIsAVisit() {
        XCTAssertEqual(kinds(stay(minutes: 10), specDefault), [.visited, .visited])
    }

    func testStayJustUnderTheDwellThresholdIsTransit() {
        XCTAssertEqual(kinds(stay(minutes: 9), specDefault), [.transit, .transit])
    }

    func testStayJustUnderTheDwellThresholdIsAVisitUnderTheOwnerRuling() {
        XCTAssertEqual(kinds(stay(minutes: 9), .default), [.visited, .visited])
    }

    func testLongDriveWithoutStoppingIsTransitHoweverLongItLasts() {
        // 30 minutes inside one place but never 10 minutes within 200 m: a drive-through.
        XCTAssertEqual(kinds(drive(minutes: 30), specDefault), [.transit, .transit])
    }

    func testDriveWithATenMinuteStopIsAVisit() {
        let approach = drive(minutes: 5)
        let stopAt = approach.last!.latitude
        let stop = (1...10).map {
            EvidenceSample(timestamp: t0.addingTimeInterval(Double(5 + $0) * 60),
                           latitude: stopAt, longitude: 10, horizontalAccuracy: 20)
        }
        XCTAssertEqual(kinds(approach + stop, specDefault), [.visited, .visited])
    }

    func testPresenceUnderTwoMinutesRecordsNothing() {
        XCTAssertEqual(kinds([sample(0), sample(1.5)], specDefault), [])
        XCTAssertEqual(kinds([sample(0), sample(1.5)], .default), [])
    }

    func testCoarseButAcceptableFixesStillConfirm() {
        XCTAssertEqual(kinds(stay(minutes: 10, accuracy: 900), specDefault), [.visited, .visited])
    }

    func testFixesWorseThanTheAccuracyGateAreEvidenceOfNothing() {
        XCTAssertEqual(kinds(stay(minutes: 30, accuracy: 1_500), .default), [])
    }

    func testInaccurateFixesDoNotShortenADwell() {
        // A bad fix mid-stay is dropped rather than splitting the stay below the dwell gate.
        var samples = stay(minutes: 12)
        samples[6] = EvidenceSample(timestamp: samples[6].timestamp, latitude: 10.5, longitude: 10,
                                    horizontalAccuracy: 3_000)
        XCTAssertEqual(kinds(samples, specDefault), [.visited, .visited])
    }
}
