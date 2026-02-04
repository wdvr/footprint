import CoreLocation
import Foundation
import MapKit

/// Thread-safe storage for loaded boundary data
/// Uses a class with nonisolated(unsafe) to allow concurrent read access after initial load
private final class BoundaryStorage: @unchecked Sendable {
    static let shared = BoundaryStorage()

    /// Countries that have state/province GeoJSON data available
    static let countriesWithStates = ["US", "CA", "RU", "FR", "DE", "ES", "IT", "NL", "BE", "GB", "AR"]

    // These are only written once during initialization, then read-only
    nonisolated(unsafe) private(set) var countryBoundaries: [GeoJSONParser.CountryBoundary] = []
    nonisolated(unsafe) private(set) var stateBoundariesByCountry: [String: [GeoJSONParser.StateBoundary]] = [:]
    nonisolated(unsafe) private(set) var isLoaded = false

    private let loadLock = NSLock()

    private init() {}

    /// Thread-safe boundary loading - only loads once
    func loadIfNeeded() {
        // Fast path: already loaded
        if isLoaded { return }

        // Slow path: acquire lock and load
        loadLock.lock()
        defer { loadLock.unlock() }

        // Double-check after acquiring lock
        if isLoaded { return }

        countryBoundaries = GeoJSONParser.parseCountries()

        // Load state boundaries for all countries that have them
        for countryCode in Self.countriesWithStates {
            let states = GeoJSONParser.parseStates(forCountry: countryCode)
            if !states.isEmpty {
                stateBoundariesByCountry[countryCode] = states
            }
        }

        isLoaded = true

        let totalStates = stateBoundariesByCountry.values.reduce(0) { $0 + $1.count }
        print("[GeoLocationMatcher] Loaded \(countryBoundaries.count) countries, \(totalStates) states/provinces across \(stateBoundariesByCountry.count) countries")
    }
}

/// Utility for matching coordinates to countries/states using on-device GeoJSON boundaries.
/// Used as a fallback when reverse geocoding fails (e.g., for coastal locations).
@MainActor
final class GeoLocationMatcher {
    static let shared = GeoLocationMatcher()

    private init() {}

    /// Load boundary data (call once at startup or before first use)
    func loadBoundariesIfNeeded() {
        BoundaryStorage.shared.loadIfNeeded()
    }

    /// Result of a location match
    struct MatchResult: Sendable {
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
        Self.matchCoordinateNonisolated(coordinate)
    }

    /// Nonisolated version for parallel processing
    static nonisolated func matchCoordinateNonisolated(_ coordinate: CLLocationCoordinate2D) -> MatchResult? {
        let storage = BoundaryStorage.shared
        storage.loadIfNeeded()

        let mapPoint = MKMapPoint(coordinate)

        // First, check countries
        for country in storage.countryBoundaries {
            if isPoint(mapPoint, inside: country.overlay) {
                // Found country, now check for state/province if available
                var stateCode: String?
                var stateName: String?

                if let stateBoundaries = storage.stateBoundariesByCountry[country.id] {
                    for state in stateBoundaries {
                        if isPoint(mapPoint, inside: state.overlay) {
                            stateCode = state.id
                            stateName = state.name
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
    private static nonisolated func isPoint(_ point: MKMapPoint, inside multiPolygon: MKMultiPolygon) -> Bool {
        for polygon in multiPolygon.polygons {
            if isPoint(point, insidePolygon: polygon) {
                return true
            }
        }
        return false
    }

    /// Check if a point is inside a polygon using ray-casting algorithm
    private static nonisolated func isPoint(_ point: MKMapPoint, insidePolygon polygon: MKPolygon) -> Bool {
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
        Self.matchCoordinateWithToleranceNonisolated(coordinate, toleranceMeters: toleranceMeters)
    }

    /// Nonisolated version for parallel processing - can be called from any thread
    static nonisolated func matchCoordinateWithToleranceNonisolated(
        _ coordinate: CLLocationCoordinate2D,
        toleranceMeters: Double = 500
    ) -> MatchResult? {
        // First try exact match
        if let result = matchCoordinateNonisolated(coordinate) {
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
            if let result = matchCoordinateNonisolated(nearbyCoord) {
                return result
            }
        }

        return nil
    }
}
