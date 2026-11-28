import XCTest
@testable import Footprint

/// Synthetic-fixture tests for city visits (§3.3 city gates).
final class CityVisitDetectionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let degreesPerMeter = 1.0 / 111_320
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Fake world: longitude < 0 is country AA, else BB; one subdivision N.
    private let world: VisitDetector.Resolver = { _, lon in
        PlaceKey(countryCode: lon < 0 ? "AA" : "BB", subdivisionCode: "N")
    }

    /// Metro (10 km) around (10, -10); Suburb (3 km) 6 km east of it; Faraway at (10, -30).
    private var matcher: CityMatcher {
        CityMatcher(gazetteer: CityGazetteer(cities: [
            City(id: "gn:1", name: "Metro", countryCode: "AA", subdivisionCode: "AA-N",
                 latitude: 10, longitude: -10, radiusMeters: 10_000),
            City(id: "gn:2", name: "Suburb", countryCode: "AA", subdivisionCode: "AA-N",
                 latitude: 10, longitude: -10 + 6_000 * degreesPerMeter, radiusMeters: 3_000),
            City(id: "gn:3", name: "Faraway", countryCode: "AA", subdivisionCode: "AA-N",
                 latitude: 10, longitude: -30, radiusMeters: 5_000),
        ]))
    }

    private func sample(_ minute: Double, _ lat: Double, _ lon: Double, accuracy: Double = 20) -> EvidenceSample {
        EvidenceSample(timestamp: t0.addingTimeInterval(minute * 60), latitude: lat, longitude: lon, horizontalAccuracy: accuracy)
    }

    /// One fix a minute for `minutes`, jittering within 20 m of (lat, lon).
    private func stay(from start: Double = 0, minutes: Int, lat: Double = 10, lon: Double = -10, accuracy: Double = 20) -> [EvidenceSample] {
        (0...minutes).map { sample(start + Double($0), lat + Double($0 % 3) * 10 * degreesPerMeter, lon, accuracy: accuracy) }
    }

    private func detect(_ samples: [EvidenceSample], config: VisitDetectionConfig = .default) -> [DetectedCityVisit] {
        CityVisitDetector.detect(samples, matcher: matcher, resolve: world, config: config, calendar: utc)
    }

    func testStayOfCityDwellIsACityVisit() {
        let visits = detect(stay(minutes: 25))
        XCTAssertEqual(visits.count, 1)
        XCTAssertEqual(visits.first?.cityId, "gn:1")
        XCTAssertEqual(visits.first?.kind, .visited)
        XCTAssertEqual(visits.first?.countryCode, "AA")
        XCTAssertEqual(visits.first?.subdivisionCode, "N")
        XCTAssertEqual(visits.first?.arrivedAt, t0)
    }

    func testStayShorterThanCityDwellIsTransit() {
        // 12 minutes confirms the country and subdivision (10 min) but not the city (20 min).
        XCTAssertEqual(detect(stay(minutes: 12)).map(\.kind), [.transit])
        XCTAssertEqual(VisitDetector.detect(stay(minutes: 12), resolve: world, calendar: utc).map(\.kind), [.visited, .visited])
    }

    func testDriveThroughIsTransitDespiteTheCountyRuling() {
        // 1 km/min across Metro's western half: 10 minutes inside the radius, never a stay-point.
        let drive = (0...10).map { sample(Double($0), 10, -10 - 8_000 * degreesPerMeter + Double($0) * 1_000 * degreesPerMeter) }
        let visits = detect(drive)
        XCTAssertEqual(visits.map(\.kind), [.transit])
        XCTAssertEqual(visits.first?.cityId, "gn:1")
    }

    func testSingleFixRecordsNothing() {
        XCTAssertEqual(detect([sample(0, 10, -10)]), [])
    }

    func testCoarseFixesAreNotCityEvidence() {
        XCTAssertEqual(detect(stay(minutes: 30, accuracy: 400)), [])
        XCTAssertFalse(VisitDetector.detect(stay(minutes: 30, accuracy: 400), resolve: world, calendar: utc).isEmpty)
    }

    func testCoarseFixInsideAStayDoesNotSplitIt() {
        var samples = stay(minutes: 30)
        samples[15].horizontalAccuracy = 900
        XCTAssertEqual(detect(samples).map(\.kind), [.visited])
    }

    func testOverlappingRadiiNearestCentroidWins() {
        // 5.5 km east of Metro: inside both radii, nearer Suburb's centroid.
        let visits = detect(stay(minutes: 25, lon: -10 + 5_500 * degreesPerMeter))
        XCTAssertEqual(visits.map(\.cityId), ["gn:2"])
    }

    func testOutsideEveryRadiusRecordsNothing() {
        XCTAssertEqual(detect(stay(minutes: 60, lon: -20)), [])
    }

    func testOtherCountryIsNotMatched() {
        let crossBorder = CityMatcher(gazetteer: CityGazetteer(cities: [
            City(id: "gn:9", name: "Border", countryCode: "BB", latitude: 10, longitude: -0.01, radiusMeters: 5_000),
        ]))
        let visits = CityVisitDetector.detect(stay(minutes: 25, lon: -0.01), matcher: crossBorder, resolve: world, calendar: utc)
        XCTAssertEqual(visits, [])
    }

    func testOvernightShortStayIsAVisit() {
        // 23:50 → 00:05 UTC: 15 minutes, under the dwell, but spans local midnight.
        let start = utc.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 23, minute: 50))!
        let samples = (0...15).map {
            EvidenceSample(timestamp: start.addingTimeInterval(Double($0) * 60),
                           latitude: 10, longitude: -10, horizontalAccuracy: 20)
        }
        XCTAssertEqual(detect(samples).map(\.kind), [.visited])
    }

    func testSeparateStaysAreSeparateVisits() {
        // Out of town in between: 55 km away, by road.
        let samples = stay(minutes: 25) + stay(from: 50, minutes: 5, lon: -9.5) + stay(from: 80, minutes: 25)
        XCTAssertEqual(detect(samples).map(\.cityId), ["gn:1", "gn:1"])
    }

    func testLayoverBetweenFlightsIsTransit() {
        // Fly in from Faraway, wait 60 minutes at Metro, fly out to Faraway.
        let samples = stay(minutes: 3, lon: -30) + stay(from: 120, minutes: 60) + stay(from: 300, minutes: 3, lon: -30)
        let metro = detect(samples).filter { $0.cityId == "gn:1" }
        XCTAssertEqual(metro.map(\.kind), [.transit])
    }

    func testShortLayoverRecordsNothing() {
        let samples = stay(minutes: 3, lon: -30) + stay(from: 120, minutes: 20) + stay(from: 300, minutes: 3, lon: -30)
        XCTAssertEqual(detect(samples).filter { $0.cityId == "gn:1" }, [])
    }

    func testLayoverMovingBetweenCityMatchesIsNotAVisit() {
        // Land, wait 25 min at Metro, move to a gate in Suburb's radius for 25 min, fly out.
        let gates = stay(from: 120, minutes: 25) + stay(from: 150, minutes: 25, lon: -10 + 5_500 * degreesPerMeter)
        let samples = stay(minutes: 3, lon: -30) + gates + stay(from: 300, minutes: 3, lon: -30)
        XCTAssertEqual(detect(samples).filter { $0.cityId != "gn:3" }, [])
    }

    func testWalkingAroundAfterLandingIsStillHeldBack() {
        // 30 minutes after landing, moving 100 m a minute: never within one stay radius.
        let walk = (0...30).map { sample(120 + Double($0), 10, -10 + Double($0) * 100 * degreesPerMeter) }
        XCTAssertEqual(detect(stay(minutes: 3, lon: -30) + walk).filter { $0.cityId == "gn:1" }, [])
    }

    func testOpenStayAfterAFlightIsHeldBack() {
        let samples = stay(minutes: 3, lon: -30) + stay(from: 120, minutes: 30)
        XCTAssertEqual(detect(samples).filter { $0.cityId == "gn:1" }, [])
    }

    func testCountyResolverPicksTheCityInTheResolvedCounty() {
        let gazetteer = CityGazetteer(cities: [
            City(id: "gn:1", name: "A", countryCode: "AA", countyFips: "00001", latitude: 10, longitude: -10, radiusMeters: 5_000),
            City(id: "gn:2", name: "B", countryCode: "AA", countyFips: "00002",
                 latitude: 10, longitude: -10 + 2_000 * degreesPerMeter, radiusMeters: 5_000),
        ])
        let visits = CityVisitDetector.detect(stay(minutes: 25), matcher: CityMatcher(gazetteer: gazetteer),
                                              resolve: world, county: { _, _ in "00002" }, calendar: utc)
        XCTAssertEqual(visits.map(\.cityId), ["gn:2"])
    }
}
