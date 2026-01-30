import BackgroundTasks
import CoreLocation
import Photos
import SwiftData
import SwiftUI
import UserNotifications

/// Sample coordinate for debugging unmatched locations
struct UnmatchedCoordinate: Identifiable, Codable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let photoCount: Int

    init(latitude: Double, longitude: Double, photoCount: Int) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.photoCount = photoCount
    }
}

/// Statistics from a photo import scan for debugging
struct ImportStatistics: Codable, Equatable {
    var totalPhotosScanned: Int = 0
    var photosWithLocation: Int = 0
    var photosWithoutLocation: Int = 0
    var clustersCreated: Int = 0
    var clustersMatched: Int = 0
    var clustersUnmatched: Int = 0
    var unmatchedCoordinates: [UnmatchedCoordinate] = [] // Sample of unmatched (max 50)
    var countriesFound: [String: Int] = [:] // Country code -> photo count

    var photosInUnmatchedClusters: Int {
        unmatchedCoordinates.reduce(0) { $0 + $1.photoCount }
    }
}

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

/// Persisted cluster data for resume
private struct PersistedCluster: Codable {
    let gridKey: String
    let latitude: Double
    let longitude: Double
    var photoCount: Int
    var earliestDate: Date?

    func toPhotoCluster() -> PhotoCluster {
        PhotoCluster(
            gridKey: gridKey,
            representativeLocation: CLLocation(latitude: latitude, longitude: longitude),
            photoCount: photoCount,
            earliestDate: earliestDate
        )
    }

    init(from cluster: PhotoCluster) {
        self.gridKey = cluster.gridKey
        self.latitude = cluster.representativeLocation.coordinate.latitude
        self.longitude = cluster.representativeLocation.coordinate.longitude
        self.photoCount = cluster.photoCount
        self.earliestDate = cluster.earliestDate
    }
}

/// Persisted scan progress for resumption
private struct PhotoScanProgress: Codable {
    var processedGridKeys: Set<String>
    var discoveredLocations: [DiscoveredLocation]
    var totalClusters: Int
    var startedAt: Date
    var pendingClusters: [PersistedCluster]? // Clusters that still need geocoding
}

/// Manages importing location data from the Photos library
@MainActor
@Observable
final class PhotoImportManager: NSObject {

    static let backgroundTaskIdentifier = "com.wouterdevriendt.footprint.photo-import"
    private static let lastScannedPhotoDateKey = "lastScannedPhotoDate"

    /// Shared instance for background scanning support
    static let shared = PhotoImportManager()

    enum ImportState: Equatable {
        case idle
        case requestingPermission
        case collecting(photosProcessed: Int)
        case scanning(progress: Double, clustersProcessed: Int, totalClusters: Int, locationsFound: Int)
        case backgrounded(progress: Double, clustersProcessed: Int, totalClusters: Int, locationsFound: Int)
        case completed(locations: [DiscoveredLocation], totalFound: Int, alreadyVisited: Int, statistics: ImportStatistics)
        case error(String)
    }

    /// Dev mode: limit photos to process (0 = no limit)
    static var devPhotoLimit: Int = 0

    var state: ImportState = .idle
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var isRunningInBackground = false
    var isMinimized = false  // User dismissed but scan continues
    var totalPhotosToProcess = 0  // For progress display when minimized
    var hasPendingScan: Bool {
        loadScanProgress() != nil
    }

    /// Number of new photos detected since last scan
    var newPhotosAvailable: Int = 0

    // CLGeocoder is thread-safe internally
    nonisolated(unsafe) private let geocoder = CLGeocoder()
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var currentScanTask: Task<Void, Never>?
    private var isObservingPhotoLibrary = false

    // Grid cell size in degrees (~1km at equator, preserves city-level granularity)
    private let gridCellSize: Double = 0.009

    private let progressKey = "PhotoImportScanProgress"

