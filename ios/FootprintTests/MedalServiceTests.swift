import SwiftData
import XCTest
@testable import Footprint

/// Retroactive awarding (§4.4) over existing `VisitedPlace` data, and how awards persist.
@MainActor
final class MedalServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }
    private var defaults: UserDefaults!
    private var suiteName: String!
    private let iso = ISO8601DateFormatter()

    override func setUp() async throws {
        container = try ModelContainer(
            for: Schema([VisitedPlace.self, LocationSample.self, Visit.self, EarnedMedal.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        suiteName = "MedalServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        container = nil
    }

    private func makeService() throws -> MedalService {
        let service = MedalService(catalog: try MedalEngineTests.loadCatalog())
        service.defaults = defaults
        service.photoLocations = { [] }
        service.distanceKm = { 0 }
        service.cityMatcherOverride = CityMatcher(gazetteer: CityGazetteer(cities: []))
        return service
    }

    private func date(_ day: String) -> Date { iso.date(from: day + "T12:00:00Z")! }

    @discardableResult
    private func insert(_ type: String, _ code: String, _ day: String?, status: VisitedPlace.PlaceStatus = .visited,
                        visitType: VisitedPlace.VisitType = .visited, in context: ModelContext? = nil) -> VisitedPlace {
        let place = VisitedPlace(regionType: .country, regionCode: code, regionName: code, status: status,
                                 visitType: visitType, visitedDate: day.map(date), markedAt: date("2024-11-01"))
        place.regionType = type
        (context ?? self.context).insert(place)
        return place
    }

    private func insertFixture(into context: ModelContext) throws {
        for place in try MedalEngineTests.loadFixture().places {
            let row = VisitedPlace(
                regionType: .country, regionCode: place.region_code, regionName: place.region_name,
                status: VisitedPlace.PlaceStatus(rawValue: place.status) ?? .visited,
                visitType: VisitedPlace.VisitType(rawValue: place.visit_type) ?? .visited,
                visitedDate: place.visited_date.flatMap(iso.date(from:)),
                markedAt: iso.date(from: place.marked_at)!, isDeleted: place.is_deleted
            )
            row.regionType = place.region_type
            context.insert(row)
        }
        try context.save()
    }

    private func medals(_ context: ModelContext? = nil) -> [String: EarnedMedal] {
        let rows = (try? (context ?? self.context).fetch(FetchDescriptor<EarnedMedal>())) ?? []
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.medalId, $0) })
    }

    // MARK: - Backfill

    func testBackfillAwardsExistingHistoryWithHistoricalDates() throws {
        try insertFixture(into: context)
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-28"))

        XCTAssertTrue(service.isBackfillComplete)
        let explorer = try XCTUnwrap(medals()["explorer_10"])
        XCTAssertEqual(explorer.tier, .silver)
        XCTAssertEqual(explorer.earnedAt, date("2019-07-01"), "earnedAt is the first tier's date")
        XCTAssertEqual(explorer.tierHistory.map(\.earnedAt), [date("2019-07-01"), date("2023-01-02")])
        XCTAssertEqual(explorer.tierHistory.last?.trigger, "Italy")
        XCTAssertTrue(explorer.isRetroactive)
        XCTAssertNil(explorer.surfacedAt)
        XCTAssertEqual(medals()["canada_complete"]?.earnedAt, date("2020-06-13"))
        XCTAssertEqual(medals()["complete_counties_dc"]?.earnedAt, date("2020-01-11"))
        XCTAssertNil(medals()["landlocked"], "transit and deleted places do not count")
    }

    func testBackfillMatchesSharedFixtureExpectations() throws {
        try insertFixture(into: context)
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-28"))
        let fixture = try MedalEngineTests.loadFixture()
        for (id, expected) in fixture.expected {
            let history = medals()[id]?.tierHistory ?? []
            XCTAssertEqual(history.map(\.level), expected.map(\.level), id)
            XCTAssertEqual(history.map { iso.string(from: $0.earnedAt) }, expected.map(\.earnedAt), id)
        }
    }

    func testBackfillIsIdempotent() throws {
        try insertFixture(into: context)
        let service = try makeService()
        let first = service.evaluate(in: context, now: date("2026-11-28"))
        let snapshot = medals().mapValues { $0.tierHistory }
        let second = service.evaluate(in: context, now: date("2026-11-29"))
        XCTAssertFalse(first.isEmpty)
        XCTAssertTrue(second.isEmpty, "re-running over unchanged history changes nothing")
        XCTAssertEqual(medals().mapValues { $0.tierHistory }, snapshot)
    }

    func testInterruptedBackfillResumesAndCompletes() throws {
        try insertFixture(into: context)
        let killed = try makeService()
        killed.evaluate(in: context, now: date("2026-11-28"), stopAfterFamilies: 2)
        XCTAssertFalse(killed.isBackfillComplete)
        let partial = medals().count
        XCTAssertGreaterThan(partial, 0)

        // Relaunch: a fresh service with the same checkpoint store finishes the pass.
        let relaunched = try makeService()
        relaunched.evaluate(in: context, now: date("2026-11-28"))
        XCTAssertTrue(relaunched.isBackfillComplete)

        let clean = try ModelContainer(
            for: Schema([VisitedPlace.self, LocationSample.self, Visit.self, EarnedMedal.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        try insertFixture(into: clean.mainContext)
        let cleanService = MedalService(catalog: try MedalEngineTests.loadCatalog())
        let cleanSuite = "MedalServiceTests-clean-\(UUID().uuidString)"
        cleanService.defaults = UserDefaults(suiteName: cleanSuite)!
        cleanService.photoLocations = { [] }
        cleanService.distanceKm = { 0 }
        cleanService.cityMatcherOverride = CityMatcher(gazetteer: CityGazetteer(cities: []))
        cleanService.evaluate(in: clean.mainContext, now: date("2026-11-28"))
        defer { UserDefaults().removePersistentDomain(forName: cleanSuite) }

        XCTAssertGreaterThan(medals().count, partial)
        XCTAssertEqual(medals().mapValues { $0.tierHistory }, medals(clean.mainContext).mapValues { $0.tierHistory })
        XCTAssertTrue(medals().values.allSatisfy(\.isRetroactive))
    }

    // MARK: - v1 badges

    func testV1BadgeEarnedWithTransitCountryIsKept() throws {
        let codes = ["FR", "DE", "NL", "BE", "IT", "ES", "PT", "AT", "CH"]
        for (index, code) in codes.enumerated() {
            insert("country", code, "2020-01-\(String(format: "%02d", index + 1))")
        }
        insert("country", "PL", "2020-02-01", visitType: .transit)
        try context.save()
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-28"))

        let explorer = try XCTUnwrap(medals()["explorer_10"])
        XCTAssertEqual(explorer.tier, .silver, "v1 Explorer (10 countries incl. transit) maps to the silver rung")
        XCTAssertEqual(explorer.tierHistory.map(\.isLegacy), [false, true])
        XCTAssertEqual(explorer.tierHistory.last?.earnedAt, date("2020-02-01"))
        XCTAssertEqual(service.results.first { $0.id == "explorer_10" }?.value, 9, "v2 progress excludes transit")
    }

    // MARK: - After the backfill

    func testNewAwardAfterBackfillIsLiveAndTierUpgradeResurfaces() throws {
        for (index, code) in ["FR", "DE", "NL", "BE"].enumerated() {
            insert("country", code, "2020-01-0\(index + 1)")
        }
        try context.save()
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-01"))
        service.markSurfaced(Array(medals().values), in: context, now: date("2026-11-01"))

        insert("country", "IT", "2026-11-10")
        try context.save()
        service.evaluate(in: context, now: date("2026-11-10"))

        let explorer = try XCTUnwrap(medals()["explorer_10"])
        XCTAssertEqual(explorer.tier, .bronze)
        XCTAssertFalse(explorer.isRetroactive)
        XCTAssertNil(explorer.surfacedAt)
        XCTAssertNotNil(medals()["first_steps"]?.surfacedAt, "unchanged medals stay surfaced")

        for code in ["ES", "PT", "AT", "CH", "PL"] {
            insert("country", code, "2026-11-20")
        }
        try context.save()
        service.markSurfaced([explorer], in: context, now: date("2026-11-11"))
        service.evaluate(in: context, now: date("2026-11-20"))
        XCTAssertEqual(medals()["explorer_10"]?.tier, .silver)
        XCTAssertNil(medals()["explorer_10"]?.surfacedAt, "a tier upgrade is shown again")
        XCTAssertEqual(medals()["explorer_10"]?.earnedAt, date("2026-11-10"), "earnedAt stays the first tier's date")
    }

    func testOlderEvidenceMovesEarnedDateEarlier() throws {
        let place = insert("country", "FR", "2024-05-01")
        try context.save()
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-01"))
        XCTAssertEqual(medals()["first_steps"]?.earnedAt, date("2024-05-01"))

        place.visitedDate = date("2015-08-01")
        try context.save()
        service.evaluate(in: context, now: date("2026-11-02"))
        XCTAssertEqual(medals()["first_steps"]?.earnedAt, date("2015-08-01"))
    }

    func testRemovingAPlaceKeepsEarnedMedal() throws {
        let place = insert("country", "FR", "2024-05-01")
        try context.save()
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-01"))
        place.isDeleted = true
        try context.save()
        service.evaluate(in: context, now: date("2026-11-02"))
        XCTAssertNotNil(medals()["first_steps"])
    }

    func testKeptTiersStayEarnedInTheCabinet() throws {
        let place = insert("country", "FR", "2024-05-01")
        try context.save()
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-01"))
        place.isDeleted = true
        try context.save()
        service.evaluate(in: context, now: date("2026-11-02"))
        let firstSteps = try XCTUnwrap(service.visibleResults(places: [place]).first { $0.id == "first_steps" })
        XCTAssertTrue(firstSteps.isEarned)
        XCTAssertEqual(firstSteps.value, 0)
        XCTAssertEqual(firstSteps.highestAward?.earnedAt, date("2024-05-01"))
    }

    func testLegacyTierShowsAsEarnedInTheCabinet() throws {
        for (index, code) in ["FR", "DE", "NL", "BE", "IT", "ES", "PT", "AT", "CH"].enumerated() {
            insert("country", code, "2020-01-0\(index + 1)")
        }
        insert("country", "PL", "2020-02-01", visitType: .transit)
        try context.save()
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-28"))
        let explorer = try XCTUnwrap(service.results.first { $0.id == "explorer_10" })
        XCTAssertEqual(explorer.highestAward?.level, "silver")
        XCTAssertNil(explorer.nextTier)
    }

    func testResetForgetsMedalsAndRestartsBackfill() throws {
        insert("country", "FR", "2024-05-01")
        try context.save()
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-01"))
        XCTAssertFalse(medals().isEmpty)

        service.reset(in: context)
        XCTAssertTrue(medals().isEmpty)
        XCTAssertFalse(service.isBackfillComplete)
        XCTAssertTrue(service.results.isEmpty)
        XCTAssertNil(defaults.dictionary(forKey: MedalService.bucketLedgerKey))
    }

    func testBucketListCompletionsCount() throws {
        let codes = ["FR", "DE", "NL", "BE", "IT"]
        let places = codes.map { insert("country", $0, nil, status: .bucketList) }
        try context.save()
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-01-01"))
        XCTAssertNil(medals()["bucket_list_5"])

        for place in places {
            place.status = VisitedPlace.PlaceStatus.visited.rawValue
            place.visitedDate = date("2026-03-01")
        }
        try context.save()
        service.evaluate(in: context, now: date("2026-03-02"))
        XCTAssertEqual(medals()["bucket_list_5"]?.earnedAt, date("2026-03-01"))
    }

    func testCountyMedalsHiddenUntilCountyLayerHasData() throws {
        let places = [insert("country", "US", "2020-01-01")]
        try context.save()
        let service = try makeService()
        service.evaluate(in: context, now: date("2026-11-01"))
        XCTAssertFalse(service.visibleResults(places: places).contains { $0.definition.family == "counties" })
        XCTAssertFalse(service.visibleResults(places: places).contains { $0.definition.family == "regions" })

        let county = insert("us_county", "06075", "2020-01-02")
        try context.save()
        service.evaluate(in: context, now: date("2026-11-01"))
        XCTAssertTrue(service.visibleResults(places: places + [county]).contains { $0.id == "county_seat" })
    }

    func testCoordinateEvidenceFromVisitsAndPhotos() throws {
        let service = try makeService()
        service.photoLocations = {
            [PhotoLocation(latitude: -33.87, longitude: 151.21, photoCount: 3, earliestDate: self.date("2018-02-01"), regionName: "Sydney")]
        }
        let visit = Visit(DetectedVisit(
            level: .country, countryCode: "NO", subdivisionCode: nil, kind: .visited,
            arrivedAt: date("2025-06-01"), departedAt: date("2025-06-03"), centroidLatitude: 69.65, centroidLongitude: 18.96,
            sampleCount: 12, source: .gps
        ))
        context.insert(visit)
        try context.save()
        service.evaluate(in: context, now: date("2026-11-01"))
        XCTAssertEqual(medals()["southern_cross"]?.earnedAt, date("2018-02-01"))
        XCTAssertEqual(medals()["polar_explorer"]?.earnedAt, date("2025-06-01"))
        XCTAssertEqual(medals()["equator_crosser"]?.earnedAt, date("2025-06-01"))
    }

    func testBundledCatalogAndGazetteersLoad() throws {
        let catalog = try XCTUnwrap(MedalService.bundledCatalog(), "medals.json is in the app bundle")
        XCTAssertEqual(catalog.catalogVersion, try MedalEngineTests.loadCatalog().catalogVersion)
        let gazetteer = try XCTUnwrap(CityGazetteer.bundled, "cities_gazetteer.json is in the app bundle")
        XCTAssertGreaterThan(gazetteer.cities.count, 2000)
        XCTAssertGreaterThanOrEqual(gazetteer.nationalCapitals.count, 195)
        XCTAssertEqual(gazetteer.usStateCapitals.count, GeographicData.usStates.count)
    }

    func testCatalogMatchesGeographicData() throws {
        let catalog = try MedalEngineTests.loadCatalog()
        for country in GeographicData.countries {
            XCTAssertEqual(catalog.countryContinents[country.id], country.continent, country.id)
            if let type = GeographicData.regionType(for: country.id) {
                XCTAssertEqual(catalog.subdivisionRegionTypes[type.rawValue], country.id)
                XCTAssertEqual(catalog.subdivisionCounts[country.id], GeographicData.states(for: country.id).count)
            }
        }
        for code in catalog.countrySets.values.flatMap({ $0 }) {
            XCTAssertTrue(GeographicData.countries.contains { $0.id == code }, "medal filter references unknown country \(code)")
        }
    }
}
