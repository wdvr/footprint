import XCTest
@testable import Footprint

final class FootprintTests: XCTestCase {
    func testVisitedPlaceCreation() {
        let place = VisitedPlace(
            regionType: .country,
            regionCode: "US",
            regionName: "United States"
        )

        XCTAssertEqual(place.regionCode, "US")
        XCTAssertEqual(place.regionName, "United States")
        XCTAssertEqual(place.regionTypeEnum, .country)
        XCTAssertFalse(place.isDeleted)
        XCTAssertFalse(place.isSynced)
    }

    func testVisitedPlaceDefaultValues() {
        let place = VisitedPlace(
            regionType: .country,
            regionCode: "FR",
            regionName: "France"
        )

        // Default status should be visited
        XCTAssertEqual(place.statusEnum, .visited)
        XCTAssertTrue(place.isVisited)
        XCTAssertFalse(place.isBucketList)

        // Default visit type should be visited
        XCTAssertEqual(place.visitTypeEnum, .visited)
        XCTAssertTrue(place.isFullVisit)
        XCTAssertFalse(place.isTransit)

        // Dates should be nil by default
        XCTAssertNil(place.visitedDate)
        XCTAssertNil(place.departureDate)
    }

    func testVisitedPlaceWithTransitType() {
        let place = VisitedPlace(
            regionType: .country,
            regionCode: "NL",
            regionName: "Netherlands",
            visitType: .transit
        )

        XCTAssertEqual(place.visitTypeEnum, .transit)
        XCTAssertTrue(place.isTransit)
        XCTAssertFalse(place.isFullVisit)
    }

    func testVisitedPlaceWithDates() {
        let arrivalDate = Date()
        let departureDate = Calendar.current.date(byAdding: .day, value: 7, to: arrivalDate)!

        let place = VisitedPlace(
            regionType: .country,
            regionCode: "JP",
            regionName: "Japan",
            visitedDate: arrivalDate,
            departureDate: departureDate
        )

        XCTAssertEqual(place.visitedDate, arrivalDate)
        XCTAssertEqual(place.departureDate, departureDate)
        XCTAssertNotNil(place.visitDuration)
        XCTAssertEqual(place.visitDuration, 8) // 7 days + 1 inclusive
    }

    func testRegionTypeDisplayName() {
        XCTAssertEqual(VisitedPlace.RegionType.country.displayName, "Country")
        XCTAssertEqual(VisitedPlace.RegionType.usState.displayName, "US State")
        XCTAssertEqual(VisitedPlace.RegionType.canadianProvince.displayName, "Canadian Province")
    }

    func testPlaceStatusEnum() {
        XCTAssertEqual(VisitedPlace.PlaceStatus.visited.displayName, "Visited")
        XCTAssertEqual(VisitedPlace.PlaceStatus.bucketList.displayName, "Bucket List")
        XCTAssertEqual(VisitedPlace.PlaceStatus.visited.icon, "checkmark.circle.fill")
        XCTAssertEqual(VisitedPlace.PlaceStatus.bucketList.icon, "star.circle.fill")
    }

    func testVisitTypeEnum() {
        XCTAssertEqual(VisitedPlace.VisitType.visited.displayName, "Visited")
        XCTAssertEqual(VisitedPlace.VisitType.transit.displayName, "Transit/Layover")
        XCTAssertEqual(VisitedPlace.VisitType.visited.icon, "figure.walk")
        XCTAssertEqual(VisitedPlace.VisitType.transit.icon, "airplane")
        XCTAssertEqual(VisitedPlace.VisitType.visited.color, "green")
        XCTAssertEqual(VisitedPlace.VisitType.transit.color, "orange")
    }
}
