import CoreGraphics
import XCTest

@testable import Footprint

final class ScratchPosterModelTests: XCTestCase {

    // MARK: - Fixtures

    private func place(
        _ type: VisitedPlace.RegionType,
        _ code: String,
        status: VisitedPlace.PlaceStatus = .visited,
        visitType: VisitedPlace.VisitType = .visited,
        deleted: Bool = false
    ) -> VisitedPlace {
        VisitedPlace(
            regionType: type, regionCode: code, regionName: code,
            status: status, visitType: visitType, isDeleted: deleted
        )
    }

    /// A US county row as written by the opt-in counties layer: `regionType` is a plain String.
    private func countyRow(_ fips: String) -> VisitedPlace {
        let row = place(.country, fips)
        row.regionType = "us_county"
        return row
    }

    private var fixture: [VisitedPlace] {
        [
            place(.country, "FR"),
            place(.country, "DE"),
            place(.country, "US"),
            place(.country, "JP"),
            place(.country, "BR"),
            place(.country, "GB"),
            place(.country, "CH", visitType: .transit),
            place(.country, "IT", deleted: true),
            place(.country, "ES", status: .bucketList),
            place(.usState, "CA"),
            place(.usState, "NY"),
            place(.usState, "TX"),
            place(.usState, "FL", status: .bucketList),
            place(.canadianProvince, "ON"),
            place(.ukCountry, "MAN"),
            place(.ukCountry, "GB-EDH"),
            place(.frenchRegion, "75"),
        ]
    }

    private let allTracked = ScratchPosterModel.subdivisionBoundaryCountries.union(["DE", "AU", "MX", "BR"])

    /// The Stats tab's formulas, written out independently of `TravelStatistics`.
    private func statsTabCount(_ places: [VisitedPlace], _ type: VisitedPlace.RegionType) -> Int {
        places.filter { !$0.isDeleted && $0.regionType == type.rawValue && $0.isVisited }.count
    }

    // MARK: - Statistics match the app

    func testStatisticsMatchStatsTab() {
        let stats = TravelStatistics(places: fixture)

        XCTAssertEqual(stats.countriesVisited, 7, "FR DE US JP BR GB + CH transit; deleted IT and bucket-list ES excluded")
        XCTAssertEqual(stats.countriesVisited, statsTabCount(fixture, .country))
        XCTAssertEqual(stats.usStatesVisited, statsTabCount(fixture, .usState))
        XCTAssertEqual(stats.usStatesVisited, 3)
        XCTAssertEqual(stats.canadianProvincesVisited, 1)
        XCTAssertEqual(stats.totalRegionsVisited, 11)
        XCTAssertEqual(stats.countriesTotal, GeographicData.countries.count)
        XCTAssertEqual(stats.usStatesTotal, GeographicData.usStates.count)
        XCTAssertEqual(stats.canadianProvincesTotal, GeographicData.canadianProvinces.count)
        XCTAssertEqual(stats.countriesBucketList, 1)
        XCTAssertEqual(stats.usStatesBucketList, 1)
        XCTAssertEqual(stats.totalBucketList, 2)
        XCTAssertEqual(
            stats.countriesPercentage,
            Double(7) / Double(GeographicData.countries.count) * 100,
            accuracy: 1e-9
        )
    }

    func testContinentsMatchContinentProgress() {
        let stats = TravelStatistics(places: fixture)
        let visitedCountries = fixture
            .filter { !$0.isDeleted && $0.regionType == "country" && $0.isVisited }
            .map(\.regionCode)
        let expected = LocalContinentStats.calculateStats(visitedCountries: visitedCountries)
            .filter { $0.visited > 0 }.count

        XCTAssertEqual(stats.continentsVisited, expected)
        XCTAssertEqual(stats.continentsVisited, 4, "Europe, North America, Asia, South America")
        XCTAssertEqual(stats.continentsTotal, LocalContinentStats.continentData.count)
    }

    func testPosterHeadlineShowsAppStatistics() {
        let model = ScratchPosterModel(places: fixture, trackedCountries: allTracked, title: "My Map")
        let stats = TravelStatistics(places: fixture)

        XCTAssertEqual(model.statistics, stats)
        XCTAssertEqual(model.headline, [
            .init(value: "7", label: "of \(GeographicData.countries.count) countries"),
            .init(value: String(format: "%.1f%%", stats.countriesPercentage), label: "of the world"),
            .init(value: "4/6", label: "continents"),
            .init(value: "3/\(GeographicData.usStates.count)", label: "US states"),
            .init(value: "1/\(GeographicData.canadianProvinces.count)", label: "Canadian provinces"),
            .init(value: "11", label: "regions visited"),
        ])
        XCTAssertEqual(
            model.subtitle,
            "7 countries across 4 continents · \(String(format: "%.1f%%", stats.countriesPercentage)) of the world"
        )
    }

