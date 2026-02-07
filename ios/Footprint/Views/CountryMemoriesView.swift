import MapKit
import Photos
import SwiftUI

/// Detail view showing all photo memories for a specific country
struct CountryMemoriesView: View {
    let countryCode: String
    @State private var photoLocations: [PhotoLocation] = []
    @State private var allAssetIDs: [String] = []
    @State private var isLoading = true
    @State private var selectedAsset: PHAsset?
    @State private var viewMode: ViewMode = .grid
    @State private var sortOrder: SortOrder = .newestFirst

    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case places = "Places"
        case map = "Map"

        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .places: return "mappin.and.ellipse"
            case .map: return "map"
            }
        }
    }

    enum SortOrder {
        case newestFirst
        case oldestFirst
        case mostPhotos
    }

    private var countryName: String {
        GeographicData.countries.first { $0.id == countryCode }?.name ?? countryCode
    }

    private var totalPhotoCount: Int {
        photoLocations.reduce(0) { $0 + $1.photoCount }
    }

    private var dateRange: String? {
        let dates = photoLocations.compactMap(\.earliestDate)
        guard let earliest = dates.min() else { return nil }
        return "Since \(earliest.formatted(date: .abbreviated, time: .omitted))"
    }

    private var sortedLocations: [PhotoLocation] {
        switch sortOrder {
        case .newestFirst:
            return photoLocations.sorted {
                ($0.earliestDate ?? .distantPast) > ($1.earliestDate ?? .distantPast)
            }
        case .oldestFirst:
            return photoLocations.sorted {
                ($0.earliestDate ?? .distantFuture) < ($1.earliestDate ?? .distantFuture)
            }
        case .mostPhotos:
            return photoLocations.sorted { $0.photoCount > $1.photoCount }
        }
    }

    private let gridColumns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // View mode picker
            Picker("View", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if isLoading {
                Spacer()
                ProgressView("Loading photos...")
                Spacer()
            } else if allAssetIDs.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No photos found for \(countryName)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                switch viewMode {
                case .grid:
                    gridView
                case .places:
                    placesView
                case .map:
                    mapView
                }
            }
        }
        .navigationTitle(countryName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Section("Sort By") {
                        Button {
                            sortOrder = .newestFirst
                        } label: {
                            if sortOrder == .newestFirst {
                                Label("Newest First", systemImage: "checkmark")
                            } else {
                                Text("Newest First")
                            }
                        }
                        Button {
                            sortOrder = .oldestFirst
                        } label: {
                            if sortOrder == .oldestFirst {
                                Label("Oldest First", systemImage: "checkmark")
                            } else {
                                Text("Oldest First")
                            }
                        }
                        Button {
                            sortOrder = .mostPhotos
                        } label: {
                            if sortOrder == .mostPhotos {
                                Label("Most Photos", systemImage: "checkmark")
                            } else {
                                Text("Most Photos")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
        .fullScreenCover(item: $selectedAsset) { asset in
            PhotoDetailView(asset: asset)
        }
        .task {
            await loadPhotos()
        }
    }

    // MARK: - Grid View (all photos)

    private var gridView: some View {
        PhotoGridView(
            assetIDs: allAssetIDs,
            onPhotoTapped: { asset in
                selectedAsset = asset
            }
        )
    }

    // MARK: - Places View (grouped by location)

    private var placesView: some View {
        List {
            // Summary
            Section {
                HStack(spacing: 16) {
                    Label("\(totalPhotoCount) photos", systemImage: "photo.fill")
                        .font(.subheadline)
                    Label("\(photoLocations.count) places", systemImage: "mappin")
                        .font(.subheadline)
                    if let range = dateRange {
                        Text(range)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Places
            ForEach(sortedLocations, id: \.id) { location in
                PlacePhotoSection(location: location, onPhotoTapped: { asset in
                    selectedAsset = asset
                })
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Map View

    private var mapView: some View {
        CountryMemoriesMapView(
            countryCode: countryCode,
            photoLocations: photoLocations,
            onPhotoTapped: { asset in
                selectedAsset = asset
            }
        )
    }

    // MARK: - Data Loading

    private func loadPhotos() async {
        let locations = PhotoLocationStore.shared.locations(forCountry: countryCode)

        // Collect all asset IDs maintaining location order
        var ids: [String] = []
        for location in locations {
            ids.append(contentsOf: location.photoAssetIDs)
        }

        await MainActor.run {
            photoLocations = locations
            allAssetIDs = ids
            isLoading = false
        }
    }
}

// MARK: - Photo Grid View (reusable grid of photos loaded from asset IDs)

struct PhotoGridView: View {
    let assetIDs: [String]
    var onPhotoTapped: ((PHAsset) -> Void)?
    @State private var assets: [PHAsset] = []
    @State private var isLoading = true

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading photos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if assets.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No photos available")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Photos may have been deleted from your library.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            PhotoThumbnailView(asset: asset)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .onTapGesture {
                                    onPhotoTapped?(asset)
                                }
                                .accessibilityLabel("Photo\(asset.creationDate.map { ", \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "")")
                                .accessibilityHint("Double tap to view full size")
                        }
                    }
                    .padding(2)
                }
            }
        }
        .task {
            await loadAssets()
        }
    }

    private func loadAssets() async {
        guard !assetIDs.isEmpty else {
            isLoading = false
            return
        }

        // Load in batches to avoid memory issues with very large sets
        let batchSize = 500
        var allAssets: [PHAsset] = []

        for batchStart in stride(from: 0, to: assetIDs.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, assetIDs.count)
            let batchIDs = Array(assetIDs[batchStart..<batchEnd])
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: batchIDs, options: nil)
            fetchResult.enumerateObjects { asset, _, _ in
                allAssets.append(asset)
            }
        }

        // Sort by creation date, newest first
        allAssets.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

        await MainActor.run {
            assets = allAssets
            isLoading = false
        }
    }
}

