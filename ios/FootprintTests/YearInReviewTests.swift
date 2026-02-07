import XCTest
@testable import Footprint

/// Regression tests for YearInReviewData.compute().
/// Ensures that Year in Review only includes places with an explicit visitedDate,
/// not places that were merely marked in the app (markedAt).
final class YearInReviewTests: XCTestCase {

    // MARK: - Helper

    private func makePlace(
        regionType: VisitedPlace.RegionType = .country,
        regionCode: String,
        regionName: String,
        visitedDate: Date? = nil,
        departureDate: Date? = nil,
        markedAt: Date = Date(),
        isDeleted: Bool = false,
        status: VisitedPlace.PlaceStatus = .visited
    ) -> VisitedPlace {
        VisitedPlace(
            regionType: regionType,
            regionCode: regionCode,
            regionName: regionName,
            status: status,
            visitedDate: visitedDate,
            departureDate: departureDate,
            markedAt: markedAt,
            isDeleted: isDeleted
        )
    }

    private func date(year: Int, month: Int = 6, day: Int = 15) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    // MARK: - Core Filtering Tests

    /// Places without visitedDate should NOT appear in Year in Review.
    /// This is the primary regression test for the markedAt fallback bug.
    func testPlacesWithoutVisitedDateExcludedFromYearInReview() {
        let places = [
            // Manually added Greece - no visitedDate, only markedAt in 2025
            makePlace(regionCode: "GR", regionName: "Greece", markedAt: date(year: 2025)),
            // Manually added Montenegro - no visitedDate, only markedAt in 2025
            makePlace(regionCode: "ME", regionName: "Montenegro", markedAt: date(year: 2025)),
        ]

        let data = YearInReviewData.compute(for: 2025, allPlaces: places)

        XCTAssertEqual(data.newCountriesCount, 0, "Countries without visitedDate should not appear in Year in Review")
        XCTAssertEqual(data.visitedCountriesCount, 0)
        XCTAssertEqual(data.totalNewPlaces, 0)
        XCTAssertEqual(data.totalVisitedPlaces, 0)
        XCTAssertFalse(data.hasData)
    }

    /// Places WITH visitedDate in the target year should appear.
    func testPlacesWithVisitedDateIncludedInYearInReview() {
        let places = [
            makePlace(regionCode: "BE", regionName: "Belgium", visitedDate: date(year: 2025, month: 3)),
            makePlace(regionCode: "FR", regionName: "France", visitedDate: date(year: 2025, month: 7)),
        ]

        let data = YearInReviewData.compute(for: 2025, allPlaces: places)

        XCTAssertEqual(data.newCountriesCount, 2)
        XCTAssertEqual(data.visitedCountriesCount, 2)
        XCTAssertTrue(data.hasData)
    }

    /// Photo-imported places with visitedDate should correctly appear.
    func testPhotoImportedPlacesAppearInYearInReview() {
        let places = [
            // Photo import set visitedDate to Jan 2025 (earliest photo date)
            makePlace(
                regionType: .usState,
                regionCode: "ID",
                regionName: "Idaho",
                visitedDate: date(year: 2025, month: 1, day: 10)
            ),
            // Manually marked CA with no visitedDate - should NOT appear
            makePlace(
                regionType: .usState,
                regionCode: "CA",
                regionName: "California"
            ),
        ]

        let data = YearInReviewData.compute(for: 2025, allPlaces: places)

        XCTAssertEqual(data.newUSStatesCount, 1, "Only Idaho (with visitedDate) should appear")
        XCTAssertEqual(data.visitedUSStatesCount, 1)
    }

    /// Places with visitedDate in a different year should not appear.
    func testPlacesFromDifferentYearExcluded() {
        let places = [
            makePlace(regionCode: "JP", regionName: "Japan", visitedDate: date(year: 2023)),
            makePlace(regionCode: "BE", regionName: "Belgium", visitedDate: date(year: 2025)),
        ]

        let data = YearInReviewData.compute(for: 2025, allPlaces: places)

        XCTAssertEqual(data.newCountriesCount, 1, "Only Belgium (2025) should be new")
        XCTAssertEqual(data.visitedCountriesCount, 1)
    }

    // MARK: - Departure Date / Multi-Year Visit Tests

    /// A visit spanning two years should appear in both years.
    func testMultiYearVisitAppearsInBothYears() {
        let places = [
            makePlace(
                regionCode: "TH",
                regionName: "Thailand",
                visitedDate: date(year: 2024, month: 12, day: 20),
                departureDate: date(year: 2025, month: 1, day: 5)
            ),
        ]

        let data2024 = YearInReviewData.compute(for: 2024, allPlaces: places)
        let data2025 = YearInReviewData.compute(for: 2025, allPlaces: places)

        XCTAssertEqual(data2024.newCountriesCount, 1, "Thailand first visited in 2024")
        XCTAssertEqual(data2024.visitedCountriesCount, 1)
        XCTAssertEqual(data2025.newCountriesCount, 0, "Thailand was first visited in 2024, not new in 2025")
        XCTAssertEqual(data2025.visitedCountriesCount, 1, "Visit extends into 2025")
    }

    // MARK: - Available Years Tests

