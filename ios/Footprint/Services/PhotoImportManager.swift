import BackgroundTasks
import CoreLocation
import Photos
import SwiftData
import SwiftUI
import UserNotifications

/// Sample coordinate for debugging unmatched locations
struct UnmatchedCoordinate: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let photoCount: Int
    let photoAssetIDs: [String]  // Local identifiers of photos at this location

    init(latitude: Double, longitude: Double, photoCount: Int, photoAssetIDs: [String] = []) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.photoCount = photoCount
        self.photoAssetIDs = photoAssetIDs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Statistics from a photo import scan for debugging
struct ImportStatistics: Codable, Equatable {
    var totalPhotosScanned: Int = 0
    var photosWithLocation: Int = 0
    var photosWithoutLocation: Int = 0
    var photosSkipped: Int = 0  // Photos skipped because already processed (incremental scan)
    var totalPhotosInLibrary: Int = 0  // Total photos enumerated
    var clustersCreated: Int = 0
    var clustersMatched: Int = 0
    var clustersUnmatched: Int = 0
    var unmatchedCoordinates: [UnmatchedCoordinate] = [] // Sample of unmatched (max 50)
    var countriesFound: [String: Int] = [:] // Country code -> photo count
    var statesFound: [String: [String: Int]] = [:] // Country code -> (state code -> photo count)

    var photosInUnmatchedClusters: Int {
        unmatchedCoordinates.reduce(0) { $0 + $1.photoCount }
    }

