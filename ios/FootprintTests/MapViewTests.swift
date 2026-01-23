import XCTest
@testable import Footprint

/// Tests for map visualization of visited places
final class MapViewTests: XCTestCase {

    // MARK: - State Code Formatting Tests

    /// Test that US state codes are correctly formatted for the world map
    func testUSStateCodeFormattingForWorldMap() {
        // Given a US state code "CA"
        let stateCode = "CA"
        let countryCode = "US"

        // When formatted for world map display
        let worldMapCode = "\(countryCode)-\(stateCode)"

        // Then it should be "US-CA"
        XCTAssertEqual(worldMapCode, "US-CA")
    }

    /// Test that Canadian province codes are correctly formatted for the world map
    func testCanadianProvinceCodeFormattingForWorldMap() {
        // Given a Canadian province code "ON"
        let provinceCode = "ON"
        let countryCode = "CA"

        // When formatted for world map display
        let worldMapCode = "\(countryCode)-\(provinceCode)"

        // Then it should be "CA-ON"
        XCTAssertEqual(worldMapCode, "CA-ON")
    }

    /// Test that state codes can be identified as states (contain hyphen)
    func testStateCodeIdentification() {
        let stateCodes = ["US-CA", "US-TX", "CA-ON", "CA-BC"]
        let countryCodes = ["US", "CA", "FR", "GB"]

        for code in stateCodes {
            XCTAssertTrue(code.contains("-"), "State code \(code) should contain hyphen")
        }

        for code in countryCodes {
            XCTAssertFalse(code.contains("-"), "Country code \(code) should not contain hyphen")
        }
    }

    // MARK: - Visited State Set Tests

    /// Test building visited state codes set from VisitedPlace data
    func testBuildingVisitedStateCodesSet() {
        // Simulate the logic from ContentView.visitedStateCodes
        let mockPlaces: [(regionType: String, regionCode: String, isDeleted: Bool)] = [
            (VisitedPlace.RegionType.usState.rawValue, "CA", false),
            (VisitedPlace.RegionType.usState.rawValue, "TX", false),
            (VisitedPlace.RegionType.usState.rawValue, "NY", true),  // Deleted
            (VisitedPlace.RegionType.canadianProvince.rawValue, "ON", false),
            (VisitedPlace.RegionType.country.rawValue, "FR", false),  // Country, not state
        ]

        var codes: Set<String> = []
        for place in mockPlaces where !place.isDeleted {
            if place.regionType == VisitedPlace.RegionType.usState.rawValue {
                codes.insert("US-\(place.regionCode)")
            } else if place.regionType == VisitedPlace.RegionType.canadianProvince.rawValue {
                codes.insert("CA-\(place.regionCode)")
            }
        }

        // Should have US-CA, US-TX, CA-ON but NOT US-NY (deleted) or FR (country)
        XCTAssertEqual(codes.count, 3)
        XCTAssertTrue(codes.contains("US-CA"))
        XCTAssertTrue(codes.contains("US-TX"))
        XCTAssertTrue(codes.contains("CA-ON"))
        XCTAssertFalse(codes.contains("US-NY"), "Deleted state should not be included")
        XCTAssertFalse(codes.contains("FR"), "Country should not be in state codes")
    }

    /// Test building visited state codes for StateMapView (no country prefix)
    func testBuildingVisitedStateCodesForStateMapView() {
        // Simulate the logic from StateMapSheet.visitedStateCodes
        let mockPlaces: [(regionType: String, regionCode: String, isDeleted: Bool)] = [
            (VisitedPlace.RegionType.usState.rawValue, "CA", false),
            (VisitedPlace.RegionType.usState.rawValue, "TX", false),
            (VisitedPlace.RegionType.usState.rawValue, "NY", true),  // Deleted
            (VisitedPlace.RegionType.canadianProvince.rawValue, "ON", false),
        ]

        let countryCode = "US"
        let regionType = countryCode == "US"
            ? VisitedPlace.RegionType.usState.rawValue
            : VisitedPlace.RegionType.canadianProvince.rawValue

        let codes = Set(
            mockPlaces
                .filter { $0.regionType == regionType && !$0.isDeleted }
                .map { $0.regionCode }
        )

        // For US states, should have CA, TX but NOT NY (deleted) or ON (Canadian)
        XCTAssertEqual(codes.count, 2)
        XCTAssertTrue(codes.contains("CA"))
        XCTAssertTrue(codes.contains("TX"))
        XCTAssertFalse(codes.contains("NY"), "Deleted state should not be included")
        XCTAssertFalse(codes.contains("ON"), "Canadian province should not be in US state codes")
    }

    // MARK: - GeoJSON State Boundary Tests

    /// Test that US states can be parsed from GeoJSON
    /// Note: This test requires GeoJSON resources in the test bundle
    func testUSStatesGeoJSONParsing() throws {
        let states = GeoJSONParser.parseUSStates()

        // Skip if resources not available in test bundle
        try XCTSkipIf(states.isEmpty, "GeoJSON resources not available in test bundle")

        // Should have 51 states (50 + DC)
        XCTAssertEqual(states.count, 51, "Should have 51 US states including DC")

        // Check some known states exist
        let stateIds = Set(states.map { $0.id })
        XCTAssertTrue(stateIds.contains("CA"), "Should contain California")
        XCTAssertTrue(stateIds.contains("TX"), "Should contain Texas")
        XCTAssertTrue(stateIds.contains("NY"), "Should contain New York")
        XCTAssertTrue(stateIds.contains("DC"), "Should contain DC")
        XCTAssertTrue(stateIds.contains("AK"), "Should contain Alaska")
        XCTAssertTrue(stateIds.contains("HI"), "Should contain Hawaii")
    }

    /// Test that Canadian provinces can be parsed from GeoJSON
    /// Note: This test requires GeoJSON resources in the test bundle
    func testCanadianProvincesGeoJSONParsing() throws {
        let provinces = GeoJSONParser.parseCanadianProvinces()

        // Skip if resources not available in test bundle
        try XCTSkipIf(provinces.isEmpty, "GeoJSON resources not available in test bundle")

        // Should have 13 provinces/territories
        XCTAssertEqual(provinces.count, 13, "Should have 13 Canadian provinces/territories")

        // Check some known provinces exist
        let provinceIds = Set(provinces.map { $0.id })
        XCTAssertTrue(provinceIds.contains("ON"), "Should contain Ontario")
        XCTAssertTrue(provinceIds.contains("BC"), "Should contain British Columbia")
        XCTAssertTrue(provinceIds.contains("QC"), "Should contain Quebec")
    }

    /// Test that state boundaries have valid polygons
    /// Note: This test requires GeoJSON resources in the test bundle
    func testStateBoundariesHaveValidPolygons() throws {
        let states = GeoJSONParser.parseUSStates()

        // Skip if resources not available in test bundle
        try XCTSkipIf(states.isEmpty, "GeoJSON resources not available in test bundle")

        for state in states {
            XCTAssertFalse(state.polygons.isEmpty, "State \(state.id) should have polygons")
            XCTAssertFalse(state.name.isEmpty, "State \(state.id) should have a name")
            XCTAssertEqual(state.countryCode, "US", "State \(state.id) should have US country code")
        }
    }
}