    /// availableYears should only list years from places with visitedDate.
    func testAvailableYearsOnlyFromVisitedDate() {
        let places = [
            // Has visitedDate
            makePlace(regionCode: "BE", regionName: "Belgium", visitedDate: date(year: 2025)),
            makePlace(regionCode: "JP", regionName: "Japan", visitedDate: date(year: 2023)),
            // No visitedDate - should NOT contribute to available years
            makePlace(regionCode: "GR", regionName: "Greece", markedAt: date(year: 2025)),
        ]

        let years = YearInReviewData.availableYears(from: places)

        XCTAssertEqual(years, [2025, 2023], "Only years from visitedDate should appear")
        XCTAssertFalse(years.isEmpty)
    }

    /// Departure dates should also contribute to available years.
    func testAvailableYearsIncludesDepartureDate() {
        let places = [
            makePlace(
                regionCode: "TH",
                regionName: "Thailand",
                visitedDate: date(year: 2024, month: 12),
                departureDate: date(year: 2025, month: 1)
            ),
        ]

        let years = YearInReviewData.availableYears(from: places)

        XCTAssertTrue(years.contains(2024))
        XCTAssertTrue(years.contains(2025))
    }

    /// No places with visitedDate should return empty available years.
    func testAvailableYearsEmptyWhenNoVisitedDates() {
        let places = [
            makePlace(regionCode: "GR", regionName: "Greece"),
            makePlace(regionCode: "ME", regionName: "Montenegro"),
        ]

        let years = YearInReviewData.availableYears(from: places)
        XCTAssertTrue(years.isEmpty)
    }

    // MARK: - Deleted & Bucket List Exclusion Tests

    /// Deleted places should be excluded even if they have visitedDate.
    func testDeletedPlacesExcluded() {
        let places = [
            makePlace(regionCode: "FR", regionName: "France", visitedDate: date(year: 2025), isDeleted: true),
        ]

        let data = YearInReviewData.compute(for: 2025, allPlaces: places)
        XCTAssertEqual(data.totalNewPlaces, 0)
        XCTAssertFalse(data.hasData)
    }

    /// Bucket list places should be excluded.
    func testBucketListPlacesExcluded() {
        let places = [
            makePlace(regionCode: "NZ", regionName: "New Zealand", visitedDate: date(year: 2025), status: .bucketList),
        ]

        let data = YearInReviewData.compute(for: 2025, allPlaces: places)
        XCTAssertEqual(data.totalNewPlaces, 0)
    }

    // MARK: - Region Type Categorization Tests

    /// US states, Canadian provinces, and other regions should be categorized correctly.
    func testRegionTypeCategorization() {
        let places = [
            makePlace(regionType: .country, regionCode: "BE", regionName: "Belgium", visitedDate: date(year: 2025)),
            makePlace(regionType: .usState, regionCode: "CA", regionName: "California", visitedDate: date(year: 2025)),
            makePlace(regionType: .usState, regionCode: "WA", regionName: "Washington", visitedDate: date(year: 2025)),
            makePlace(regionType: .canadianProvince, regionCode: "BC", regionName: "British Columbia", visitedDate: date(year: 2025)),
            makePlace(regionType: .belgianProvince, regionCode: "VLG", regionName: "Flanders", visitedDate: date(year: 2025)),
        ]

        let data = YearInReviewData.compute(for: 2025, allPlaces: places)

        XCTAssertEqual(data.newCountriesCount, 1, "1 country: Belgium")
        XCTAssertEqual(data.newUSStatesCount, 2, "2 US states: CA, WA")
        XCTAssertEqual(data.newCanadianProvincesCount, 1, "1 Canadian province: BC")
        XCTAssertEqual(data.newOtherRegionsCount, 1, "1 other region: Flanders")
        XCTAssertEqual(data.totalNewPlaces, 5)
    }

    // MARK: - Mixed Scenarios

    /// Mix of places with and without visitedDate - only those with dates should count.
    func testMixedPlacesOnlyVisitedDatesCounted() {
        let places = [
            // With visitedDate - should count
            makePlace(regionCode: "BE", regionName: "Belgium", visitedDate: date(year: 2025)),
            makePlace(regionType: .usState, regionCode: "ID", regionName: "Idaho", visitedDate: date(year: 2025)),
            // Without visitedDate - should NOT count
            makePlace(regionCode: "GR", regionName: "Greece", markedAt: date(year: 2025)),
            makePlace(regionCode: "ME", regionName: "Montenegro", markedAt: date(year: 2025)),
            makePlace(regionType: .usState, regionCode: "CA", regionName: "California", markedAt: date(year: 2025)),
            makePlace(regionType: .usState, regionCode: "WA", regionName: "Washington", markedAt: date(year: 2024)),
            makePlace(regionType: .usState, regionCode: "OR", regionName: "Oregon"),
        ]

        let data = YearInReviewData.compute(for: 2025, allPlaces: places)

        XCTAssertEqual(data.newCountriesCount, 1, "Only Belgium has visitedDate in 2025")
        XCTAssertEqual(data.newUSStatesCount, 1, "Only Idaho has visitedDate in 2025")
        XCTAssertEqual(data.totalNewPlaces, 2, "Only 2 places have visitedDate in 2025")
    }

    /// Empty places list should produce empty data.
    func testEmptyPlacesList() {
        let data = YearInReviewData.compute(for: 2025, allPlaces: [])

        XCTAssertEqual(data.totalNewPlaces, 0)
        XCTAssertEqual(data.totalVisitedPlaces, 0)
        XCTAssertFalse(data.hasData)
    }
}
