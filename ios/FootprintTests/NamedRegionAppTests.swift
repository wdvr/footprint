import SwiftData
import XCTest
@testable import Footprint

/// Named regions against the app: bundle, GeographicData and VisitedPlace rows.
final class NamedRegionAppTests: XCTestCase {
    func testBundledCatalogLoads() {
        XCTAssertGreaterThan(NamedRegionCatalog.bundled.regions.count, 75)
        XCTAssertNotNil(NamedRegionCatalog.bundled.region(id: "us-bay-area"))
    }

    func testSubdivisionTypeMapMatchesGeographicData() {
        for country in GeographicData.countries where !GeographicData.states(for: country.id).isEmpty {
            let type = GeographicData.regionType(for: country.id)
            XCTAssertNotNil(type, country.id)
            if let type {
                XCTAssertEqual(RegionResolver.subdivisionCountries[type.rawValue], country.id, type.rawValue)
            }
        }
        XCTAssertEqual(RegionResolver.subdivisionCountries.count, Set(RegionResolver.subdivisionCountries.values).count)
    }

    func testEverySubdivisionAndCountryMemberExists() {
        let countries = Set(GeographicData.countries.map(\.id))
        for region in NamedRegionCatalog.bundled.regions {
            for key in region.memberKeys {
                switch RegionMemberKey(key) {
                case .country(let code):
                    XCTAssertTrue(countries.contains(code), "\(region.id): \(key)")
                case .subdivision(let country, let code):
                    XCTAssertTrue(GeographicData.states(for: country).contains { $0.id == code }, "\(region.id): \(key)")
                    XCTAssertEqual(region.memberName(key), GeographicData.states(for: country).first { $0.id == code }?.name)
                case .usCounty, .city:
                    break
                case nil:
                    XCTFail("\(region.id): unparseable \(key)")
                }
            }
        }
    }

    @MainActor
    func testVisitedKeysFromPlacesSkipBucketListDeletedAndTransitRows() throws {
        let container = try ModelContainer(for: VisitedPlace.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let places = [
            VisitedPlace(regionType: .usState, regionCode: "MA", regionName: "Massachusetts"),
            VisitedPlace(regionType: .usState, regionCode: "VT", regionName: "Vermont", status: .bucketList),
            VisitedPlace(regionType: .usState, regionCode: "ME", regionName: "Maine", isDeleted: true),
            VisitedPlace(regionType: .country, regionCode: "CH", regionName: "Switzerland", visitType: .transit),
            VisitedPlace(regionType: .country, regionCode: "AT", regionName: "Austria"),
        ]
        for place in places { context.insert(place) }

        let keys = RegionResolver.visitedKeys(from: places)
        XCTAssertEqual(keys, ["US-MA", "AT"], "transit does not count toward coverage (§2.5)")
        let newEngland = try XCTUnwrap(NamedRegionCatalog.bundled.region(id: "us-new-england"))
        XCTAssertEqual(RegionResolver.coverage(of: newEngland, visitedKeys: keys).visitedMembers, ["US-MA"])
    }

    func testRegionTypeIsAdditive() {
        XCTAssertEqual(VisitedPlace.RegionType(rawValue: "region"), .region)
        XCTAssertEqual(VisitedPlace.RegionType.country.rawValue, "country")
        XCTAssertEqual(VisitedPlace.RegionType.usState.rawValue, "us_state")
    }
}
