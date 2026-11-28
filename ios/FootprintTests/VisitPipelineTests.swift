import SwiftData
import XCTest
@testable import Footprint

@MainActor
final class VisitPipelineTests: XCTestCase {
    private var container: ModelContainer!
    private var pipeline: VisitPipeline!
    private var defaults: UserDefaults!
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private let degreesPerMeter = 1.0 / 111_320

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Schema([VisitedPlace.self, LocationSample.self, Visit.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        defaults = UserDefaults(suiteName: "VisitPipelineTests")
        defaults.removePersistentDomain(forName: "VisitPipelineTests")
        pipeline = VisitPipeline(container: container)
        pipeline.defaults = defaults
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        pipeline.calendar = utc
        // Everything is in California, USA.
        pipeline.resolve = { _, _ in PlaceKey(countryCode: "US", subdivisionCode: "CA") }
    }

    private var context: ModelContext { container.mainContext }

    private func stay(startingAt start: Date, minutes: Int = 12, latitude: Double = 37) -> [EvidenceSample] {
        (0...minutes).map {
            EvidenceSample(timestamp: start.addingTimeInterval(Double($0) * 60),
                           latitude: latitude + Double($0 % 3) * 10 * degreesPerMeter, longitude: -122, horizontalAccuracy: 20)
        }
    }

    private func places() throws -> [VisitedPlace] {
        try context.fetch(FetchDescriptor<VisitedPlace>(sortBy: [SortDescriptor(\.regionType)]))
    }

    func testStayRecordsVisitsAndUpsertsCountryAndState() throws {
        let newPlaces = pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))

        XCTAssertEqual(Set(newPlaces), [
            VisitPipeline.NewPlace(countryCode: "US", subdivisionCode: nil),
            VisitPipeline.NewPlace(countryCode: "US", subdivisionCode: "CA"),
        ])
        let places = try places()
        XCTAssertEqual(places.map(\.regionType), ["country", "us_state"])
        XCTAssertEqual(places.map(\.regionCode), ["US", "CA"])
        XCTAssertTrue(places.allSatisfy { $0.visitedDate == t0 && $0.isFullVisit && !$0.isSynced })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocationSample>(predicate: #Predicate { $0.processedAt == nil })), 0)
    }

    func testRerunAndGrowingStayDoNotDuplicate() throws {
        let samples = stay(startingAt: t0, minutes: 30)
        pipeline.record(Array(samples.prefix(15)), now: t0.addingTimeInterval(15 * 60))
        let second = pipeline.record(Array(samples.dropFirst(15)), now: t0.addingTimeInterval(31 * 60))
        pipeline.run(now: t0.addingTimeInterval(32 * 60))

        XCTAssertEqual(second, [])
        let visits = try context.fetch(FetchDescriptor<Visit>())
        XCTAssertEqual(visits.count, 2)
        XCTAssertTrue(visits.allSatisfy { $0.departedAt == t0.addingTimeInterval(30 * 60) })
        XCTAssertTrue(try places().allSatisfy { $0.visitCount == 1 })
    }

