import XCTest
@testable import Footprint

/// Named regions (§2.4): bundled dataset shape, marquee sets against their real-world
/// definitions, and coverage math per kind. Foundation-only, so it also runs on Linux.
final class NamedRegionTests: XCTestCase {
    private static let datasetURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Footprint/Resources/GeoData/named_regions.json")

    private var catalog: NamedRegionCatalog {
        get throws { try NamedRegionCatalog(data: Data(contentsOf: Self.datasetURL)) }
    }

    private func region(_ id: String) throws -> NamedRegion {
        try XCTUnwrap(try catalog.region(id: id), "missing region \(id)")
    }

    private func keys(_ rows: [(String, String)]) -> Set<String> {
        RegionResolver.visitedKeys(rows.map { (regionType: $0.0, regionCode: $0.1) })
    }

    // MARK: - Dataset

    func testDatasetHasTheV1SetOfAboutEightyRegions() throws {
        let regions = try catalog.regions
        XCTAssertTrue((75...100).contains(regions.count), "v1 ships ~80 regions, got \(regions.count)")
        XCTAssertEqual(Set(regions.map(\.id)).count, regions.count, "region ids are unique")
        for kind in NamedRegion.Kind.allCases {
            XCTAssertFalse(try catalog.regions(of: kind).isEmpty, "no \(kind) regions")
        }
    }

    func testEveryRegionIsWellFormed() throws {
        for region in try catalog.regions {
            XCTAssertFalse(region.memberKeys.isEmpty, region.id)
            XCTAssertEqual(Set(region.memberKeys).count, region.memberKeys.count, "\(region.id) duplicate member")
            XCTAssertFalse(region.blurb.isEmpty, region.id)
            for key in region.memberKeys {
                XCTAssertNotNil(RegionMemberKey(key), "\(region.id): unparseable member \(key)")
                XCTAssertNotEqual(region.memberName(key), key, "\(region.id): no name for \(key)")
            }
        }
    }

    func testTopTwentyFiveUSMetrosAreCBSACountyLists() throws {
        let metros = try catalog.regions.filter { $0.cbsa != nil }
        XCTAssertEqual(metros.count, 25)
        for metro in metros {
            XCTAssertEqual(metro.kind, .metro, metro.id)
            for key in metro.memberKeys {
                guard case .usCounty = RegionMemberKey(key) else {
                    return XCTFail("\(metro.id): \(key) is not a county")
                }
            }
        }
        XCTAssertEqual(try region("us-metro-los-angeles").memberKeys.sorted(), ["06037", "06059"])
        XCTAssertEqual(try region("us-metro-san-francisco").memberKeys.sorted(), ["06001", "06013", "06041", "06075", "06081"])
        XCTAssertEqual(try region("us-metro-new-york").memberKeys.count, 22)
    }

    // MARK: - Marquee sets, by hand against their real-world definitions

    func testBayAreaIsTheNineCounties() throws {
        let bayArea = try region("us-bay-area")
        // Alameda, Contra Costa, Marin, Napa, San Francisco, San Mateo, Santa Clara, Solano, Sonoma.
        XCTAssertEqual(Set(bayArea.memberKeys), ["06001", "06013", "06041", "06055", "06075", "06081", "06085", "06095", "06097"])
        XCTAssertTrue(bayArea.isMedalSet)
        XCTAssertEqual(bayArea.memberName("06085"), "Santa Clara County, CA")
    }

    func testSiliconValleyIsSantaClaraSanMateoAlamedaAndSanFrancisco() throws {
        XCTAssertEqual(Set(try region("us-silicon-valley").memberKeys), ["06085", "06081", "06001", "06075"])
    }

    func testNewEnglandIsTheSixStates() throws {
        let newEngland = try region("us-new-england")
        XCTAssertEqual(Set(newEngland.memberKeys), ["US-CT", "US-MA", "US-ME", "US-NH", "US-RI", "US-VT"])
        XCTAssertEqual(newEngland.kind, .cultural)
        XCTAssertTrue(newEngland.isMedalSet)
    }

