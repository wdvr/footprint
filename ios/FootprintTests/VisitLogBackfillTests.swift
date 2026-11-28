import SwiftData
import XCTest
@testable import Footprint

/// Migration of place records into the `Visit` log, and the log feeding stats.
@MainActor
final class VisitLogBackfillTests: XCTestCase {
    private var container: ModelContainer!
    private var pipeline: VisitPipeline!
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15 08:00 UTC
    private let markedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let degreesPerMeter = 1.0 / 111_320
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Schema([VisitedPlace.self, LocationSample.self, Visit.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let defaults = UserDefaults(suiteName: "VisitLogBackfillTests")!
        defaults.removePersistentDomain(forName: "VisitLogBackfillTests")
        pipeline = VisitPipeline(container: container)
        pipeline.defaults = defaults
        pipeline.calendar = utc
        pipeline.resolve = { _, _ in PlaceKey(countryCode: "US", subdivisionCode: "CA") }
    }

    private var context: ModelContext { container.mainContext }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @discardableResult
    private func place(
        _ type: VisitedPlace.RegionType, _ code: String, status: VisitedPlace.PlaceStatus = .visited,
        visitType: VisitedPlace.VisitType = .visited, visitedDate: Date? = nil, isDeleted: Bool = false
    ) -> VisitedPlace {
        let place = VisitedPlace(
            regionType: type, regionCode: code, regionName: code, status: status, visitType: visitType,
            visitedDate: visitedDate, markedAt: markedAt, lastModifiedAt: markedAt, isDeleted: isDeleted, isSynced: true
        )
        context.insert(place)
        return place
    }

    private func visits() throws -> [Visit] {
        try context.fetch(FetchDescriptor<Visit>(sortBy: [SortDescriptor(\.arrivedAt)]))
    }

    private func stay(startingAt start: Date, minutes: Int = 12) -> [EvidenceSample] {
        (0...minutes).map {
            EvidenceSample(timestamp: start.addingTimeInterval(Double($0) * 60),
                           latitude: 37 + Double($0 % 3) * 10 * degreesPerMeter, longitude: -122, horizontalAccuracy: 20)
        }
    }

    // MARK: - Migration

    func testExistingPlacesMigrateAsGrandfatheredVisits() throws {
        place(.country, "FR", visitedDate: date(2019, 6, 1))
        place(.usState, "CA", visitedDate: date(2020, 3, 1))
        place(.country, "JP")
        try context.save()

        let result = VisitLogBackfill.run(in: context)

        XCTAssertEqual(result.inserted, 3)
        let rows = try visits()
        XCTAssertTrue(rows.allSatisfy {
            $0.evidence == .grandfathered && $0.kind == .visited && $0.source == .manual && $0.sampleCount == 0
        })
        let byCode = Dictionary(uniqueKeysWithValues: rows.map { ($0.subdivisionCode ?? $0.countryCode!, $0) })
        XCTAssertEqual(byCode["FR"]?.arrivedAt, date(2019, 6, 1))
        XCTAssertEqual(byCode["FR"]?.level, .country)
        XCTAssertEqual(byCode["CA"]?.level, .subdivision)
        XCTAssertEqual(byCode["CA"]?.countryCode, "US")
        XCTAssertEqual(byCode["CA"]?.arrivedAt, date(2020, 3, 1))
        XCTAssertEqual(byCode["JP"]?.isDateKnown, false)
        XCTAssertEqual(byCode["JP"]?.arrivedAt, markedAt)
    }

    func testMigrationLeavesPlaceRecordsUntouched() throws {
        let france = place(.country, "FR", visitedDate: date(2019, 6, 1))
        try context.save()

        VisitLogBackfill.run(in: context)

        XCTAssertEqual(france.visitType, "visited")
        XCTAssertEqual(france.visitCount, 1)
        XCTAssertEqual(france.lastModifiedAt, markedAt)
        XCTAssertTrue(france.isSynced)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<VisitedPlace>()), 1)
    }

    func testOnlyLiveVisitedPlacesMigrate() throws {
        place(.country, "IS", status: .bucketList)
        place(.country, "PT", visitedDate: date(2019, 1, 1), isDeleted: true)
        place(.country, "QA", visitType: .transit, visitedDate: date(2021, 1, 1))
        try context.save()

        VisitLogBackfill.run(in: context)

        let rows = try visits()
        XCTAssertEqual(rows.map(\.countryCode), ["QA"])
        // A place the user explicitly marked as transit keeps that meaning.
        XCTAssertEqual(rows.first?.kind, .transit)
    }

    func testMigrationIsIdempotent() throws {
        place(.country, "FR", visitedDate: date(2019, 6, 1))
        place(.usState, "CA")
        try context.save()

        VisitLogBackfill.run(in: context)
        XCTAssertEqual(VisitLogBackfill.run(in: context), VisitLogBackfill.Result())
        XCTAssertEqual(try visits().count, 2)
    }

    func testDuplicatePlaceRecordsMigrateOnce() throws {
        place(.country, "FR", visitedDate: date(2020, 6, 1))
        place(.country, "FR", visitedDate: date(2019, 6, 1))
        try context.save()

        VisitLogBackfill.run(in: context)

        XCTAssertEqual(try visits().map(\.arrivedAt), [date(2019, 6, 1)])
    }

    func testPrefixedSubdivisionCodesMapToTheShortCode() {
        XCTAssertEqual(VisitLogBackfill.placeID(regionType: "uk_country", regionCode: "GB-WRL"),
                       VisitLog.PlaceID(level: .subdivision, countryCode: "GB", subdivisionCode: "WRL"))
        XCTAssertNil(VisitLogBackfill.placeID(regionType: "not_a_region_type", regionCode: "X"))
    }

    func testMirrorFollowsEditsAndRemovals() throws {
        let france = place(.country, "FR", visitedDate: date(2019, 6, 1))
        let spain = place(.country, "ES", visitedDate: date(2019, 7, 1))
        try context.save()
        VisitLogBackfill.run(in: context)

        france.visitedDate = date(2018, 5, 1)
        spain.isDeleted = true
        try context.save()
        let result = VisitLogBackfill.run(in: context)

        XCTAssertEqual(result, VisitLogBackfill.Result(inserted: 0, updated: 1, removed: 1))
        XCTAssertEqual(try visits().map(\.arrivedAt), [date(2018, 5, 1)])
    }

    // MARK: - Interplay with detected visits

    func testDetectedVisitsNeedNoMirror() throws {
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))

        XCTAssertEqual(VisitLogBackfill.run(in: context).inserted, 0)
        XCTAssertTrue(try visits().allSatisfy { $0.evidence == .detected })
    }

    func testLayoverDoesNotReplaceAVisitedPlaceInTheLog() throws {
        // The pipeline dates an undated visited place from a layover without demoting it.
        place(.country, "QA", visitedDate: t0)
        context.insert(Visit(DetectedVisit(
            level: .country, countryCode: "QA", subdivisionCode: nil, kind: .transit,
            arrivedAt: t0, departedAt: t0.addingTimeInterval(3600),
            centroidLatitude: 25.27, centroidLongitude: 51.6, sampleCount: 20, source: .gps
        )))
        try context.save()
        XCTAssertEqual(VisitLogBackfill.run(in: context), .init(inserted: 1))
        let rows = try visits()
        XCTAssertEqual(rows.map(\.kind).sorted { $0.rawValue < $1.rawValue }, [.transit, .visited])
        XCTAssertEqual(rows.first { $0.evidence == .grandfathered }?.kind, .visited)
        XCTAssertEqual(pipeline.travelStats(now: t0).placesVisited, 1)
    }

    private func detected(_ kind: DetectedVisitKind, at arrival: Date) -> Visit {
        Visit(DetectedVisit(
            level: .country, countryCode: "QA", subdivisionCode: nil, kind: kind,
            arrivedAt: arrival, departedAt: arrival.addingTimeInterval(3600),
            centroidLatitude: 25.27, centroidLongitude: 51.6, sampleCount: 20, source: .gps
        ))
    }

    func testDetectedLayoverExplainsATransitPlace() throws {
        place(.country, "QA", visitType: .transit, visitedDate: t0)
        context.insert(detected(.transit, at: t0))
        try context.save()
        XCTAssertEqual(VisitLogBackfill.run(in: context), .init())
        XCTAssertEqual(try visits().count, 1)
    }

    func testLayoverThenFullVisitCreditsTheFullVisit() throws {
        // The pipeline keeps the layover date when a later stay upgrades the place.
        let later = t0.addingTimeInterval(40 * 86400)
        place(.country, "QA", visitedDate: t0)
        context.insert(detected(.transit, at: t0))
        context.insert(detected(.visited, at: later))
        try context.save()
        XCTAssertEqual(VisitLogBackfill.run(in: context), .init())
        let firstVisits = VisitLog.firstVisits(pipeline.logEntries())
        XCTAssertEqual(firstVisits.map(\.value), [later])
    }

    func testHistoryOlderThanTheEvidenceIsStillMirrored() throws {
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))
        let country = try XCTUnwrap(try context.fetch(FetchDescriptor<VisitedPlace>()).first { $0.regionType == "country" })
        country.visitedDate = date(2015, 8, 1)
        try context.save()

        VisitLogBackfill.run(in: context)

        let grandfathered = try visits().filter { $0.evidence == .grandfathered }
        XCTAssertEqual(grandfathered.map(\.arrivedAt), [date(2015, 8, 1)])
        XCTAssertEqual(grandfathered.first?.level, .country)
    }

    func testDetectionNeverMergesIntoAGrandfatheredRow() throws {
        place(.country, "US", visitedDate: t0)
        try context.save()
        VisitLogBackfill.run(in: context)

        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))

        let rows = try visits().filter { $0.level == .country }
        XCTAssertEqual(rows.map(\.evidence).sorted { $0.rawValue < $1.rawValue }, [.detected, .grandfathered])
        XCTAssertEqual(rows.first { $0.evidence == .grandfathered }?.sampleCount, 0)
    }

    func testDriveThroughFeedsATransitPlaceThatALaterStayUpgrades() throws {
        pipeline.config.passThroughCountsAsVisit = false
        let drive = (0...4).map {
            EvidenceSample(timestamp: t0.addingTimeInterval(Double($0) * 60),
                           latitude: 37 + Double($0) * 1000 * degreesPerMeter, longitude: -122, horizontalAccuracy: 20)
        }
        pipeline.record(drive, now: t0.addingTimeInterval(300))
        let state = { try XCTUnwrap(try self.context.fetch(FetchDescriptor<VisitedPlace>()).first { $0.regionType == "us_state" }) }
        XCTAssertTrue(try state().isTransit)

        let later = t0.addingTimeInterval(2 * 86_400)
        pipeline.record(stay(startingAt: later), now: later.addingTimeInterval(3600))

        XCTAssertTrue(try state().isFullVisit)
        XCTAssertEqual(try state().visitedDate, t0)
        XCTAssertEqual(try state().visitCount, 2)
    }

    // MARK: - Stats from the log

    func testTravelStatsDeriveStreaksFromMigratedHistoryAndDistanceFromStays() throws {
        place(.country, "FR", visitedDate: date(2026, 10, 3))
        place(.country, "BE", visitedDate: date(2026, 11, 20))
        try context.save()
        // Two stays ~111 km apart, in California then (north of 37.5°) Nevada.
        pipeline.resolve = { lat, _ in PlaceKey(countryCode: "US", subdivisionCode: lat < 37.5 ? "CA" : "NV") }
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))
        let later = t0.addingTimeInterval(86_400)
        pipeline.record(stay(startingAt: later).map {
            EvidenceSample(timestamp: $0.timestamp, latitude: $0.latitude + 1, longitude: $0.longitude,
                           horizontalAccuracy: $0.horizontalAccuracy)
        }, now: later.addingTimeInterval(3600))
        // Added by hand after launch: picked up by the stats read.
        place(.country, "DE", visitedDate: date(2026, 12, 5))
        try context.save()

        let stats = pipeline.travelStats(now: later)

        // Oct, Nov, Dec 2026 (grandfathered) + Jan 2027 (detected).
        XCTAssertEqual(stats.months, VisitLog.Streak(longest: 4, current: 4))
        XCTAssertEqual(stats.placesVisited, 6)
        XCTAssertEqual(stats.distanceMeters, 111_195, accuracy: 500)
        XCTAssertEqual(pipeline.status().distanceKm, 111.2, accuracy: 0.5)
    }
}
