import XCTest
@testable import Footprint

final class CityCollectionsTests: XCTestCase {

    // MARK: - Fixtures

    private func city(
        _ id: String,
        country: String = "FR",
        subdivision: String? = nil,
        national: Bool = false,
        stateCapital: Bool = false,
        population: Int = 500_000
    ) -> GazetteerCity {
        GazetteerCity(
            id: id,
            name: id,
            countryCode: country,
            subdivisionCode: subdivision,
            countyFips: nil,
            lat: 0,
            lon: 0,
            radiusMeters: GazetteerCity.matchRadius(population: population),
            population: population,
            isNationalCapital: national,
            isSubdivisionCapital: stateCapital,
            timeZone: nil
        )
    }

    private func record(
        _ id: String,
        regionType: String = "city",
        isVisited: Bool = true,
        isTransit: Bool = false,
        isDeleted: Bool = false,
        date: Date? = nil
    ) -> CityVisitRecord {
        CityVisitRecord(
            regionType: regionType,
            regionCode: id,
            isVisited: isVisited,
            isTransit: isTransit,
            isDeleted: isDeleted,
            visitedDate: date
        )
    }

    /// Paris and Washington are national capitals; Washington, Austin and Sacramento are US state capitals.
    private lazy var fixture = CityGazetteer(
        cities: [
            city("paris", national: true),
            city("lyon"),
            city("washington", country: "US", subdivision: "US-DC", national: true, stateCapital: true),
            city("austin", country: "US", subdivision: "US-TX", stateCapital: true),
            city("sacramento", country: "US", subdivision: "US-CA", stateCapital: true),
            city("toronto", country: "CA"),
            city("quebec", country: "CA", subdivision: "CA-QC", stateCapital: true),
        ],
        dataVersion: "test"
    )

    private func progress(_ collection: CityCollection, _ records: [CityVisitRecord]) -> CityCollectionProgress {
        let all = CityCounting.progress(for: [collection], in: fixture, records: records)
        XCTAssertEqual(all.count, 1)
        return all[0]
    }

    // MARK: - Membership and denominators

    func testDenominatorsComeFromGazetteerFlags() {
        XCTAssertEqual(progress(.allCities, []).total, 7)
        XCTAssertEqual(progress(.nationalCapitals, []).total, 2)
        XCTAssertEqual(progress(.usStateCapitals, []).total, 3)
    }

    func testNonUSSubdivisionCapitalIsNotAUSStateCapital() {
        let quebec = fixture.city(id: "quebec")!
        XCTAssertTrue(quebec.isCapital)
        XCTAssertFalse(quebec.isUSStateCapital)
        XCTAssertFalse(CityCollection.usStateCapitals.contains(quebec))
    }

    func testCityInTwoCollectionsCountsInBoth() {
        let records = [record("washington")]
        XCTAssertEqual(progress(.nationalCapitals, records).visited, 1)
        XCTAssertEqual(progress(.usStateCapitals, records).visited, 1)
        XCTAssertEqual(progress(.allCities, records).visited, 1)
    }

    // MARK: - Counting rules

    func testFullVisitsCount() {
        let records = [record("paris"), record("austin"), record("lyon")]
        XCTAssertEqual(progress(.allCities, records).visited, 3)
        XCTAssertEqual(progress(.nationalCapitals, records).visited, 1)
        XCTAssertEqual(progress(.usStateCapitals, records).visited, 1)
    }

    func testTransitOnlyDoesNotCount() {
        let records = [record("paris", isTransit: true)]
        XCTAssertEqual(progress(.nationalCapitals, records).visited, 0)
        XCTAssertEqual(CityCounting.transitCityIDs(from: records), ["paris"])
    }

    func testTransitPlusFullVisitCountsOnceAndIsNotTransit() {
        let records = [record("paris", isTransit: true), record("paris")]
        XCTAssertEqual(progress(.nationalCapitals, records).visited, 1)
        XCTAssertTrue(CityCounting.transitCityIDs(from: records).isEmpty)
    }

