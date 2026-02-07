import Photos
import SwiftUI

/// Main memories view showing photos organized by country/region
struct MemoriesView: View {
    let visitedPlaces: [VisitedPlace]
    @State private var photoStats: PhotoLocationStats = .empty
    @State private var isLoading = true
    @State private var selectedCountryCode: String?
    @State private var searchText = ""

    private var hasPhotos: Bool {
        photoStats.totalPhotos > 0
    }

    private var filteredCountries: [PhotoLocationStats.CountryPhotoInfo] {
        if searchText.isEmpty {
            return photoStats.countries
        }
        return photoStats.countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedByContinent: [(continent: String, countries: [PhotoLocationStats.CountryPhotoInfo])] {
        let grouped = Dictionary(grouping: filteredCountries) { $0.continent }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (continent: $0.key, countries: $0.value.sorted { $0.photoCount > $1.photoCount }) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading memories...")
                } else if !hasPhotos {
                    emptyStateView
                } else {
                    memoriesListView
                }
            }
            .navigationTitle("Memories")
            .navigationDestination(item: $selectedCountryCode) { countryCode in
                CountryMemoriesView(countryCode: countryCode)
            }
        }
        .task {
            await loadPhotoStats()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("No Photo Memories Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Import photos from your library to see your travel memories organized by country.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Memories List

    private var memoriesListView: some View {
        VStack(spacing: 0) {
            // Summary header
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    StatBadge(
                        value: "\(photoStats.totalPhotos.formatted())",
                        label: "Photos",
                        icon: "photo.fill",
                        color: .blue
                    )
                    StatBadge(
                        value: "\(photoStats.countries.count)",
                        label: "Countries",
                        icon: "flag.fill",
                        color: .green
                    )
                    if let earliest = photoStats.earliestDate {
                        StatBadge(
                            value: earliest.formatted(.dateTime.year()),
                            label: "Since",
                            icon: "calendar",
                            color: .orange
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            // Countries list grouped by continent
            List {
                if searchText.isEmpty {
                    ForEach(groupedByContinent, id: \.continent) { group in
                        Section(group.continent) {
                            ForEach(group.countries) { country in
                                CountryMemoryRow(country: country) {
                                    selectedCountryCode = country.code
                                }
                            }
                        }
                    }
                } else {
                    ForEach(filteredCountries) { country in
                        CountryMemoryRow(country: country) {
                            selectedCountryCode = country.code
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search countries")
        }
    }

    // MARK: - Data Loading

    private func loadPhotoStats() async {
        let locations = PhotoLocationStore.shared.load()
        guard !locations.isEmpty else {
            isLoading = false
            return
        }

        // Build country stats from photo locations
        var countryData: [String: (photoCount: Int, locationCount: Int, earliestDate: Date?, assetIDs: [String])] = [:]

        for location in locations {
            guard let countryCode = location.countryCode else { continue }
            var existing = countryData[countryCode] ?? (0, 0, nil, [])
            existing.photoCount += location.photoCount
            existing.locationCount += 1
            if let date = location.earliestDate {
                if existing.earliestDate == nil || date < existing.earliestDate! {
                    existing.earliestDate = date
                }
            }
            // Collect first few asset IDs for preview thumbnails
            if existing.assetIDs.count < 4 {
                existing.assetIDs.append(contentsOf: location.photoAssetIDs.prefix(4 - existing.assetIDs.count))
            }
            countryData[countryCode] = existing
        }

        // Convert to display model
        var countries: [PhotoLocationStats.CountryPhotoInfo] = []
        for (code, data) in countryData {
            let countryInfo = GeographicData.countries.first { $0.id == code }
            let name = countryInfo?.name ?? code
            let continent = countryInfo?.continent ?? "Other"

            countries.append(PhotoLocationStats.CountryPhotoInfo(
                code: code,
                name: name,
                continent: continent,
                photoCount: data.photoCount,
                locationCount: data.locationCount,
                earliestDate: data.earliestDate,
                previewAssetIDs: data.assetIDs
            ))
        }

        countries.sort { $0.photoCount > $1.photoCount }

        let totalPhotos = countries.reduce(0) { $0 + $1.photoCount }
        let earliestDate = countries.compactMap(\.earliestDate).min()

        photoStats = PhotoLocationStats(
            totalPhotos: totalPhotos,
            countries: countries,
            earliestDate: earliestDate
        )
        isLoading = false
    }
}

// MARK: - Photo Location Stats Model

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

// MARK: - Country Memory Row

private struct CountryMemoryRow: View {
    let country: PhotoLocationStats.CountryPhotoInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Preview thumbnails (2x2 grid)
                PhotoPreviewGrid(assetIDs: country.previewAssetIDs)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(country.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Label(
                            "\(country.photoCount) photo\(country.photoCount == 1 ? "" : "s")",
                            systemImage: "photo"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if country.locationCount > 1 {
                            Label(
                                "\(country.locationCount) places",
                                systemImage: "mappin"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let date = country.earliestDate {
                        Text("Since \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(country.name), \(country.photoCount) photos")
        .accessibilityHint("Double tap to view memories from \(country.name)")
    }
}

// MARK: - Photo Preview Grid (2x2 thumbnails)

struct PhotoPreviewGrid: View {
    let assetIDs: [String]
    @State private var assets: [PHAsset] = []
    @State private var isLoaded = false

    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
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
