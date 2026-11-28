import SwiftData
import XCTest
@testable import Footprint

@MainActor
final class SubdivisionCodeMigrationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: VisitedPlace.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func live() throws -> [VisitedPlace] {
        try context.fetch(FetchDescriptor<VisitedPlace>(predicate: #Predicate { !$0.isDeleted }))
    }

    func testShortCode() {
        XCTAssertEqual(SubdivisionCode.short("GB-MAN"), "MAN")
        XCTAssertEqual(SubdivisionCode.short("FR-75C"), "75C")
        XCTAssertEqual(SubdivisionCode.short("CA"), "CA")
    }

    func testPrefixedCodeIsReplacedByShortCode() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let old = VisitedPlace(regionType: .ukCountry, regionCode: "GB-MAN", regionName: "Manchester",
                               visitedDate: date, isSynced: true)
        context.insert(old)

        XCTAssertEqual(SubdivisionCodeMigration.run(in: context, now: now), 1)

        XCTAssertTrue(old.isDeleted)
        XCTAssertFalse(old.isSynced)
        let places = try live()
        XCTAssertEqual(places.map(\.regionCode), ["MAN"])
        XCTAssertEqual(places.first?.visitedDate, date)
        XCTAssertEqual(places.first?.regionType, VisitedPlace.RegionType.ukCountry.rawValue)
        XCTAssertFalse(places.first!.isSynced)
    }

    func testDuplicateMergesIntoExistingShortCode() throws {
        let early = Date(timeIntervalSince1970: 1_600_000_000)
        let existing = VisitedPlace(regionType: .ukCountry, regionCode: "MAN", regionName: "Manchester",
                                    status: .bucketList, isSynced: true)
        context.insert(existing)
        context.insert(VisitedPlace(regionType: .ukCountry, regionCode: "GB-MAN", regionName: "Manchester",
                                    visitedDate: early))

        XCTAssertEqual(SubdivisionCodeMigration.run(in: context, now: now), 1)

        let places = try live()
        XCTAssertEqual(places.count, 1)
        XCTAssertTrue(places[0] === existing)
        XCTAssertEqual(existing.visitedDate, early)
        XCTAssertTrue(existing.isVisited)
        XCTAssertFalse(existing.isSynced)
    }

    func testLeavesValidCodesAndOtherCountryPrefixesAlone() throws {
        context.insert(VisitedPlace(regionType: .usState, regionCode: "CA", regionName: "California"))
        context.insert(VisitedPlace(regionType: .country, regionCode: "GB", regionName: "United Kingdom"))
        context.insert(VisitedPlace(regionType: .ukCountry, regionCode: "FR-75C", regionName: "Paris"))

        XCTAssertEqual(SubdivisionCodeMigration.run(in: context, now: now), 0)
        XCTAssertEqual(try live().count, 3)
    }

    func testCodeMissingFromRegionListKeepsItsName() throws {
        context.insert(VisitedPlace(regionType: .ukCountry, regionCode: "GB-ZZZ", regionName: "Nowhere"))

        XCTAssertEqual(SubdivisionCodeMigration.run(in: context, now: now), 1)
        let places = try live()
        XCTAssertEqual(places.map(\.regionCode), ["ZZZ"])
        XCTAssertEqual(places.first?.regionName, "Nowhere")
    }

    func testRemovedShortCodeIsNotRestored() throws {
        context.insert(VisitedPlace(regionType: .ukCountry, regionCode: "MAN", regionName: "Manchester",
                                    lastModifiedAt: Date(timeIntervalSince1970: 1_750_000_000), isDeleted: true))
        let old = VisitedPlace(regionType: .ukCountry, regionCode: "GB-MAN", regionName: "Manchester",
                               lastModifiedAt: Date(timeIntervalSince1970: 1_700_000_000))
        context.insert(old)

        XCTAssertEqual(SubdivisionCodeMigration.run(in: context, now: now), 1)
        XCTAssertTrue(old.isDeleted)
        XCTAssertTrue(try live().isEmpty)
    }

    func testRunningTwiceIsANoOp() throws {
        context.insert(VisitedPlace(regionType: .ukCountry, regionCode: "GB-MAN", regionName: "Manchester"))
        SubdivisionCodeMigration.run(in: context, now: now)
        XCTAssertEqual(SubdivisionCodeMigration.run(in: context, now: now), 0)
        XCTAssertEqual(try live().map(\.regionCode), ["MAN"])
    }
}
