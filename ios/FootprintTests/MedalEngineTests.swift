import XCTest
@testable import Footprint

/// Medal engine (§4.1) and the shared iOS/backend fixture history (§6.4).
final class MedalEngineTests: XCTestCase {
    // MARK: - Fixtures

    static var repoRoot: URL {
        if let root = ProcessInfo.processInfo.environment["FOOTPRINT_REPO_ROOT"] {
            return URL(fileURLWithPath: root)
        }
        // ios/FootprintTests/MedalEngineTests.swift → repo root
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    static func loadCatalog() throws -> MedalCatalog {
        try MedalCatalog.decode(Data(contentsOf: repoRoot.appendingPathComponent("ios/Footprint/Resources/medals.json")))
    }

    struct FixtureFile: Decodable {
        struct Place: Decodable {
            let region_type: String
            let region_code: String
            let region_name: String
            let status: String
            let visit_type: String
            let is_deleted: Bool
            let visited_date: String?
            let marked_at: String
        }
        struct Award: Decodable, Equatable {
            let level: String
            let earnedAt: String
            let trigger: String
        }
        let places: [Place]
        let excludedFamilies: [String]
        let expected: [String: [Award]]
    }

    static func loadFixture() throws -> FixtureFile {
        let url = repoRoot.appendingPathComponent("ios/FootprintTests/Fixtures/medal_fixture_history.json")
        return try JSONDecoder().decode(FixtureFile.self, from: Data(contentsOf: url))
    }

    static let iso: ISO8601DateFormatter = ISO8601DateFormatter()

    static func facts(_ fixture: FixtureFile) -> [MedalEngine.PlaceFact] {
        fixture.places.compactMap { place in
            guard MedalEngine.countsTowardMedals(status: place.status, visitType: place.visit_type, isDeleted: place.is_deleted),
                  let date = place.visited_date.flatMap(iso.date(from:)) ?? iso.date(from: place.marked_at)
            else { return nil }
            return MedalEngine.PlaceFact(regionType: place.region_type, regionCode: place.region_code, name: place.region_name, date: date)
        }
    }

    func date(_ string: String) -> Date {
        Self.iso.date(from: string + "T12:00:00Z")!
    }

    func country(_ code: String, _ day: String) -> MedalEngine.PlaceFact {
        MedalEngine.PlaceFact(regionType: "country", regionCode: code, name: code, date: date(day))
    }

    func result(_ id: String, _ results: [MedalEngine.Result]) -> MedalEngine.Result {
        results.first { $0.id == id }!
    }

    // MARK: - Catalog

    func testCatalogKeepsEveryV1Badge() throws {
        let catalog = try Self.loadCatalog()
        let v1 = [
            "first_steps", "explorer_10", "globetrotter_25", "world_traveler_50", "elite_traveler_100",
            "world_champion_150", "europe_explorer", "asia_adventurer", "africa_safari", "americas_explorer",
            "oceania_hopper", "all_continents", "us_starter", "us_half", "us_complete", "canada_explorer",
            "canada_complete", "time_zone_master", "all_time_zones", "bucket_list_5", "bucket_list_25",
        ]
        let legacy = Set(catalog.medals.compactMap(\.legacyBadgeId))
        XCTAssertEqual(legacy, Set(v1))
        for medal in catalog.medals where medal.legacyBadgeId != nil {
            XCTAssertEqual(medal.id, medal.legacyBadgeId, "v1 ids are kept so cabinets stay recognizable")
            XCTAssertTrue(medal.tiers.contains { $0.level == medal.legacyTier }, medal.id)
        }
    }

    func testCatalogTiersAreOrderedAndIdsUnique() throws {
        let catalog = try Self.loadCatalog()
        XCTAssertEqual(Set(catalog.medals.map(\.id)).count, catalog.medals.count)
        for medal in catalog.medals {
            XCTAssertFalse(medal.tiers.isEmpty, medal.id)
            XCTAssertEqual(medal.tiers.map(\.threshold), medal.tiers.map(\.threshold).sorted(), medal.id)
            for tier in medal.tiers {
                XCTAssertNotNil(MedalTierLevel(rawValue: tier.level), medal.id)
            }
        }
        XCTAssertGreaterThan(catalog.medals.filter { $0.tiers.count > 1 }.count, 20, "v2 medals are tiered")
    }

    // MARK: - Shared fixture (iOS ↔ backend parity)

    func testFixtureHistoryProducesExpectedMedalsAndDates() throws {
        let catalog = try Self.loadCatalog()
        let fixture = try Self.loadFixture()
        let results = MedalEngine.evaluate(MedalEngine.Input(places: Self.facts(fixture)), catalog: catalog, platform: "backend")
        var compared = 0
        for result in results where !fixture.excludedFamilies.contains(result.definition.family) {
            let actual = result.awards.map {
                FixtureFile.Award(level: $0.level, earnedAt: Self.iso.string(from: $0.earnedAt), trigger: $0.trigger)
            }
            XCTAssertEqual(actual, fixture.expected[result.id], result.id)
            compared += 1
        }
        XCTAssertEqual(compared, fixture.expected.count)
        XCTAssertGreaterThanOrEqual(fixture.expected.values.filter { !$0.isEmpty }.count, 10)
    }

    func testRetroactiveAwardsUseHistoricalDates() throws {
        let catalog = try Self.loadCatalog()
        let results = MedalEngine.evaluate(MedalEngine.Input(places: Self.facts(try Self.loadFixture())), catalog: catalog)
        let explorer = result("explorer_10", results)
        XCTAssertEqual(explorer.awards.map(\.level), ["bronze", "silver"])
        XCTAssertEqual(explorer.awards.map(\.earnedAt), [date("2019-07-01"), date("2023-01-02")])
        XCTAssertEqual(explorer.awards.last?.trigger, "Italy")
        XCTAssertEqual(result("canada_complete", results).awards.first?.earnedAt, date("2020-06-13"))
        // Transit (CH), bucket list (PT) and deleted (AT) places never count.
        XCTAssertEqual(result("full_atlas", results).value, 11)
    }

    func testEvaluationIsIdempotent() throws {
        let catalog = try Self.loadCatalog()
        let input = MedalEngine.Input(places: Self.facts(try Self.loadFixture()))
        let first = MedalEngine.evaluate(input, catalog: catalog).map(\.awards)
        let second = MedalEngine.evaluate(input, catalog: catalog).map(\.awards)
        XCTAssertEqual(first, second)
    }

    func testFactOrderDoesNotChangeAwards() throws {
        let catalog = try Self.loadCatalog()
        let facts = Self.facts(try Self.loadFixture())
        let forward = MedalEngine.evaluate(MedalEngine.Input(places: facts), catalog: catalog).map(\.awards)
        let reversed = MedalEngine.evaluate(MedalEngine.Input(places: facts.reversed()), catalog: catalog).map(\.awards)
        XCTAssertEqual(forward, reversed)
    }

    // MARK: - Metrics

    func testDuplicatePlaceCountsOnceAtEarliestDate() throws {
        let catalog = try Self.loadCatalog()
        let results = MedalEngine.evaluate(MedalEngine.Input(places: [country("FR", "2022-01-01"), country("FR", "2020-01-01")]), catalog: catalog)
        XCTAssertEqual(result("first_steps", results).awards.first?.earnedAt, date("2020-01-01"))
        XCTAssertEqual(result("first_steps", results).value, 1)
    }

    func testTieredMedalSkipsToHighestTierAtOnce() throws {
        let catalog = try Self.loadCatalog()
        let codes = ["FR", "DE", "NL", "BE", "IT", "ES", "PT", "AT", "CH", "PL"]
        let results = MedalEngine.evaluate(MedalEngine.Input(places: codes.map { country($0, "2021-04-01") }), catalog: catalog)
        let explorer = result("explorer_10", results)
        XCTAssertEqual(explorer.awards.map(\.level), ["bronze", "silver"])
        XCTAssertEqual(explorer.awards.map(\.earnedAt), [date("2021-04-01"), date("2021-04-01")])
        XCTAssertNil(explorer.nextTier)
        let europe = result("europe_explorer", results)
        XCTAssertEqual(europe.awards.map(\.level), ["bronze"])
        XCTAssertEqual(europe.nextTier?.threshold, 20)
        XCTAssertEqual(europe.progressTotal, 20)
    }

    func testMonthlyStreakBreaksOnGapMonth() throws {
        let catalog = try Self.loadCatalog()
        let facts = [country("FR", "2021-01-10"), country("DE", "2021-02-10"), country("NL", "2021-04-10"),
                     country("BE", "2021-05-10"), country("IT", "2021-06-10")]
        let monthly = result("monthly_explorer", MedalEngine.evaluate(MedalEngine.Input(places: facts), catalog: catalog))
        XCTAssertEqual(monthly.value, 3)
        XCTAssertEqual(monthly.awards.first?.earnedAt, date("2021-06-10"))
    }

    func testWeeklyStreakCrossesYearBoundary() throws {
        let catalog = try Self.loadCatalog()
        // Mon 2024-12-23, Mon 12-30, Mon 2025-01-06, Mon 01-13: four consecutive ISO weeks.
        let facts = ["2024-12-23", "2024-12-30", "2025-01-06", "2025-01-13"].enumerated().map { country(["FR", "DE", "NL", "BE"][$0.offset], $0.element) }
        let weekly = result("weekly_wanderer", MedalEngine.evaluate(MedalEngine.Input(places: facts), catalog: catalog))
        XCTAssertEqual(weekly.value, 4)
        XCTAssertEqual(weekly.awards.first?.earnedAt, date("2025-01-13"))
    }

    func testYearsSpanCountsWholeYears() {
        XCTAssertEqual(MedalEngine.wholeYears(from: date("2015-06-02"), to: date("2020-06-01")), 4)
        XCTAssertEqual(MedalEngine.wholeYears(from: date("2015-06-02"), to: date("2020-06-02")), 5)
    }

    func testCountiesInStateUsesFipsPrefix() throws {
        let catalog = try Self.loadCatalog()
        let counties = ["44001", "44003", "44005", "44007", "44009"].map {
            MedalEngine.PlaceFact(regionType: "us_county", regionCode: $0, name: $0, date: date("2023-0\($0.suffix(1) == "9" ? 9 : 1)-01"))
        }
        let results = MedalEngine.evaluate(MedalEngine.Input(places: counties), catalog: catalog)
        XCTAssertEqual(result("complete_counties_ri", results).awards.first?.earnedAt, date("2023-09-01"))
        XCTAssertFalse(result("complete_counties_ct", results).isEarned)
        XCTAssertEqual(result("county_seat", results).value, 5)
    }

    func testLowerFortyEightIgnoresAlaskaHawaiiAndDC() throws {
        let catalog = try Self.loadCatalog()
        let lower48 = catalog.medals.first { $0.id == "lower_48" }!
        let facts = (lower48.members ?? []).map { MedalEngine.PlaceFact(regionType: "us_state", regionCode: $0, name: $0, date: date("2022-03-01")) }
            + ["AK", "HI", "DC"].map { MedalEngine.PlaceFact(regionType: "us_state", regionCode: $0, name: $0, date: date("2020-03-01")) }
        let results = MedalEngine.evaluate(MedalEngine.Input(places: facts), catalog: catalog)
        XCTAssertEqual(lower48.members?.count, 48)
        XCTAssertEqual(result("lower_48", results).awards.first?.earnedAt, date("2022-03-01"))
        XCTAssertEqual(result("fifty_plus_one", results).awards.map(\.level), ["bronze", "silver", "gold"])
    }

    func testTimeZonesAndDateLine() throws {
        let catalog = try Self.loadCatalog()
        let facts = [
            MedalEngine.PlaceFact(regionType: "country", regionCode: "JP", name: "Japan", date: date("2019-01-01"), timeZones: [9]),
            MedalEngine.PlaceFact(regionType: "us_state", regionCode: "AK", name: "Alaska", date: date("2019-02-01"), timeZones: [-9]),
        ]
        let results = MedalEngine.evaluate(MedalEngine.Input(places: facts), catalog: catalog)
        XCTAssertFalse(result("date_line_crosser", results).isEarned, "UTC+9 and UTC−9 are not on the date line")
        let crossing = facts + [
            MedalEngine.PlaceFact(regionType: "country", regionCode: "FJ", name: "Fiji", date: date("2019-03-01"), timeZones: [12]),
            MedalEngine.PlaceFact(regionType: "us_state", regionCode: "HI", name: "Hawaii", date: date("2019-04-01"), timeZones: [-10]),
        ]
        let crossed = result("date_line_crosser", MedalEngine.evaluate(MedalEngine.Input(places: crossing), catalog: catalog))
        XCTAssertEqual(crossed.awards.first?.earnedAt, date("2019-04-01"))
        XCTAssertEqual(crossed.awards.first?.trigger, "Hawaii")
    }

    func testCoordinateMedalsFromVisitsAndPhotos() throws {
        let catalog = try Self.loadCatalog()
        let coordinates = [
            MedalEngine.CoordinateFact(latitude: 52.37, longitude: 4.90, date: date("2018-05-01"), label: "Amsterdam"),
            MedalEngine.CoordinateFact(latitude: -33.87, longitude: 151.21, date: date("2019-05-01"), label: "Sydney"),
            MedalEngine.CoordinateFact(latitude: 40.71, longitude: -74.0, date: date("2020-05-01"), label: "New York"),
            MedalEngine.CoordinateFact(latitude: 0.2, longitude: -78.5, date: date("2021-05-01"), label: "Quito"),
            MedalEngine.CoordinateFact(latitude: 69.65, longitude: 18.96, date: date("2022-05-01"), label: "Tromsø"),
            MedalEngine.CoordinateFact(latitude: -64.8, longitude: -62.9, date: date("2023-05-01"), label: "Antarctic Peninsula"),
        ]
        let results = MedalEngine.evaluate(MedalEngine.Input(coordinates: coordinates), catalog: catalog)
        XCTAssertEqual(result("equator_crosser", results).awards.first?.earnedAt, date("2019-05-01"))
        XCTAssertEqual(result("four_hemispheres", results).awards.first?.earnedAt, date("2020-05-01"))
        XCTAssertEqual(result("meridian_split", results).awards.first?.trigger, "New York")
        XCTAssertEqual(result("on_the_equator", results).awards.first?.trigger, "Quito")
        XCTAssertEqual(result("polar_explorer", results).awards.first?.trigger, "Tromsø")
        XCTAssertEqual(result("southern_cross", results).awards.first?.trigger, "Sydney")
        XCTAssertEqual(result("all_continents", results).value, 1, "Antarctica counts from coordinates")
    }

    func testCityMatcherAndCapitals() throws {
        let catalog = try Self.loadCatalog()
        let matcher = CityMatcher(cities: [
            .init(id: "gn:2988507", name: "Paris", kind: "national", latitude: 48.8534, longitude: 2.3488, radiusMeters: 15_000),
            .init(id: "gn:2988507", name: "Paris", kind: "city", latitude: 48.8534, longitude: 2.3488, radiusMeters: 15_000),
            .init(id: "gn:5391959", name: "San Francisco", kind: "city", latitude: 37.7749, longitude: -122.4194, radiusMeters: 10_000),
        ])
        let coordinates = [
            MedalEngine.CoordinateFact(latitude: 48.86, longitude: 2.29, date: date("2021-01-01"), label: "Eiffel Tower"),
            MedalEngine.CoordinateFact(latitude: 48.892, longitude: 2.236, date: date("2020-01-01"), label: "La Défense"),
            MedalEngine.CoordinateFact(latitude: 37.80, longitude: -122.27, date: date("2020-01-01"), label: "Oakland"),
        ]
        let hits = matcher.hits(coordinates)
        XCTAssertEqual(hits.filter { $0.kind == "national" }.map(\.date), [date("2020-01-01")], "La Défense is within Paris' radius")
        XCTAssertFalse(hits.contains { $0.name == "San Francisco" }, "Oakland is 13 km away, outside the 10 km radius")
        let results = MedalEngine.evaluate(MedalEngine.Input(cities: hits), catalog: catalog)
        XCTAssertEqual(result("capital_gains", results).value, 1)
        XCTAssertEqual(result("city_slicker", results).value, 1)
    }

    func testOverlappingCityRadiiCreditOnlyTheNearestCity() {
        let matcher = CityMatcher(cities: [
            .init(id: "nyc", name: "New York City", kind: "city", latitude: 40.7143, longitude: -74.0060, radiusMeters: 15_000),
            .init(id: "jc", name: "Jersey City", kind: "city", latitude: 40.7282, longitude: -74.0776, radiusMeters: 5_000),
        ])
        let hits = matcher.hits([MedalEngine.CoordinateFact(latitude: 40.7280, longitude: -74.0770, date: date("2022-01-01"), label: "Photo")])
        XCTAssertEqual(hits.map(\.name), ["Jersey City"])
    }

    func testNeighbouringCapitalsBothCount() {
        let matcher = CityMatcher(cities: [
            .init(id: "rome", name: "Rome", kind: "national", latitude: 41.8919, longitude: 12.5113, radiusMeters: 15_000),
            .init(id: "vatican", name: "Vatican City", kind: "national", latitude: 41.9024, longitude: 12.4533, radiusMeters: 1_500),
        ])
        let hits = matcher.hits([MedalEngine.CoordinateFact(latitude: 41.9031, longitude: 12.4663, date: date("2022-01-01"), label: "Castel Sant'Angelo")])
        XCTAssertEqual(Set(hits.map(\.name)), ["Rome", "Vatican City"])
    }

    func testDistanceAwardsAtMeasurementDate() throws {
        let catalog = try Self.loadCatalog()
        let results = MedalEngine.evaluate(MedalEngine.Input(distanceKm: 41_000, distanceAsOf: date("2026-11-01")), catalog: catalog)
        XCTAssertEqual(result("around_the_world", results).awards.map(\.level), ["bronze", "silver"])
        XCTAssertEqual(result("wanderer", results).awards.first?.earnedAt, date("2026-11-01"))
        XCTAssertEqual(result("voyager", results).awards.count, 2)
    }

    func testHomeTurfFollowsMostVisitedCountry() throws {
        let catalog = try Self.loadCatalog()
        let be = (1...11).map { MedalEngine.PlaceFact(regionType: "belgian_province", regionCode: "B\($0)", name: "B\($0)", date: date("2020-01-\(String(format: "%02d", $0))")) }
        let results = MedalEngine.evaluate(MedalEngine.Input(places: be), catalog: catalog)
        XCTAssertEqual(catalog.subdivisionCounts["BE"], 11)
        XCTAssertEqual(result("home_turf", results).awards.first?.earnedAt, date("2020-01-11"))
    }

    func testBackendPlatformExcludesDeviceOnlyMedals() throws {
        let catalog = try Self.loadCatalog()
        let backend = MedalEngine.evaluate(MedalEngine.Input(), catalog: catalog, platform: "backend").map(\.id)
        XCTAssertFalse(backend.contains("capital_gains"))
        XCTAssertFalse(backend.contains("wanderer"))
        XCTAssertTrue(backend.contains("first_steps"))
    }
}
