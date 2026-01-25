import BackgroundTasks
import CoreLocation
import Photos
import SwiftData
import SwiftUI
import UserNotifications

/// Represents a discovered location from the photo library
struct DiscoveredLocation: Identifiable, Hashable, Codable {
    let id: UUID
    let regionType: String
    let regionCode: String
    let regionName: String
    let photoCount: Int
    let earliestDate: Date?

    init(
        id: UUID = UUID(),
        regionType: VisitedPlace.RegionType,
        regionCode: String,
        regionName: String,
        photoCount: Int,
        earliestDate: Date?
    ) {
        self.id = id
        self.regionType = regionType.rawValue
        self.regionCode = regionCode
        self.regionName = regionName
        self.photoCount = photoCount
        self.earliestDate = earliestDate
    }

    var visitedPlaceRegionType: VisitedPlace.RegionType {
        VisitedPlace.RegionType(rawValue: regionType) ?? .country
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(regionType)
        hasher.combine(regionCode)
    }

    static func == (lhs: DiscoveredLocation, rhs: DiscoveredLocation) -> Bool {
        lhs.regionType == rhs.regionType && lhs.regionCode == rhs.regionCode
    }
}

/// Represents a cluster of photos in a geographic grid cell
private struct PhotoCluster {
    let gridKey: String
    let representativeLocation: CLLocation
    var photoCount: Int
    var earliestDate: Date?
}

/// Persisted scan progress for resumption
private struct ScanProgress: Codable {
    var processedGridKeys: Set<String>
    var discoveredLocations: [DiscoveredLocation]
    var totalClusters: Int
    var startedAt: Date
}

/// Manages importing location data from the Photos library
@MainActor
@Observable
final class PhotoImportManager {

    static let backgroundTaskIdentifier = "com.wd.footprint.photo-import"

    enum ImportState: Equatable {
        case idle
        case requestingPermission
        case collecting(photosProcessed: Int)
        case scanning(progress: Double, clustersProcessed: Int, totalClusters: Int)
        case backgrounded(progress: Double, clustersProcessed: Int, totalClusters: Int)
        case completed(locations: [DiscoveredLocation])
        case error(String)
    }

    var state: ImportState = .idle
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var isRunningInBackground = false
    var hasPendingScan: Bool {
        loadScanProgress() != nil
    }

    private let geocoder = CLGeocoder()
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var currentScanTask: Task<Void, Never>?

    // Grid cell size in degrees (~55km at equator)
    private let gridCellSize: Double = 0.5

