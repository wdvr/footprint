import XCTest
@testable import Skratch

final class SkratchTests: XCTestCase {
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

    func testRegionTypeDisplayName() {
        XCTAssertEqual(VisitedPlace.RegionType.country.displayName, "Country")
        XCTAssertEqual(VisitedPlace.RegionType.usState.displayName, "US State")
        XCTAssertEqual(VisitedPlace.RegionType.canadianProvince.displayName, "Canadian Province")
    }
}