// MARK: - Place Photo Section

private struct PlacePhotoSection: View {
    let location: PhotoLocation
    var onPhotoTapped: ((PHAsset) -> Void)?
    @State private var assets: [PHAsset] = []
    @State private var isExpanded = false

    private let previewColumns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 2)
    ]

    var body: some View {
        Section {
            // Place header with photo count
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.regionName ?? "Unknown Location")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            Text("\(location.photoCount) photo\(location.photoCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let date = location.earliestDate {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(location.regionName ?? "Unknown Location"), \(location.photoCount) photo\(location.photoCount == 1 ? "" : "s")")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand photos")

            // Photo thumbnails (when expanded)
            if isExpanded {
                if assets.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .task {
                            await loadAssets()
                        }
                } else {
                    LazyVGrid(columns: previewColumns, spacing: 2) {
                        ForEach(assets, id: \.localIdentifier) { asset in
                            PhotoThumbnailView(asset: asset)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .onTapGesture {
                                    onPhotoTapped?(asset)
                                }
                                .accessibilityLabel("Photo\(asset.creationDate.map { ", \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "")")
                                .accessibilityHint("Double tap to view full size")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func loadAssets() async {
        guard !location.photoAssetIDs.isEmpty else { return }
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: location.photoAssetIDs,
            options: nil
        )
        var loaded: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            loaded.append(asset)
        }
        loaded.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        await MainActor.run {
            assets = loaded
        }
    }
}

// MARK: - Country Memories Map View

private struct CountryMemoriesMapView: View {
    let countryCode: String
    let photoLocations: [PhotoLocation]
    var onPhotoTapped: ((PHAsset) -> Void)?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedLocation: PhotoLocation?
    @State private var showingPhotoGallery = false

    var body: some View {
        Map(position: $cameraPosition) {
            ForEach(photoLocations, id: \.id) { location in
                Annotation(
                    "",
                    coordinate: location.coordinate,
                    anchor: .center
                ) {
                    Button {
                        selectedLocation = location
                        showingPhotoGallery = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(photoCountColor(location.photoCount).opacity(0.9))
                                .frame(width: 36, height: 36)

                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                                .frame(width: 36, height: 36)

                            Text(formatCount(location.photoCount))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityLabel("\(location.regionName ?? "Location"), \(location.photoCount) photo\(location.photoCount == 1 ? "" : "s")")
                    .accessibilityHint("Double tap to view photos")
                }
            }
        }
        .mapStyle(.standard)
        .sheet(isPresented: $showingPhotoGallery) {
            if let location = selectedLocation {
                PhotoGalleryView(photoAssetIDs: location.photoAssetIDs)
            }
        }
    }

    private func photoCountColor(_ count: Int) -> Color {
        if count >= 1000 { return .pink }
        if count >= 100 { return .purple }
        if count >= 10 { return .teal }
        return .blue
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 { return "\(count / 1000)k" }
        return "\(count)"
    }
}

#Preview {
    NavigationStack {
        CountryMemoriesView(countryCode: "US")
    }
}