    func testHeadlineHidesStatesAndProvincesWhenNotTracked() {
        let model = ScratchPosterModel(places: fixture, trackedCountries: [], title: "")
        XCTAssertEqual(model.headline.map(\.label), [
            "of \(GeographicData.countries.count) countries", "of the world", "continents", "regions visited",
        ])
        XCTAssertEqual(model.headline.last?.value, "11", "Total regions counts states as the Stats tab does")
        XCTAssertTrue(model.coverage.isEmpty)
        XCTAssertTrue(model.subdivisionCountries.isEmpty)
    }

    func testEmptyPoster() {
        let model = ScratchPosterModel(places: [], trackedCountries: allTracked, title: "")
        XCTAssertEqual(model.headline.first?.value, "0")
        XCTAssertEqual(model.subtitle, "0 countries across 0 continents · 0.0% of the world")
        XCTAssertTrue(model.coverage.isEmpty)
        XCTAssertTrue(model.visitedCountryCodes.isEmpty)
    }

    // MARK: - Coverage matches the country popups

    func testCoverageMatchesCountryCoverage() {
        let model = ScratchPosterModel(places: fixture, trackedCountries: allTracked, title: "")
        let live = fixture.filter { !$0.isDeleted }

        XCTAssertEqual(Set(model.coverage.map(\.countryCode)), ["US", "CA", "GB", "FR"])
        for line in model.coverage {
            let app = CountryCoverage.coverage(for: line.countryCode, visitedPlaces: live)
            XCTAssertEqual(line.visitedCount, app?.visitedCount, line.countryCode)
            XCTAssertEqual(line.totalCount, app?.totalCount, line.countryCode)
            XCTAssertEqual(line.percentage, app?.percentage ?? -1, accuracy: 1e-9, line.countryCode)
            XCTAssertEqual(line.subdivisionLabel, app?.subdivisionLabel, line.countryCode)
            XCTAssertEqual(line.percentText, String(format: "%.0f%%", app?.percentage ?? -1))
        }

        let us = model.coverage.first { $0.countryCode == "US" }
        XCTAssertEqual(us?.countText, "3/\(GeographicData.usStates.count) states")
        let gb = model.coverage.first { $0.countryCode == "GB" }
        XCTAssertEqual(gb?.visitedCount, 2)

        let percentages = model.coverage.map(\.percentage)
        XCTAssertEqual(percentages, percentages.sorted(by: >), "Most explored first")
    }

    func testCoverageOnlyForTrackedCountries() {
        let model = ScratchPosterModel(places: fixture, trackedCountries: ["US"], title: "")
        XCTAssertEqual(model.coverage.map(\.countryCode), ["US"])
    }

    func testCoverageIsCapped() {
        let codes = ["US", "CA", "GB", "FR", "IT", "JP", "KR", "NO", "NL", "BE", "ES"]
        let places = codes.compactMap { code -> VisitedPlace? in
            guard let type = GeographicData.regionType(for: code),
                  let first = GeographicData.states(for: code).first else { return nil }
            return place(type, first.id)
        }
        let model = ScratchPosterModel(places: places, trackedCountries: Set(codes), title: "")
        XCTAssertEqual(model.coverage.count, ScratchPosterModel.maxCoverageLines)
    }

    // MARK: - Map fill

    func testVisitedCountriesExcludeBucketListAndDeleted() {
        let model = ScratchPosterModel(places: fixture, trackedCountries: allTracked, title: "")
        XCTAssertEqual(model.visitedCountryCodes, ["FR", "DE", "US", "JP", "BR", "GB", "CH"])
        XCTAssertEqual(model.visitedCountryCodes.count, model.statistics.countriesVisited)
    }

    func testSubdivisionsMatchShortAndPrefixedCodes() {
        let model = ScratchPosterModel(places: fixture, trackedCountries: allTracked, title: "")

        XCTAssertTrue(model.isSubdivisionVisited(countryCode: "GB", boundaryCode: "GB-MAN"))
        XCTAssertTrue(model.isSubdivisionVisited(countryCode: "GB", boundaryCode: "GB-EDH"))
        XCTAssertFalse(model.isSubdivisionVisited(countryCode: "GB", boundaryCode: "GB-LND"))
        XCTAssertTrue(model.isSubdivisionVisited(countryCode: "US", boundaryCode: "CA"))
        XCTAssertFalse(model.isSubdivisionVisited(countryCode: "US", boundaryCode: "FL"), "Bucket list stays unscratched")
        XCTAssertTrue(model.isSubdivisionVisited(countryCode: "CA", boundaryCode: "ON"))
        XCTAssertTrue(model.isSubdivisionVisited(countryCode: "FR", boundaryCode: "FR-75"))
        XCTAssertEqual(model.visitedSubdivisions["GB"], ["MAN", "EDH"])
    }

    func testVisitedOverseasTerritoryScratchesItsDepartment() {
        let places = [place(.country, "FR"), place(.country, "GF"), place(.frenchRegion, "75")]
        let model = ScratchPosterModel(places: places, trackedCountries: ["FR"], title: "")

        XCTAssertTrue(model.isSubdivisionVisited(countryCode: "FR", boundaryCode: "FR-GF"))
        XCTAssertFalse(model.isSubdivisionVisited(countryCode: "FR", boundaryCode: "FR-MQ"))
        XCTAssertFalse(model.isSubdivisionVisited(countryCode: "FR", boundaryCode: "FR-13"))
        XCTAssertFalse(
            model.isSubdivisionVisited(countryCode: "US", boundaryCode: "CA"),
            "Only listed territories borrow a country visit"
        )
        let france = model.coverage.first { $0.countryCode == "FR" }
        XCTAssertEqual(france?.visitedCount, 1, "Coverage still counts saved departments only, like the app")
    }

