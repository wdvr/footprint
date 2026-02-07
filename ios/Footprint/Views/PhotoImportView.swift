import MapKit
import Photos
import SwiftData
import SwiftUI

/// View for importing locations from the photo library
struct PhotoImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<VisitedPlace> { !$0.isDeleted })
    private var existingPlaces: [VisitedPlace]

    private var importManager: PhotoImportManager { PhotoImportManager.shared }
    @State private var selectedLocations: Set<DiscoveredLocation> = []
    @State private var showImportConfirmation = false

    var body: some View {
        NavigationStack {
            VStack {
                switch importManager.state {
                case .idle:
                    IdleView(
                        onStartScan: startScan,
                        onFullRescan: startFullRescan,
                        hasPendingScan: importManager.hasPendingScan,
                        hasCompletedScanBefore: importManager.lastScannedPhotoDate != nil || importManager.processedPhotoCount > 0,
                        onResume: resumeScan
                    )

                case .requestingPermission:
                    PermissionRequestView()

                case .collecting(let photosProcessed):
                    CollectingView(
                        photosProcessed: photosProcessed,
                        totalPhotos: importManager.totalPhotosToProcess,
                        onMinimize: minimizeAndDismiss
                    )

                case .scanning(let progress, let processed, let total, let locationsFound):
                    ScanningView(progress: progress, processed: processed, total: total, locationsFound: locationsFound, isBackgrounded: false, onMinimize: minimizeAndDismiss)

                case .backgrounded(let progress, let processed, let total, let locationsFound):
                    ScanningView(progress: progress, processed: processed, total: total, locationsFound: locationsFound, isBackgrounded: true, onMinimize: minimizeAndDismiss)

                case .completed(let locations, let totalFound, let alreadyVisited, let statistics):
                    if locations.isEmpty {
                        NoLocationsFoundView(
                            totalFound: totalFound,
                            alreadyVisited: alreadyVisited,
                            statistics: statistics,
                            onDismiss: {
                                importManager.reset()
                                dismiss()
                            }
                        )
                    } else {
                        LocationsListView(
                            locations: locations,
                            totalFound: totalFound,
                            alreadyVisited: alreadyVisited,
                            statistics: statistics,
                            selectedLocations: $selectedLocations,
                            onImport: { showImportConfirmation = true }
                        )
                    }

                case .error(let message):
                    ErrorView(message: message, onRetry: startScan, onDismiss: { dismiss() })
                }
            }
            .navigationTitle("Import from Photos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if importManager.isScanning {
                        Button("Minimize") {
                            minimizeAndDismiss()
                        }
                    } else {
                        Button("Cancel") {
                            importManager.reset()
                            dismiss()
                        }
                    }
                }
            }
            .alert("Import Locations", isPresented: $showImportConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Import") {
                    importSelectedLocations()
                }
            } message: {
                Text("Add \(selectedLocations.count) location\(selectedLocations.count == 1 ? "" : "s") to your visited places?")
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background && importManager.isScanning {
                    importManager.handleBackgroundTransition()
                } else if newPhase == .active && importManager.isRunningInBackground {
                    importManager.handleForegroundTransition()
                }
            }
            .onAppear {
                // Restore from minimized state when view appears
                importManager.restore()
            }
        }
    }

    private func minimizeAndDismiss() {
        importManager.minimize()
        dismiss()
    }

    private func startScan() {
        Task {
            await importManager.scanPhotoLibrary(existingPlaces: existingPlaces, scanAllPhotos: false)

            // Auto-select all discovered locations
            if case .completed(let locations, _, _, _) = importManager.state {
                selectedLocations = Set(locations)
            }
        }
    }

    private func startFullRescan() {
        Task {
            await importManager.scanPhotoLibrary(existingPlaces: existingPlaces, scanAllPhotos: true)

            // Auto-select all discovered locations
            if case .completed(let locations, _, _, _) = importManager.state {
                selectedLocations = Set(locations)
            }
        }
    }

    private func resumeScan() {
        Task {
            await importManager.resumeScan(existingPlaces: existingPlaces)

            // Auto-select all discovered locations
            if case .completed(let locations, _, _, _) = importManager.state {
                selectedLocations = Set(locations)
            }
        }
    }

    private func importSelectedLocations() {
        importManager.importLocations(Array(selectedLocations), into: modelContext)
        dismiss()
    }
}

