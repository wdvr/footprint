import SwiftUI

// MARK: - Share Card Data

/// Computed travel statistics for sharing
struct ShareCardData {
    let countriesVisited: Int
    let countriesTotal: Int
    let usStatesVisited: Int
    let usStatesTotal: Int
    let canadianProvincesVisited: Int
    let canadianProvincesTotal: Int
    let continentStats: [LocalContinentStats]
    let visitedCountryNames: [String]

    var totalRegionsVisited: Int {
        countriesVisited + usStatesVisited + canadianProvincesVisited
    }

    var countriesPercentage: Double {
        guard countriesTotal > 0 else { return 0 }
        return Double(countriesVisited) / Double(countriesTotal) * 100
    }

    var continentsVisited: Int {
        continentStats.filter { $0.visited > 0 }.count
    }

    static func from(visitedPlaces: [VisitedPlace]) -> ShareCardData {
        let activePlaces = visitedPlaces.filter { !$0.isDeleted && $0.isVisited }

        let countries = activePlaces.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
        }
        let usStates = activePlaces.filter {
            $0.regionType == VisitedPlace.RegionType.usState.rawValue
        }
        let canadianProvinces = activePlaces.filter {
            $0.regionType == VisitedPlace.RegionType.canadianProvince.rawValue
        }

        let countryCodes = countries.map { $0.regionCode }
        let continentStats = LocalContinentStats.calculateStats(visitedCountries: countryCodes)

        return ShareCardData(
            countriesVisited: countries.count,
            countriesTotal: GeographicData.countries.count,
            usStatesVisited: usStates.count,
            usStatesTotal: GeographicData.usStates.count,
            canadianProvincesVisited: canadianProvinces.count,
            canadianProvincesTotal: GeographicData.canadianProvinces.count,
            continentStats: continentStats,
            visitedCountryNames: countries.map { $0.regionName }.sorted()
        )
    }
}

// MARK: - Stats Share Card