    func testTerritorySubdivisionsAreRealSubdivisions() {
        for (countryCode, codes) in ScratchPosterModel.territorySubdivisions {
            let subdivisions = Set(GeographicData.states(for: countryCode).map(\.id))
            XCTAssertTrue(codes.isSubset(of: subdivisions), countryCode)
        }
    }

    func testSubdivisionsOnlyDrawnForTrackedCountriesWithBoundaries() {
        let model = ScratchPosterModel(places: fixture, trackedCountries: ["US", "DE"], title: "")
        XCTAssertEqual(model.subdivisionCountries, ["US"], "DE has no bundled boundaries")
        XCTAssertFalse(model.isSubdivisionVisited(countryCode: "GB", boundaryCode: "GB-MAN"))
    }

    func testSubdivisionBoundaryCountriesHaveSubdivisionTypes() {
        for code in ScratchPosterModel.subdivisionBoundaryCountries {
            XCTAssertNotNil(GeographicData.regionType(for: code), code)
            XCTAssertFalse(GeographicData.states(for: code).isEmpty, code)
        }
    }

    func testCountyRowsDoNotChangePoster() {
        let base = ScratchPosterModel(places: fixture, trackedCountries: allTracked, title: "T")
        let withCounties = ScratchPosterModel(
            places: fixture + [countyRow("06075"), countyRow("36061")],
            trackedCountries: allTracked,
            title: "T"
        )
        XCTAssertEqual(base, withCounties)
    }

    // MARK: - Print size

    func testA3PrintsAt300DPI() {
        XCTAssertEqual(PosterSize.a3.pngDPI, 300)
        XCTAssertEqual(PosterSize.a3.pngPixelSize, CGSize(width: 4963, height: 3508))
    }

    func testPNGStaysWithinPixelBudget() {
        for size in PosterSize.allCases {
            let pixels = size.pngPixelSize.width * size.pngPixelSize.height
            XCTAssertLessThanOrEqual(pixels, PosterSize.maxPNGPixels * 1.001, size.rawValue)
            XCTAssertGreaterThanOrEqual(size.pngDPI, 200, size.rawValue)
            XCTAssertGreaterThan(size.pngPixelSize.width, size.pngPixelSize.height, "Landscape")
        }
        XCTAssertEqual(PosterSize.a2.pngDPI, 300)
        XCTAssertLessThan(PosterSize.a1.pngDPI, 300)
    }

    // MARK: - Projection and layout

    func testProjectionCorners() {
        let rect = CGRect(x: 10, y: 20, width: 1000, height: 500)
        let northWest = ScratchPosterProjection.point(
            latitude: ScratchPosterProjection.northLatitude, longitude: -180, in: rect
        )
        let southEast = ScratchPosterProjection.point(
            latitude: ScratchPosterProjection.southLatitude, longitude: 180, in: rect
        )
        XCTAssertEqual(northWest.x, rect.minX, accuracy: 1e-6)
        XCTAssertEqual(northWest.y, rect.minY, accuracy: 1e-6)
        XCTAssertEqual(southEast.x, rect.maxX, accuracy: 1e-6)
        XCTAssertEqual(southEast.y, rect.maxY, accuracy: 1e-6)

        let antarctic = ScratchPosterProjection.point(latitude: -80, longitude: 0, in: rect)
        XCTAssertEqual(antarctic.y, rect.maxY, accuracy: 1e-6, "Clamped to the southern edge")
    }

    func testUnwrapAntimeridian() {
        XCTAssertEqual(ScratchPosterProjection.unwrappedLongitudes([179, -179, -178, 178]), [179, 181, 182, 178])
        XCTAssertEqual(ScratchPosterProjection.unwrappedLongitudes([10, 20, 30]), [10, 20, 30])
        XCTAssertEqual(ScratchPosterProjection.unwrappedLongitudes([]), [])
    }

    func testLayoutBlocksFitAndDoNotOverlap() {
        for size in PosterSize.allCases {
            let layout = ScratchPosterLayout(pageSize: size.landscapeSize)
            for block in [layout.title, layout.map, layout.stats, layout.footer] {
                XCTAssertTrue(layout.page.contains(block), size.rawValue)
            }
            XCTAssertLessThanOrEqual(layout.title.maxY, layout.map.minY)
            XCTAssertLessThanOrEqual(layout.map.maxY, layout.stats.minY)
            XCTAssertLessThanOrEqual(layout.stats.maxY, layout.footer.minY)
            XCTAssertEqual(
                Double(layout.map.width / layout.map.height),
                ScratchPosterProjection.aspectRatio,
                accuracy: 1e-6
            )
            XCTAssertGreaterThan(layout.map.width, layout.page.width * 0.7, "Map dominates the poster")
        }
    }
}
