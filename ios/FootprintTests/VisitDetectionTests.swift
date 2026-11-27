import XCTest
@testable import Footprint

/// Synthetic-fixture tests for stay-point clustering and the §3.3 gates.
final class VisitDetectionTests: XCTestCase {
    /// 2027-01-15 08:00 UTC.
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let degreesPerMeter = 1.0 / 111_320
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// The ruling's opposite: the spec's original transit default for pass-throughs.
    private var specDefault: VisitDetectionConfig {
        var config = VisitDetectionConfig()
        config.passThroughCountsAsVisit = false
        return config
    }

    /// Fake world: longitude < 0 is country AA, else BB; latitude < 0 is subdivision S, else N.
    private let world: VisitDetector.Resolver = { lat, lon in
        PlaceKey(countryCode: lon < 0 ? "AA" : "BB", subdivisionCode: lat < 0 ? "S" : "N")
    }

    private func sample(
        _ minute: Double, _ lat: Double, _ lon: Double,
        accuracy: Double = 20, source: SampleSource = .gps, base: Date? = nil
    ) -> EvidenceSample {
        EvidenceSample(
            timestamp: (base ?? t0).addingTimeInterval(minute * 60),
            latitude: lat, longitude: lon, horizontalAccuracy: accuracy, source: source
        )
    }

    /// 12 minutes jittering within 20 m.
    private var stay: [EvidenceSample] {
        (0...12).map { sample(Double($0), 10 + Double($0 % 3) * 10 * degreesPerMeter, 10) }
    }

    /// ~60 km/h for 3 minutes.
    private var drive: [EvidenceSample] {
        (0...3).map { sample(Double($0), 10 + Double($0) * 1000 * degreesPerMeter, 10) }
    }

    /// Longitude of an airport 50 km past the end of a 6-fix inbound flight leg from longitude 1.
    private var airport: Double { 1 + 5 * 15_000 * degreesPerMeter + 50_000 * degreesPerMeter }

    /// A flight leg at ~900 km/h, one fix per minute.
    private func flightLeg(from minute: Double, lon: Double, fixes: Int) -> [EvidenceSample] {
        (0..<fixes).map { sample(minute + Double($0), 10, lon + Double($0) * 15_000 * degreesPerMeter) }
    }

    private func detect(_ samples: [EvidenceSample], config: VisitDetectionConfig = .default,
                        resolve: VisitDetector.Resolver? = nil) -> [DetectedVisit] {
        VisitDetector.detect(samples, resolve: resolve ?? world, config: config, calendar: utc)
    }

    // MARK: - Clustering

    func testStayPointNeedsFiveMinutesWithin200Meters() {
        XCTAssertEqual(StayPointClusterer.cluster(Array(stay.prefix(4)), calendar: utc), [])
        let stays = StayPointClusterer.cluster(stay + [sample(30, 11, 10)], calendar: utc)
        XCTAssertEqual(stays.count, 1)
        XCTAssertEqual(stays.first?.range, 0...12)
        XCTAssertEqual(stays.first?.duration, 12 * 60)
    }

    func testStayPointEndsWhenLeavingRadius() {
        let here: [EvidenceSample] = (0...6).map { sample(Double($0), 10, 10) }
        let away: [EvidenceSample] = (7...9).map { sample(Double($0), 10 + 300 * degreesPerMeter, 10) }
        let samples = here + away
        let stays = StayPointClusterer.cluster(samples, calendar: utc)
        XCTAssertEqual(stays.map(\.range), [0...6])
    }

    // MARK: - Gates

    func testTenMinuteStayConfirmsCountryAndSubdivision() {
        let visits = detect(stay, config: specDefault)
        XCTAssertEqual(visits.map(\.level), [.country, .subdivision])
        XCTAssertTrue(visits.allSatisfy { $0.kind == .visited && $0.countryCode == "BB" })
        XCTAssertEqual(visits.last?.subdivisionCode, "N")
        XCTAssertEqual(visits.first?.sampleCount, 13)
    }

    func testSingleFlyBySampleRecordsNothing() {
        XCTAssertEqual(detect([sample(0, 10, 10)]), [])
    }

    func testDriveThroughCountsAsFullVisit() {
        let visits = detect(drive)
        XCTAssertEqual(visits.map(\.level), [.country, .subdivision])
        XCTAssertTrue(visits.allSatisfy { $0.kind == .visited })
    }

    func testDriveThroughIsTransitUnderSpecDefault() {
        let visits = detect(drive, config: specDefault)
        XCTAssertEqual(visits.count, 2)
        XCTAssertTrue(visits.allSatisfy { $0.kind == .transit })
    }