// MARK: - Idle State View

private struct IdleView: View {
    let onStartScan: () -> Void
    let onFullRescan: () -> Void
    let hasPendingScan: Bool
    let hasCompletedScanBefore: Bool
    let onResume: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Scan Photo Library")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Footprint can scan your photos to discover places you've visited based on location data embedded in your photos.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.green)
                    Text("All processing happens on your device")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "icloud.slash")
                        .foregroundStyle(.green)
                    Text("No photos are uploaded to any server")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                if hasPendingScan {
                    Button(action: onResume) {
                        Label("Resume Previous Scan", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.tint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button(action: onStartScan) {
                        Text("Start New Scan")
                            .font(.subheadline)
                    }
                } else if hasCompletedScanBefore {
                    // User has scanned before - offer incremental scan as primary
                    Button(action: onStartScan) {
                        Label("Scan New Photos", systemImage: "plus.magnifyingglass")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.tint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Show how many photos are already tracked
                    let trackedCount = PhotoImportManager.shared.processedPhotoCount
                    if trackedCount > 0 {
                        Text("\(trackedCount.formatted()) photos already scanned")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: onFullRescan) {
                        Text("Full Rescan (All Photos)")
                            .font(.subheadline)
                    }
                } else {
                    // First time scan
                    Button(action: onStartScan) {
                        Label("Start Scan", systemImage: "magnifyingglass")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.tint)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Collecting View (Phase 1: Enumerating photos)

private struct CollectingView: View {
    let photosProcessed: Int
    let totalPhotos: Int
    let onMinimize: () -> Void

    @State private var displayedCount: Int = 0
    @State private var animationTimer: Timer?

    private var progress: Double {
        guard totalPhotos > 0 else { return 0 }
        return min(1.0, Double(displayedCount) / Double(totalPhotos))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.2)
                    .foregroundStyle(.tint)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)

                VStack {
                    Text("\(Int(progress * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                    Text("\(displayedCount.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .frame(width: 120, height: 120)

            VStack(spacing: 8) {
                Text("Checking Photos...")
                    .font(.headline)

                Text("Checking \(displayedCount.formatted()) of \(totalPhotos.formatted()) photos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                Text("Finding new photos to process")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onMinimize) {
                Label("Continue in Background", systemImage: "arrow.down.right.square")
                    .font(.subheadline)
            }
            .padding(.bottom, 24)
        }
        .onChange(of: photosProcessed) { _, newValue in
            animateToValue(newValue)
        }
        .onAppear {
            displayedCount = photosProcessed
        }
    }

    private func animateToValue(_ target: Int) {
        // Calculate steps to animate smoothly
        let difference = target - displayedCount
        guard difference > 0 else {
            displayedCount = target
            return
        }

        // Animate quickly - roughly 50 updates to reach target
        let steps = min(difference, 50)
        let increment = max(1, difference / steps)

        // Cancel any existing animation
        animationTimer?.invalidate()
        animationTimer = nil

        // Use Task-based animation for Swift 6 concurrency compatibility
        Task { @MainActor in
            while displayedCount < target {
                displayedCount = min(displayedCount + increment, target)
                try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            }
        }
    }
}

// MARK: - Permission Request View

private struct PermissionRequestView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Requesting Photo Access...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

// MARK: - Scanning View

private struct ScanningView: View {
    let progress: Double
    let processed: Int
    let total: Int
    let locationsFound: Int
    let isBackgrounded: Bool
    let onMinimize: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.2)
                    .foregroundStyle(.tint)

                Circle()
                    .trim(from: 0, to: min(1.0, progress))
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: progress)

                VStack {
                    Text("\(Int(min(100, progress * 100)))%")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("\(processed)/\(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Scanning progress: \(Int(min(100, progress * 100))) percent, \(processed) of \(total) photos scanned")

            VStack(spacing: 8) {
                Text("Scanning Photos...")
                    .font(.headline)

                if locationsFound > 0 {
                    Text("\(locationsFound) unique location\(locationsFound == 1 ? "" : "s") detected")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                } else {
                    Text("Analyzing location data from your photos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Background mode indicator
            if isBackgrounded {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.orange)
                        Text("Continuing in background...")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    Text("You'll be notified when complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else {
                // Tip about background processing
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Keep app open for faster scanning")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }

            Spacer()

            Button(action: onMinimize) {
                Label("Continue in Background", systemImage: "arrow.down.right.square")
                    .font(.subheadline)
            }
            .padding(.bottom, 24)
        }
    }
}

// MARK: - No Locations Found View

private struct NoLocationsFoundView: View {
    let totalFound: Int
    let alreadyVisited: Int
    let statistics: ImportStatistics
    let onDismiss: () -> Void
    @State private var showingStats = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 40)

                    Image(systemName: "photo.badge.checkmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    VStack(spacing: 12) {
                        if totalFound > 0 {
                            Text("All Caught Up!")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Found \(totalFound) location\(totalFound == 1 ? "" : "s") in your photos, but \(alreadyVisited == totalFound ? "all" : "\(alreadyVisited)") \(alreadyVisited == 1 ? "is" : "are") already in your visited places.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        } else {
                            Text("No Locations Found")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Your photos don't contain location data, or the locations couldn't be identified.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }

                    // Statistics summary
                    Button {
                        showingStats.toggle()
                    } label: {
                        Label("View Scan Details", systemImage: showingStats ? "chevron.up" : "chevron.down")
                            .font(.subheadline)
                    }

                    if showingStats {
                        StatisticsView(statistics: statistics)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 24)
                }
            }

            Button("Done", action: onDismiss)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
    }
}

// MARK: - Locations List View

private struct LocationsListView: View {
    let locations: [DiscoveredLocation]
    let totalFound: Int
    let alreadyVisited: Int
    let statistics: ImportStatistics
    @Binding var selectedLocations: Set<DiscoveredLocation>
    let onImport: () -> Void
    @State private var showingStats = false

    private var countries: [DiscoveredLocation] {
        locations.filter { $0.regionType == VisitedPlace.RegionType.country.rawValue }
    }

    private var states: [DiscoveredLocation] {
        locations.filter {
            $0.regionType == VisitedPlace.RegionType.usState.rawValue ||
            $0.regionType == VisitedPlace.RegionType.canadianProvince.rawValue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Found \(locations.count) New Location\(locations.count == 1 ? "" : "s")")
                    .font(.headline)

                if alreadyVisited > 0 {
                    Text("\(totalFound) total found, \(alreadyVisited) already visited")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Select the places you want to add")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()

            // Selection controls
            HStack {
                Button("Select All") {
                    selectedLocations = Set(locations)
                }
                .font(.subheadline)

                Spacer()

                Button("Deselect All") {
                    selectedLocations.removeAll()
                }
                .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Locations list
            List {
                if !countries.isEmpty {
                    Section("Countries") {
                        ForEach(countries) { location in
                            LocationRow(
                                location: location,
                                isSelected: selectedLocations.contains(location),
                                onToggle: { toggleSelection(location) }
                            )
                        }
                    }
                }

                if !states.isEmpty {
                    Section("States & Provinces") {
                        ForEach(states) { location in
                            LocationRow(
                                location: location,
                                isSelected: selectedLocations.contains(location),
                                onToggle: { toggleSelection(location) }
                            )
                        }
                    }
                }

                // Statistics section
                Section {
                    Button {
                        showingStats.toggle()
                    } label: {
                        HStack {
                            Label("Scan Details", systemImage: "chart.bar.doc.horizontal")
                            Spacer()
                            Image(systemName: showingStats ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showingStats {
                        StatisticsView(statistics: statistics)
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Import button
            Button(action: onImport) {
                Text("Import \(selectedLocations.count) Location\(selectedLocations.count == 1 ? "" : "s")")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedLocations.isEmpty ? Color.gray : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedLocations.isEmpty)
            .padding()
        }
    }

    private func toggleSelection(_ location: DiscoveredLocation) {
        if selectedLocations.contains(location) {
            selectedLocations.remove(location)
        } else {
            selectedLocations.insert(location)
        }
    }
}

// MARK: - Location Row

private struct LocationRow: View {
    let location: DiscoveredLocation
    let isSelected: Bool
    let onToggle: () -> Void

    private var iconName: String {
        switch location.regionType {
        case VisitedPlace.RegionType.country.rawValue: return "flag.fill"
        case VisitedPlace.RegionType.usState.rawValue: return "star.fill"
        case VisitedPlace.RegionType.canadianProvince.rawValue: return "leaf.fill"
        default: return "mappin"
        }
    }

    private var iconColor: Color {
        switch location.regionType {
        case VisitedPlace.RegionType.country.rawValue: return .green
        case VisitedPlace.RegionType.usState.rawValue: return .blue
        case VisitedPlace.RegionType.canadianProvince.rawValue: return .red
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .green : .secondary)
                    .font(.title2)
                    .accessibilityHidden(true)

                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.regionName)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text("\(location.photoCount) photo\(location.photoCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let date = location.earliestDate {
                            Text("Since \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Text(location.regionCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(location.regionName), \(location.photoCount) photos, \(isSelected ? "selected" : "not selected")")
        .accessibilityHint("Double tap to \(isSelected ? "deselect" : "select")")
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text("Something Went Wrong")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Cancel", action: onDismiss)
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Statistics View

private struct StatisticsView: View {
    let statistics: ImportStatistics
    @State private var showingUnmatched = false
    @State private var showingUnmatchedMap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Incremental scan info
            if statistics.wasIncrementalScan {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.green)
                    Text("Incremental scan - \(statistics.photosSkipped) photos skipped")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(.bottom, 4)
            }

            // Photo counts
            Group {
                if statistics.totalPhotosInLibrary > 0 && statistics.totalPhotosInLibrary != statistics.totalPhotosScanned {
                    StatRow(label: "Total photos in library", value: "\(statistics.totalPhotosInLibrary)")
                    StatRow(label: "Photos skipped (already scanned)", value: "\(statistics.photosSkipped)", color: .blue)
                }
                StatRow(label: "New photos scanned", value: "\(statistics.totalPhotosScanned)")
                StatRow(label: "With location data", value: "\(statistics.photosWithLocation)", color: .green)
                StatRow(label: "Without location data", value: "\(statistics.photosWithoutLocation)", color: statistics.photosWithoutLocation > 0 ? .orange : .secondary)
            }

            Divider()

            // Cluster counts
            Group {
                StatRow(label: "Location clusters", value: "\(statistics.clustersCreated)")
                StatRow(label: "Matched to country", value: "\(statistics.clustersMatched)", color: .green)
                StatRow(label: "Unmatched (ocean/unknown)", value: "\(statistics.clustersUnmatched)", color: statistics.clustersUnmatched > 0 ? .red : .secondary)
            }

            if statistics.clustersUnmatched > 0 {
                StatRow(
                    label: "Photos in unmatched clusters",
                    value: "\(statistics.photosInUnmatchedClusters)",
                    color: .red
                )
            }

            // Countries found with state breakdown
            if !statistics.countriesFound.isEmpty {
                Divider()

                Text("Photos by Country (\(statistics.countriesFound.count))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                let sortedCountries = statistics.countriesFound.sorted { $0.value > $1.value }
                ForEach(sortedCountries, id: \.key) { country, count in
                    CountryStatRow(
                        countryCode: country,
                        photoCount: count,
                        statesFound: statistics.statesFound[country] ?? [:]
                    )
                }
            }

            // Unmatched coordinates (for debugging)
            if !statistics.unmatchedCoordinates.isEmpty {
                Divider()

                HStack {
                    Button {
                        showingUnmatched.toggle()
                    } label: {
                        HStack {
                            Text("Unmatched Coordinates (\(statistics.unmatchedCoordinates.count) samples)")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Image(systemName: showingUnmatched ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                    }

                    Spacer()

                    Button {
                        showingUnmatchedMap = true
                    } label: {
                        Label("Map", systemImage: "map")
                            .font(.caption)
                    }
                }

                if showingUnmatched {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(statistics.unmatchedCoordinates.prefix(20)) { coord in
                            HStack {
                                Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                                    .font(.caption2)
                                    .monospaced()
                                Spacer()
                                Text("\(coord.photoCount) photos")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if statistics.unmatchedCoordinates.count > 20 {
                            Text("+ \(statistics.unmatchedCoordinates.count - 20) more...")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 8)
                }
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingUnmatchedMap) {
            UnmatchedCoordinatesMapView(coordinates: statistics.unmatchedCoordinates)
        }
    }
}

// MARK: - Country Stat Row with State Breakdown

private struct CountryStatRow: View {
    let countryCode: String
    let photoCount: Int
    let statesFound: [String: Int]

    private var countryName: String {
        GeographicData.countries.first { $0.id == countryCode }?.name ?? countryCode
    }

    private var totalStatesInCountry: Int {
        GeographicData.states(for: countryCode).count
    }

    /// All states sorted by photo count, formatted as comma-separated list
    private var allStatesList: String? {
        guard !statesFound.isEmpty else { return nil }
        let sortedStates = statesFound.sorted { $0.value > $1.value }
        return sortedStates.map { $0.key }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(countryName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatPhotoCount(photoCount))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }

            // State breakdown if available - show ALL states
            if let statesList = allStatesList, totalStatesInCountry > 0 {
                HStack(alignment: .top) {
                    Text(statesList)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)  // Allow wrapping
                    Spacer()
                    Text("(\(statesFound.count)/\(totalStatesInCountry))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else if !statesFound.isEmpty {
                // Country has states but we don't have total count in GeographicData
                Text(allStatesList ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
        }
    }

    private func formatPhotoCount(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            return String(format: "%.1fk photos", k)
        }
        return "\(count) photos"
    }
}

// MARK: - Unmatched Coordinates Map View

private struct UnmatchedCoordinatesMapView: View {
    let coordinates: [UnmatchedCoordinate]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCoordinate: UnmatchedCoordinate?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(coordinates) { coord in
                    Annotation(
                        "",
                        coordinate: CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude),
                        anchor: .center
                    ) {
                        Button {
                            selectedCoordinate = coord
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.red.opacity(0.8))
                                    .frame(width: 30, height: 30)
                                Text("\(coord.photoCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .navigationTitle("Unmatched Locations (\(coordinates.count))")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedCoordinate) { coord in
                UnmatchedPhotoDetailView(coordinate: coord)
            }
        }
    }
}

// MARK: - Unmatched Photo Detail View

private struct UnmatchedPhotoDetailView: View {
    let coordinate: UnmatchedCoordinate
    @Environment(\.dismiss) private var dismiss
    @State private var photos: [UIImage] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Location info
                VStack(spacing: 4) {
                    Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                        .font(.headline)
                        .monospaced()
                    Text("\(coordinate.photoCount) photos at this location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()

                // Mini map
                Map {
                    Marker(
                        "Location",
                        coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    )
                    .tint(.red)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Photos
                if isLoading {
                    ProgressView("Loading photos...")
                        .frame(maxHeight: .infinity)
                } else if photos.isEmpty {
                    Text("No photos available")
                        .foregroundStyle(.secondary)
                        .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(Array(photos.enumerated()), id: \.offset) { _, photo in
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Unmatched Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadPhotos()
            }
        }
    }

    private func loadPhotos() async {
        guard !coordinate.photoAssetIDs.isEmpty else {
            isLoading = false
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: coordinate.photoAssetIDs, options: nil)
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isSynchronous = false

        var loadedPhotos: [UIImage] = []

        fetchResult.enumerateObjects { asset, _, _ in
            let semaphore = DispatchSemaphore(value: 0)
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    loadedPhotos.append(image)
                }
                semaphore.signal()
            }
            semaphore.wait()
        }

        await MainActor.run {
            photos = loadedPhotos
            isLoading = false
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    PhotoImportView()
        .modelContainer(for: VisitedPlace.self, inMemory: true)
}
