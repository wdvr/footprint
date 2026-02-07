import Photos
import SwiftUI

// MARK: - Trip Model

/// Represents a trip: a cluster of photos taken in the same country within a time window
struct Trip: Identifiable {
    let id = UUID()
    let countryCode: String
    let countryName: String
    let flagEmoji: String
    let startDate: Date
    let endDate: Date
    let photoCount: Int
    let locationCount: Int
    let coverAssetIDs: [String]  // Up to 4 asset IDs for cover photos
    let allAssetIDs: [String]    // All photo asset IDs in this trip

    /// Formatted date range for display
    var dateRangeText: String {
        let calendar = Calendar.current

        let startMonth = calendar.component(.month, from: startDate)
        let startYear = calendar.component(.year, from: startDate)
        let endMonth = calendar.component(.month, from: endDate)
        let endYear = calendar.component(.year, from: endDate)

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"

        if startYear == endYear && startMonth == endMonth {
            // Same month: "Feb 2025"
            return "\(monthFormatter.string(from: startDate)) \(yearFormatter.string(from: startDate))"
        } else if startYear == endYear {
            // Same year, different months: "Jan - Mar 2025"
            return "\(monthFormatter.string(from: startDate)) - \(monthFormatter.string(from: endDate)) \(yearFormatter.string(from: endDate))"
        } else {
            // Different years: "Dec 2024 - Jan 2025"
            return "\(monthFormatter.string(from: startDate)) \(yearFormatter.string(from: startDate)) - \(monthFormatter.string(from: endDate)) \(yearFormatter.string(from: endDate))"
        }
    }

    /// Duration text like "3 days" or "1 week"
    var durationText: String? {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if days == 0 { return "1 day" }
        if days == 1 { return "2 days" }
        if days < 7 { return "\(days + 1) days" }
        let weeks = days / 7
        if weeks == 1 { return "~1 week" }
        if weeks < 5 { return "~\(weeks) weeks" }
        let months = days / 30
        if months == 1 { return "~1 month" }
        return "~\(months) months"
    }
}

// MARK: - Trip Builder

/// Builds trips from PhotoLocation data by clustering locations by country and time proximity
enum TripBuilder {
    /// Maximum gap in days between photo clusters to be considered the same trip
    static let maxGapDays: Int = 7

    /// Build trips from photo locations
    static func buildTrips(from locations: [PhotoLocation]) -> [Trip] {
        // Group locations by country
        var byCountry: [String: [PhotoLocation]] = [:]
        for location in locations {
            guard let code = location.countryCode else { continue }
            byCountry[code, default: []].append(location)
        }

        var trips: [Trip] = []

        for (countryCode, countryLocations) in byCountry {
            let countryTrips = clusterIntoTrips(
                countryCode: countryCode,
                locations: countryLocations
            )
            trips.append(contentsOf: countryTrips)
        }

        // Sort by most recent first
        trips.sort { $0.endDate > $1.endDate }
        return trips
    }

    /// Cluster locations within a country into trips based on time proximity
    /// We load actual PHAsset dates to get accurate per-photo date ranges
    private static func clusterIntoTrips(
        countryCode: String,
        locations: [PhotoLocation]
    ) -> [Trip] {
        let countryInfo = GeographicData.countries.first { $0.id == countryCode }
        let countryName = countryInfo?.name ?? countryCode
        let flag = flagEmoji(for: countryCode)

        // Collect all asset IDs from all locations
        let allAssetIDs = locations.flatMap { $0.photoAssetIDs }
        guard !allAssetIDs.isEmpty else { return [] }

        // Fetch assets to get accurate dates
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: allAssetIDs,
            options: nil
        )

        // Build array of (assetID, date) sorted by date
        var assetDates: [(id: String, date: Date)] = []
        fetchResult.enumerateObjects { asset, _, _ in
            if let date = asset.creationDate {
                assetDates.append((id: asset.localIdentifier, date: date))
            }
        }

