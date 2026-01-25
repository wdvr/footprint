import CoreLocation
import Photos
import SwiftData
import SwiftUI

/// Represents a discovered location from the photo library
struct DiscoveredLocation: Identifiable, Hashable {
    let id = UUID()
    let regionType: VisitedPlace.RegionType
    let regionCode: String
    let regionName: String
    let photoCount: Int
    let earliestDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(regionType.rawValue)
        hasher.combine(regionCode)
    }

    static func == (lhs: DiscoveredLocation, rhs: DiscoveredLocation) -> Bool {
        lhs.regionType == rhs.regionType && lhs.regionCode == rhs.regionCode
    }
}

/// Manages importing location data from the Photos library
@MainActor
@Observable
final class PhotoImportManager {

    enum ImportState: Equatable {
        case idle
        case requestingPermission
        case scanning(progress: Double, photosProcessed: Int, totalPhotos: Int)
        case completed(locations: [DiscoveredLocation])
        case error(String)
    }

    var state: ImportState = .idle
    var authorizationStatus: PHAuthorizationStatus = .notDetermined

    private let geocoder = CLGeocoder()

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Request permission to access the photo library
    func requestPermission() async -> Bool {
        state = .requestingPermission

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status

        switch status {
        case .authorized, .limited:
            state = .idle
            return true
        case .denied, .restricted:
            state = .error("Photo library access denied. Please enable access in Settings.")
            return false
        case .notDetermined:
            state = .idle
            return false
        @unknown default:
            state = .idle
            return false
        }
    }

    /// Scan the photo library for locations
    func scanPhotoLibrary(existingPlaces: [VisitedPlace]) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            let granted = await requestPermission()
            if !granted { return }
        }

        state = .scanning(progress: 0, photosProcessed: 0, totalPhotos: 0)

        // Fetch all photos with location data
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "location != nil")
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalPhotos = assets.count

        if totalPhotos == 0 {
            state = .completed(locations: [])
            return
        }

        state = .scanning(progress: 0, photosProcessed: 0, totalPhotos: totalPhotos)

        // Track discovered locations with counts
        var locationCounts: [String: (type: VisitedPlace.RegionType, code: String, name: String, count: Int, earliestDate: Date?)] = [:]

        // Get existing place codes for filtering
        let existingCodes = Set(existingPlaces.filter { !$0.isDeleted }.map { "\($0.regionType):\($0.regionCode)" })

        // Process photos in batches to avoid overwhelming the geocoder
        let batchSize = 50
        var processedCount = 0

        // Sample photos if there are too many (geocoding is rate-limited)
        let maxPhotosToProcess = 500
        let sampleRate = totalPhotos > maxPhotosToProcess ? Double(maxPhotosToProcess) / Double(totalPhotos) : 1.0

        var photosToProcess: [(CLLocation, Date?)] = []

        assets.enumerateObjects { asset, index, _ in
            if let location = asset.location {
                // Sample if needed
                if sampleRate >= 1.0 || Double.random(in: 0...1) < sampleRate {
                    photosToProcess.append((location, asset.creationDate))
                }
            }
        }

        // Process sampled photos
        for (location, date) in photosToProcess {
            processedCount += 1

            // Update progress
            let progress = Double(processedCount) / Double(photosToProcess.count)
            state = .scanning(progress: progress, photosProcessed: processedCount, totalPhotos: photosToProcess.count)

            // Reverse geocode
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)

                if let placemark = placemarks.first, let countryCode = placemark.isoCountryCode {
                    // Check if country exists in our data
                    if let country = GeographicData.countries.first(where: { $0.id == countryCode }) {
                        let key = "country:\(countryCode)"
                        if !existingCodes.contains(key) {
                            var entry = locationCounts[key] ?? (.country, countryCode, country.name, 0, nil)
                            entry.count += 1
                            if let photoDate = date {
                                if entry.earliestDate == nil || photoDate < entry.earliestDate! {
                                    entry.earliestDate = photoDate
                                }
                            }
                            locationCounts[key] = entry
                        }
                    }

                    // Check for US states or Canadian provinces
                    if countryCode == "US" || countryCode == "CA" {
                        if let adminArea = placemark.administrativeArea {
                            let stateCode = stateNameToCode(adminArea, country: countryCode)
                            let regionType: VisitedPlace.RegionType = countryCode == "US" ? .usState : .canadianProvince
                            let key = "\(regionType.rawValue):\(stateCode)"

                            if !existingCodes.contains(key) {
                                let stateName = GeographicData.states(for: countryCode)
                                    .first { $0.id == stateCode }?.name ?? adminArea

                                var entry = locationCounts[key] ?? (regionType, stateCode, stateName, 0, nil)
                                entry.count += 1
                                if let photoDate = date {
                                    if entry.earliestDate == nil || photoDate < entry.earliestDate! {
                                        entry.earliestDate = photoDate
                                    }
                                }
                                locationCounts[key] = entry
                            }
                        }
                    }
                }

                // Small delay to avoid geocoder rate limiting
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms

            } catch {
                // Geocoding failed for this photo, continue with others
                continue
            }
        }

        // Convert to DiscoveredLocation array
        let discoveredLocations = locationCounts.values.map { entry in
            DiscoveredLocation(
                regionType: entry.type,
                regionCode: entry.code,
                regionName: entry.name,
                photoCount: entry.count,
                earliestDate: entry.earliestDate
            )
        }
        .sorted { lhs, rhs in
            // Sort by photo count descending
            lhs.photoCount > rhs.photoCount
        }

        state = .completed(locations: discoveredLocations)
    }

    /// Import selected locations as visited places
    func importLocations(_ locations: [DiscoveredLocation], into modelContext: ModelContext) {
        for location in locations {
            let place = VisitedPlace(
                regionType: location.regionType,
                regionCode: location.regionCode,
                regionName: location.regionName,
                visitedDate: location.earliestDate
            )
            modelContext.insert(place)
        }
    }

    /// Reset the import state
    func reset() {
        state = .idle
    }

    /// Convert state/province name to code
    private func stateNameToCode(_ name: String, country: String) -> String {
        // US States
        let usStates: [String: String] = [
            "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
            "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
            "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
            "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
            "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
            "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
            "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
            "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
            "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
            "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC",
            "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX", "Utah": "UT",
            "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
            "Wisconsin": "WI", "Wyoming": "WY", "District of Columbia": "DC"
        ]

        // Canadian Provinces
        let caProvinces: [String: String] = [
            "Alberta": "AB", "British Columbia": "BC", "Manitoba": "MB",
            "New Brunswick": "NB", "Newfoundland and Labrador": "NL",
            "Northwest Territories": "NT", "Nova Scotia": "NS", "Nunavut": "NU",
            "Ontario": "ON", "Prince Edward Island": "PE", "Quebec": "QC",
            "Saskatchewan": "SK", "Yukon": "YT"
        ]

        if country == "US" {
            return usStates[name] ?? name
        } else if country == "CA" {
            return caProvinces[name] ?? name
        }
        return name
    }
}
