import SwiftData
import XCTest
@testable import Footprint

@MainActor
final class LegacyPlaceMigrationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Schema([VisitedPlace.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
    }

    private func activePlaces() throws -> [VisitedPlace] {
        try context.fetch(FetchDescriptor<VisitedPlace>()).filter { !$0.isDeleted }
    }

    func testSevastopolSubdivisionVisitMovesToOwnTerritory() throws {
        let visited = Date(timeIntervalSince1970: 1_500_000_000)
        context.insert(VisitedPlace(regionType: .russianFederalSubject, regionCode: "SEV", regionName: "Sevastopol", visitedDate: visited))

        LegacyPlaceMigration.run(in: context)

        let places = try activePlaces()
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.regionType, VisitedPlace.RegionType.country.rawValue)
        XCTAssertEqual(places.first?.regionCode, "XS")
        XCTAssertEqual(places.first?.visitedDate, visited)
    }

    func testSingleProvinceCommunityMovesToProvinceCode() throws {
        context.insert(VisitedPlace(regionType: .spanishCommunity, regionCode: "MD", regionName: "Madrid", status: .bucketList))

        LegacyPlaceMigration.run(in: context)

        let places = try activePlaces()
        XCTAssertEqual(places.map(\.regionCode), ["M"])
        XCTAssertEqual(places.first?.statusEnum, .bucketList)
        XCTAssertTrue(GeographicData.states(for: "ES").contains { $0.id == "M" })
    }

    func testMultiProvinceCommunityIsLeftUntouched() throws {
        context.insert(VisitedPlace(regionType: .spanishCommunity, regionCode: "AN", regionName: "Andalusia"))

        LegacyPlaceMigration.run(in: context)

        XCTAssertEqual(try activePlaces().map(\.regionCode), ["AN"])
    }

    func testMigrationIsIdempotentAndDoesNotDuplicateExistingTarget() throws {
        context.insert(VisitedPlace(regionType: .country, regionCode: "XS", regionName: "Sevastopol"))
        context.insert(VisitedPlace(regionType: .russianFederalSubject, regionCode: "SEV", regionName: "Sevastopol"))

        LegacyPlaceMigration.run(in: context)
        LegacyPlaceMigration.run(in: context)

        let places = try activePlaces()
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.regionCode, "XS")
    }

    func testEveryMigrationTargetExistsInGeographicData() {
        for province in LegacyPlaceMigration.spanishCommunityToProvince.values {
            XCTAssertTrue(GeographicData.states(for: "ES").contains { $0.id == province }, province)
        }
        XCTAssertTrue(GeographicData.countries.contains { $0.id == "XS" })
    }
}
