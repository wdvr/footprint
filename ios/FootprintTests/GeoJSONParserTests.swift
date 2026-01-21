import CoreLocation
import MapKit
import XCTest

@testable import Footprint

final class GeoJSONParserTests: XCTestCase {

    // MARK: - Bundle Loading Tests

    func testParseCountriesFromBundle() {
        // This test verifies the GeoJSON file is properly included in the bundle
        let boundaries = GeoJSONParser.parseCountries()

        // Should load countries from the bundle
        XCTAssertGreaterThan(boundaries.count, 0, "Should load at least some countries from bundle")

        // If we have the full dataset, should have ~177 countries
        if boundaries.count > 100 {
            XCTAssertGreaterThan(boundaries.count, 150, "Should have most world countries")
        }
    }

    func testParsedCountriesHaveRequiredFields() {
        let boundaries = GeoJSONParser.parseCountries()

        // Skip if bundle loading failed (tested separately)
        guard !boundaries.isEmpty else { return }

        for boundary in boundaries.prefix(10) {
            // Each boundary should have valid data
            XCTAssertFalse(boundary.id.isEmpty, "Country should have ISO code")
            XCTAssertFalse(boundary.name.isEmpty, "Country should have name")
            XCTAssertFalse(boundary.polygons.isEmpty, "Country should have at least one polygon")
        }
    }

    func testParsedCountriesHaveValidPolygons() {
        let boundaries = GeoJSONParser.parseCountries()

        guard !boundaries.isEmpty else { return }

        for boundary in boundaries.prefix(10) {
            for polygon in boundary.polygons {
                XCTAssertGreaterThanOrEqual(
                    polygon.pointCount, 3,
                    "Polygon should have at least 3 points for \(boundary.name)"
                )
            }
        }
    }

    // MARK: - GeoJSON Parsing Tests

    func testParseValidPolygonGeoJSON() throws {
        let geoJSON = """
        {
            "type": "FeatureCollection",
            "features": [{
                "type": "Feature",
                "properties": {
                    "iso_code": "XX",
                    "name": "Test Country",
                    "continent": "Test Continent"
                },
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]
                }
            }]
        }
        """

        let data = geoJSON.data(using: .utf8)!
        let boundaries = try GeoJSONParser.parseGeoJSON(data)

        XCTAssertEqual(boundaries.count, 1)
        XCTAssertEqual(boundaries[0].id, "XX")
        XCTAssertEqual(boundaries[0].name, "Test Country")
        XCTAssertEqual(boundaries[0].continent, "Test Continent")
        XCTAssertEqual(boundaries[0].polygons.count, 1)
        XCTAssertEqual(boundaries[0].polygons[0].pointCount, 5)
    }

    func testParseMultiPolygonGeoJSON() throws {
        let geoJSON = """
        {
            "type": "FeatureCollection",
            "features": [{
                "type": "Feature",
                "properties": {
                    "iso_code": "YY",
                    "name": "Island Nation",
                    "continent": "Oceania"
                },
                "geometry": {
                    "type": "MultiPolygon",
                    "coordinates": [
                        [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]],
                        [[[5, 5], [6, 5], [6, 6], [5, 6], [5, 5]]]
                    ]
                }
            }]
        }
        """

        let data = geoJSON.data(using: .utf8)!
        let boundaries = try GeoJSONParser.parseGeoJSON(data)

        XCTAssertEqual(boundaries.count, 1)
        XCTAssertEqual(boundaries[0].id, "YY")
        XCTAssertEqual(boundaries[0].polygons.count, 2, "Should have two separate polygons")
    }