    func testLakeTahoeIsItsSixCountiesAcrossTwoStates() throws {
        let tahoe = try region("us-lake-tahoe")
        // El Dorado, Placer, Nevada (CA); Douglas, Washoe, Carson City (NV).
        XCTAssertEqual(Set(tahoe.memberKeys), ["06017", "06061", "06057", "32005", "32031", "32510"])
        XCTAssertEqual(tahoe.kind, .geographic)
        XCTAssertTrue(tahoe.isMedalSet)
    }

    func testSpecHandPickedRegions() throws {
        XCTAssertEqual(Set(try region("us-wine-country").memberKeys), ["06055", "06097"])
        XCTAssertEqual(try region("us-cape-cod").memberKeys, ["25001"])
        XCTAssertEqual(try region("us-the-hamptons").memberKeys, ["36103"])
        XCTAssertEqual(try region("us-death-valley").memberKeys, ["06027"])
        XCTAssertEqual(Set(try region("fr-provence").memberKeys), ["FR-04", "FR-05", "FR-06", "FR-13", "FR-83", "FR-84"])
        XCTAssertEqual(try region("it-tuscany").memberKeys.count, 10)
        XCTAssertEqual(try region("de-bavaria").memberKeys, ["DE-BY"])
        XCTAssertEqual(Set(try region("es-catalonia").memberKeys), ["ES-B", "ES-GI", "ES-L", "ES-T"])
        XCTAssertEqual(Set(try region("be-flanders").memberKeys), ["BE-VAN", "BE-VLI", "BE-VOV", "BE-VWV", "BE-VBR"])
        XCTAssertEqual(Set(try region("jp-kanto").memberKeys), ["JP-08", "JP-09", "JP-10", "JP-11", "JP-12", "JP-13", "JP-14"])
        XCTAssertTrue(try region("jp-kansai").memberKeys.contains("JP-27"))
        for id in ["gb-cotswolds", "nl-randstad", "au-outback"] {
            XCTAssertNotNil(try catalog.region(id: id), id)
        }
        let alps = try region("eu-alps")
        XCTAssertTrue(Set(["FR-74", "CH", "AT", "IT-BZ", "DE-BY"]).isSubset(of: Set(alps.memberKeys)), "the Alps cross borders")
    }

    // MARK: - Member keys

    func testMemberKeyParsing() {
        XCTAssertEqual(RegionMemberKey("CH"), .country("CH"))
        XCTAssertEqual(RegionMemberKey("FR-13"), .subdivision(country: "FR", code: "13"))
        XCTAssertEqual(RegionMemberKey("ES-B"), .subdivision(country: "ES", code: "B"))
        XCTAssertEqual(RegionMemberKey("06001"), .usCounty(fips: "06001"))
        XCTAssertEqual(RegionMemberKey("gn:5391959"), .city(id: "gn:5391959"))
        XCTAssertNil(RegionMemberKey("bogus"))
        XCTAssertNil(RegionMemberKey("0600"))
        for key in ["CH", "FR-13", "06001", "gn:5391959"] {
            XCTAssertEqual(RegionMemberKey(key)?.key, key)
        }
    }

    func testSavedRowsMapToPlaceKeys() {
        XCTAssertEqual(RegionResolver.placeKey(regionType: "country", regionCode: "CH"), "CH")
        XCTAssertEqual(RegionResolver.placeKey(regionType: "us_state", regionCode: "MA"), "US-MA")
        XCTAssertEqual(RegionResolver.placeKey(regionType: "french_region", regionCode: "13"), "FR-13")
        // Boundary-form codes saved by older photo imports.
        XCTAssertEqual(RegionResolver.placeKey(regionType: "uk_country", regionCode: "GB-GLS"), "GB-GLS")
        XCTAssertEqual(RegionResolver.placeKey(regionType: "us_county", regionCode: "06085"), "06085")
        XCTAssertEqual(RegionResolver.placeKey(regionType: "city", regionCode: "gn:5391959"), "gn:5391959")
        XCTAssertNil(RegionResolver.placeKey(regionType: "region", regionCode: "us-bay-area"))
        XCTAssertNil(RegionResolver.placeKey(regionType: "landmark", regionCode: "eiffel-tower"))
    }