    private let progressKey = "PhotoImportScanProgress"

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Register background task handler - call from app delegate
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                await PhotoImportManager.handleBackgroundTask(task as! BGProcessingTask)
            }
        }
    }

    /// Handle background processing task
    private static func handleBackgroundTask(_ task: BGProcessingTask) async {
        let manager = PhotoImportManager()

        task.expirationHandler = {
            manager.currentScanTask?.cancel()
        }

        // Resume scan if there's pending progress
        if manager.hasPendingScan {
            await manager.resumeScan(existingPlaces: [])
        }

        task.setTaskCompleted(success: !Task.isCancelled)
    }

    /// Schedule background processing task
    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = true // Geocoding needs network
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background task: \(error)")
        }
    }

    /// Check if currently scanning
    var isScanning: Bool {
        switch state {
        case .collecting, .scanning, .backgrounded:
            return true
        default:
            return false
        }
    }

    /// Request notification permission for background updates
    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Notifications not critical, continue without them
        }
    }

    /// Called when app enters background during scan
    func handleBackgroundTransition() {
        guard isScanning else { return }

        isRunningInBackground = true

        // Update state to show backgrounded
        if case .scanning(let progress, let processed, let total) = state {
            state = .backgrounded(progress: progress, clustersProcessed: processed, totalClusters: total)
        }

        // Start background task to get extended execution time
        beginBackgroundTask()

        // Schedule BGProcessingTask for longer background work
        scheduleBackgroundTask()

        // Show notification that import continues
        showBackgroundNotification()
    }

    /// Called when app returns to foreground
    func handleForegroundTransition() {
        isRunningInBackground = false

        // Update state back to scanning if we were backgrounded
        if case .backgrounded(let progress, let processed, let total) = state {
            state = .scanning(progress: progress, clustersProcessed: processed, totalClusters: total)
        }

        // Remove any pending notifications
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["photo-import-background"])
    }

    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "PhotoImport") { [weak self] in
            // Time expired - save progress and end task
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func showBackgroundNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Photo Import in Progress"
        content.body = "Scanning continues in the background. You'll be notified when complete."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "photo-import-background",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func showCompletionNotification(locationsFound: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Photo Import Complete"
        content.body = locationsFound > 0
            ? "Found \(locationsFound) new location\(locationsFound == 1 ? "" : "s") from your photos!"
            : "No new locations found in your photos."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "photo-import-complete",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
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

    /// Convert coordinate to grid key for clustering
    private func gridKey(for coordinate: CLLocationCoordinate2D) -> String {
        let latCell = Int(floor(coordinate.latitude / gridCellSize))
        let lonCell = Int(floor(coordinate.longitude / gridCellSize))
        return "\(latCell),\(lonCell)"
    }

    /// Scan the photo library for locations using clustering
    func scanPhotoLibrary(existingPlaces: [VisitedPlace]) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            let granted = await requestPermission()
            if !granted { return }
        }

        // Request notification permission for background updates
        await requestNotificationPermission()

        // Clear any previous progress
        clearScanProgress()

        state = .collecting(photosProcessed: 0)

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

        // Phase 1: Quick enumeration and clustering (very fast, no geocoding)
        var clusters: [String: PhotoCluster] = [:]
        var photosProcessed = 0

        assets.enumerateObjects { [self] asset, _, _ in
            photosProcessed += 1
            if photosProcessed % 1000 == 0 {
                // Update UI periodically during enumeration
                Task { @MainActor in
                    self.state = .collecting(photosProcessed: photosProcessed)
                }
            }

            guard let location = asset.location else { return }
            let key = self.gridKey(for: location.coordinate)

            if var existing = clusters[key] {
                existing.photoCount += 1
                if let date = asset.creationDate {
                    if existing.earliestDate == nil || date < existing.earliestDate! {
                        existing.earliestDate = date
                    }
                }
                clusters[key] = existing
            } else {
                clusters[key] = PhotoCluster(
                    gridKey: key,
                    representativeLocation: location,
                    photoCount: 1,
                    earliestDate: asset.creationDate
                )
            }
        }

        // Phase 2: Geocode unique clusters (much fewer API calls)
        await geocodeClusters(Array(clusters.values), existingPlaces: existingPlaces)
    }

    /// Resume a previously interrupted scan
    func resumeScan(existingPlaces: [VisitedPlace]) async {
        guard let progress = loadScanProgress() else {
            state = .idle
            return
        }

        // Request notification permission
        await requestNotificationPermission()

        // Re-fetch photos and rebuild clusters
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "location != nil")
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var clusters: [String: PhotoCluster] = [:]
        assets.enumerateObjects { [self] asset, _, _ in
            guard let location = asset.location else { return }
            let key = self.gridKey(for: location.coordinate)

            // Skip already processed clusters
            if progress.processedGridKeys.contains(key) { return }

            if var existing = clusters[key] {
                existing.photoCount += 1
                if let date = asset.creationDate {
                    if existing.earliestDate == nil || date < existing.earliestDate! {
                        existing.earliestDate = date
                    }
                }
                clusters[key] = existing
            } else {
                clusters[key] = PhotoCluster(
                    gridKey: key,
                    representativeLocation: location,
                    photoCount: 1,
                    earliestDate: asset.creationDate
                )
            }
        }

        // Continue geocoding remaining clusters
        await geocodeClusters(
            Array(clusters.values),
            existingPlaces: existingPlaces,
            existingProgress: progress
        )
    }

    /// Geocode clusters and discover locations
    private func geocodeClusters(
        _ clusters: [PhotoCluster],
        existingPlaces: [VisitedPlace],
        existingProgress: ScanProgress? = nil
    ) async {
        let totalClusters = clusters.count + (existingProgress?.processedGridKeys.count ?? 0)

        if clusters.isEmpty {
            let locations = existingProgress?.discoveredLocations ?? []
            state = .completed(locations: locations)
            clearScanProgress()
            if isRunningInBackground {
                showCompletionNotification(locationsFound: locations.count)
            }
            endBackgroundTask()
            return
        }

        state = .scanning(
            progress: 0,
            clustersProcessed: existingProgress?.processedGridKeys.count ?? 0,
            totalClusters: totalClusters
        )

        // Get existing place codes for filtering
        let existingCodes = Set(existingPlaces.filter { !$0.isDeleted }.map { "\($0.regionType):\($0.regionCode)" })

        // Track discovered locations
        var locationCounts: [String: (type: VisitedPlace.RegionType, code: String, name: String, count: Int, earliestDate: Date?)] = [:]

        // Restore previous discoveries
        if let progress = existingProgress {
            for location in progress.discoveredLocations {
                let key = "\(location.regionType):\(location.regionCode)"
                locationCounts[key] = (
                    location.visitedPlaceRegionType,
                    location.regionCode,
                    location.regionName,
                    location.photoCount,
                    location.earliestDate
                )
            }
        }

        var processedGridKeys = existingProgress?.processedGridKeys ?? Set<String>()
        var processedCount = processedGridKeys.count

        // Store task for cancellation support
        currentScanTask = Task {
            for cluster in clusters {
                // Check for cancellation
                if Task.isCancelled {
                    saveScanProgress(ScanProgress(
                        processedGridKeys: processedGridKeys,
                        discoveredLocations: buildDiscoveredLocations(from: locationCounts),
                        totalClusters: totalClusters,
                        startedAt: existingProgress?.startedAt ?? Date()
                    ))
                    return
                }

                processedCount += 1
                processedGridKeys.insert(cluster.gridKey)

                // Update progress
                let progress = Double(processedCount) / Double(totalClusters)
                if isRunningInBackground {
                    state = .backgrounded(progress: progress, clustersProcessed: processedCount, totalClusters: totalClusters)
                } else {
                    state = .scanning(progress: progress, clustersProcessed: processedCount, totalClusters: totalClusters)
                }

                // Geocode
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(cluster.representativeLocation)

                    if let placemark = placemarks.first, let countryCode = placemark.isoCountryCode {
                        // Check if country exists in our data
                        if let country = GeographicData.countries.first(where: { $0.id == countryCode }) {
                            let key = "country:\(countryCode)"
                            if !existingCodes.contains(key) {
                                var entry = locationCounts[key] ?? (.country, countryCode, country.name, 0, nil)
                                entry.count += cluster.photoCount
                                if let clusterDate = cluster.earliestDate {
                                    if entry.earliestDate == nil || clusterDate < entry.earliestDate! {
                                        entry.earliestDate = clusterDate
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
                                    entry.count += cluster.photoCount
                                    if let clusterDate = cluster.earliestDate {
                                        if entry.earliestDate == nil || clusterDate < entry.earliestDate! {
                                            entry.earliestDate = clusterDate
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
                    // Geocoding failed, continue with next cluster
                    continue
                }

                // Save progress periodically (every 10 clusters)
                if processedCount % 10 == 0 {
                    saveScanProgress(ScanProgress(
                        processedGridKeys: processedGridKeys,
                        discoveredLocations: buildDiscoveredLocations(from: locationCounts),
                        totalClusters: totalClusters,
                        startedAt: existingProgress?.startedAt ?? Date()
                    ))
                }
            }

            // Complete
            let discoveredLocations = buildDiscoveredLocations(from: locationCounts)
            state = .completed(locations: discoveredLocations)
            clearScanProgress()

            // Notify if in background
            endBackgroundTask()
            if isRunningInBackground {
                showCompletionNotification(locationsFound: discoveredLocations.count)
            }
            isRunningInBackground = false
        }

        await currentScanTask?.value
    }

    private func buildDiscoveredLocations(
        from locationCounts: [String: (type: VisitedPlace.RegionType, code: String, name: String, count: Int, earliestDate: Date?)]
    ) -> [DiscoveredLocation] {
        locationCounts.values.map { entry in
            DiscoveredLocation(
                regionType: entry.type,
                regionCode: entry.code,
                regionName: entry.name,
                photoCount: entry.count,
                earliestDate: entry.earliestDate
            )
        }
        .sorted { $0.photoCount > $1.photoCount }
    }

    // MARK: - Progress Persistence

    private func saveScanProgress(_ progress: ScanProgress) {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    private func loadScanProgress() -> ScanProgress? {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let progress = try? JSONDecoder().decode(ScanProgress.self, from: data) else {
            return nil
        }
        return progress
    }

    private func clearScanProgress() {
        UserDefaults.standard.removeObject(forKey: progressKey)
    }

    /// Import selected locations as visited places
    func importLocations(_ locations: [DiscoveredLocation], into modelContext: ModelContext) {
        for location in locations {
            let place = VisitedPlace(
                regionType: location.visitedPlaceRegionType,
                regionCode: location.regionCode,
                regionName: location.regionName,
                visitedDate: location.earliestDate
            )
            modelContext.insert(place)
        }
    }

    /// Reset the import state
    func reset() {
        currentScanTask?.cancel()
        currentScanTask = nil
        state = .idle
        isRunningInBackground = false
        clearScanProgress()
        endBackgroundTask()
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["photo-import-background", "photo-import-complete"]
        )
    }

    /// Convert state/province name to code
    private func stateNameToCode(_ name: String, country: String) -> String {
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