    func testSeparateStayIncrementsVisitCountAndKeepsEarliestDate() throws {
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))
        let later = t0.addingTimeInterval(3 * 86_400)
        let newPlaces = pipeline.record(stay(startingAt: later), now: later.addingTimeInterval(3600))

        XCTAssertEqual(newPlaces, [])
        XCTAssertTrue(try places().allSatisfy { $0.visitCount == 2 && $0.visitedDate == t0 })
    }

    func testBucketListPlaceBecomesVisited() throws {
        context.insert(VisitedPlace(regionType: .country, regionCode: "US", regionName: "United States", status: .bucketList))
        let newPlaces = pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))

        XCTAssertTrue(newPlaces.contains(VisitPipeline.NewPlace(countryCode: "US", subdivisionCode: nil)))
        let country = try places().first { $0.regionType == "country" }
        XCTAssertEqual(country?.statusEnum, .visited)
    }

    func testPlaceRemovedByUserAfterTheVisitIsNotRecreated() throws {
        context.insert(VisitedPlace(regionType: .country, regionCode: "US", regionName: "United States",
                                    lastModifiedAt: t0.addingTimeInterval(86_400), isDeleted: true))
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(2 * 86_400))

        let countries = try places().filter { $0.regionType == "country" }
        XCTAssertEqual(countries.count, 1)
        XCTAssertTrue(countries[0].isDeleted)
    }

    func testFlyBySampleRecordsNothing() throws {
        let newPlaces = pipeline.record([EvidenceSample(timestamp: t0, latitude: 37, longitude: -122, horizontalAccuracy: 20)], now: t0)
        XCTAssertEqual(newPlaces, [])
        XCTAssertEqual(try places().count, 0)
    }

    func testInaccurateSamplesAreNotStored() throws {
        pipeline.record([EvidenceSample(timestamp: t0, latitude: 37, longitude: -122, horizontalAccuracy: 5_000)], now: t0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocationSample>()), 0)
    }

    func testOldSamplesAreDeletedAfterRetention() throws {
        context.insert(LocationSample(timestamp: t0.addingTimeInterval(-400 * 86_400), latitude: 37, longitude: -122,
                                      horizontalAccuracy: 20, processedAt: t0))
        pipeline.run(now: t0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocationSample>()), 0)
    }

    func testDistanceAccumulatesOnlyNewLegs() throws {
        let drive = (0...3).map {
            EvidenceSample(timestamp: t0.addingTimeInterval(Double($0) * 60),
                           latitude: 37 + Double($0) * 1000 * degreesPerMeter, longitude: -122, horizontalAccuracy: 20)
        }
        pipeline.record(Array(drive.prefix(2)), now: t0.addingTimeInterval(60))
        pipeline.record(Array(drive.dropFirst(2)), now: t0.addingTimeInterval(180))
        pipeline.run(now: t0.addingTimeInterval(240))

        XCTAssertEqual(pipeline.status().distanceKm, 3, accuracy: 0.01)
    }

    func testMultiDayStayStaysOneVisit() throws {
        let hourly = stride(from: 0, through: 96, by: 1).map {
            EvidenceSample(timestamp: t0.addingTimeInterval(Double($0) * 3600),
                           latitude: 37 + Double($0 % 3) * 10 * degreesPerMeter, longitude: -122, horizontalAccuracy: 20)
        }
        for day in 0..<4 {
            let batch = Array(hourly[(day * 24)..<((day + 1) * 24)])
            pipeline.record(batch, now: batch.last!.timestamp)
        }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 2)
        XCTAssertTrue(try places().allSatisfy { $0.visitCount == 1 })
    }

    func testLateSampleDoesNotRecountDistance() throws {
        let drive = (0...3).map {
            EvidenceSample(timestamp: t0.addingTimeInterval(Double($0) * 60),
                           latitude: 37 + Double($0) * 1000 * degreesPerMeter, longitude: -122, horizontalAccuracy: 20)
        }
        pipeline.record(drive, now: t0.addingTimeInterval(180))
        pipeline.record([EvidenceSample(timestamp: t0.addingTimeInterval(-600), latitude: 37, longitude: -122,
                                        horizontalAccuracy: 20)], now: t0.addingTimeInterval(240))

        XCTAssertEqual(pipeline.status().distanceKm, 3, accuracy: 0.01)
    }

    func testStayHeldBackAfterLandingSurvivesALongGap() throws {
        // Arrive by air (900 km/h legs), wait at the gate, then nothing for two days.
        let inbound = (0..<6).map {
            EvidenceSample(timestamp: t0.addingTimeInterval(Double($0) * 60), latitude: 37,
                           longitude: -125 + Double($0) * 15_000 * degreesPerMeter, horizontalAccuracy: 20)
        }
        let gateStart = t0.addingTimeInterval(10 * 60)
        let atGate = stay(startingAt: gateStart, minutes: 30)
        XCTAssertEqual(pipeline.record(inbound + atGate, now: gateStart.addingTimeInterval(1800)), [])

        let twoDaysLater = gateStart.addingTimeInterval(2 * 86_400)
        let later = [EvidenceSample(timestamp: twoDaysLater, latitude: 37, longitude: -122, horizontalAccuracy: 20)]
        let newPlaces = pipeline.record(later, now: twoDaysLater)

        XCTAssertTrue(newPlaces.contains(VisitPipeline.NewPlace(countryCode: "US", subdivisionCode: nil)))
        XCTAssertNil(defaults.object(forKey: VisitPipeline.heldBackSinceKey))
    }

    func testStatusReportsCounts() {
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))
        let status = pipeline.status()
        XCTAssertEqual(status.visits, 2)
        XCTAssertEqual(status.storedSamples, 13)
        XCTAssertEqual(status.pendingSamples, 0)
        XCTAssertEqual(status.lastRunAt, t0.addingTimeInterval(3600))
    }

    // MARK: - Counties (Phase 2)

    private func useCounty(_ fips: String?) {
        pipeline.resolve = { _, _ in PlaceKey(countryCode: "US", subdivisionCode: "CA", countyFips: fips) }
    }

    func testCountyStayUpsertsUSCounty() throws {
        useCounty("06075")
        let newPlaces = pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))

        XCTAssertTrue(newPlaces.contains(VisitPipeline.NewPlace(countryCode: "US", subdivisionCode: "CA", countyFips: "06075")))
        let county = try XCTUnwrap(places().first { $0.regionType == VisitedPlace.RegionType.usCounty.rawValue })
        XCTAssertEqual(county.regionCode, "06075")
        XCTAssertEqual(county.regionName, "San Francisco County")
        XCTAssertEqual(county.visitedDate, t0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 3)
    }

    func testReresolveBackfillsCountiesOnceAndIsIdempotent() throws {
        useCounty(nil)
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))
        // Somewhere else the next day: a return to the same spot with no fixes in between is one stay.
        pipeline.record(stay(startingAt: t0.addingTimeInterval(86_400), latitude: 37.5), now: t0.addingTimeInterval(90_000))
        XCTAssertFalse(try places().contains { $0.regionType == VisitedPlace.RegionType.usCounty.rawValue })

        useCounty("06075")
        let first = pipeline.reresolveIfNeeded(dataVersion: "v2", now: t0.addingTimeInterval(100_000))
        XCTAssertEqual(first.compactMap(\.countyFips), ["06075"])
        let snapshot = try places().map { "\($0.regionType):\($0.regionCode):\($0.visitCount)" }
        XCTAssertTrue(snapshot.contains("us_county:06075:2"))
        XCTAssertTrue(snapshot.contains("us_state:CA:2"))

        XCTAssertEqual(pipeline.reresolveIfNeeded(dataVersion: "v2"), [])
        pipeline.reresolve(now: t0.addingTimeInterval(200_000))
        XCTAssertEqual(try places().map { "\($0.regionType):\($0.regionCode):\($0.visitCount)" }, snapshot)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 6)
    }

    func testForcedReresolveRunsAgainForTheSameDataVersion() throws {
        useCounty(nil)
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))
        XCTAssertEqual(pipeline.reresolveIfNeeded(dataVersion: "v2"), [])

        // Counties switched on after the data version was already stamped.
        useCounty("06075")
        XCTAssertEqual(pipeline.reresolveIfNeeded(dataVersion: "v2"), [])
        let forced = pipeline.reresolveIfNeeded(dataVersion: "v2", force: true)
        XCTAssertEqual(forced.compactMap(\.countyFips), ["06075"])
    }
}
