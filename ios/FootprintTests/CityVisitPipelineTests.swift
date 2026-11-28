import SwiftData
import XCTest
@testable import Footprint

@MainActor
final class CityVisitPipelineTests: XCTestCase {
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
        defaults = UserDefaults(suiteName: "CityVisitPipelineTests")
        defaults.removePersistentDomain(forName: "CityVisitPipelineTests")
        defaults.set(true, forKey: CityLayer.enabledDefaultsKey)
        pipeline = VisitPipeline(container: container)
        pipeline.defaults = defaults
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        pipeline.calendar = utc
        pipeline.resolve = { _, _ in PlaceKey(countryCode: "US", subdivisionCode: "CA") }
        pipeline.cityLayer.gazetteer = CityGazetteer(cities: [
            City(id: "gn:5391959", name: "San Francisco", countryCode: "US", subdivisionCode: "US-CA",
                 latitude: 37, longitude: -122, radiusMeters: 8_000, population: 864_816),
        ])
    }

    private var context: ModelContext { container.mainContext }

    private func stay(startingAt start: Date, minutes: Int = 25) -> [EvidenceSample] {
        (0...minutes).map {
            EvidenceSample(timestamp: start.addingTimeInterval(Double($0) * 60),
                           latitude: 37 + Double($0 % 3) * 10 * degreesPerMeter, longitude: -122, horizontalAccuracy: 20)
        }
    }

    private func cityPlaces() throws -> [VisitedPlace] {
        let city = VisitedPlace.RegionType.city.rawValue
        return try context.fetch(FetchDescriptor<VisitedPlace>(predicate: #Predicate { $0.regionType == city }))
    }

    private func cityVisits() throws -> [Visit] {
        try context.fetch(FetchDescriptor<Visit>()).filter(\.isCityVisit)
    }

    func testCityLayerIsOffByDefault() throws {
        defaults.removeObject(forKey: CityLayer.enabledDefaultsKey)
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))

        XCTAssertEqual(try cityPlaces().count, 0)
        XCTAssertEqual(try cityVisits().count, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<VisitedPlace>()), 2)
    }

    func testStayRecordsCityVisitAndPlace() throws {
        let newPlaces = pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))

        XCTAssertEqual(Set(newPlaces), [
            VisitPipeline.NewPlace(countryCode: "US", subdivisionCode: nil),
            VisitPipeline.NewPlace(countryCode: "US", subdivisionCode: "CA"),
        ])
        let places = try cityPlaces()
        XCTAssertEqual(places.map(\.regionCode), ["gn:5391959"])
        XCTAssertEqual(places.first?.regionName, "San Francisco")
        XCTAssertEqual(places.first?.regionTypeEnum, .city)
        XCTAssertEqual(places.first?.visitedDate, t0)
        XCTAssertEqual(places.first?.isFullVisit, true)
        let visits = try cityVisits()
        XCTAssertEqual(visits.map(\.cityId), ["gn:5391959"])
        XCTAssertEqual(visits.first?.countryCode, "US")
        XCTAssertEqual(visits.first?.subdivisionCode, "CA")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Visit>()), 3)
    }

    func testShortStayIsTransitThenUpgradesWhenItGrows() throws {
        let samples = stay(startingAt: t0, minutes: 30)
        pipeline.record(Array(samples.prefix(13)), now: t0.addingTimeInterval(13 * 60))
        XCTAssertEqual(try cityPlaces().map(\.isTransit), [true])

        pipeline.record(Array(samples.dropFirst(13)), now: t0.addingTimeInterval(31 * 60))
        XCTAssertEqual(try cityPlaces().map(\.isFullVisit), [true])
        XCTAssertEqual(try cityVisits().map(\.kind), [.visited])
        XCTAssertEqual(try cityPlaces().first?.visitCount, 1)
    }

    func testRerunDoesNotDuplicateAndLaterStayCountsAgain() throws {
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))
        pipeline.run(now: t0.addingTimeInterval(7200))
        XCTAssertEqual(try cityVisits().count, 1)

        let later = t0.addingTimeInterval(3 * 86_400)
        pipeline.record(stay(startingAt: later), now: later.addingTimeInterval(3600))
        XCTAssertEqual(try cityVisits().count, 2)
        XCTAssertEqual(try cityPlaces().map(\.visitCount), [2])
        XCTAssertEqual(try cityPlaces().first?.visitedDate, t0)
    }

    func testTransitBeforeTheFirstFullVisitIsNotConfirmedHistory() throws {
        pipeline.record(stay(startingAt: t0, minutes: 12), now: t0.addingTimeInterval(3600))
        XCTAssertEqual(try cityPlaces().map(\.isTransit), [true])

        let later = t0.addingTimeInterval(3 * 86_400)
        pipeline.record(stay(startingAt: later), now: later.addingTimeInterval(3600))
        let place = try XCTUnwrap(try cityPlaces().first)
        XCTAssertTrue(place.isFullVisit)
        XCTAssertEqual(place.visitCount, 1)
        XCTAssertEqual(place.visitedDate, later)
    }

    func testTransitAfterAFullVisitChangesNothingUntilItIsConfirmed() throws {
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))
        let later = t0.addingTimeInterval(3 * 86_400)
        let samples = stay(startingAt: later, minutes: 30)
        pipeline.record(Array(samples.prefix(13)), now: later.addingTimeInterval(13 * 60))
        XCTAssertEqual(try cityPlaces().map(\.visitCount), [1])

        pipeline.record(Array(samples.dropFirst(13)), now: later.addingTimeInterval(31 * 60))
        XCTAssertEqual(try cityPlaces().map(\.visitCount), [2])
        XCTAssertEqual(try cityPlaces().first?.visitedDate, t0)
    }

    func testLateEarlierEvidenceBackdatesTheCity() throws {
        let samples = stay(startingAt: t0, minutes: 40)
        pipeline.record(Array(samples.dropFirst(10)), now: t0.addingTimeInterval(41 * 60))
        XCTAssertEqual(try cityPlaces().first?.visitedDate, t0.addingTimeInterval(10 * 60))

        pipeline.record(Array(samples.prefix(10)), now: t0.addingTimeInterval(42 * 60))
        XCTAssertEqual(try cityVisits().map(\.arrivedAt), [t0])
        XCTAssertEqual(try cityPlaces().first?.visitedDate, t0)
        XCTAssertEqual(try cityPlaces().first?.visitCount, 1)
    }

    func testBucketListCityBecomesVisited() throws {
        context.insert(VisitedPlace(regionType: .city, regionCode: "gn:5391959", regionName: "San Francisco", status: .bucketList))
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(3600))

        let places = try cityPlaces()
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.isVisited, true)
    }

    func testRemovedCityReturnsOnlyForALaterVisit() throws {
        context.insert(VisitedPlace(regionType: .city, regionCode: "gn:5391959", regionName: "San Francisco",
                                    lastModifiedAt: t0.addingTimeInterval(86_400), isDeleted: true))
        pipeline.record(stay(startingAt: t0), now: t0.addingTimeInterval(2 * 86_400))
        XCTAssertEqual(try cityPlaces().map(\.isDeleted), [true])

        let later = t0.addingTimeInterval(3 * 86_400)
        pipeline.record(stay(startingAt: later), now: later.addingTimeInterval(3600))
        XCTAssertEqual(try cityPlaces().map(\.isDeleted), [false])
    }

    func testCoverageCountsFullVisitsOnly() throws {
        let gazetteer = pipeline.cityLayer.gazetteer!
        let transit = VisitedPlace(regionType: .city, regionCode: "gn:5391959", regionName: "San Francisco", visitType: .transit)
        XCTAssertEqual(CityCoverage(gazetteer: gazetteer, places: [transit]).cities, CoverageCount(visited: 0, total: 1))
        let visited = VisitedPlace(regionType: .city, regionCode: "gn:5391959", regionName: "San Francisco")
        XCTAssertEqual(CityCoverage(gazetteer: gazetteer, places: [visited]).cities, CoverageCount(visited: 1, total: 1))
    }
}
