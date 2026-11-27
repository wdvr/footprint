import XCTest
@testable import Footprint

/// County data packs, index and matcher (§2.2). Data is read from the repo checkout so the
/// assertions are about the committed files, not a copy.
final class CountyDataTests: XCTestCase {
    static let countiesDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Footprint/Resources/GeoData/counties")

    static let loader: CountyMatcher.Loader = { state in
        try? Data(contentsOf: countiesDir.appendingPathComponent("counties_US-\(state).json"))
    }

    static let index: CountyIndex = {
        let data = try! Data(contentsOf: countiesDir.appendingPathComponent("counties_index.json"))
        return try! CountyIndex(data: data)
    }()

    // MARK: - Data audit: FIPS <-> index <-> packs

    func testIndexCoversFiftyStatesDCAndPuertoRico() {
        let index = Self.index
        XCTAssertEqual(index.states.count, 52)
        XCTAssertTrue(index.states.contains("DC"))
        XCTAssertTrue(index.states.contains("PR"))
        XCTAssertEqual(index.counties.count, 3_222)
        XCTAssertEqual(index.counties(inState: "LA").count, 64)
        XCTAssertEqual(index.counties(inState: "TX").count, 254)
        XCTAssertEqual(index.counties(inState: "PR").count, 78)
        XCTAssertEqual(index.counties(inState: "DC").count, 1)
    }

    func testEveryIndexStateIsAnAppSubdivision() {
        let usStates = Set(GeographicData.states(for: "US").map(\.id))
        let missing = Set(Self.index.states).subtracting(usStates)
        XCTAssertTrue(missing.isEmpty, "index states without a US subdivision: \(missing.sorted())")
    }

    func testPacksAndIndexAgreeOnFips() {
        for state in Self.index.states {
            let packFips = Set(CountyPack.decodeOrFail(Self.loader(state), state: state).map(\.fips))
            let indexFips = Set(Self.index.counties(inState: state).map(\.fips))
            XCTAssertEqual(packFips, indexFips, "state \(state)")
        }
        for (fips, county) in Self.index.counties {
            XCTAssertEqual(fips.count, 5, fips)
            XCTAssertTrue(fips.allSatisfy(\.isNumber), fips)
            XCTAssertFalse(county.name.isEmpty, fips)
            XCTAssertGreaterThan(county.landKm2, 0, fips)
        }
    }

    func testPacksStayWithinSizeBudget() throws {
        var total = 0
        for file in try FileManager.default.contentsOfDirectory(at: Self.countiesDir, includingPropertiesForKeys: nil) {
            let size = try Data(contentsOf: file).count
            total += size
            if file.lastPathComponent.hasPrefix("counties_US-") {
                XCTAssertLessThanOrEqual(size, 250_000, file.lastPathComponent)
            }
        }
        XCTAssertLessThanOrEqual(total, 6_000_000)
    }

    // MARK: - Matching

    /// One known interior point per county (3,222 fixtures): each resolves to its own county.
    func testEveryCountyMatchesItsInteriorPoint() {
        let matcher = CountyMatcher(loader: Self.loader)
        var mismatches: [String] = []
        for county in Self.index.counties.values {
            let match = matcher.county(latitude: county.lat, longitude: county.lon, state: county.state)
            if match != county.fips {
                mismatches.append("\(county.fips) \(county.name) -> \(match ?? "nil")")
            }
        }
        XCTAssertTrue(mismatches.isEmpty, mismatches.prefix(20).joined(separator: "\n"))
    }

