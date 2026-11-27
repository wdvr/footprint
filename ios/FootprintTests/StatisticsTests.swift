import XCTest
@testable import Footprint

final class StatisticsTests: XCTestCase {

    // MARK: - VisitedPlace Tests

    func testVisitedPlaceWithVisitType() {
        let place = VisitedPlace(
            regionType: .country,
            regionCode: "FR",
            regionName: "France",
            status: .visited,
            visitType: .transit
        )

        XCTAssertEqual(place.regionCode, "FR")
        XCTAssertEqual(place.visitTypeEnum, .transit)
        XCTAssertTrue(place.isTransit)
        XCTAssertFalse(place.isFullVisit)
    }

    func testVisitedPlaceFullVisit() {
        let place = VisitedPlace(
            regionType: .country,
            regionCode: "JP",
            regionName: "Japan",
            visitType: .visited
        )

        XCTAssertTrue(place.isFullVisit)
        XCTAssertFalse(place.isTransit)
    }

    func testVisitedPlaceWithDates() {
        let arrival = Date()
        let departure = Calendar.current.date(byAdding: .day, value: 5, to: arrival)!

        let place = VisitedPlace(
            regionType: .country,
            regionCode: "IT",
            regionName: "Italy",
            visitedDate: arrival,
            departureDate: departure
        )

        XCTAssertNotNil(place.visitedDate)
        XCTAssertNotNil(place.departureDate)
        XCTAssertNotNil(place.visitDuration)
        XCTAssertEqual(place.visitDuration, 6) // 5 days + 1 (inclusive)
    }

    func testVisitedPlaceNoDuration() {
        let place = VisitedPlace(
            regionType: .country,
            regionCode: "DE",
            regionName: "Germany",
            visitedDate: Date()
        )

        XCTAssertNil(place.visitDuration)
    }

    func testVisitTypeDisplayName() {
        XCTAssertEqual(VisitedPlace.VisitType.visited.displayName, "Visited")
        XCTAssertEqual(VisitedPlace.VisitType.transit.displayName, "Transit/Layover")
    }

    func testVisitTypeIcon() {
        XCTAssertEqual(VisitedPlace.VisitType.visited.icon, "figure.walk")
        XCTAssertEqual(VisitedPlace.VisitType.transit.icon, "airplane")
    }

    // MARK: - LocalContinentStats Tests

    func testContinentStatsCalculation() {
        let visitedCountries = ["FR", "DE", "IT", "JP", "US", "BR"]
        let stats = LocalContinentStats.calculateStats(visitedCountries: visitedCountries)

        XCTAssertEqual(stats.count, 6) // All continents except Antarctica

        // Find Europe stats
        let europe = stats.first { $0.name == "Europe" }
        XCTAssertNotNil(europe)
        XCTAssertEqual(europe?.visited, 3) // FR, DE, IT
        XCTAssertEqual(europe?.total, 45) // includes Sevastopol (XS)
    }

    func testContinentStatsEmpty() {
        let stats = LocalContinentStats.calculateStats(visitedCountries: [])

        for stat in stats {
            XCTAssertEqual(stat.visited, 0)
        }
    }

    func testContinentStatsPercentage() {
        let visitedCountries = ["FR", "DE"]
        let stats = LocalContinentStats.calculateStats(visitedCountries: visitedCountries)

        let europe = stats.first { $0.name == "Europe" }
        XCTAssertNotNil(europe)
        let expectedPercentage = Double(2) / Double(45) * 100
        XCTAssertEqual(europe?.percentage ?? 0, expectedPercentage, accuracy: 0.01)
    }

    // MARK: - TimeZoneLocalStats Tests

    // US spans multiple time zones, so its zones come from the visited states only
    private let usStatesNYAndHI = [
        (VisitedPlace.RegionType.usState.rawValue, "NY"),
        (VisitedPlace.RegionType.usState.rawValue, "HI"),
    ]

    func testTimeZoneCalculation() {
        let visitedCountries = ["GB", "JP", "US"]
        let stats = TimeZoneLocalStats.calculate(visitedCountries: visitedCountries, visitedStates: usStatesNYAndHI)

        // GB = UTC+0, JP = UTC+9, NY = UTC-5, HI = UTC-10
        XCTAssertEqual(stats.visitedZones, [0, 9, -5, -10])
        XCTAssertEqual(stats.zonesVisited, 4)
    }

    func testTimeZoneMultiZoneCountryWithoutStates() {
        let stats = TimeZoneLocalStats.calculate(visitedCountries: ["GB", "JP", "US"])

        // Visiting the US without any states adds no US time zones
        XCTAssertEqual(stats.visitedZones, [0, 9])
    }