        guard !assetDates.isEmpty else {
            // Fallback: use cluster-level dates if asset fetch fails
            return clusterByClusterDates(
                countryCode: countryCode,
                countryName: countryName,
                flag: flag,
                locations: locations
            )
        }

        // Sort by date
        assetDates.sort { $0.date < $1.date }

        // Cluster into trips: photos within maxGapDays of each other
        var tripGroups: [[(id: String, date: Date)]] = []
        var currentGroup: [(id: String, date: Date)] = [assetDates[0]]

        for i in 1..<assetDates.count {
            let gap = Calendar.current.dateComponents(
                [.day],
                from: assetDates[i - 1].date,
                to: assetDates[i].date
            ).day ?? 0

            if gap > maxGapDays {
                tripGroups.append(currentGroup)
                currentGroup = [assetDates[i]]
            } else {
                currentGroup.append(assetDates[i])
            }
        }
        tripGroups.append(currentGroup)

        // Convert groups into Trip objects
        return tripGroups.compactMap { group in
            guard let startDate = group.first?.date,
                  let endDate = group.last?.date else { return nil }

            let ids = group.map { $0.id }
            // Use up to 4 evenly-spaced photos as cover
            let coverIDs = selectCoverPhotos(from: ids, count: 4)

            // Count unique grid cells this trip spans
            let assetIDSet = Set(ids)
            let locationCount = locations.filter { loc in
                loc.photoAssetIDs.contains(where: { assetIDSet.contains($0) })
            }.count

            return Trip(
                countryCode: countryCode,
                countryName: countryName,
                flagEmoji: flag,
                startDate: startDate,
                endDate: endDate,
                photoCount: ids.count,
                locationCount: locationCount,
                coverAssetIDs: coverIDs,
                allAssetIDs: ids
            )
        }
    }

    /// Fallback: cluster using PhotoLocation earliestDate when asset dates unavailable
    private static func clusterByClusterDates(
        countryCode: String,
        countryName: String,
        flag: String,
        locations: [PhotoLocation]
    ) -> [Trip] {
        // Sort locations by date
        let sorted = locations
            .filter { $0.earliestDate != nil }
            .sorted { $0.earliestDate! < $1.earliestDate! }

        guard !sorted.isEmpty else { return [] }

        var tripGroups: [[PhotoLocation]] = []
        var currentGroup: [PhotoLocation] = [sorted[0]]

        for i in 1..<sorted.count {
            let gap = Calendar.current.dateComponents(
                [.day],
                from: sorted[i - 1].earliestDate!,
                to: sorted[i].earliestDate!
            ).day ?? 0

            if gap > maxGapDays {
                tripGroups.append(currentGroup)
                currentGroup = [sorted[i]]
            } else {
                currentGroup.append(sorted[i])
            }
        }
        tripGroups.append(currentGroup)

        return tripGroups.compactMap { group in
            guard let startDate = group.first?.earliestDate,
                  let endDate = group.last?.earliestDate else { return nil }

            let allIDs = group.flatMap { $0.photoAssetIDs }
            let coverIDs = selectCoverPhotos(from: allIDs, count: 4)
            let photoCount = group.reduce(0) { $0 + $1.photoCount }

            return Trip(
                countryCode: countryCode,
                countryName: countryName,
                flagEmoji: flag,
                startDate: startDate,
                endDate: endDate,
                photoCount: photoCount,
                locationCount: group.count,
                coverAssetIDs: coverIDs,
                allAssetIDs: allIDs
            )
        }
    }

    /// Select evenly-spaced cover photos from a list of IDs
    private static func selectCoverPhotos(from ids: [String], count: Int) -> [String] {
        guard ids.count > count else { return ids }
        var selected: [String] = []
        let step = ids.count / count
        for i in 0..<count {
            selected.append(ids[i * step])
        }
        return selected
    }

    /// Convert country code to flag emoji
    private static func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                flag.append(String(unicode))
            }
        }
        return flag
    }
}

