import XCTest
@testable import Footprint

/// The bundled gazetteer from the app bundle, or from the source tree when run outside the app.
enum BundledGazetteer {
    static let shared: CityGazetteer = {
        if let gazetteer = CityGazetteer.bundled { return gazetteer }
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Footprint/Resources/GeoData/\(CityGazetteer.resourceName).json")
        return try! CityGazetteer(data: Data(contentsOf: url))
    }()
}

final class CityGazetteerTests: XCTestCase {
    private var gazetteer: CityGazetteer { BundledGazetteer.shared }
    private var matcher: CityMatcher { CityMatcher(gazetteer: gazetteer) }

    private func city(_ lat: Double, _ lon: Double, _ cc: String, _ sub: String? = nil, county: String? = nil) -> City? {
        matcher.match(latitude: lat, longitude: lon,
                      context: CityPlaceContext(countryCode: cc, subdivisionCode: sub, countyFips: county))
    }

    // MARK: - Data

    func testIdsAreUniqueGeoNamesKeys() {
        let ids = gazetteer.cities.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ids.allSatisfy { $0.range(of: #"^gn:[0-9]+$"#, options: .regularExpression) != nil })
    }

    func testSizeMatchesInclusionRules() {
        XCTAssertGreaterThan(gazetteer.cities.count, 4_500)
        for city in gazetteer.cities where !city.isCapital {
            XCTAssertGreaterThanOrEqual(city.population, city.countryCode == "US" ? 25_000 : 100_000, city.id)
        }
    }

    func testNationalCapitalsAreOnePerCountryForAll195() {
        let capitals = gazetteer.nationalCapitals
        let expected = Set(GeographicData.countries.map(\.id)).subtracting(["TW", "XS"])
        XCTAssertEqual(capitals.count, 195)
        XCTAssertEqual(Set(capitals.map(\.countryCode)), expected)
        for (cc, name) in [("US", "Washington"), ("FR", "Paris"), ("GB", "London"), ("NL", "Amsterdam"),
                           ("BO", "Sucre"), ("VA", "Vatican City"), ("IL", "Jerusalem")] {
            XCTAssertEqual(capitals.first { $0.countryCode == cc }?.name, name, cc)
        }
    }

    func testUSStateCapitalsAre51IncludingDC() {
        let capitals = gazetteer.usStateCapitals
        XCTAssertEqual(capitals.count, 51)
        XCTAssertEqual(Set(capitals.compactMap(\.subdivisionCode)), Set(GeographicData.usStates.map { "US-\($0.id)" }))
        let washington = capitals.first { $0.subdivisionCode == "US-DC" }
        XCTAssertEqual(washington?.name, "Washington")
        XCTAssertEqual(washington?.isNationalCapital, true)
        XCTAssertEqual(capitals.first { $0.subdivisionCode == "US-CA" }?.name, "Sacramento")
        XCTAssertTrue(capitals.allSatisfy(\.isCapital))
    }

    func testRadiiAreClampedAndGrowWithPopulation() {
        XCTAssertTrue(gazetteer.cities.allSatisfy { (1_500...15_000).contains($0.radiusMeters) })
        let nyc = gazetteer.city(id: "gn:5128581")!
        let jerseyCity = gazetteer.city(id: "gn:5099836")!
        XCTAssertEqual(nyc.radiusMeters, 15_000)
        XCTAssertLessThan(jerseyCity.radiusMeters, nyc.radiusMeters)
    }

    func testUSPlacesCarryStateAndCounty() {
        let us = gazetteer.cities.filter { $0.countryCode == "US" && $0.boundaryCountryCode == nil }
        XCTAssertTrue(us.allSatisfy { $0.subdivisionCode?.hasPrefix("US-") == true })
        XCTAssertEqual(gazetteer.city(id: "gn:5099836")?.countyFips, "34017")
    }

    // MARK: - Matching

    func testStaysAcrossNewYorkCityMatchNewYorkCity() {
        for (lat, lon) in [(40.7580, -73.9855), (40.7081, -73.9571), (40.8296, -73.9262), (40.6720, -73.9778)] {
            XCTAssertEqual(city(lat, lon, "US", "NY")?.name, "New York City", "\(lat),\(lon)")
        }
    }

    func testCityAcrossAStateLineIsNotMatchedEvenIfNearer() {
        // Exchange Place, Jersey City: 2.3 km from NYC's centroid, 4.5 km from Jersey City's.
        XCTAssertEqual(city(40.7163, -74.0328, "US", "NJ")?.name, "Jersey City")
        XCTAssertNotEqual(city(40.8270, -73.9750, "US", "NJ")?.name, "New York City")
    }

    func testLondonMatchesInEveryBorough() {
        XCTAssertEqual(city(51.5390, -0.1426, "GB", "CMD")?.name, "London")
        XCTAssertEqual(city(51.5007, -0.1246, "GB", "WSM")?.name, "London")
        XCTAssertEqual(city(51.5450, -0.0553, "GB", "HCK")?.name, "London")
    }

    func testParisDoesNotMatchOutsideItsDepartment() {
        XCTAssertEqual(city(48.8606, 2.3376, "FR", "75")?.name, "Paris")
        XCTAssertNotEqual(city(48.8918, 2.2389, "FR", "92")?.name, "Paris")
    }

    func testVaticanStayMatchesVaticanNotRome() {
        // The bundled outlines put the Vatican inside Italy.
        XCTAssertEqual(city(41.9022, 12.4539, "IT", "RM")?.name, "Vatican City")
        XCTAssertEqual(city(41.8960, 12.4823, "IT", "RM")?.name, "Rome")
    }

    func testNoContextOrNoRadiusMeansNoCity() {
        XCTAssertNil(matcher.match(latitude: 40.758, longitude: -73.9855, context: nil))
        XCTAssertNil(city(44.0, -110.5, "US", "WY"))
        XCTAssertNil(city(40.758, -73.9855, "CA", "ON"))
    }

    // MARK: - Synthetic matching rules

    private let degreesPerMeter = 1.0 / 111_320

    private func synthetic(_ cities: [City]) -> CityMatcher {
        CityMatcher(gazetteer: CityGazetteer(cities: cities))
    }

    private func make(_ id: String, lon: Double, radius: Double = 5_000, cc: String = "AA", sub: String? = "AA-N",
                      subs: [String] = [], fips: String? = nil, bcc: String? = nil) -> City {
        City(id: id, name: id, countryCode: cc, boundaryCountryCode: bcc, subdivisionCode: sub,
             additionalSubdivisionCodes: subs, countyFips: fips, latitude: 0, longitude: lon, radiusMeters: radius)
    }

    func testOverlapNearestCentroidWins() {
        let m = synthetic([make("big", lon: 0, radius: 15_000), make("small", lon: 4_000 * degreesPerMeter)])
        let at = { (meters: Double) in
            m.match(latitude: 0, longitude: meters * self.degreesPerMeter, context: CityPlaceContext(countryCode: "AA", subdivisionCode: "N"))?.id
        }
        XCTAssertEqual(at(1_000), "big")
        XCTAssertEqual(at(3_000), "small")
        XCTAssertEqual(at(12_000), "big")
        XCTAssertNil(at(16_000))
    }

    func testResolvedCountyBreaksTheOverlapTie() {
        let m = synthetic([make("a", lon: 0, fips: "00001"), make("b", lon: 2_000 * degreesPerMeter, fips: "00002")])
        let context = CityPlaceContext(countryCode: "AA", subdivisionCode: "N", countyFips: "00002")
        XCTAssertEqual(m.match(latitude: 0, longitude: 500 * degreesPerMeter, context: context)?.id, "b")
        XCTAssertEqual(m.match(latitude: 0, longitude: 500 * degreesPerMeter,
                               context: CityPlaceContext(countryCode: "AA", subdivisionCode: "N"))?.id, "a")
    }

    func testCountryAndSubdivisionMustBeConsistent() {
        let m = synthetic([make("x", lon: 0, subs: ["AA-E"])])
        func match(_ cc: String, _ sub: String?) -> String? {
            m.match(latitude: 0, longitude: 0, context: CityPlaceContext(countryCode: cc, subdivisionCode: sub))?.id
        }
        XCTAssertEqual(match("AA", "N"), "x")
        XCTAssertEqual(match("AA", "E"), "x")
        XCTAssertEqual(match("AA", nil), "x")
        XCTAssertNil(match("AA", "S"))
        XCTAssertNil(match("BB", "N"))
    }

    func testBoundaryCountryAndAliasesAreAccepted() {
        let border = synthetic([make("laredo", lon: 0, cc: "US", sub: nil, bcc: "MX")])
        XCTAssertEqual(border.match(latitude: 0, longitude: 0, context: CityPlaceContext(countryCode: "MX"))?.id, "laredo")
        let taipei = synthetic([make("taipei", lon: 0, cc: "TW", sub: nil)])
        XCTAssertEqual(taipei.match(latitude: 0, longitude: 0, context: CityPlaceContext(countryCode: "CN-TW"))?.id, "taipei")
    }

    func testGridLookupWorksAcrossTheAntimeridian() {
        let m = synthetic([make("fiji", lon: 179.99, sub: nil)])
        XCTAssertEqual(m.match(latitude: 0, longitude: -179.99, context: CityPlaceContext(countryCode: "AA"))?.id, "fiji")
    }

    // MARK: - Coverage

    func testCoverageIsAgainstTheGazetteerDenominator() {
        let coverage = CityCoverage(gazetteer: gazetteer, visitedCityIds: ["gn:5128581", "gn:2988507", "gn:4140963", "gn:999999999"])
        XCTAssertEqual(coverage.cities, CoverageCount(visited: 3, total: gazetteer.cities.count))
        XCTAssertEqual(coverage.nationalCapitals, CoverageCount(visited: 2, total: 195))
        XCTAssertEqual(coverage.usStateCapitals, CoverageCount(visited: 1, total: 51))
        XCTAssertEqual(coverage.cities(inCountry: "US").visited, 2)
        XCTAssertEqual(coverage.cities(inCountry: "US").total, gazetteer.cities(inCountry: "US").count)
        XCTAssertEqual(coverage.nationalCapitals.label("capitals"), "2 of 195 capitals")
    }

    func testEmptyCoverage() {
        let coverage = CityCoverage(gazetteer: CityGazetteer(cities: []), visitedCityIds: ["gn:1"])
        XCTAssertEqual(coverage.cities, CoverageCount(visited: 0, total: 0))
        XCTAssertEqual(coverage.cities.fraction, 0)
    }
}