    func testParsePolygonWithHoles() throws {
        // Polygon with interior ring (hole)
        let geoJSON = """
        {
            "type": "FeatureCollection",
            "features": [{
                "type": "Feature",
                "properties": {
                    "iso_code": "ZZ",
                    "name": "Donut Country",
                    "continent": "Test"
                },
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [
                        [[0, 0], [10, 0], [10, 10], [0, 10], [0, 0]],
                        [[2, 2], [8, 2], [8, 8], [2, 8], [2, 2]]
                    ]
                }
            }]
        }
        """

        let data = geoJSON.data(using: .utf8)!
        let boundaries = try GeoJSONParser.parseGeoJSON(data)

        XCTAssertEqual(boundaries.count, 1)
        XCTAssertEqual(boundaries[0].polygons.count, 1)

        let polygon = boundaries[0].polygons[0]
        XCTAssertEqual(polygon.interiorPolygons?.count, 1, "Should have one interior ring (hole)")
    }

    func testParseSkipsInvalidFeatures() throws {
        let geoJSON = """
        {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {"name": "No ISO Code"},
                    "geometry": {"type": "Polygon", "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 0]]]}
                },
                {
                    "type": "Feature",
                    "properties": {"iso_code": "OK", "name": "Valid Country"},
                    "geometry": {"type": "Polygon", "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 0]]]}
                },
                {
                    "type": "Feature",
                    "properties": {"iso_code": "NG"},
                    "geometry": {"type": "Polygon", "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 0]]]}
                }
            ]
        }
        """

        let data = geoJSON.data(using: .utf8)!
        let boundaries = try GeoJSONParser.parseGeoJSON(data)

        // Should only have the valid one with both iso_code and name
        XCTAssertEqual(boundaries.count, 1)
        XCTAssertEqual(boundaries[0].id, "OK")
    }

    func testParseInvalidJSONThrows() {
        let invalidJSON = "not valid json".data(using: .utf8)!

        XCTAssertThrowsError(try GeoJSONParser.parseGeoJSON(invalidJSON))
    }

    func testParseEmptyFeaturesReturnsEmpty() throws {
        let geoJSON = """
        {
            "type": "FeatureCollection",
            "features": []
        }
        """

        let data = geoJSON.data(using: .utf8)!
        let boundaries = try GeoJSONParser.parseGeoJSON(data)

        XCTAssertTrue(boundaries.isEmpty)
    }

    // MARK: - Overlay Creation Tests

    func testCountryBoundaryOverlayCreation() throws {
        let geoJSON = """
        {
            "type": "FeatureCollection",
            "features": [{
                "type": "Feature",
                "properties": {"iso_code": "US", "name": "United States", "continent": "North America"},
                "geometry": {
                    "type": "MultiPolygon",
                    "coordinates": [
                        [[[0, 0], [1, 0], [1, 1], [0, 0]]],
                        [[[2, 2], [3, 2], [3, 3], [2, 2]]]
                    ]
                }
            }]
        }
        """

        let data = geoJSON.data(using: .utf8)!
        let boundaries = try GeoJSONParser.parseGeoJSON(data)

        XCTAssertEqual(boundaries.count, 1)

        let overlay = boundaries[0].overlay
        XCTAssertTrue(overlay is MKMultiPolygon)
    }

    // MARK: - Coordinate Parsing Tests

    func testCoordinatesAreParsedCorrectly() throws {
        let geoJSON = """
        {
            "type": "FeatureCollection",
            "features": [{
                "type": "Feature",
                "properties": {"iso_code": "PT", "name": "Point Test", "continent": "Test"},
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[[-122.4, 37.8], [-122.4, 37.9], [-122.3, 37.9], [-122.3, 37.8], [-122.4, 37.8]]]
                }
            }]
        }
        """

        let data = geoJSON.data(using: .utf8)!
        let boundaries = try GeoJSONParser.parseGeoJSON(data)

        XCTAssertEqual(boundaries.count, 1)

        let polygon = boundaries[0].polygons[0]
        var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polygon.pointCount)
        polygon.getCoordinates(&coords, range: NSRange(location: 0, length: polygon.pointCount))

        // GeoJSON is [longitude, latitude], MapKit expects (latitude, longitude)
        // First point should be approximately lat: 37.8, lon: -122.4
        XCTAssertEqual(coords[0].latitude, 37.8, accuracy: 0.01)
        XCTAssertEqual(coords[0].longitude, -122.4, accuracy: 0.01)
    }
}