    /// Whether this was an incremental scan that skipped photos
    var wasIncrementalScan: Bool {
        photosSkipped > 0
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
private struct PhotoCluster: Sendable {
    let gridKey: String
    let representativeLocation: CLLocation
    var photoCount: Int
    var earliestDate: Date?
    var photoAssetIDs: [String]  // Local identifiers of photos in this cluster
}

/// Result of geocoding a single cluster
private struct GeocodingResult: Sendable {
    let cluster: PhotoCluster
    let countryCode: String?
    let countryName: String?
    let adminArea: String?
    let stateCode: String?
    let matched: Bool  // True if geocoding or fallback found a match
}

/// Persisted cluster data for resume
private struct PersistedCluster: Codable {
    let gridKey: String
    let latitude: Double
    let longitude: Double
    var photoCount: Int
    var earliestDate: Date?
    var photoAssetIDs: [String]

    func toPhotoCluster() -> PhotoCluster {
        PhotoCluster(
            gridKey: gridKey,
            representativeLocation: CLLocation(latitude: latitude, longitude: longitude),
            photoCount: photoCount,
            earliestDate: earliestDate,
            photoAssetIDs: photoAssetIDs
        )
    }

    init(from cluster: PhotoCluster) {
        self.gridKey = cluster.gridKey
        self.latitude = cluster.representativeLocation.coordinate.latitude
        self.longitude = cluster.representativeLocation.coordinate.longitude
        self.photoCount = cluster.photoCount
        self.earliestDate = cluster.earliestDate
        self.photoAssetIDs = cluster.photoAssetIDs
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

    // Note: CLGeocoder instances can only process one request at a time.
    // We create a new instance per geocoding request to enable true parallelism.
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var currentScanTask: Task<Void, Never>?
    private var isObservingPhotoLibrary = false

    // Grid cell size in degrees (~1km at equator, preserves city-level granularity)
    private let gridCellSize: Double = 0.009

    // Concurrency limit for parallel geocoding (adjust based on foreground/background)
    private var geocodingConcurrencyLimit: Int {
        isRunningInBackground ? 3 : 10  // More aggressive when app is in foreground
    }

    private let progressKey = "PhotoImportScanProgress"
    private let processedPhotoIDsKey = "processedPhotoAssetIDs"

    // Cache for processed photo IDs (loaded lazily, saved periodically)
    private var _processedPhotoIDsCache: Set<String>?
    private var processedPhotoIDsDirty = false

    private override init() {
        super.init()
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Last date when photos were fully scanned (legacy, kept for migration)
    var lastScannedPhotoDate: Date? {
        get { UserDefaults.standard.object(forKey: Self.lastScannedPhotoDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastScannedPhotoDateKey) }
    }

    // MARK: - Processed Photo ID Tracking

    /// Get the set of processed photo IDs (uses localIdentifier for instant lookup)
    private var processedPhotoIDs: Set<String> {
        get {
            if let cache = _processedPhotoIDsCache {
                return cache
            }
            // Load from UserDefaults
            if let data = UserDefaults.standard.data(forKey: processedPhotoIDsKey) {
                do {
                    let ids = try JSONDecoder().decode(Set<String>.self, from: data)
                    _processedPhotoIDsCache = ids
                    print("[PhotoImport] Loaded \(ids.count) processed photo IDs from storage (\(data.count) bytes)")
                    return ids
                } catch {
                    print("[PhotoImport] ERROR: Failed to decode processed photo IDs: \(error)")
                    // Data is corrupted, clear it
                    UserDefaults.standard.removeObject(forKey: processedPhotoIDsKey)
                }
            } else {
                print("[PhotoImport] No processed photo IDs found in storage (first run or cleared)")
            }
            _processedPhotoIDsCache = Set()
            return Set()
        }
        set {
            _processedPhotoIDsCache = newValue
            processedPhotoIDsDirty = true
        }
    }

    /// Save processed photo IDs to UserDefaults (call periodically during import)
    private func saveProcessedPhotoIDs() {
        guard processedPhotoIDsDirty, let cache = _processedPhotoIDsCache else { return }
        do {
            let data = try JSONEncoder().encode(cache)
            UserDefaults.standard.set(data, forKey: processedPhotoIDsKey)
            processedPhotoIDsDirty = false
            print("[PhotoImport] Saved \(cache.count) processed photo IDs to storage (\(data.count) bytes)")
        } catch {
            print("[PhotoImport] ERROR: Failed to encode processed photo IDs: \(error)")
        }
    }

    /// Check if a photo has already been processed
    func hasProcessedPhoto(_ localIdentifier: String) -> Bool {
        processedPhotoIDs.contains(localIdentifier)
    }

    /// Mark photos as processed (batch operation for efficiency)
    private func markPhotosAsProcessed(_ localIdentifiers: [String]) {
        var ids = processedPhotoIDs
        for id in localIdentifiers {
            ids.insert(id)
        }
        processedPhotoIDs = ids
    }

    /// Clear all processed photo IDs (for full rescan)
    func clearProcessedPhotoIDs() {
        _processedPhotoIDsCache = Set()
        processedPhotoIDsDirty = true
        saveProcessedPhotoIDs()
        print("[PhotoImport] Cleared processed photo IDs")
    }

    /// Get count of processed photos
    var processedPhotoCount: Int {
        processedPhotoIDs.count
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

        let scanStartTime = Date()
        print("[PhotoImport] ========== SCAN STARTED ==========")

        // Fetch ALL photos - we use localIdentifier tracking instead of date filtering
        // This ensures photos with old EXIF dates (e.g., imported from camera) are still detected
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let fetchStartTime = Date()
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let fetchDuration = Date().timeIntervalSince(fetchStartTime)
        print("[PhotoImport] Photo library fetch took \(String(format: "%.2f", fetchDuration))s")

        // Get the set of already processed photo IDs for fast lookup
        let alreadyProcessedIDs = scanAllPhotos ? Set<String>() : processedPhotoIDs
        print("[PhotoImport] ========================================")
        print("[PhotoImport] SCAN MODE: \(scanAllPhotos ? "FULL SCAN" : "INCREMENTAL SCAN")")
        print("[PhotoImport] Total photos in library: \(assets.count)")
        print("[PhotoImport] Previously tracked photo count: \(processedPhotoCount)")
        print("[PhotoImport] IDs loaded for skip check: \(alreadyProcessedIDs.count)")
        if scanAllPhotos {
            print("[PhotoImport] Full scan requested - will process all photos regardless of previous scans")
        } else {
            if alreadyProcessedIDs.isEmpty {
                print("[PhotoImport] ⚠️ WARNING: No previously processed photos found!")
                print("[PhotoImport] This is expected for first-time scans.")
                print("[PhotoImport] If this is NOT your first scan, processedPhotoIDs may not be persisting correctly.")
                // Debug: Check if the UserDefaults key exists
                if let data = UserDefaults.standard.data(forKey: processedPhotoIDsKey) {
                    print("[PhotoImport] DEBUG: UserDefaults has data for key (\(data.count) bytes) but loaded 0 IDs")
                } else {
                    print("[PhotoImport] DEBUG: UserDefaults has no data for key '\(processedPhotoIDsKey)'")
                }
            } else {
                print("[PhotoImport] ✓ Will skip \(alreadyProcessedIDs.count) previously processed photos")
            }
        }
        print("[PhotoImport] ========================================")
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
        print("[PhotoImport] Phase 1: Starting photo enumeration...")
        let enumerationStartTime = Date()
        let cellSize = self.gridCellSize
        let enumerationResult = await collectPhotoClusters(
            assets: assets,
            totalPhotos: totalPhotos,
            cellSize: cellSize,
            alreadyProcessedIDs: alreadyProcessedIDs
        )
        let enumerationDuration = Date().timeIntervalSince(enumerationStartTime)
        print("[PhotoImport] Phase 1 complete: \(String(format: "%.2f", enumerationDuration))s - \(enumerationResult.clusters.count) clusters from \(enumerationResult.photosWithLocation) photos with location (skipped \(enumerationResult.skippedAlreadyProcessed) already processed)")

        // Log incremental scan effectiveness
        if !scanAllPhotos && enumerationResult.skippedAlreadyProcessed > 0 {
            let percentSkipped = Double(enumerationResult.skippedAlreadyProcessed) / Double(enumerationResult.totalPhotosEnumerated) * 100
            print("[PhotoImport] INCREMENTAL SCAN: Skipped \(enumerationResult.skippedAlreadyProcessed) of \(enumerationResult.totalPhotosEnumerated) photos (\(String(format: "%.1f", percentSkipped))%) - only \(enumerationResult.newPhotoIDs.count) new photos to process")
        } else if !scanAllPhotos && alreadyProcessedIDs.isEmpty {
            print("[PhotoImport] INCREMENTAL SCAN: No previously processed photos found - this appears to be the first scan")
        }

        // Mark newly processed photos as done
        if !enumerationResult.newPhotoIDs.isEmpty {
            markPhotosAsProcessed(enumerationResult.newPhotoIDs)
            saveProcessedPhotoIDs()
            print("[PhotoImport] Marked \(enumerationResult.newPhotoIDs.count) new photos as processed (total tracked: \(processedPhotoCount))")
        } else {
            print("[PhotoImport] No new photos to mark as processed")
        }

        // Initialize statistics from enumeration
        var statistics = ImportStatistics()
        statistics.totalPhotosScanned = enumerationResult.totalPhotos
        statistics.photosWithLocation = enumerationResult.photosWithLocation
        statistics.photosWithoutLocation = enumerationResult.photosWithoutLocation
        statistics.photosSkipped = enumerationResult.skippedAlreadyProcessed
        statistics.totalPhotosInLibrary = enumerationResult.totalPhotosEnumerated
        statistics.clustersCreated = enumerationResult.clusters.count

        // Phase 2: Geocode unique clusters (much fewer API calls)
        print("[PhotoImport] Phase 2: Starting geocoding of \(enumerationResult.clusters.count) clusters (concurrency: \(geocodingConcurrencyLimit))...")
        let geocodingStartTime = Date()
        await geocodeClusters(Array(enumerationResult.clusters.values), existingPlaces: existingPlaces, statistics: statistics)
        let geocodingDuration = Date().timeIntervalSince(geocodingStartTime)
        let totalDuration = Date().timeIntervalSince(scanStartTime)
        print("[PhotoImport] Phase 2 complete: \(String(format: "%.2f", geocodingDuration))s")
        print("[PhotoImport] ========== SCAN COMPLETE: \(String(format: "%.2f", totalDuration))s total ==========")
    }

    /// Collect photo clusters on a background thread with progress updates
    private func collectPhotoClusters(
        assets: PHFetchResult<PHAsset>,
        totalPhotos: Int,
        cellSize: Double,
        alreadyProcessedIDs: Set<String>
    ) async -> EnumerationResult {
        // Use AsyncStream to receive progress updates from background thread
        let (stream, continuation) = AsyncStream.makeStream(of: (result: EnumerationResult?, progress: Int).self)

        // Start background enumeration
        Task.detached {
            await Self.enumeratePhotosInBackgroundWithProgress(
                assets: assets,
                totalPhotos: totalPhotos,
                cellSize: cellSize,
                alreadyProcessedIDs: alreadyProcessedIDs,
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
        var finalResult = EnumerationResult(clusters: [:], totalPhotos: 0, photosWithLocation: 0, photosWithoutLocation: 0, newPhotoIDs: [], skippedAlreadyProcessed: 0, totalPhotosEnumerated: 0)
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
        let newPhotoIDs: [String]  // IDs of newly processed photos (for tracking)
        let skippedAlreadyProcessed: Int  // Count of photos skipped because already processed
        let totalPhotosEnumerated: Int  // Total photos we iterated through (including skipped)
    }

    /// Nonisolated helper that runs photo enumeration on a background thread with progress updates
    /// Uses parallel processing for faster enumeration of large photo libraries
    private nonisolated static func enumeratePhotosInBackgroundWithProgress(
        assets: PHFetchResult<PHAsset>,
        totalPhotos: Int,
        cellSize: Double,
        alreadyProcessedIDs: Set<String>,
        progressCallback: @Sendable @escaping (Int) -> Void,
        completion: @Sendable @escaping (EnumerationResult) -> Void
    ) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Use a concurrent queue for parallel batch processing
            let processingQueue = DispatchQueue(label: "photo.enumeration", qos: .userInitiated, attributes: .concurrent)
            let resultQueue = DispatchQueue(label: "photo.results", qos: .userInitiated)

            // Determine batch size and count
            let batchSize = 1000
            let batchCount = (totalPhotos + batchSize - 1) / batchSize

            print("[PhotoImport] Parallel enumeration: \(totalPhotos) photos in \(batchCount) batches of \(batchSize)")

            // Thread-safe containers for results
            var clusters: [String: PhotoCluster] = [:]
            var photosWithLocation = 0
            var newPhotoIDs: [String] = []
            var skippedCount = 0
            var completedBatches = 0

            let group = DispatchGroup()

            for batchIndex in 0..<batchCount {
                group.enter()
                processingQueue.async {
                    let batchStart = batchIndex * batchSize
                    let batchEnd = min(batchStart + batchSize, totalPhotos)

                    // Local results for this batch
                    var localClusters: [String: PhotoCluster] = [:]
                    var localPhotosWithLocation = 0
                    var localNewPhotoIDs: [String] = []
                    var localSkippedCount = 0

                    autoreleasepool {
                        let range = NSRange(location: batchStart, length: batchEnd - batchStart)
                        let indices = IndexSet(integersIn: Range(range)!)

                        assets.enumerateObjects(at: indices, options: []) { asset, _, _ in
                            // Skip already processed photos (fast O(1) lookup)
                            if alreadyProcessedIDs.contains(asset.localIdentifier) {
                                localSkippedCount += 1
                                return
                            }

                            // Track this photo as newly processed
                            localNewPhotoIDs.append(asset.localIdentifier)

                            guard let location = asset.location else { return }
                            localPhotosWithLocation += 1
                            let latCell = Int(floor(location.coordinate.latitude / cellSize))
                            let lonCell = Int(floor(location.coordinate.longitude / cellSize))
                            let key = "\(latCell),\(lonCell)"

                            if var existing = localClusters[key] {
                                existing.photoCount += 1
                                existing.photoAssetIDs.append(asset.localIdentifier)
                                if let date = asset.creationDate {
                                    if existing.earliestDate == nil || date < existing.earliestDate! {
                                        existing.earliestDate = date
                                    }
                                }
                                localClusters[key] = existing
                            } else {
                                localClusters[key] = PhotoCluster(
                                    gridKey: key,
                                    representativeLocation: location,
                                    photoCount: 1,
                                    earliestDate: asset.creationDate,
                                    photoAssetIDs: [asset.localIdentifier]
                                )
                            }
                        }
                    }

                    // Merge results on the result queue (serial for thread safety)
                    resultQueue.async {
                        for (key, localCluster) in localClusters {
                            if var existing = clusters[key] {
                                existing.photoCount += localCluster.photoCount
                                existing.photoAssetIDs.append(contentsOf: localCluster.photoAssetIDs)
                                if let localDate = localCluster.earliestDate {
                                    if existing.earliestDate == nil || localDate < existing.earliestDate! {
                                        existing.earliestDate = localDate
                                    }
                                }
                                clusters[key] = existing
                            } else {
                                clusters[key] = localCluster
                            }
                        }
                        photosWithLocation += localPhotosWithLocation
                        newPhotoIDs.append(contentsOf: localNewPhotoIDs)
                        skippedCount += localSkippedCount
                        completedBatches += 1

                        // Report progress
                        let processedPhotos = min(completedBatches * batchSize, totalPhotos)
                        progressCallback(processedPhotos)

                        group.leave()
                    }
                }
            }

            // Wait for all batches to complete
            group.notify(queue: resultQueue) {
                let photosWithoutLocation = newPhotoIDs.count - photosWithLocation
                print("[PhotoImport] Parallel enumeration complete: \(totalPhotos) total photos, \(skippedCount) skipped (already processed), \(newPhotoIDs.count) new, \(photosWithLocation) with location, \(clusters.count) clusters")

                let result = EnumerationResult(
                    clusters: clusters,
                    totalPhotos: newPhotoIDs.count,
                    photosWithLocation: photosWithLocation,
                    photosWithoutLocation: photosWithoutLocation,
                    newPhotoIDs: newPhotoIDs,
                    skippedAlreadyProcessed: skippedCount,
                    totalPhotosEnumerated: totalPhotos
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
                                existing.photoAssetIDs.append(asset.localIdentifier)
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
                                    earliestDate: asset.creationDate,
                                    photoAssetIDs: [asset.localIdentifier]
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

        // Collect all photo locations for map display
        var photoLocations: [PhotoLocation] = []

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

        // Parallel geocoding helper
        let concurrencyLimit = geocodingConcurrencyLimit
        print("[PhotoImport] Using parallel geocoding with concurrency limit: \(concurrencyLimit)")

        // Store task for cancellation support
        currentScanTask = Task {
            // Process clusters in parallel batches
            var clusterIndex = 0
            while clusterIndex < clusters.count {
                // Check for cancellation
                if Task.isCancelled {
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

                // Get the next batch of clusters to process in parallel
                let batchEnd = min(clusterIndex + concurrencyLimit, clusters.count)
                let batch = Array(clusters[clusterIndex..<batchEnd])

                // Geocode batch in parallel using TaskGroup
                let results = await withTaskGroup(of: GeocodingResult.self, returning: [GeocodingResult].self) { group in
                    for cluster in batch {
                        group.addTask {
                            await self.geocodeSingleCluster(cluster)
                        }
                    }

                    var batchResults: [GeocodingResult] = []
                    for await result in group {
                        batchResults.append(result)
                    }
                    return batchResults
                }

                // Process results sequentially (for thread-safe state updates)
                for result in results {
                    let cluster = result.cluster
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

                    // Process geocoding result
                    if let countryCode = result.countryCode {
                        // Track as matched cluster
                        stats.clustersMatched += 1
                        stats.countriesFound[countryCode, default: 0] += cluster.photoCount

                        if processedCount <= 5 {
                            print("[PhotoImport] Geocoded cluster \(processedCount): \(countryCode) - \(result.countryName ?? "?")")
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
                            }
                        }

                        // Check for states/provinces - works for all countries with state data
                        // For US/CA: use adminArea from geocoding, convert to code
                        // For other countries: use stateCode from GeoJSON boundary matching
                        var stateCode: String?
                        if countryCode == "US" || countryCode == "CA" {
                            if let adminArea = result.adminArea {
                                stateCode = stateNameToCode(adminArea, country: countryCode)
                            }
                        } else if let boundaryStateCode = result.stateCode {
                            // Use state code from GeoJSON boundary matching
                            stateCode = boundaryStateCode
                        }

                        if let stateCode = stateCode {
                            // Track state for statistics
                            stats.statesFound[countryCode, default: [:]][stateCode, default: 0] += cluster.photoCount

                            // Get region type for this country
                            let regionType = regionTypeForState(country: countryCode)
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
                                    .first { $0.id == stateCode }?.name ?? result.adminArea ?? stateCode

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

                        // Save photo location for map display
                        photoLocations.append(PhotoLocation(
                            latitude: cluster.representativeLocation.coordinate.latitude,
                            longitude: cluster.representativeLocation.coordinate.longitude,
                            photoCount: cluster.photoCount,
                            earliestDate: cluster.earliestDate,
                            countryCode: countryCode,
                            regionName: result.countryName,
                            photoAssetIDs: cluster.photoAssetIDs,
                            gridKey: cluster.gridKey
                        ))
                    } else {
                        // Track as unmatched cluster
                        stats.clustersUnmatched += 1
                        if stats.unmatchedCoordinates.count < 50 {
                            stats.unmatchedCoordinates.append(UnmatchedCoordinate(
                                latitude: cluster.representativeLocation.coordinate.latitude,
                                longitude: cluster.representativeLocation.coordinate.longitude,
                                photoCount: cluster.photoCount,
                                photoAssetIDs: Array(cluster.photoAssetIDs.prefix(10))  // Store up to 10 photo IDs per location
                            ))
                        }
                        // Still save location for map (without country info)
                        photoLocations.append(PhotoLocation(
                            latitude: cluster.representativeLocation.coordinate.latitude,
                            longitude: cluster.representativeLocation.coordinate.longitude,
                            photoCount: cluster.photoCount,
                            earliestDate: cluster.earliestDate,
                            countryCode: nil,
                            regionName: nil,
                            photoAssetIDs: cluster.photoAssetIDs,
                            gridKey: cluster.gridKey
                        ))
                    }
                }

                clusterIndex = batchEnd

                // Log progress every 50 clusters or at completion
                let progressPercent = Int((Double(processedCount) / Double(totalClusters)) * 100)
                if processedCount % 50 == 0 || processedCount == totalClusters {
                    print("[PhotoImport] Geocoding progress: \(processedCount)/\(totalClusters) clusters (\(progressPercent)%) - \(allFoundLocations.count) locations found")
                }

                // Save progress periodically (every batch)
                let remainingClusters = clusters.filter { !processedGridKeys.contains($0.gridKey) }
                saveScanProgress(PhotoScanProgress(
                    processedGridKeys: processedGridKeys,
                    discoveredLocations: buildDiscoveredLocations(from: locationCounts),
                    totalClusters: totalClusters,
                    startedAt: existingProgress?.startedAt ?? Date(),
                    pendingClusters: remainingClusters.map { PersistedCluster(from: $0) }
                ))
            }

            // Complete
            let discoveredLocations = buildDiscoveredLocations(from: locationCounts)
            let totalFound = allFoundLocations.count
            print("[PhotoImport] Geocoding complete: \(totalFound) total locations found, \(alreadyVisitedCount) already visited, \(discoveredLocations.count) new")
            for loc in discoveredLocations.prefix(10) {
                print("[PhotoImport]   - \(loc.regionName) (\(loc.regionCode)): \(loc.photoCount) photos")
            }

            // Mark scan complete (this enables delta scanning for future scans)
            markScanComplete()

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

            // Merge photo locations with existing ones for map display
            PhotoLocationStore.shared.merge(photoLocations)
            print("[PhotoImport] Merged \(photoLocations.count) photo locations for map display (total: \(PhotoLocationStore.shared.locationCount) locations, \(PhotoLocationStore.shared.totalPhotoCount) photos)")

            state = .completed(locations: discoveredLocations, totalFound: totalFound, alreadyVisited: alreadyVisitedCount, statistics: stats)
            clearScanProgress()

            // Track analytics
            AnalyticsService.shared.trackPhotoScanCompleted(
                photosScanned: stats.totalPhotosScanned,
                photosWithLocation: stats.photosWithLocation,
                countriesFound: stats.countriesFound.count,
                statesFound: stats.statesFound.values.reduce(0) { $0 + $1.count },
                locationsImported: discoveredLocations.count
            )

            // Notify if in background
            endBackgroundTask()
            if isRunningInBackground {
                showCompletionNotification(locationsFound: discoveredLocations.count)
            }
            isRunningInBackground = false
        }

        await currentScanTask?.value
    }

    /// Geocode a single cluster and return the result
    /// This is designed to be called in parallel from a TaskGroup
    /// IMPORTANT: This method is nonisolated to enable true parallel execution
    private nonisolated func geocodeSingleCluster(_ cluster: PhotoCluster) async -> GeocodingResult {
        var countryCode: String?
        var countryName: String?
        var adminArea: String?
        var stateCode: String?
        var matched = false

        // Create a new CLGeocoder instance for this request.
        // CLGeocoder can only process one request at a time per instance,
        // so sharing a single instance across parallel tasks would cause
        // requests to cancel each other.
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(cluster.representativeLocation)

            if let placemark = placemarks.first, let code = placemark.isoCountryCode {
                countryCode = code
                countryName = placemark.country
                adminArea = placemark.administrativeArea
                matched = true
            } else {
                // Geocoding returned no country - try fallback boundary matching
                if let match = GeoLocationMatcher.matchCoordinateWithToleranceNonisolated(
                    cluster.representativeLocation.coordinate,
                    toleranceMeters: 500
                ) {
                    countryCode = match.countryCode
                    countryName = match.countryName
                    stateCode = match.stateCode
                    if match.stateCode != nil {
                        adminArea = match.stateName
                    }
                    matched = true
                }
            }
        } catch {
            // Geocoding failed - try fallback boundary matching
            if let match = GeoLocationMatcher.matchCoordinateWithToleranceNonisolated(
                cluster.representativeLocation.coordinate,
                toleranceMeters: 500
            ) {
                countryCode = match.countryCode
                countryName = match.countryName
                stateCode = match.stateCode
                if match.stateCode != nil {
                    adminArea = match.stateName
                }
                matched = true
            }
        }

        return GeocodingResult(
            cluster: cluster,
            countryCode: countryCode,
            countryName: countryName,
            adminArea: adminArea,
            stateCode: stateCode,
            matched: matched
        )
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

    /// Get the region type for a state/province based on country
    private func regionTypeForState(country: String) -> VisitedPlace.RegionType {
        switch country {
        case "US": return .usState
        case "CA": return .canadianProvince
        case "AU": return .australianState
        case "MX": return .mexicanState
        case "BR": return .brazilianState
        case "DE": return .germanState
        case "FR": return .frenchRegion
        case "ES": return .spanishCommunity
        case "IT": return .italianRegion
        case "NL": return .dutchProvince
        case "BE": return .belgianProvince
        case "GB": return .ukCountry
        case "RU": return .russianFederalSubject
        case "AR": return .argentineProvince
        default: return .country  // Fallback, shouldn't happen
        }
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