    func testDeletedRowsDoNotCount() {
        let records = [record("paris", isDeleted: true), record("austin", isTransit: true, isDeleted: true)]
        XCTAssertEqual(progress(.allCities, records).visited, 0)
        XCTAssertTrue(CityCounting.transitCityIDs(from: records).isEmpty)
    }

    func testBucketListRowsDoNotCount() {
        let records = [record("paris", isVisited: false)]
        XCTAssertEqual(progress(.nationalCapitals, records).visited, 0)
        XCTAssertTrue(CityCounting.transitCityIDs(from: records).isEmpty)
    }

    func testNonCityRegionTypesAreIgnored() {
        let records = [record("paris", regionType: "country"), record("austin", regionType: "us_state")]
        XCTAssertEqual(progress(.allCities, records).visited, 0)
    }

    func testDuplicateRowsAreDeduplicated() {
        let records = [record("austin"), record("austin"), record("austin")]
        XCTAssertEqual(progress(.usStateCapitals, records).visited, 1)
    }

    func testUnknownCityIDsNeverExceedDenominator() {
        let records = [record("paris"), record("gn:999999999"), record("atlantis")]
        let national = progress(.nationalCapitals, records)
        XCTAssertEqual(national.visited, 1)
        let all = progress(.allCities, records)
        XCTAssertEqual(all.visited, 1)
        XCTAssertLessThanOrEqual(all.visited, all.total)
    }

    func testCompletedCollection() {
        let records = [record("washington"), record("austin"), record("sacramento")]
        let states = progress(.usStateCapitals, records)
        XCTAssertEqual(states.visited, 3)
        XCTAssertEqual(states.fraction, 1, accuracy: 0.0001)
    }

    func testStatus() {
        let records = [record("paris"), record("lyon", isTransit: true)]
        let visited = CityCounting.visitedCityIDs(from: records)
        let transit = CityCounting.transitCityIDs(from: records)
        XCTAssertEqual(CityCounting.status(of: "paris", visitedIDs: visited, transitIDs: transit), .visited)
        XCTAssertEqual(CityCounting.status(of: "lyon", visitedIDs: visited, transitIDs: transit), .transit)
        XCTAssertEqual(CityCounting.status(of: "austin", visitedIDs: visited, transitIDs: transit), .notYet)
    }

