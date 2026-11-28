import SwiftUI

/// Named regions (§2.4): every region with its coverage, grouped by kind.
struct RegionsView: View {
    let visitedPlaces: [VisitedPlace]
    var catalog: NamedRegionCatalog = .bundled

    @State private var searchText = ""

    private var coverages: [RegionCoverage] {
        catalog.coverage(visitedKeys: RegionResolver.visitedKeys(from: visitedPlaces))
    }

    private var filtered: [RegionCoverage] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return coverages }
        return coverages.filter { coverage in
            let region = coverage.region
            return region.name.localizedCaseInsensitiveContains(query)
                || region.memberKeys.contains { region.memberName($0).localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        let all = coverages
        let shown = filtered
        List {
            Section {
                HStack(spacing: 16) {
                    CoverageRing(fraction: all.isEmpty ? 0 : Double(all.filter(\.isVisited).count) / Double(all.count))
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(all.filter(\.isVisited).count) of \(all.count) regions visited")
                            .font(.headline)
                        Text("\(all.filter(\.isComplete).count) fully explored")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("regionsSummary")
            }

            ForEach(NamedRegion.Kind.allCases, id: \.self) { kind in
                let rows = shown.filter { $0.region.kind == kind }
                if !rows.isEmpty {
                    Section(kind.displayName) {
                        ForEach(rows, id: \.region.id) { coverage in
                            NavigationLink {
                                RegionDetailView(region: coverage.region, visitedPlaces: visitedPlaces)
                            } label: {
                                RegionRow(coverage: coverage)
                            }
                            .accessibilityIdentifier("region_\(coverage.region.id)")
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search regions or places")
        .navigationTitle("Regions")
    }
}

struct RegionRow: View {
    let coverage: RegionCoverage

    var body: some View {
        HStack(spacing: 12) {
            CoverageRing(fraction: coverage.fraction, lineWidth: 4)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(coverage.region.name)
                    .font(.body)
                Text(coverage.region.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(coverage.visitedCount)/\(coverage.totalMembers)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(coverage.isVisited ? .green : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(coverage.region.name), \(coverage.visitedCount) of \(coverage.totalMembers) visited")
    }
}

/// Region page: coverage ring and member checklist.
struct RegionDetailView: View {
    let region: NamedRegion
    let visitedPlaces: [VisitedPlace]

    private var currentCoverage: RegionCoverage {
        RegionResolver.coverage(of: region, visitedKeys: RegionResolver.visitedKeys(from: visitedPlaces))
    }

    var body: some View {
        let coverage = currentCoverage
        List {
            Section {
                VStack(spacing: 12) {
                    ZStack {
                        CoverageRing(fraction: coverage.fraction, lineWidth: 12)
                        VStack(spacing: 0) {
                            Text("\(Int((coverage.fraction * 100).rounded()))%")
                                .font(.title.bold().monospacedDigit())
                            Text("\(coverage.visitedCount) of \(coverage.totalMembers)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 140, height: 140)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(coverage.visitedCount) of \(coverage.totalMembers) places visited")
                    .accessibilityIdentifier("regionCoverageRing")

                    Text(region.blurb)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    if coverage.isComplete {
                        Label("Fully explored", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    } else if coverage.isVisited {
                        Label("Visited", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                ForEach(region.memberKeys, id: \.self) { key in
                    let visited = coverage.isMemberVisited(key)
                    HStack(spacing: 12) {
                        Image(systemName: visited ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(visited ? .green : .secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(region.memberName(key))
                            Text(Self.memberLevel(key))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(region.memberName(key)), \(visited ? "visited" : "not visited")")
                    .accessibilityIdentifier("regionMember_\(key)")
                }
            } header: {
                Text("Places in this region")
            } footer: {
                if region.memberKeys.contains(where: { if case .usCounty = RegionMemberKey($0) { return true }; return false }) {
                    Text("Counties count once county visits are recorded.")
                }
            }
        }
        .navigationTitle(region.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    static func memberLevel(_ key: String) -> String {
        switch RegionMemberKey(key) {
        case .country: return "Country"
        case .subdivision(let country, _):
            return GeographicData.countries.first { $0.id == country }?.name ?? country
        case .usCounty: return "US county"
        case .city: return "City"
        case nil: return ""
        }
    }
}

struct CoverageRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(fraction, 0), 1)))
                .stroke(Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

/// Stats-screen entry to the regions list.
struct NamedRegionsStatRow: View {
    let visitedPlaces: [VisitedPlace]
    var catalog: NamedRegionCatalog = .bundled

    var body: some View {
        let coverages = catalog.coverage(visitedKeys: RegionResolver.visitedKeys(from: visitedPlaces))
        let visited = coverages.filter(\.isVisited).count
        HStack(spacing: 12) {
            CoverageRing(fraction: coverages.isEmpty ? 0 : Double(visited) / Double(coverages.count), lineWidth: 5)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Regions")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(visited) of \(coverages.count) named regions visited")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
        )
        .accessibilityElement(children: .combine)
    }
}