// MARK: - Memories View

/// Main memories view showing photos organized as trips
struct MemoriesView: View {
    let visitedPlaces: [VisitedPlace]
    @State private var trips: [Trip] = []
    @State private var isLoading = true
    @State private var selectedTrip: Trip?
    @State private var searchText = ""

    private var hasTrips: Bool {
        !trips.isEmpty
    }

    private var filteredTrips: [Trip] {
        if searchText.isEmpty {
            return trips
        }
        return trips.filter {
            $0.countryName.localizedCaseInsensitiveContains(searchText)
                || $0.countryCode.localizedCaseInsensitiveContains(searchText)
                || $0.dateRangeText.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Group trips by year for section headers
    private var tripsByYear: [(year: Int, trips: [Trip])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredTrips) { trip in
            calendar.component(.year, from: trip.startDate)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (year: $0.key, trips: $0.value) }
    }

    private var totalPhotos: Int {
        trips.reduce(0) { $0 + $1.photoCount }
    }

    private var countryCount: Int {
        Set(trips.map { $0.countryCode }).count
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading trips...")
                } else if !hasTrips {
                    emptyStateView
                } else {
                    tripsListView
                }
            }
            .navigationTitle("Memories")
            .navigationDestination(item: $selectedTrip) { trip in
                TripDetailView(trip: trip)
            }
        }
        .task {
            await loadTrips()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "airplane.departure")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("No Trips Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Import photos from your library to see your travel memories organized as trips.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Trips List

    private var tripsListView: some View {
        VStack(spacing: 0) {
            // Summary header
            HStack(spacing: 16) {
                StatBadge(
                    value: "\(trips.count)",
                    label: trips.count == 1 ? "Trip" : "Trips",
                    icon: "airplane",
                    color: .blue
                )
                StatBadge(
                    value: "\(totalPhotos.formatted())",
                    label: "Photos",
                    icon: "photo.fill",
                    color: .purple
                )
                StatBadge(
                    value: "\(countryCount)",
                    label: countryCount == 1 ? "Country" : "Countries",
                    icon: "flag.fill",
                    color: .green
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Trip cards grouped by year
            List {
                ForEach(tripsByYear, id: \.year) { yearGroup in
                    Section {
                        ForEach(yearGroup.trips) { trip in
                            TripCardRow(trip: trip) {
                                selectedTrip = trip
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    } header: {
                        Text(String(yearGroup.year))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search trips")
        }
    }

    // MARK: - Data Loading

    private func loadTrips() async {
        let locations = PhotoLocationStore.shared.load()
        guard !locations.isEmpty else {
            isLoading = false
            return
        }

        // Build trips on a background-friendly path
        let builtTrips = TripBuilder.buildTrips(from: locations)

        await MainActor.run {
            trips = builtTrips
            isLoading = false
        }
    }
}

// MARK: - Make Trip work with navigationDestination

extension Trip: Hashable {
    static func == (lhs: Trip, rhs: Trip) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - Trip Card Row

private struct TripCardRow: View {
    let trip: Trip
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Cover photo area
                ZStack(alignment: .bottomLeading) {
                    TripCoverImage(assetIDs: trip.coverAssetIDs)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Gradient overlay for text readability
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Trip info overlay
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(trip.flagEmoji)
                                .font(.title2)
                            Text(trip.countryName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }

                        HStack(spacing: 12) {
                            Text(trip.dateRangeText)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))

                            if let duration = trip.durationText {
                                Text(duration)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.white.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }

                        HStack(spacing: 8) {
                            Label(
                                "\(trip.photoCount)",
                                systemImage: "photo"
                            )
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))

                            if trip.locationCount > 1 {
                                Label(
                                    "\(trip.locationCount) places",
                                    systemImage: "mappin"
                                )
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.countryName), \(trip.dateRangeText), \(trip.photoCount) photos")
        .accessibilityHint("Double tap to view trip photos")
    }
}

// MARK: - Trip Cover Image

private struct TripCoverImage: View {
    let assetIDs: [String]
    @State private var assets: [PHAsset] = []

    var body: some View {
        GeometryReader { geometry in
            if assets.isEmpty {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.4))
                    }
            } else if assets.count == 1 {
                PhotoThumbnailView(asset: assets[0])
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else if assets.count == 2 {
                HStack(spacing: 2) {
                    PhotoThumbnailView(asset: assets[0])
                        .frame(width: geometry.size.width / 2 - 1, height: geometry.size.height)
                        .clipped()
                    PhotoThumbnailView(asset: assets[1])
                        .frame(width: geometry.size.width / 2 - 1, height: geometry.size.height)
                        .clipped()
                }
            } else {
                // Main photo takes 2/3 width, two small photos on the right
                HStack(spacing: 2) {
                    PhotoThumbnailView(asset: assets[0])
                        .frame(width: geometry.size.width * 2 / 3 - 1, height: geometry.size.height)
                        .clipped()

                    VStack(spacing: 2) {
                        PhotoThumbnailView(asset: assets[1])
                            .frame(height: geometry.size.height / 2 - 1)
                            .clipped()
                        if assets.count > 2 {
                            PhotoThumbnailView(asset: assets[2])
                                .frame(height: geometry.size.height / 2 - 1)
                                .clipped()
                        }
                    }
                    .frame(width: geometry.size.width / 3 - 1)
                }
            }
        }
        .task {
            await loadAssets()
        }
    }

    private func loadAssets() async {
        guard !assetIDs.isEmpty else { return }
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: Array(assetIDs.prefix(4)),
            options: nil
        )
        var loaded: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            loaded.append(asset)
        }
        await MainActor.run {
            assets = loaded
        }
    }
}

// MARK: - Trip Detail View

struct TripDetailView: View {
    let trip: Trip
    @State private var selectedAsset: PHAsset?

    var body: some View {
        PhotoGridView(
            assetIDs: trip.allAssetIDs,
            onPhotoTapped: { asset in
                selectedAsset = asset
            }
        )
        .navigationTitle("\(trip.flagEmoji) \(trip.countryName)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text("\(trip.flagEmoji) \(trip.countryName)")
                        .font(.headline)
                    Text(trip.dateRangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .fullScreenCover(item: $selectedAsset) { asset in
            PhotoDetailView(asset: asset)
        }
    }
}

// MARK: - Photo Location Stats Model (kept for backward compatibility)

struct PhotoLocationStats {
    var totalPhotos: Int
    var countries: [CountryPhotoInfo]
    var earliestDate: Date?

    static let empty = PhotoLocationStats(totalPhotos: 0, countries: [], earliestDate: nil)

    struct CountryPhotoInfo: Identifiable {
        let code: String
        let name: String
        let continent: String
        let photoCount: Int
        let locationCount: Int
        let earliestDate: Date?
        let previewAssetIDs: [String]

        var id: String { code }
    }
}

// MARK: - Photo Preview Grid (2x2 thumbnails, kept for other views that use it)

struct PhotoPreviewGrid: View {
    let assetIDs: [String]
    @State private var assets: [PHAsset] = []
    @State private var isLoaded = false

    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
    ]

    var body: some View {
        Group {
            if assets.isEmpty {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
            } else if assets.count == 1 {
                PhotoThumbnailView(asset: assets[0])
            } else {
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(assets.prefix(4), id: \.localIdentifier) { asset in
                        PhotoThumbnailView(asset: asset)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                    }
                }
            }
        }
        .task {
            await loadAssets()
        }
    }

    private func loadAssets() async {
        guard !assetIDs.isEmpty else {
            isLoaded = true
            return
        }
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: Array(assetIDs.prefix(4)),
            options: nil
        )
        var loaded: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            loaded.append(asset)
        }
        await MainActor.run {
            assets = loaded
            isLoaded = true
        }
    }
}

#Preview {
    MemoriesView(visitedPlaces: [])
}
