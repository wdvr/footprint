import CoreLocation
import Foundation

/// Represents a cluster of photos at a geographic location for display on the map
struct PhotoLocation: Identifiable, Codable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let photoCount: Int
    let earliestDate: Date?
    let countryCode: String?
    let regionName: String?

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        photoCount: Int,
        earliestDate: Date? = nil,
        countryCode: String? = nil,
        regionName: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.photoCount = photoCount
        self.earliestDate = earliestDate
        self.countryCode = countryCode
        self.regionName = regionName
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

    /// Save photo locations to UserDefaults
    func save(_ locations: [PhotoLocation]) {
        if let encoded = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
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

    /// Clear stored photo locations
    func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// Get total photo count
    var totalPhotoCount: Int {
        load().reduce(0) { $0 + $1.photoCount }
    }
}
