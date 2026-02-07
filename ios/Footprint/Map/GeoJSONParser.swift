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
            Log.geo.error("GeoJSON file not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let boundaries = try parseGeoJSON(data)
            Log.geo.debug("Loaded \(boundaries.count) country boundaries")
            return boundaries
        } catch {
            Log.geo.error("Error parsing GeoJSON: \(error)")
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

    // MARK: - State/Province Boundaries

    /// A parsed state/province with its polygon boundaries
    struct StateBoundary: Identifiable {
        let id: String  // State code (e.g., "CA", "TX", "ON")
        let name: String
        let countryCode: String
        let polygons: [MKPolygon]

        /// Create a single multi-polygon overlay for this state
        var overlay: MKMultiPolygon {
            MKMultiPolygon(polygons)
        }
    }

    /// Parse US states GeoJSON data from the app bundle
    static func parseUSStates() -> [StateBoundary] {
        let url = Bundle.main.url(
            forResource: "us_states",
            withExtension: "geojson",
            subdirectory: "GeoData"
        ) ?? Bundle.main.url(
            forResource: "us_states",
            withExtension: "geojson"
        )

        guard let url else {
            Log.geo.error("US states GeoJSON file not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let boundaries = try parseStateGeoJSON(data)
            Log.geo.debug("Loaded \(boundaries.count) US state boundaries")
            return boundaries
        } catch {
            Log.geo.error("Error parsing US states GeoJSON: \(error)")
            return []
        }
    }

    /// Parse Canadian provinces GeoJSON data from the app bundle
    static func parseCanadianProvinces() -> [StateBoundary] {
        let url = Bundle.main.url(
            forResource: "canadian_provinces",
            withExtension: "geojson",
            subdirectory: "GeoData"
        ) ?? Bundle.main.url(
            forResource: "canadian_provinces",
            withExtension: "geojson"
        )

        guard let url else {
            Log.geo.error("Canadian provinces GeoJSON file not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let boundaries = try parseStateGeoJSON(data)
            Log.geo.debug("Loaded \(boundaries.count) Canadian province boundaries")
            return boundaries
        } catch {
            Log.geo.error("Error parsing Canadian provinces GeoJSON: \(error)")
            return []
        }
    }

    /// Parse states/provinces for any country using the XX_states.geojson naming convention
    static func parseStates(forCountry countryCode: String) -> [StateBoundary] {
        // Map country codes to file names
        let fileName: String
        switch countryCode {
        case "US":
            return parseUSStates()
        case "CA":
            return parseCanadianProvinces()
        default:
            fileName = "\(countryCode)_states"
        }

        let url = Bundle.main.url(
            forResource: fileName,
            withExtension: "geojson",
            subdirectory: "GeoData"
        ) ?? Bundle.main.url(
            forResource: fileName,
            withExtension: "geojson"
        )

        guard let url else {
            Log.geo.error("\(countryCode) states GeoJSON file not found in bundle: \(fileName).geojson")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let boundaries = try parseStateGeoJSON(data)
            Log.geo.debug("Loaded \(boundaries.count) \(countryCode) state/province boundaries")
            return boundaries
        } catch {
            Log.geo.error("Error parsing \(countryCode) states GeoJSON: \(error)")
            return []
        }
    }

    /// Parse state/province GeoJSON data
    private static func parseStateGeoJSON(_ data: Data) throws -> [StateBoundary] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]]
        else {
            throw GeoJSONError.invalidFormat
        }

        var boundaries: [StateBoundary] = []

        for feature in features {
            guard let properties = feature["properties"] as? [String: Any],
                  let stateCode = properties["state_code"] as? String,
                  let name = properties["name"] as? String,
                  let countryCode = properties["country_code"] as? String,
                  let geometry = feature["geometry"] as? [String: Any]
            else {
                continue
            }

            let polygons = parseGeometry(geometry)

            if !polygons.isEmpty {
                boundaries.append(StateBoundary(
                    id: stateCode,
                    name: name,
                    countryCode: countryCode,
                    polygons: polygons
                ))
            }
        }

        return boundaries
    }
}