/// A beautiful card showing travel statistics, designed for social media sharing
struct StatsShareCardView: View {
    let data: ShareCardData
    let colorScheme: ShareCardColorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            ZStack {
                LinearGradient(
                    colors: colorScheme.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("\(data.countriesVisited)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("countries visited")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Text("\(String(format: "%.1f", data.countriesPercentage))% of the world")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.vertical, 32)
            }

            // Stats body
            VStack(spacing: 20) {
                // Region stats row
                HStack(spacing: 0) {
                    ShareStatItem(
                        value: "\(data.usStatesVisited)",
                        label: "US States",
                        total: data.usStatesTotal,
                        color: colorScheme.accentColor
                    )

                    Divider()
                        .frame(height: 50)

                    ShareStatItem(
                        value: "\(data.canadianProvincesVisited)",
                        label: "CA Provinces",
                        total: data.canadianProvincesTotal,
                        color: colorScheme.accentColor
                    )

                    Divider()
                        .frame(height: 50)

                    ShareStatItem(
                        value: "\(data.continentsVisited)",
                        label: "Continents",
                        total: 6,
                        color: colorScheme.accentColor
                    )
                }
                .padding(.horizontal, 16)

                // Continent progress bars
                VStack(alignment: .leading, spacing: 10) {
                    Text("Continents")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(1)

                    ForEach(data.continentStats) { stat in
                        ShareContinentRow(stat: stat, accentColor: colorScheme.accentColor)
                    }
                }
                .padding(.horizontal, 20)

                // Footer branding
                HStack {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(colorScheme.accentColor)
                    Text("Footprint")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedDate())
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .padding(.top, 20)
            .background(Color(.systemBackground))
        }
        .frame(width: 390)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - Map Share Card

/// A share card showing visited countries as a dot-grid world map
struct MapShareCardView: View {
    let data: ShareCardData
    let visitedCountryCodes: Set<String>
    let colorScheme: ShareCardColorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Map area with gradient background
            ZStack {
                LinearGradient(
                    colors: [
                        colorScheme.gradientColors[0].opacity(0.15),
                        colorScheme.gradientColors[1].opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Simple world map grid visualization
                SimplifiedWorldMapView(
                    visitedCountryCodes: visitedCountryCodes,
                    accentColor: colorScheme.accentColor
                )
                .padding(20)
            }
            .frame(height: 280)

            // Stats overlay at bottom
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(data.countriesVisited)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme.accentColor)

                    Text("of \(data.countriesTotal) countries")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Country names list
                if !data.visitedCountryNames.isEmpty {
                    Text(formatCountryList())
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                // Footer branding
                HStack {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(colorScheme.accentColor)
                    Text("Footprint")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedDate())
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
            .background(Color(.systemBackground))
        }
        .frame(width: 390)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
    }

    private func formatCountryList() -> String {
        let names = data.visitedCountryNames
        if names.count <= 8 {
            return names.joined(separator: " \u{2022} ")
        } else {
            let shown = Array(names.prefix(7))
            return shown.joined(separator: " \u{2022} ") + " + \(names.count - 7) more"
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - Simplified World Map

/// A dot-grid world map that highlights visited countries by continent region
struct SimplifiedWorldMapView: View {
    let visitedCountryCodes: Set<String>
    let accentColor: Color

    private struct ContinentRegion {
        let name: String
        let xRange: ClosedRange<Int>
        let yRange: ClosedRange<Int>
    }

    private var continentRegions: [ContinentRegion] {
        [
            ContinentRegion(name: "Europe", xRange: 10...14, yRange: 1...4),
            ContinentRegion(name: "Asia", xRange: 14...21, yRange: 1...6),
            ContinentRegion(name: "Africa", xRange: 10...14, yRange: 4...9),
            ContinentRegion(name: "North America", xRange: 1...8, yRange: 1...6),
            ContinentRegion(name: "South America", xRange: 4...8, yRange: 6...10),
            ContinentRegion(name: "Oceania", xRange: 18...22, yRange: 6...10),
        ]
    }

    private func visitedFraction(for continent: String) -> Double {
        guard let data = LocalContinentStats.continentData.first(where: { $0.name == continent })
        else {
            return 0
        }
        let visited = data.codes.intersection(visitedCountryCodes).count
        return data.total > 0 ? Double(visited) / Double(data.total) : 0
    }

    var body: some View {
        Canvas { context, size in
            let cols = 23
            let rows = 11
            let dotSpacing = min(size.width / CGFloat(cols), size.height / CGFloat(rows))
            let dotRadius = dotSpacing * 0.3
            let offsetX = (size.width - CGFloat(cols) * dotSpacing) / 2
            let offsetY = (size.height - CGFloat(rows) * dotSpacing) / 2

            for region in continentRegions {
                let fraction = visitedFraction(for: region.name)

                for x in region.xRange {
                    for y in region.yRange {
                        let center = CGPoint(
                            x: offsetX + CGFloat(x) * dotSpacing + dotSpacing / 2,
                            y: offsetY + CGFloat(y) * dotSpacing + dotSpacing / 2
                        )
                        let rect = CGRect(
                            x: center.x - dotRadius,
                            y: center.y - dotRadius,
                            width: dotRadius * 2,
                            height: dotRadius * 2
                        )
                        let circle = Path(ellipseIn: rect)

                        if fraction > 0 {
                            let dotIndex =
                                (x - region.xRange.lowerBound)
                                * (region.yRange.upperBound - region.yRange.lowerBound + 1)
                                + (y - region.yRange.lowerBound)
                            let totalDots =
                                (region.xRange.upperBound - region.xRange.lowerBound + 1)
                                * (region.yRange.upperBound - region.yRange.lowerBound + 1)
                            let visitedDotCount = Int(Double(totalDots) * fraction)

                            if dotIndex < visitedDotCount {
                                context.fill(circle, with: .color(accentColor))
                            } else {
                                context.fill(circle, with: .color(.gray.opacity(0.2)))
                            }
                        } else {
                            context.fill(circle, with: .color(.gray.opacity(0.2)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ShareStatItem: View {
    let value: String
    let label: String
    let total: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text("of \(total)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShareContinentRow: View {
    let stat: LocalContinentStats
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(stat.emoji)
                .font(.system(size: 14))
                .frame(width: 20)

            Text(stat.name)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 100, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(stat.visited > 0 ? accentColor : Color.clear)
                        .frame(
                            width: geometry.size.width * CGFloat(stat.percentage / 100),
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            Text("\(stat.visited)/\(stat.total)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Color Schemes

enum ShareCardColorScheme: String, CaseIterable, Identifiable {
    case ocean
    case sunset
    case forest
    case midnight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .midnight: return "Midnight"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .ocean:
            return [
                Color(red: 0.1, green: 0.5, blue: 0.9),
                Color(red: 0.2, green: 0.7, blue: 0.8),
            ]
        case .sunset:
            return [
                Color(red: 0.9, green: 0.3, blue: 0.4),
                Color(red: 1.0, green: 0.6, blue: 0.3),
            ]
        case .forest:
            return [
                Color(red: 0.15, green: 0.6, blue: 0.4),
                Color(red: 0.3, green: 0.8, blue: 0.5),
            ]
        case .midnight:
            return [
                Color(red: 0.2, green: 0.15, blue: 0.4),
                Color(red: 0.4, green: 0.2, blue: 0.6),
            ]
        }
    }

    var accentColor: Color {
        switch self {
        case .ocean: return Color(red: 0.1, green: 0.5, blue: 0.9)
        case .sunset: return Color(red: 0.9, green: 0.35, blue: 0.3)
        case .forest: return Color(red: 0.15, green: 0.65, blue: 0.4)
        case .midnight: return Color(red: 0.4, green: 0.3, blue: 0.7)
        }
    }
}

// MARK: - Share Sheet View

/// Main share view that lets users pick card type, color scheme, and share
struct ShareSheetView: View {
    let visitedPlaces: [VisitedPlace]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCardType: ShareCardType = .stats
    @State private var selectedColorScheme: ShareCardColorScheme = .ocean
    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var showShareSheet = false

    enum ShareCardType: String, CaseIterable, Identifiable {
        case stats
        case map

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .stats: return "Stats Card"
            case .map: return "Map Card"
            }
        }

        var icon: String {
            switch self {
            case .stats: return "chart.bar.fill"
            case .map: return "map.fill"
            }
        }
    }

    private var cardData: ShareCardData {
        ShareCardData.from(visitedPlaces: visitedPlaces)
    }

    private var visitedCountryCodes: Set<String> {
        Set(
            visitedPlaces
                .filter {
                    $0.regionType == VisitedPlace.RegionType.country.rawValue
                        && !$0.isDeleted
                        && $0.isVisited
                }
                .map { $0.regionCode }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Card type picker
                    Picker("Card Type", selection: $selectedCardType) {
                        ForEach(ShareCardType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Card preview
                    Group {
                        switch selectedCardType {
                        case .stats:
                            StatsShareCardView(
                                data: cardData,
                                colorScheme: selectedColorScheme
                            )
                        case .map:
                            MapShareCardView(
                                data: cardData,
                                visitedCountryCodes: visitedCountryCodes,
                                colorScheme: selectedColorScheme
                            )
                        }
                    }
                    .scaleEffect(0.85)
                    .frame(height: selectedCardType == .stats ? 520 : 420)

                    // Color scheme picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ShareCardColorScheme.allCases) { scheme in
                                    ColorSchemeButton(
                                        scheme: scheme,
                                        isSelected: selectedColorScheme == scheme
                                    ) {
                                        selectedColorScheme = scheme
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Share button
                    Button {
                        renderAndShare()
                    } label: {
                        HStack {
                            if isRendering {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text("Share")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedColorScheme.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isRendering)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Share Your Travels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ActivityViewController(activityItems: [image, shareText()])
                }
            }
        }
    }

    private func shareText() -> String {
        let data = cardData
        return
            "I've visited \(data.countriesVisited) countries (\(String(format: "%.1f", data.countriesPercentage))% of the world)! Track your travels with Footprint."
    }

    @MainActor
    private func renderAndShare() {
        isRendering = true

        let cardView: AnyView
        switch selectedCardType {
        case .stats:
            cardView = AnyView(
                StatsShareCardView(
                    data: cardData,
                    colorScheme: selectedColorScheme
                )
                .padding(20)
                .background(Color(.systemGroupedBackground))
            )
        case .map:
            cardView = AnyView(
                MapShareCardView(
                    data: cardData,
                    visitedCountryCodes: visitedCountryCodes,
                    colorScheme: selectedColorScheme
                )
                .padding(20)
                .background(Color(.systemGroupedBackground))
            )
        }

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0  // High resolution for social media

        if let uiImage = renderer.uiImage {
            renderedImage = uiImage
            showShareSheet = true
        }

        isRendering = false
    }
}

// MARK: - Color Scheme Button

struct ColorSchemeButton: View {
    let scheme: ShareCardColorScheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: scheme.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ? Color.primary : Color.clear, lineWidth: 3
                            )
                            .padding(2)
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                Color(.systemBackground), lineWidth: isSelected ? 2 : 0)
                    )

                Text(scheme.displayName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(scheme.displayName) theme")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - UIKit Activity View Controller (Share Sheet)

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

// MARK: - Previews

#Preview("Stats Card - Ocean") {
    StatsShareCardView(
        data: ShareCardData(
            countriesVisited: 23,
            countriesTotal: 195,
            usStatesVisited: 15,
            usStatesTotal: 50,
            canadianProvincesVisited: 3,
            canadianProvincesTotal: 13,
            continentStats: LocalContinentStats.calculateStats(
                visitedCountries: [
                    "US", "CA", "MX", "GB", "FR", "DE", "IT", "ES", "JP",
                    "TH", "AU", "NZ", "BR", "AR", "EG", "ZA", "KE", "IN",
                    "CN", "KR", "PT", "NL", "GR",
                ]
            ),
            visitedCountryNames: [
                "United States", "Canada", "Mexico", "United Kingdom",
                "France", "Germany", "Italy", "Spain", "Japan",
            ]
        ),
        colorScheme: .ocean
    )
    .padding()
}

#Preview("Map Card - Sunset") {
    MapShareCardView(
        data: ShareCardData(
            countriesVisited: 12,
            countriesTotal: 195,
            usStatesVisited: 8,
            usStatesTotal: 50,
            canadianProvincesVisited: 2,
            canadianProvincesTotal: 13,
            continentStats: [],
            visitedCountryNames: [
                "United States", "Canada", "Mexico", "France", "Germany"
            ]
        ),
        visitedCountryCodes: Set([
            "US", "CA", "MX", "FR", "DE", "IT", "ES", "JP", "TH", "AU", "NZ", "BR"
        ]),
        colorScheme: .sunset
    )
    .padding()
}

#Preview("Share Sheet") {
    ShareSheetView(visitedPlaces: [])
}
