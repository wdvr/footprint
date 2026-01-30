import CoreLocation
import Foundation
import MapKit

/// Utility for matching coordinates to countries/states using on-device GeoJSON boundaries.
/// Used as a fallback when reverse geocoding fails (e.g., for coastal locations).
@MainActor
final class GeoLocationMatcher {
    static let shared = GeoLocationMatcher()

    private var countryBoundaries: [GeoJSONParser.CountryBoundary] = []
    private var usStateBoundaries: [GeoJSONParser.StateBoundary] = []
    private var canadianProvinceBoundaries: [GeoJSONParser.StateBoundary] = []
    private var isLoaded = false

    private init() {}

    /// Load boundary data (call once at startup or before first use)
    func loadBoundariesIfNeeded() {
        guard !isLoaded else { return }

        countryBoundaries = GeoJSONParser.parseCountries()
        usStateBoundaries = GeoJSONParser.parseUSStates()
        canadianProvinceBoundaries = GeoJSONParser.parseCanadianProvinces()
        isLoaded = true

        print("[GeoLocationMatcher] Loaded \(countryBoundaries.count) countries, \(usStateBoundaries.count) US states, \(canadianProvinceBoundaries.count) CA provinces")
    }

    /// Result of a location match
    struct MatchResult {
        let countryCode: String
        let countryName: String
        let stateCode: String?
        let stateName: String?
    }

    /// Find which country (and optionally state) contains the given coordinate.
    /// This uses point-in-polygon testing against GeoJSON boundaries.
    /// - Parameter coordinate: The coordinate to match
    /// - Returns: MatchResult if found, nil if coordinate is not in any known boundary
    func matchCoordinate(_ coordinate: CLLocationCoordinate2D) -> MatchResult? {
        loadBoundariesIfNeeded()

        let mapPoint = MKMapPoint(coordinate)

        // First, check countries
        for country in countryBoundaries {
            if isPoint(mapPoint, inside: country.overlay) {
                // Found country, now check for state/province
                var stateCode: String?
                var stateName: String?

                if country.id == "US" {
                    for state in usStateBoundaries {
                        if isPoint(mapPoint, inside: state.overlay) {
                            stateCode = state.id
                            stateName = state.name
                            break
                        }
                    }
                } else if country.id == "CA" {
                    for province in canadianProvinceBoundaries {
                        if isPoint(mapPoint, inside: province.overlay) {
                            stateCode = province.id
                            stateName = province.name
                            break
                        }
                    }
                }

                return MatchResult(
                    countryCode: country.id,
                    countryName: country.name,
                    stateCode: stateCode,
                    stateName: stateName
                )
            }
        }

        return nil
    }

    /// Check if a point is inside a multi-polygon
    private nonisolated func isPoint(_ point: MKMapPoint, inside multiPolygon: MKMultiPolygon) -> Bool {
        for polygon in multiPolygon.polygons {
            if isPoint(point, insidePolygon: polygon) {
                return true
            }
        }
        return false
    }

    /// Check if a point is inside a polygon using ray-casting algorithm
    private nonisolated func isPoint(_ point: MKMapPoint, insidePolygon polygon: MKPolygon) -> Bool {
        let renderer = MKPolygonRenderer(polygon: polygon)
        let mapPoint = renderer.point(for: point)
        return renderer.path?.contains(mapPoint) ?? false
    }

    /// Find country with a tolerance buffer (useful for coastal locations).
    /// If the exact coordinate is not in any country, try nearby points.
    /// - Parameters:
    ///   - coordinate: The coordinate to match
    ///   - toleranceMeters: Distance in meters to search around the point
    /// - Returns: MatchResult if found within tolerance, nil otherwise
    func matchCoordinateWithTolerance(
        _ coordinate: CLLocationCoordinate2D,
        toleranceMeters: Double = 500
    ) -> MatchResult? {
        // First try exact match
        if let result = matchCoordinate(coordinate) {
            return result
        }

        // Try nearby points (N, S, E, W) at the tolerance distance
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(coordinate.latitude * .pi / 180)

        let latOffset = toleranceMeters / metersPerDegreeLatitude
        let lonOffset = toleranceMeters / metersPerDegreeLongitude

        let nearbyOffsets: [(Double, Double)] = [
            (latOffset, 0),      // North
            (-latOffset, 0),     // South
            (0, lonOffset),      // East
            (0, -lonOffset),     // West
            (latOffset, lonOffset),    // NE
            (latOffset, -lonOffset),   // NW
            (-latOffset, lonOffset),   // SE
            (-latOffset, -lonOffset),  // SW
        ]

        for (latOff, lonOff) in nearbyOffsets {
            let nearbyCoord = CLLocationCoordinate2D(
                latitude: coordinate.latitude + latOff,
                longitude: coordinate.longitude + lonOff
            )
            if let result = matchCoordinate(nearbyCoord) {
                return result
            }
        }

        return nil
    }
}