    func testTimeZoneFarthestPoints() {
        let visitedCountries = ["GB", "JP", "US"]
        let stats = TimeZoneLocalStats.calculate(visitedCountries: visitedCountries, visitedStates: usStatesNYAndHI)

        XCTAssertEqual(stats.farthestEast, 9) // Japan
        XCTAssertEqual(stats.farthestWest, -10) // US Hawaii
    }

    func testTimeZoneEmpty() {
        let stats = TimeZoneLocalStats.calculate(visitedCountries: [])

        XCTAssertEqual(stats.zonesVisited, 0)
        XCTAssertNil(stats.farthestEast)
        XCTAssertNil(stats.farthestWest)
        XCTAssertEqual(stats.percentage, 0)
    }

    func testTimeZonePercentage() {
        let visitedCountries = ["GB", "FR", "DE"]
        let stats = TimeZoneLocalStats.calculate(visitedCountries: visitedCountries)

        // GB = UTC+0, FR & DE = UTC+1
        XCTAssertEqual(stats.zonesVisited, 2) // 0 and 1
        let expectedPercentage = Double(2) / 24.0 * 100
        XCTAssertEqual(stats.percentage, expectedPercentage, accuracy: 0.01)
    }

    // MARK: - LocalBadgeProgress Tests

    func testBadgeProgressNoPlaces() {
        let badges = LocalBadgeProgress.calculateProgress(visitedPlaces: [])

        for badge in badges {
            XCTAssertFalse(badge.unlocked)
            XCTAssertEqual(badge.progress, 0)
        }
    }

    func testBadgeProgressFirstSteps() {
        let place = VisitedPlace(
            regionType: .country,
            regionCode: "FR",
            regionName: "France"
        )

        let badges = LocalBadgeProgress.calculateProgress(visitedPlaces: [place])
        let firstSteps = badges.first { $0.id == "first_steps" }

        XCTAssertNotNil(firstSteps)
        XCTAssertTrue(firstSteps?.unlocked ?? false)
        XCTAssertEqual(firstSteps?.progress, 1)
    }

    func testBadgeProgressPercentage() {
        let places = (0..<5).map { i in
            VisitedPlace(
                regionType: .country,
                regionCode: "C\(i)",
                regionName: "Country \(i)"
            )
        }

        let badges = LocalBadgeProgress.calculateProgress(visitedPlaces: places)
        let explorer = badges.first { $0.id == "explorer_10" }

        XCTAssertNotNil(explorer)
        XCTAssertEqual(explorer?.progress, 5)
        XCTAssertEqual(explorer?.progressPercentage ?? 0, 50.0, accuracy: 0.01)
        XCTAssertFalse(explorer?.unlocked ?? true)
    }

    func testBadgeProgressUSStates() {
        let places = (0..<10).map { i in
            VisitedPlace(
                regionType: .usState,
                regionCode: "S\(i)",
                regionName: "State \(i)"
            )
        }

        let badges = LocalBadgeProgress.calculateProgress(visitedPlaces: places)
        let usStarter = badges.first { $0.id == "us_starter" }

        XCTAssertNotNil(usStarter)
        XCTAssertTrue(usStarter?.unlocked ?? false)
        XCTAssertEqual(usStarter?.progress, 10)
    }

    func testBadgeProgressExcludesDeleted() {
        let place1 = VisitedPlace(
            regionType: .country,
            regionCode: "FR",
            regionName: "France"
        )

        var place2 = VisitedPlace(
            regionType: .country,
            regionCode: "DE",
            regionName: "Germany"
        )
        place2.isDeleted = true

        let badges = LocalBadgeProgress.calculateProgress(visitedPlaces: [place1, place2])
        let firstSteps = badges.first { $0.id == "first_steps" }

        XCTAssertEqual(firstSteps?.progress, 1) // Only non-deleted counted
    }

    func testBadgeProgressExcludesBucketList() {
        let visited = VisitedPlace(
            regionType: .country,
            regionCode: "FR",
            regionName: "France",
            status: .visited
        )

        let bucketList = VisitedPlace(
            regionType: .country,
            regionCode: "JP",
            regionName: "Japan",
            status: .bucketList
        )

        let badges = LocalBadgeProgress.calculateProgress(visitedPlaces: [visited, bucketList])
        let firstSteps = badges.first { $0.id == "first_steps" }

        XCTAssertEqual(firstSteps?.progress, 1) // Only visited counted
    }
}
