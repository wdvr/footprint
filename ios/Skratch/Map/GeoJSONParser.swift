import CoreLocation
import Foundation
import MapKit

/// Parser for GeoJSON country boundary data
struct GeoJSONParser {
    /// A parsed country with its polygon boundaries
    struct CountryBoundary: Identifiable {
        let id: String  // ISO code
        let name: String
        let continent: String
        let polygons: [MKPolygon]

        /// Create a single multi-polygon overlay for this country
        var overlay: MKMultiPolygon {
            MKMultiPolygon(polygons)
        }
    }

    /// Parse GeoJSON data from the app bundle
    static func parseCountries() -> [CountryBoundary] {
        // Try with subdirectory first (folder reference), then without (group)
        let url = Bundle.main.url(
            forResource: "countries",
            withExtension: "geojson",
            subdirectory: "GeoData"
        ) ?? Bundle.main.url(
            forResource: "countries",
            withExtension: "geojson"
        )

        guard let url else {
            print("GeoJSON file not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let boundaries = try parseGeoJSON(data)
            print("Loaded \(boundaries.count) country boundaries")
            return boundaries
        } catch {
            print("Error parsing GeoJSON: \(error)")
            return []
        }
    }

    /// Parse GeoJSON data
    static func parseGeoJSON(_ data: Data) throws -> [CountryBoundary] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]]
        else {
            throw GeoJSONError.invalidFormat
        }

        var boundaries: [CountryBoundary] = []

        for feature in features {
            guard let properties = feature["properties"] as? [String: Any],
                  let isoCode = properties["iso_code"] as? String,
                  let name = properties["name"] as? String,
                  let geometry = feature["geometry"] as? [String: Any]
            else {
                continue
            }

            let continent = properties["continent"] as? String ?? ""
            let polygons = parseGeometry(geometry)

            if !polygons.isEmpty {
                boundaries.append(CountryBoundary(
                    id: isoCode,
                    name: name,
                    continent: continent,
                    polygons: polygons
                ))
            }
        }

        return boundaries
    }

    /// Parse geometry object into MKPolygons
    private static func parseGeometry(_ geometry: [String: Any]) -> [MKPolygon] {
        guard let type = geometry["type"] as? String,
              let coordinates = geometry["coordinates"] as? [Any]
        else {
            return []
        }

        switch type {
        case "Polygon":
            if let polygon = parsePolygon(coordinates as? [[[Double]]] ?? []) {
                return [polygon]
            }
            return []

        case "MultiPolygon":
            return (coordinates as? [[[[Double]]]] ?? []).compactMap { polygonCoords in
                parsePolygon(polygonCoords)
            }

        default:
            return []
        }
    }

    /// Parse a single polygon from coordinate arrays
    private static func parsePolygon(_ rings: [[[Double]]]) -> MKPolygon? {
        guard let exteriorRing = rings.first else { return nil }

        let exteriorCoords = exteriorRing.map { coord -> CLLocationCoordinate2D in
            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }

        guard exteriorCoords.count >= 3 else { return nil }

        // Handle interior rings (holes)
        if rings.count > 1 {
            let interiorPolygons = rings.dropFirst().compactMap { ring -> MKPolygon? in
                let coords = ring.map { coord -> CLLocationCoordinate2D in
                    CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
                guard coords.count >= 3 else { return nil }
                return MKPolygon(coordinates: coords, count: coords.count)
            }

            return MKPolygon(
                coordinates: exteriorCoords,
                count: exteriorCoords.count,
                interiorPolygons: interiorPolygons
            )
        }

        return MKPolygon(coordinates: exteriorCoords, count: exteriorCoords.count)
    }

    enum GeoJSONError: Error {
        case invalidFormat
        case fileNotFound
    }
}