    /// Real-world coordinates for county equivalents that are easy to get wrong.
    func testEdgeCaseCountyEquivalents() {
        let cases: [(String, String, Double, Double)] = [
            ("51760", "VA", 37.5407, -77.4360),   // Richmond city (independent city)
            ("24510", "MD", 39.2904, -76.6122),   // Baltimore city
            ("29510", "MO", 38.6270, -90.1994),   // St. Louis city
            ("51610", "VA", 38.8823, -77.1711),   // Falls Church city
            ("51013", "VA", 38.8816, -77.0910),   // Arlington County, next to it
            ("32510", "NV", 39.1638, -119.7674),  // Carson City (consolidated)
            ("22071", "LA", 29.9511, -90.0715),   // Orleans Parish
            ("22033", "LA", 30.4515, -91.1871),   // East Baton Rouge Parish
            ("02020", "AK", 61.2181, -149.9003),  // Anchorage Municipality
            ("02110", "AK", 58.3019, -134.4197),  // Juneau City and Borough
            ("02090", "AK", 64.8378, -147.7164),  // Fairbanks North Star Borough
            ("72127", "PR", 18.4655, -66.1057),   // San Juan Municipio
            ("72113", "PR", 18.0111, -66.6141),   // Ponce Municipio
            ("11001", "DC", 38.8977, -77.0365),   // District of Columbia
            ("15003", "HI", 21.3069, -157.8583),  // Honolulu
            ("15005", "HI", 21.1878, -156.9789),  // Kalawao, the smallest county
            ("36061", "NY", 40.7831, -73.9712),   // New York County (Manhattan)
            ("36047", "NY", 40.6782, -73.9442),   // Kings County (Brooklyn)
            ("06075", "CA", 37.7793, -122.4193),  // San Francisco
            ("06001", "CA", 37.8044, -122.2712),  // Alameda (Oakland)
            ("06037", "CA", 34.0522, -118.2437),  // Los Angeles
            ("17031", "IL", 41.8781, -87.6298),   // Cook
            ("48201", "TX", 29.7604, -95.3698),   // Harris
            ("04013", "AZ", 33.4484, -112.0740),  // Maricopa
            ("53033", "WA", 47.6062, -122.3321),  // King
            ("12086", "FL", 25.7617, -80.1918),   // Miami-Dade
            ("08031", "CO", 39.7392, -104.9903),  // Denver
            ("08014", "CO", 39.9205, -105.0867),  // Broomfield, the newest county
            ("09110", "CT", 41.7658, -72.6734),   // Capitol Planning Region (Hartford)
            ("56029", "WY", 44.5263, -109.0565),  // Park County (Cody)
        ]
        let matcher = CountyMatcher(loader: Self.loader)
        for (fips, state, lat, lon) in cases {
            XCTAssertEqual(matcher.county(latitude: lat, longitude: lon, state: state), fips, "\(fips) \(state)")
        }
    }

    func testPointOutsideStateMatchesNothing() {
        let matcher = CountyMatcher(loader: Self.loader)
        // Mid-Atlantic, and a Nevada point tested against California's pack.
        XCTAssertNil(matcher.county(latitude: 35.0, longitude: -50.0, state: "NC"))
        XCTAssertNil(matcher.county(latitude: 36.1699, longitude: -115.1398, state: "CA"))
    }

    func testMatcherKeepsAtMostFourStatesParsed() {
        let matcher = CountyMatcher(loader: Self.loader)
        for state in ["CA", "NV", "OR", "WA", "ID"] {
            _ = matcher.shapes(forState: state)
        }
        XCTAssertEqual(matcher.loadedStates, ["NV", "OR", "WA", "ID"])
        _ = matcher.shapes(forState: "NV")
        _ = matcher.shapes(forState: "AZ")
        XCTAssertEqual(matcher.loadedStates, ["WA", "ID", "NV", "AZ"])
    }

    func testUnknownStateLoadsNothing() {
        let matcher = CountyMatcher(loader: Self.loader)
        XCTAssertTrue(matcher.shapes(forState: "ZZ").isEmpty)
        XCTAssertNil(matcher.county(latitude: 0, longitude: 0, state: "ZZ"))
    }

    // MARK: - Geometry

    func testRingWithHole() throws {
        let json = """
        {"scale":10,"counties":[{"fips":"00001","bbox":[0,0,10,10],
         "polygons":[[[0,0,100,0,0,100,-100,0],[30,30,40,0,0,40,-40,0]]]}]}
        """
        let shape = try XCTUnwrap(CountyPack.decode(Data(json.utf8)).first)
        XCTAssertTrue(shape.contains(latitude: 1, longitude: 1))
        XCTAssertFalse(shape.contains(latitude: 5, longitude: 5), "inside the hole")
        XCTAssertFalse(shape.contains(latitude: 11, longitude: 5), "outside the bbox")
    }

    func testPluralTerms() {
        XCTAssertEqual(Self.index.pluralTerm(forState: "LA"), "parishes")
        XCTAssertEqual(Self.index.pluralTerm(forState: "CA"), "counties")
    }
}

private extension CountyPack {
    static func decodeOrFail(_ data: Data?, state: String) -> [CountyShape] {
        guard let data, let shapes = try? decode(data) else {
            XCTFail("missing or unreadable pack for \(state)")
            return []
        }
        return shapes
    }
}