    private override init() {
        super.init()
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Last date when photos were fully scanned
    var lastScannedPhotoDate: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastScannedPhotoDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastScannedPhotoDateKey) }
    }

    /// Start observing photo library for changes
    func startObservingPhotoLibrary() {
        guard !isObservingPhotoLibrary else { return }
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }

        PHPhotoLibrary.shared().register(self)
        isObservingPhotoLibrary = true
        print("[PhotoImport] Started observing photo library for changes")

        // Check for new photos immediately
        Task {
            await checkForNewPhotos()
        }
    }

    /// Stop observing photo library
    func stopObservingPhotoLibrary() {
        guard isObservingPhotoLibrary else { return }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        isObservingPhotoLibrary = false
    }

    /// Check how many new photos have been added since last scan
    func checkForNewPhotos() async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }

        let fetchOptions = PHFetchOptions()

        // Only fetch photos newer than last scan
        if let lastDate = lastScannedPhotoDate {
            fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastDate as NSDate)
        }

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        // Count only photos with location data
        var count = 0
        assets.enumerateObjects { asset, _, _ in
            if asset.location != nil {
                count += 1
            }
        }

        newPhotosAvailable = count
        print("[PhotoImport] Found \(count) new photos with location since last scan")
    }

    /// Minimize the import view while continuing scan
    func minimize() {
        isMinimized = true
    }

    /// Restore from minimized state
    func restore() {
        isMinimized = false
    }

    /// Register background task handler - call from app delegate
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            Task { @MainActor in
                guard let processingTask = task as? BGProcessingTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                await PhotoImportManager.handleBackgroundTask(processingTask)
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
        if case .scanning(let progress, let processed, let total, let locations) = state {
            state = .backgrounded(progress: progress, clustersProcessed: processed, totalClusters: total, locationsFound: locations)
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
        if case .backgrounded(let progress, let processed, let total, let locations) = state {
            state = .scanning(progress: progress, clustersProcessed: processed, totalClusters: total, locationsFound: locations)
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
            // Start observing for new photos
            startObservingPhotoLibrary()
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
    private nonisolated func gridKey(for coordinate: CLLocationCoordinate2D) -> String {
        let latCell = Int(floor(coordinate.latitude / gridCellSize))
        let lonCell = Int(floor(coordinate.longitude / gridCellSize))
        return "\(latCell),\(lonCell)"
    }

    /// Scan the photo library for locations using clustering
    /// - Parameter scanAllPhotos: If true, ignores lastScannedPhotoDate and scans all photos. Default is false (incremental scan).
    func scanPhotoLibrary(existingPlaces: [VisitedPlace], scanAllPhotos: Bool = false) async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            let granted = await requestPermission()
            if !granted { return }
            // After requesting permission, continue with the scan
            return await scanPhotoLibrary(existingPlaces: existingPlaces, scanAllPhotos: scanAllPhotos)
        }

        // Request notification permission for background updates
        await requestNotificationPermission()

        // Clear any previous progress
        clearScanProgress()

        state = .collecting(photosProcessed: 0)

        // Fetch photos - filter by date if this is an incremental scan
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // Only fetch photos newer than last scan (incremental scan) unless user requests full scan
        if !scanAllPhotos, let lastDate = lastScannedPhotoDate {
            fetchOptions.predicate = NSPredicate(format: "creationDate > %@", lastDate as NSDate)
            print("[PhotoImport] Incremental scan: only photos after \(lastDate)")
        } else {
            print("[PhotoImport] Full scan: processing all photos")
        }

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        var totalPhotos = assets.count

        // Apply dev limit if set
        if Self.devPhotoLimit > 0 {
            totalPhotos = min(totalPhotos, Self.devPhotoLimit)
            print("[PhotoImport] DEV MODE: Limiting to \(totalPhotos) photos")
        }

        totalPhotosToProcess = totalPhotos

        if totalPhotos == 0 {
            state = .completed(locations: [], totalFound: 0, alreadyVisited: 0, statistics: ImportStatistics())
            return
        }

        // Phase 1: Enumerate photos on background thread to avoid blocking UI
        let cellSize = self.gridCellSize
        let enumerationResult = await collectPhotoClusters(assets: assets, totalPhotos: totalPhotos, cellSize: cellSize)

        // Initialize statistics from enumeration
        var statistics = ImportStatistics()
        statistics.totalPhotosScanned = enumerationResult.totalPhotos
        statistics.photosWithLocation = enumerationResult.photosWithLocation
        statistics.photosWithoutLocation = enumerationResult.photosWithoutLocation
        statistics.clustersCreated = enumerationResult.clusters.count

        // Phase 2: Geocode unique clusters (much fewer API calls)
        await geocodeClusters(Array(enumerationResult.clusters.values), existingPlaces: existingPlaces, statistics: statistics)
    }

    /// Collect photo clusters on a background thread with progress updates
    private func collectPhotoClusters(
        assets: PHFetchResult<PHAsset>,
        totalPhotos: Int,
        cellSize: Double
    ) async -> EnumerationResult {
        // Use AsyncStream to receive progress updates from background thread
        let (stream, continuation) = AsyncStream.makeStream(of: (result: EnumerationResult?, progress: Int).self)

        // Start background enumeration
        Task.detached {
            await Self.enumeratePhotosInBackgroundWithProgress(
                assets: assets,
                totalPhotos: totalPhotos,
                cellSize: cellSize,
                progressCallback: { processed in
                    continuation.yield((result: nil, progress: processed))
                },
                completion: { result in
                    continuation.yield((result: result, progress: totalPhotos))
                    continuation.finish()
                }
            )
        }

        // Process stream and update UI
        var finalResult = EnumerationResult(clusters: [:], totalPhotos: 0, photosWithLocation: 0, photosWithoutLocation: 0)
        for await update in stream {
            if let result = update.result {
                finalResult = result
            } else {
                // Update progress on main actor
                state = .collecting(photosProcessed: update.progress)
            }
        }
        return finalResult
    }

    /// Result from photo enumeration including statistics
    private struct EnumerationResult: Sendable {
        let clusters: [String: PhotoCluster]
        let totalPhotos: Int
        let photosWithLocation: Int
        let photosWithoutLocation: Int
    }

    /// Nonisolated helper that runs photo enumeration on a background thread with progress updates
    private nonisolated static func enumeratePhotosInBackgroundWithProgress(
        assets: PHFetchResult<PHAsset>,
        totalPhotos: Int,
        cellSize: Double,
        progressCallback: @Sendable @escaping (Int) -> Void,
        completion: @Sendable @escaping (EnumerationResult) -> Void
    ) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var clusters: [String: PhotoCluster] = [:]
                var photosWithLocation = 0
                var processedTotal = 0

                // Use smaller batches for smoother progress updates
                let smallBatchSize = 100

                for batchStart in stride(from: 0, to: totalPhotos, by: smallBatchSize) {
                    let batchEnd = min(batchStart + smallBatchSize, totalPhotos)

                    autoreleasepool {
                        let range = NSRange(location: batchStart, length: batchEnd - batchStart)
                        let indices = IndexSet(integersIn: Range(range)!)

                        assets.enumerateObjects(at: indices, options: []) { asset, _, _ in
                            guard let location = asset.location else { return }
                            photosWithLocation += 1
                            let latCell = Int(floor(location.coordinate.latitude / cellSize))
                            let lonCell = Int(floor(location.coordinate.longitude / cellSize))
                            let key = "\(latCell),\(lonCell)"

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
                    }

                    // Update progress after each small batch - clean sequential updates
                    processedTotal = batchEnd
                    progressCallback(processedTotal)
                }

                let photosWithoutLocation = totalPhotos - photosWithLocation
                print("[PhotoImport] Enumeration complete: \(totalPhotos) photos, \(photosWithLocation) with location, \(photosWithoutLocation) without location, \(clusters.count) clusters")

                let result = EnumerationResult(
                    clusters: clusters,
                    totalPhotos: totalPhotos,
                    photosWithLocation: photosWithLocation,
                    photosWithoutLocation: photosWithoutLocation
                )
                completion(result)
                continuation.resume()
            }
        }
    }

    /// Resume a previously interrupted scan
    func resumeScan(existingPlaces: [VisitedPlace]) async {
        guard let progress = loadScanProgress() else {
            state = .idle
            return
        }

        // Request notification permission
        await requestNotificationPermission()

        // If we have saved clusters, use them directly (skip Phase 1)
        if let savedClusters = progress.pendingClusters, !savedClusters.isEmpty {
            print("[PhotoImport] Resuming with \(savedClusters.count) saved clusters (skipping photo enumeration)")
            let clusters = savedClusters.map { $0.toPhotoCluster() }
            await geocodeClusters(clusters, existingPlaces: existingPlaces, existingProgress: progress)
            return
        }

        // Fallback: Re-fetch photos and rebuild clusters (for older progress format)
        print("[PhotoImport] No saved clusters, re-enumerating photos...")
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let totalPhotos = assets.count

        state = .collecting(photosProcessed: 0)

        // Process in batches on background thread
        let cellSize = self.gridCellSize
        let processedGridKeys = progress.processedGridKeys
        let clusters = await collectPhotoClustersForResume(
            assets: assets,
            totalPhotos: totalPhotos,
            cellSize: cellSize,
            processedGridKeys: processedGridKeys
        )

        // Continue geocoding remaining clusters
        await geocodeClusters(
            Array(clusters.values),
            existingPlaces: existingPlaces,
            existingProgress: progress
        )
    }

    /// Collect photo clusters for resume on a background thread
    private func collectPhotoClustersForResume(
        assets: PHFetchResult<PHAsset>,
        totalPhotos: Int,
        cellSize: Double,
        processedGridKeys: Set<String>
    ) async -> [String: PhotoCluster] {
        await Self.enumeratePhotosForResumeInBackground(
            assets: assets,
            totalPhotos: totalPhotos,
            cellSize: cellSize,
            processedGridKeys: processedGridKeys
        )
    }

    /// Nonisolated helper for resume enumeration
    private nonisolated static func enumeratePhotosForResumeInBackground(
        assets: PHFetchResult<PHAsset>,
        totalPhotos: Int,
        cellSize: Double,
        processedGridKeys: Set<String>
    ) async -> [String: PhotoCluster] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var clusters: [String: PhotoCluster] = [:]
                let batchSize = 500

                for batchStart in stride(from: 0, to: totalPhotos, by: batchSize) {
                    autoreleasepool {
                        let batchEnd = min(batchStart + batchSize, totalPhotos)
                        let range = NSRange(location: batchStart, length: batchEnd - batchStart)
                        let indices = IndexSet(integersIn: Range(range)!)

                        assets.enumerateObjects(at: indices, options: []) { asset, _, _ in
                            guard let location = asset.location else { return }
                            let latCell = Int(floor(location.coordinate.latitude / cellSize))
                            let lonCell = Int(floor(location.coordinate.longitude / cellSize))
                            let key = "\(latCell),\(lonCell)"

                            // Skip already processed clusters
                            if processedGridKeys.contains(key) { return }

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
                    }
                }

                continuation.resume(returning: clusters)
            }
        }
    }

    /// Geocode clusters and discover locations
    private func geocodeClusters(
        _ clusters: [PhotoCluster],
        existingPlaces: [VisitedPlace],
        existingProgress: PhotoScanProgress? = nil,
        statistics: ImportStatistics = ImportStatistics()
    ) async {
        var stats = statistics
        let totalClusters = clusters.count + (existingProgress?.processedGridKeys.count ?? 0)

        print("[PhotoImport] Starting geocoding: \(clusters.count) clusters to process")

        if clusters.isEmpty {
            print("[PhotoImport] No clusters to geocode")
            let locations = existingProgress?.discoveredLocations ?? []
            state = .completed(locations: locations, totalFound: 0, alreadyVisited: 0, statistics: stats)
            clearScanProgress()
            if isRunningInBackground {
                showCompletionNotification(locationsFound: locations.count)
            }
            endBackgroundTask()
            return
        }

        // Save clusters immediately so resume can skip Phase 1 if interrupted
        if existingProgress == nil {
            saveScanProgress(PhotoScanProgress(
                processedGridKeys: [],
                discoveredLocations: [],
                totalClusters: totalClusters,
                startedAt: Date(),
                pendingClusters: clusters.map { PersistedCluster(from: $0) }
            ))
        }

        state = .scanning(
            progress: 0,
            clustersProcessed: existingProgress?.processedGridKeys.count ?? 0,
            totalClusters: totalClusters,
            locationsFound: 0
        )

        // Get existing place codes for filtering
        let existingCodes = Set(existingPlaces.filter { !$0.isDeleted }.map { "\($0.regionType):\($0.regionCode)" })
        print("[PhotoImport] Existing places to filter: \(existingCodes.count) - \(existingCodes)")

        // Track discovered locations (new ones only)
        var locationCounts: [String: (type: VisitedPlace.RegionType, code: String, name: String, count: Int, earliestDate: Date?)] = [:]

        // Track ALL found locations (including already visited) for stats
        var allFoundLocations: Set<String> = []
        var alreadyVisitedCount = 0

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
                    // Save remaining clusters for resume
                    let remainingClusters = clusters.filter { !processedGridKeys.contains($0.gridKey) }
                    saveScanProgress(PhotoScanProgress(
                        processedGridKeys: processedGridKeys,
                        discoveredLocations: buildDiscoveredLocations(from: locationCounts),
                        totalClusters: totalClusters,
                        startedAt: existingProgress?.startedAt ?? Date(),
                        pendingClusters: remainingClusters.map { PersistedCluster(from: $0) }
                    ))
                    return
                }

                processedCount += 1
                processedGridKeys.insert(cluster.gridKey)

                // Update progress
                let progress = Double(processedCount) / Double(totalClusters)
                let uniqueLocations = allFoundLocations.count
                if isRunningInBackground {
                    state = .backgrounded(progress: progress, clustersProcessed: processedCount, totalClusters: totalClusters, locationsFound: uniqueLocations)
                } else {
                    state = .scanning(progress: progress, clustersProcessed: processedCount, totalClusters: totalClusters, locationsFound: uniqueLocations)
                }

                // Geocode
                do {
                    let placemarks = try await geocoder.reverseGeocodeLocation(cluster.representativeLocation)

                    var countryCode: String?
                    var countryName: String?
                    var adminArea: String?

                    if let placemark = placemarks.first, let code = placemark.isoCountryCode {
                        countryCode = code
                        countryName = placemark.country
                        adminArea = placemark.administrativeArea
                    } else {
                        // Geocoding returned no country - try fallback boundary matching
                        // This handles coastal locations where the coordinate is slightly in the ocean
                        if let match = await GeoLocationMatcher.shared.matchCoordinateWithTolerance(
                            cluster.representativeLocation.coordinate,
                            toleranceMeters: 500
                        ) {
                            countryCode = match.countryCode
                            countryName = match.countryName
                            // Use state from boundary match if available
                            if let stateCode = match.stateCode {
                                adminArea = match.stateName
                            }
                            if processedCount <= 10 {
                                print("[PhotoImport] Fallback match for cluster \(processedCount): \(match.countryCode) - \(match.countryName)")
                            }
                        } else if processedCount <= 5 {
                            print("[PhotoImport] No country code from geocoder or boundary match")
                        }
                    }

                    if let countryCode = countryCode {
                        // Track as matched cluster
                        stats.clustersMatched += 1
                        stats.countriesFound[countryCode, default: 0] += cluster.photoCount

                        if processedCount <= 5 {
                            print("[PhotoImport] Geocoded cluster \(processedCount): \(countryCode) - \(countryName ?? "?")")
                        }
                        // Check if country exists in our data
                        if let country = GeographicData.countries.first(where: { $0.id == countryCode }) {
                            let key = "country:\(countryCode)"

                            // Track this as a found location
                            if !allFoundLocations.contains(key) {
                                allFoundLocations.insert(key)
                                if existingCodes.contains(key) {
                                    alreadyVisitedCount += 1
                                }
                            }

                            if !existingCodes.contains(key) {
                                var entry = locationCounts[key] ?? (.country, countryCode, country.name, 0, nil)
                                entry.count += cluster.photoCount
                                if let clusterDate = cluster.earliestDate {
                                    if entry.earliestDate == nil || clusterDate < entry.earliestDate! {
                                        entry.earliestDate = clusterDate
                                    }
                                }
                                locationCounts[key] = entry
                                if processedCount <= 5 {
                                    print("[PhotoImport] Added new location: \(country.name)")
                                }
                            } else if processedCount <= 5 {
                                print("[PhotoImport] Country \(countryCode) already exists, skipping")
                            }
                        } else if processedCount <= 5 {
                            print("[PhotoImport] Country \(countryCode) not found in GeographicData")
                        }

                        // Check for US states or Canadian provinces
                        if countryCode == "US" || countryCode == "CA" {
                            if let adminArea = adminArea {
                                let stateCode = stateNameToCode(adminArea, country: countryCode)
                                let regionType: VisitedPlace.RegionType = countryCode == "US" ? .usState : .canadianProvince
                                let key = "\(regionType.rawValue):\(stateCode)"

                                // Track this as a found location
                                if !allFoundLocations.contains(key) {
                                    allFoundLocations.insert(key)
                                    if existingCodes.contains(key) {
                                        alreadyVisitedCount += 1
                                    }
                                }

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
                    } else {
                        // Track as unmatched cluster
                        stats.clustersUnmatched += 1
                        if stats.unmatchedCoordinates.count < 50 {
                            stats.unmatchedCoordinates.append(UnmatchedCoordinate(
                                latitude: cluster.representativeLocation.coordinate.latitude,
                                longitude: cluster.representativeLocation.coordinate.longitude,
                                photoCount: cluster.photoCount
                            ))
                        }
                    }

                    // Small delay to avoid geocoder rate limiting
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms

                } catch {
                    // Geocoding failed - try fallback boundary matching
                    if let match = await GeoLocationMatcher.shared.matchCoordinateWithTolerance(
                        cluster.representativeLocation.coordinate,
                        toleranceMeters: 500
                    ) {
                        // Fallback matched
                        stats.clustersMatched += 1
                        stats.countriesFound[match.countryCode, default: 0] += cluster.photoCount

                        if let country = GeographicData.countries.first(where: { $0.id == match.countryCode }) {
                            let key = "country:\(match.countryCode)"

                            if !allFoundLocations.contains(key) {
                                allFoundLocations.insert(key)
                                if existingCodes.contains(key) {
                                    alreadyVisitedCount += 1
                                }
                            }

                            if !existingCodes.contains(key) {
                                var entry = locationCounts[key] ?? (.country, match.countryCode, country.name, 0, nil)
                                entry.count += cluster.photoCount
                                if let clusterDate = cluster.earliestDate {
                                    if entry.earliestDate == nil || clusterDate < entry.earliestDate! {
                                        entry.earliestDate = clusterDate
                                    }
                                }
                                locationCounts[key] = entry
                                print("[PhotoImport] Fallback added: \(country.name)")
                            }
                        }
                    } else {
                        // Both geocoding and fallback failed - track as unmatched
                        stats.clustersUnmatched += 1
                        if stats.unmatchedCoordinates.count < 50 {
                            stats.unmatchedCoordinates.append(UnmatchedCoordinate(
                                latitude: cluster.representativeLocation.coordinate.latitude,
                                longitude: cluster.representativeLocation.coordinate.longitude,
                                photoCount: cluster.photoCount
                            ))
                        }
                        if processedCount <= 5 {
                            print("[PhotoImport] Geocoding error for cluster \(processedCount): \(error)")
                        }
                    }
                    continue
                }

                // Save progress periodically (every 10 clusters)
                if processedCount % 10 == 0 {
                    // Calculate remaining clusters for resume
                    let remainingClusters = clusters.filter { !processedGridKeys.contains($0.gridKey) }
                    saveScanProgress(PhotoScanProgress(
                        processedGridKeys: processedGridKeys,
                        discoveredLocations: buildDiscoveredLocations(from: locationCounts),
                        totalClusters: totalClusters,
                        startedAt: existingProgress?.startedAt ?? Date(),
                        pendingClusters: remainingClusters.map { PersistedCluster(from: $0) }
                    ))
                }
            }

            // Complete
            let discoveredLocations = buildDiscoveredLocations(from: locationCounts)
            let totalFound = allFoundLocations.count
            print("[PhotoImport] Geocoding complete: \(totalFound) total locations found, \(alreadyVisitedCount) already visited, \(discoveredLocations.count) new")
            for loc in discoveredLocations.prefix(10) {
                print("[PhotoImport]   - \(loc.regionName) (\(loc.regionCode)): \(loc.photoCount) photos")
            }

            // Print statistics summary
            print("[PhotoImport] === STATISTICS ===")
            print("[PhotoImport] Total photos scanned: \(stats.totalPhotosScanned)")
            print("[PhotoImport] Photos with location: \(stats.photosWithLocation)")
            print("[PhotoImport] Photos without location: \(stats.photosWithoutLocation)")
            print("[PhotoImport] Clusters created: \(stats.clustersCreated)")
            print("[PhotoImport] Clusters matched to country: \(stats.clustersMatched)")
            print("[PhotoImport] Clusters unmatched (no country): \(stats.clustersUnmatched)")
            print("[PhotoImport] Photos in unmatched clusters: \(stats.photosInUnmatchedClusters)")
            if !stats.unmatchedCoordinates.isEmpty {
                print("[PhotoImport] Sample unmatched coordinates:")
                for coord in stats.unmatchedCoordinates.prefix(10) {
                    print("[PhotoImport]   (\(coord.latitude), \(coord.longitude)) - \(coord.photoCount) photos")
                }
            }
            print("[PhotoImport] Countries found: \(stats.countriesFound.sorted(by: { $0.value > $1.value }).prefix(10).map { "\($0.key): \($0.value)" }.joined(separator: ", "))")

            state = .completed(locations: discoveredLocations, totalFound: totalFound, alreadyVisited: alreadyVisitedCount, statistics: stats)
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

    private func saveScanProgress(_ progress: PhotoScanProgress) {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }

    private func loadScanProgress() -> PhotoScanProgress? {
        guard let data = UserDefaults.standard.data(forKey: progressKey),
              let progress = try? JSONDecoder().decode(PhotoScanProgress.self, from: data) else {
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
        // Save the last sync date and mark scan complete
        UserDefaults.standard.set(Date(), forKey: "lastPhotoSync")
        markScanComplete()

        // Schedule next periodic background scan
        schedulePeriodicBackgroundTask()
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

    /// Mark scan as complete and save the date
    func markScanComplete() {
        lastScannedPhotoDate = Date()
        newPhotosAvailable = 0
    }

    /// Schedule periodic background task for automatic photo monitoring
    func schedulePeriodicBackgroundTask() {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        let request = BGProcessingTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = true // Geocoding needs network
        request.requiresExternalPower = false
        // Schedule for early morning when user is likely asleep
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60) // 6 hours from now

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[PhotoImport] Scheduled periodic background task")
        } catch {
            print("[PhotoImport] Failed to schedule periodic task: \(error)")
        }
        #endif
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotoImportManager: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Check if new photos were added
        Task { @MainActor in
            await self.checkForNewPhotos()

            // If significant number of new photos, schedule background scan
            if self.newPhotosAvailable >= 5 {
                self.schedulePeriodicBackgroundTask()
            }
        }
    }
}