    func testFirstVisitDateIsEarliestLiveRow() {
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)
        let records = [
            record("paris", date: late),
            record("paris", date: early),
            record("lyon", isTransit: true, date: late),
            record("austin", isDeleted: true, date: early),
            record("sacramento", isVisited: false, date: early),
        ]
        let dates = CityCounting.firstVisitDates(from: records)
        XCTAssertEqual(dates["paris"], early)
        XCTAssertEqual(dates["lyon"], late)
        XCTAssertNil(dates["austin"])
        XCTAssertNil(dates["sacramento"])
    }

    // MARK: - Presentation

    func testSummaryShowsCountAgainstDenominator() {
        let records = [record("paris")]
        XCTAssertEqual(progress(.nationalCapitals, records).summary, "1 of 2 national capitals")
        XCTAssertEqual(progress(.usStateCapitals, []).summary, "0 of 3 US state capitals")
    }

    func testFractionWithEmptyCollectionIsZero() {
        let empty = CityGazetteer(cities: [], dataVersion: "empty")
        let result = CityCounting.progress(for: .nationalCapitals, in: empty, visitedIDs: ["paris"])
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.visited, 0)
        XCTAssertEqual(result.fraction, 0)
    }

    func testMatchRadiusIsClampedAndGrowsWithPopulation() {
        XCTAssertEqual(GazetteerCity.matchRadius(population: 0), 1_500)
        XCTAssertEqual(GazetteerCity.matchRadius(population: 100_000_000), 15_000)
        XCTAssertLessThan(
            GazetteerCity.matchRadius(population: 300_000),
            GazetteerCity.matchRadius(population: 8_000_000)
        )
    }

    // MARK: - Bundled data

    private func bundledGazetteer() throws -> CityGazetteer {
        if let source = try? BundledCityGazetteer.fromBundle(.main) {
            return try CityGazetteer(source: source)
        }
        let geoData = URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Footprint/Resources/GeoData")
        return try CityGazetteer(
            source: BundledCityGazetteer(
                citiesData: Data(contentsOf: geoData.appendingPathComponent("world_cities.json")),
                capitalsData: Data(contentsOf: geoData.appendingPathComponent("capitals.json"))
            )
        )
    }

    func testBundledCollectionsHaveExpectedDenominators() throws {
        let gazetteer = try bundledGazetteer()
        XCTAssertEqual(gazetteer.cities(in: .nationalCapitals).count, 195)
        XCTAssertEqual(gazetteer.cities(in: .usStateCapitals).count, 51)
        XCTAssertGreaterThan(gazetteer.cities(in: .allCities).count, 2_000)
    }

    func testBundledNationalCapitalsAreOnePerCountry() throws {
        let capitals = try bundledGazetteer().cities(in: .nationalCapitals)
        XCTAssertEqual(Set(capitals.map(\.countryCode)).count, 195)
    }

    func testBundledUSStateCapitalsCoverEveryStateAndDC() throws {
        let capitals = try bundledGazetteer().cities(in: .usStateCapitals)
        let states = Set(capitals.compactMap(\.subdivisionCode))
        XCTAssertEqual(states.count, 51)
        XCTAssertTrue(states.contains("US-DC"))
        let expected = Set(GeographicData.usStates.map { "US-\($0.id)" })
        XCTAssertTrue(states.isSubset(of: expected.union(["US-DC"])), "Unexpected: \(states.subtracting(expected))")
    }

    func testBundledCityIDsAreUnique() throws {
        let cities = try bundledGazetteer().cities
        XCTAssertEqual(Set(cities.map(\.id)).count, cities.count)
    }

    func testBundledWellKnownCapitals() throws {
        let gazetteer = try bundledGazetteer()
        let national = Set(gazetteer.cities(in: .nationalCapitals).map(\.name))
        for name in ["Paris", "Tokyo", "Washington", "Canberra", "Brasília", "Ottawa"] {
            XCTAssertTrue(national.contains(name), "Missing national capital \(name)")
        }
        let states = Set(gazetteer.cities(in: .usStateCapitals).map(\.name))
        for name in ["Sacramento", "Austin", "Albany", "Juneau", "Honolulu", "Washington"] {
            XCTAssertTrue(states.contains(name), "Missing US state capital \(name)")
        }
    }

    func testBundledCountingAgainstRealData() throws {
        let gazetteer = try bundledGazetteer()
        let paris = try XCTUnwrap(gazetteer.cities(in: .nationalCapitals).first { $0.name == "Paris" })
        let austin = try XCTUnwrap(gazetteer.cities(in: .usStateCapitals).first { $0.name == "Austin" })
        let records = [record(paris.id), record(austin.id), record(austin.id, isTransit: true)]
        let result = CityCounting.progress(in: gazetteer, records: records)
        let byCollection = Dictionary(uniqueKeysWithValues: result.map { ($0.collection, $0) })
        XCTAssertEqual(byCollection[.nationalCapitals]?.summary, "1 of 195 national capitals")
        XCTAssertEqual(byCollection[.usStateCapitals]?.summary, "1 of 51 US state capitals")
        XCTAssertEqual(byCollection[.allCities]?.visited, 2)
    }

    // MARK: - Data model

    func testCityRegionTypeIsAdditiveString() {
        XCTAssertEqual(VisitedPlace.RegionType.city.rawValue, CityCounting.regionType)
        XCTAssertEqual(VisitedPlace.RegionType(rawValue: "city"), .city)
        XCTAssertEqual(VisitedPlace.RegionType.country.rawValue, "country")
    }
}