    // MARK: - Coverage math per kind

    func testMetroCoverageFromCountyVisits() throws {
        let bayArea = try region("us-bay-area")
        let none = RegionResolver.coverage(of: bayArea, visitedKeys: keys([("us_state", "CA")]))
        XCTAssertFalse(none.isVisited, "a state visit says nothing about which county")
        XCTAssertEqual(none.fraction, 0)

        let three = RegionResolver.coverage(
            of: bayArea, visitedKeys: keys([("us_county", "06075"), ("us_county", "06081"), ("us_county", "06085"), ("us_county", "06037")])
        )
        XCTAssertTrue(three.isVisited)
        XCTAssertFalse(three.isComplete)
        XCTAssertEqual(three.visitedCount, 3)
        XCTAssertEqual(three.totalMembers, 9)
        XCTAssertEqual(three.fraction, 3.0 / 9.0, accuracy: 1e-9)
        XCTAssertEqual(three.visitedMembers, ["06075", "06081", "06085"], "member order")
        XCTAssertTrue(three.isMemberVisited("06085"))
        XCTAssertFalse(three.isMemberVisited("06001"))
    }

    func testCulturalCoverageFromSubdivisionVisits() throws {
        let newEngland = try region("us-new-england")
        let one = RegionResolver.coverage(of: newEngland, visitedKeys: keys([("us_state", "MA")]))
        XCTAssertTrue(one.isVisited, "one member visited makes the region visited")
        XCTAssertEqual(one.fraction, 1.0 / 6.0, accuracy: 1e-9)

        let all = RegionResolver.coverage(
            of: newEngland, visitedKeys: keys(["CT", "MA", "ME", "NH", "RI", "VT"].map { ("us_state", $0) })
        )
        XCTAssertTrue(all.isComplete)
        XCTAssertEqual(all.fraction, 1)

        let provence = RegionResolver.coverage(of: try region("fr-provence"), visitedKeys: keys([("french_region", "13"), ("french_region", "75")]))
        XCTAssertEqual(provence.visitedMembers, ["FR-13"])
    }

    func testGeographicCoverageAcrossBordersAndLevels() throws {
        let alps = try region("eu-alps")
        let visited = keys([("country", "CH"), ("french_region", "74"), ("italian_region", "BZ"), ("country", "FR")])
        let coverage = RegionResolver.coverage(of: alps, visitedKeys: visited)
        XCTAssertEqual(Set(coverage.visitedMembers), ["CH", "FR-74", "IT-BZ"], "a France visit is not an Alps member")
        XCTAssertEqual(coverage.fraction, 3.0 / Double(alps.memberKeys.count), accuracy: 1e-9)

        let tahoe = RegionResolver.coverage(of: try region("us-lake-tahoe"), visitedKeys: keys([("us_county", "32510")]))
        XCTAssertTrue(tahoe.isVisited)
        XCTAssertEqual(tahoe.fraction, 1.0 / 6.0, accuracy: 1e-9)
    }

    func testCatalogLookups() throws {
        let catalog = try catalog
        let containingSF = Set(catalog.regions(containing: "06075").map(\.id))
        XCTAssertEqual(containingSF, ["us-bay-area", "us-silicon-valley", "us-metro-san-francisco"])
        let coverages = catalog.coverage(visitedKeys: keys([("us_county", "06075")]))
        XCTAssertEqual(coverages.count, catalog.regions.count)
        XCTAssertEqual(Set(coverages.filter(\.isVisited).map(\.region.id)), containingSF)
    }

    func testEmptyRegionCoverageIsZero() {
        let empty = NamedRegion(id: "xx-empty", name: "Empty", kind: .cultural, memberKeys: [], blurb: "")
        let coverage = RegionResolver.coverage(of: empty, visitedKeys: ["US"])
        XCTAssertEqual(coverage.fraction, 0)
        XCTAssertFalse(coverage.isVisited)
        XCTAssertFalse(coverage.isComplete)
    }
}