    func testPassUnderTwoMinutesRecordsNothing() {
        XCTAssertEqual(detect(Array(drive.prefix(2))), [])
    }

    func testDriveAcrossBorderRecordsBothCountries() {
        let crossing = (0...6).map { sample(Double($0), 10, -0.025 + Double($0) * 1000 * degreesPerMeter) }
        let countries = detect(crossing).filter { $0.level == .country }.map(\.countryCode)
        XCTAssertEqual(countries, ["AA", "BB"])
    }

    func testOvernightStayConfirmsBelowDwell() {
        let lateEvening = t0.addingTimeInterval(-(8 * 3600 + 5 * 60))  // 23:55 UTC
        let night = [0.0, 4, 8].map { sample($0, 10, 10, base: lateEvening) }
        XCTAssertTrue(detect(night, config: specDefault).allSatisfy { $0.kind == .visited })
        let daytime = [0.0, 4, 8].map { sample($0, 10, 10) }
        XCTAssertTrue(detect(daytime, config: specDefault).allSatisfy { $0.kind == .transit })
    }

    func testFlightOverCountryRecordsNothing() {
        XCTAssertEqual(detect(flightLeg(from: 0, lon: -1, fixes: 21)), [])
    }

    func testLayoverOf45MinutesIsCountryTransitOnly() {
        let inbound = flightLeg(from: 0, lon: 1, fixes: 6)
        let atGate: [EvidenceSample] = (0...10).map { sample(10 + Double($0) * 5, 10, airport) }
        let outbound = flightLeg(from: 61, lon: airport + 15_000 * degreesPerMeter, fixes: 5)
        let samples = inbound + atGate + outbound
        let visits = detect(samples)
        XCTAssertEqual(visits.count, 1)
        XCTAssertEqual(visits.first?.level, .country)
        XCTAssertEqual(visits.first?.kind, .transit)
    }

    func testShortLayoverRecordsNothing() {
        let inbound = flightLeg(from: 0, lon: 1, fixes: 6)
        let atGate: [EvidenceSample] = (0...6).map { sample(10 + Double($0) * 5, 10, airport) }
        let outbound = flightLeg(from: 41, lon: airport + 15_000 * degreesPerMeter, fixes: 5)
        let samples = inbound + atGate + outbound
        XCTAssertEqual(detect(samples), [])
    }

    func testStayAfterLandingIsAVisit() {
        let inbound = flightLeg(from: 0, lon: 1, fixes: 6)
        let atGate: [EvidenceSample] = (0...6).map { sample(10 + Double($0) * 5, 10, airport) }
        let samples = inbound + atGate
        let visits = detect(samples)
        XCTAssertEqual(visits.count, 2)
        XCTAssertTrue(visits.allSatisfy { $0.kind == .visited })
    }

    func testInaccurateSamplesAreDropped() {
        let blurry = stay.map { var s = $0; s.horizontalAccuracy = 1_500; return s }
        XCTAssertEqual(detect(blurry), [])
    }

    func testOneGPSSamplePlusPhotoConfirms() {
        let visits = detect([sample(0, 10, 10), sample(12, 10, 10, source: .photo)], config: specDefault)
        XCTAssertEqual(visits.count, 2)
        XCTAssertTrue(visits.allSatisfy { $0.kind == .visited })
    }

    func testStayWhoseCentroidIsOutsideTheBoundaryDoesNotConfirm() {
        let withHole: VisitDetector.Resolver = { lat, lon in
            let inHole = GeoMath.distanceMeters(lat1: lat, lon1: lon, lat2: 10, lon2: 10) < 30
            return PlaceKey(countryCode: inHole ? "HO" : "BB", subdivisionCode: nil)
        }
        let ring = (0...12).map { i -> EvidenceSample in
            let angle = Double(i) * .pi / 3
            return sample(Double(i), 10 + cos(angle) * 90 * degreesPerMeter,
                          10 + sin(angle) * 90 * degreesPerMeter / cos(10 * .pi / 180))
        }
        let visits = detect(ring, config: specDefault, resolve: withHole)
        XCTAssertEqual(visits.map(\.kind), [.transit])
    }

    // MARK: - Distance

    func testDistanceIgnoresJitterAndSumsMovement() {
        let jitter = (0...30).map { sample(Double($0), 10 + Double($0 % 2) * 15 * degreesPerMeter, 10, accuracy: 30) }
        XCTAssertEqual(DistanceAccumulator.meters(jitter), 0)
        XCTAssertEqual(DistanceAccumulator.meters(drive), 3_000, accuracy: 5)
    }
}
