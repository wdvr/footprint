import CoreLocation
import Foundation

/// Represents a cluster of photos at a geographic location for display on the map
struct PhotoLocation: Identifiable, Codable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    var photoCount: Int
    var earliestDate: Date?
    var countryCode: String?  // Made mutable for rematch
    var stateCode: String?    // State/province code (e.g., "CA", "ON")
    var regionName: String?   // Made mutable for rematch
    var photoAssetIDs: [String]  // Local identifiers of photos in this cluster
    let gridKey: String  // Grid cell key for merging clusters

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        photoCount: Int,
        earliestDate: Date? = nil,
        countryCode: String? = nil,
        stateCode: String? = nil,
        regionName: String? = nil,
        photoAssetIDs: [String] = [],
        gridKey: String = ""
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.photoCount = photoCount
        self.earliestDate = earliestDate
        self.countryCode = countryCode
        self.stateCode = stateCode
        self.regionName = regionName
        self.photoAssetIDs = photoAssetIDs
        self.gridKey = gridKey.isEmpty ? "\(Int(floor(latitude / 0.009))),\(Int(floor(longitude / 0.009)))" : gridKey
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

/// Result of rematching photo locations
struct RematchResult {
    var locationsProcessed: Int = 0
    var newMatches: Int = 0  // Previously unmatched, now matched
    var statesFound: Int = 0  // New states/provinces found
    var countriesFound: [String: Int] = [:]  // Country -> photo count
    var statesByCountry: [String: [String: Int]] = [:]  // Country -> state -> photo count
}

/// Manager for storing and retrieving photo locations
@MainActor
class PhotoLocationStore {
    static let shared = PhotoLocationStore()

    private let userDefaultsKey = "photoLocations"
    private let lastRematchVersionKey = "photoLocationLastRematchVersion"

    private init() {}

    /// Save photo locations to UserDefaults (overwrites existing)
    func save(_ locations: [PhotoLocation]) {
        if let encoded = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            let totalCount = totalPhotoCount
            Log.photoStore.debug("Saved \(locations.count) locations (\(totalCount) total photos)")
        }
    }

    /// Merge new photo locations with existing ones
    /// Locations with the same gridKey are combined (photo counts and IDs merged)
    func merge(_ newLocations: [PhotoLocation]) {
        var existingByGridKey: [String: PhotoLocation] = [:]
        for location in load() {
            existingByGridKey[location.gridKey] = location
        }

        // Merge new locations
        for newLocation in newLocations {
            if var existing = existingByGridKey[newLocation.gridKey] {
                // Merge: add photo count and IDs
                existing.photoCount += newLocation.photoCount
                existing.photoAssetIDs.append(contentsOf: newLocation.photoAssetIDs)
                // Keep earliest date
                if let newDate = newLocation.earliestDate {
                    if existing.earliestDate == nil || newDate < existing.earliestDate! {
                        existing.earliestDate = newDate
                    }
                }
                existingByGridKey[newLocation.gridKey] = existing
            } else {
                existingByGridKey[newLocation.gridKey] = newLocation
            }
        }

        let merged = Array(existingByGridKey.values)
        save(merged)
        Log.photoStore.debug("Merged \(newLocations.count) new locations, total: \(merged.count) locations")
    }

    /// Load photo locations from UserDefaults
    func load() -> [PhotoLocation] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let locations = try? JSONDecoder().decode([PhotoLocation].self, from: data)
        else {
            return []
        }
        return locations
    }

    /// Get photo location by grid key
    func location(forGridKey gridKey: String) -> PhotoLocation? {
        load().first { $0.gridKey == gridKey }
    }

    /// Clear stored photo locations
    func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// Get total photo count
    var totalPhotoCount: Int {
        load().reduce(0) { $0 + $1.photoCount }
    }

    /// Get location count
    var locationCount: Int {
        load().count
    }

    /// Get the last app version that performed a rematch
    var lastRematchVersion: String? {
        UserDefaults.standard.string(forKey: lastRematchVersionKey)
    }

    /// Check if rematch is needed (new app version with potentially new regions)
    func needsRematch(currentVersion: String) -> Bool {
        guard !load().isEmpty else { return false }
        return lastRematchVersion != currentVersion
    }

    /// Rematch all stored coordinates against current geographic data
    /// This allows finding new regions that were added in app updates
    /// Returns a result with statistics about what was found
    /// Uses 100m tolerance to catch beach/coastal photos
    func rematchAllCoordinates() async -> RematchResult {
        var result = RematchResult()
        var locations = load()
        result.locationsProcessed = locations.count

        Log.photoStore.info("Starting rematch of \(locations.count) locations with 100m coastal tolerance...")

        for i in 0..<locations.count {
            var location = locations[i]
            let coord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)

            // Try to match using GeoJSON boundaries with 100m tolerance for beach photos
            if let match = GeoLocationMatcher.matchCoordinateWithToleranceNonisolated(coord, toleranceMeters: 100) {
                let wasUnmatched = location.countryCode == nil
                let hadNoState = location.stateCode == nil

                location.countryCode = match.countryCode
                location.regionName = match.countryName

                if wasUnmatched {
                    result.newMatches += 1
                }

                // Track country
                result.countriesFound[match.countryCode, default: 0] += location.photoCount

                // Check for state/province
                if let stateCode = match.stateCode {
                    location.stateCode = stateCode
                    if hadNoState {
                        result.statesFound += 1
                    }
                    result.statesByCountry[match.countryCode, default: [:]][stateCode, default: 0] += location.photoCount
                }

                locations[i] = location
            }
        }

        // Save updated locations
        save(locations)

        // Mark this version as rematched
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        UserDefaults.standard.set(version, forKey: lastRematchVersionKey)

        // Track analytics
        AnalyticsService.shared.trackBoundaryReprocess(
            locationsProcessed: result.locationsProcessed,
            newCountryMatches: result.newMatches,
            newStateMatches: result.statesFound
        )

        Log.photoStore.info("Rematch complete: \(result.newMatches) new matches, \(result.statesFound) states found")
        return result
    }

    /// Get all unmatched locations (no country code)
    func unmatchedLocations() -> [PhotoLocation] {
        load().filter { $0.countryCode == nil }
    }

    /// Get locations by country
    func locations(forCountry countryCode: String) -> [PhotoLocation] {
        load().filter { $0.countryCode == countryCode }
    }

    /// Get locations by state
    func locations(forState stateCode: String, inCountry countryCode: String) -> [PhotoLocation] {
        load().filter { $0.countryCode == countryCode && $0.stateCode == stateCode }
    }

    /// Get summary statistics for all stored locations
    func getStatistics() -> (countries: [String: Int], states: [String: [String: Int]], unmatched: Int) {
        var countries: [String: Int] = [:]
        var states: [String: [String: Int]] = [:]
        var unmatched = 0

        for location in load() {
            if let country = location.countryCode {
                countries[country, default: 0] += location.photoCount
                if let state = location.stateCode {
                    states[country, default: [:]][state, default: 0] += location.photoCount
                }
            } else {
                unmatched += location.photoCount
            }
        }

        return (countries, states, unmatched)
    }
}
