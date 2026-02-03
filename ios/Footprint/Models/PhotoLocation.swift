import CoreLocation
import Foundation

/// Represents a cluster of photos at a geographic location for display on the map
struct PhotoLocation: Identifiable, Codable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    var photoCount: Int
    var earliestDate: Date?
    let countryCode: String?
    let regionName: String?
    var photoAssetIDs: [String]  // Local identifiers of photos in this cluster
    let gridKey: String  // Grid cell key for merging clusters

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        photoCount: Int,
        earliestDate: Date? = nil,
        countryCode: String? = nil,
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

/// Manager for storing and retrieving photo locations
@MainActor
class PhotoLocationStore {
    static let shared = PhotoLocationStore()

    private let userDefaultsKey = "photoLocations"

    private init() {}

    /// Save photo locations to UserDefaults (overwrites existing)
    func save(_ locations: [PhotoLocation]) {
        if let encoded = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("[PhotoLocationStore] Saved \(locations.count) locations (\(totalPhotoCount) total photos)")
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
        print("[PhotoLocationStore] Merged \(newLocations.count) new locations, total: \(merged.count) locations")
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
}
