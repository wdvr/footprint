import SwiftData
import SwiftUI

// MARK: - Presentation helpers

extension MedalTierLevel {
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver: return Color(red: 0.62, green: 0.65, blue: 0.70)
        case .gold: return Color(red: 0.95, green: 0.75, blue: 0.10)
        case .platinum: return Color(red: 0.45, green: 0.75, blue: 0.85)
        }
    }
}

enum MedalFamily {
    static let order = ["countries", "subdivisions", "counties", "cities", "regions", "continents",
                        "completionist", "timezones", "distance", "streaks", "novelty"]

    static func displayName(_ family: String) -> String {
        switch family {
        case "countries": return "Countries"
        case "subdivisions": return "States & Regions"
        case "counties": return "Counties"
        case "cities": return "Cities & Capitals"
        case "regions": return "Named Regions"
        case "continents": return "Continents"
        case "completionist": return "Completionist"
        case "timezones": return "Time Zones"
        case "distance": return "Distance"
        case "streaks": return "Streaks & Cadence"
        case "novelty": return "Geography"
        default: return family.capitalized
        }
    }

    static func rank(_ family: String) -> Int { order.firstIndex(of: family) ?? order.count }
}

private extension MedalEngine.Result {
    var displayTier: MedalTierLevel? {
        guard let level = highestAward?.level else { return nil }
        // Single-threshold milestone medals show at platinum styling (§4.2).
        return definition.isMilestone ? .platinum : MedalTierLevel(rawValue: level)
    }

    var progressText: String {
        let format: (Double) -> String = { value in
            value >= 1000 ? value.formatted(.number.precision(.fractionLength(0))) : String(Int(value))
        }
        let unit = definition.metric == "distanceKm" ? " km" : definition.metric == "homeCountryCompletion" ? "%" : ""
        return "\(format(min(value, progressTotal)))/\(format(progressTotal))\(unit)"
    }
}

// MARK: - Medal icon

struct MedalBadge: View {
    let icon: String
    let tier: MedalTierLevel?
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(tier.map { AnyShapeStyle($0.color.gradient) } ?? AnyShapeStyle(Color.gray.opacity(0.2)))
            Circle()
                .strokeBorder(tier?.color.opacity(0.6) ?? Color.gray.opacity(0.35), lineWidth: size * 0.06)
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tier == nil ? Color.gray : Color.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Cabinet

struct MedalsView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", earned = "Earned", inProgress = "In Progress", locked = "Locked"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var visitedPlaces: [VisitedPlace]
    @State private var filter: Filter = .all
    private let service = MedalService.shared

    private var results: [MedalEngine.Result] {
        service.visibleResults(places: visitedPlaces).filter { result in
            switch filter {
            case .all: return true
            case .earned: return result.isEarned
            case .inProgress: return !result.isEarned && result.value > 0
            case .locked: return !result.isEarned && result.value == 0
            }
        }
    }

    private var families: [(String, [MedalEngine.Result])] {
        Dictionary(grouping: results, by: \.definition.family)
            .sorted { MedalFamily.rank($0.key) < MedalFamily.rank($1.key) }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("medalsFilter")

                if families.isEmpty {
                    ContentUnavailableView("No medals here yet", systemImage: "medal",
                                           description: Text("Keep exploring: medals award automatically, even offline."))
                }

                ForEach(families, id: \.0) { family, medals in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(MedalFamily.displayName(family))
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 16) {
                            ForEach(medals) { result in
                                NavigationLink {
                                    MedalDetailView(result: result)
                                } label: {
                                    MedalTile(result: result)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Medals")
        .task {
            if service.results.isEmpty { service.evaluate(in: modelContext) }
        }
    }
}

struct MedalTile: View {
    let result: MedalEngine.Result

    var body: some View {
        VStack(spacing: 6) {
            MedalBadge(icon: result.definition.icon, tier: result.displayTier)
            Text(result.definition.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if result.nextTier != nil {
                ProgressView(value: result.progressFraction)
                    .tint(result.displayTier?.color ?? .gray)
                    .frame(width: 64)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("medal_\(result.id)")
    }

    private var accessibilityText: String {
        let tier = result.highestAward.map { "\(MedalTierLevel(rawValue: $0.level)?.displayName ?? $0.level) earned" } ?? "Not earned"
        return "\(result.definition.name), \(tier), \(result.progressText)"
    }
}

// MARK: - Detail

struct MedalDetailView: View {
    let result: MedalEngine.Result
    @Query private var earnedMedals: [EarnedMedal]

    private var earned: EarnedMedal? { earnedMedals.first { $0.medalId == result.id } }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    MedalBadge(icon: result.definition.icon, tier: tierForDisplay, size: 96)
                    Text(result.definition.name).font(.title2.bold())
                    Text(result.definition.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if result.nextTier != nil {
                        ProgressView(value: result.progressFraction) {
                            Text(result.progressText).font(.caption)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Tiers") {
                ForEach(result.definition.tiers, id: \.level) { tier in
                    let record = earned?.tierHistory.first { $0.level == tier.level }
                    HStack {
                        Circle()
                            .fill(MedalTierLevel(rawValue: tier.level)?.color ?? .gray)
                            .frame(width: 12, height: 12)
                            .opacity(record == nil ? 0.3 : 1)
                        VStack(alignment: .leading) {
                            Text("\(MedalTierLevel(rawValue: tier.level)?.displayName ?? tier.level) · \(Int(tier.threshold).formatted())")
                            if let record {
                                Text("\(record.earnedAt.formatted(date: .abbreviated, time: .omitted)) · \(record.trigger)\(record.isLegacy ? " (from your earlier badge)" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if record != nil {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            if let note = result.definition.note {
                Section { Text(note).font(.footnote).foregroundStyle(.secondary) }
            }

            if let earned {
                Section {
                    MedalShareButton(definition: result.definition, earned: earned)
                }
            }
        }
        .navigationTitle(result.definition.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tierForDisplay: MedalTierLevel? {
        guard let earned else { return nil }
        return result.definition.isMilestone ? MedalTierLevel.platinum : earned.tier
    }
}

// MARK: - Share card (rendered locally)

struct MedalShareCard: View {
    let definition: MedalCatalog.Definition
    let tier: MedalTierLevel
    let earnedAt: Date

    var body: some View {
        VStack(spacing: 16) {
            MedalBadge(icon: definition.icon, tier: tier, size: 140)
            Text(definition.name).font(.largeTitle.bold())
            Text(definition.isMilestone ? definition.description : "\(tier.displayName) · \(definition.description)")
                .font(.title3)
                .multilineTextAlignment(.center)
            Text("Earned \(earnedAt.formatted(date: .long, time: .omitted))")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Footprint").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: 540, height: 540)
        .background(LinearGradient(colors: [tier.color.opacity(0.25), .white], startPoint: .top, endPoint: .bottom))
        .environment(\.colorScheme, .light)
    }
}

struct MedalShareButton: View {
    let definition: MedalCatalog.Definition
    let earned: EarnedMedal

    var body: some View {
        if let image = renderedImage {
            ShareLink(item: image, preview: SharePreview(definition.name, image: image)) {
                Label("Share Medal", systemImage: "square.and.arrow.up")
            }
        }
    }

    @MainActor private var renderedImage: Image? {
        let tier = definition.isMilestone ? MedalTierLevel.platinum : earned.tier
        let renderer = ImageRenderer(content: MedalShareCard(definition: definition, tier: tier, earnedAt: earned.earnedAt))
        renderer.scale = 2
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

// MARK: - Surfacing (§4.3)

struct MedalSurfacingSheet: View {
    let medals: [EarnedMedal]
    let onDone: () -> Void
    @State private var page = 0
    private let catalog = MedalService.shared.catalog

    var body: some View {
        VStack(spacing: 16) {
            Text(medals.count == 1 ? "New Medal" : "\(medals.count) New Medals")
                .font(.headline)
                .padding(.top)
            TabView(selection: $page) {
                ForEach(Array(medals.enumerated()), id: \.offset) { index, medal in
                    card(for: medal).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: medals.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < medals.count - 1 ? "Next" : "Done") {
                if page < medals.count - 1 { withAnimation { page += 1 } } else { onDone() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("medalSheetNext")
            if medals.count > 1 && page < medals.count - 1 {
                Button("Skip All", action: onDone).font(.footnote)
            }
        }
        .padding(.bottom)
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func card(for medal: EarnedMedal) -> some View {
        let definition = catalog?.medals.first { $0.id == medal.medalId }
        VStack(spacing: 12) {
            MedalBadge(icon: definition?.icon ?? "medal", tier: definition?.isMilestone == true ? MedalTierLevel.platinum : medal.tier, size: 110)
            Text(definition?.name ?? medal.medalId).font(.title2.bold())
            if definition?.isMilestone == false {
                Text(medal.tier.displayName).font(.headline).foregroundStyle(medal.tier.color)
            }
            if let top = medal.tierHistory.last {
                Text("\(top.earnedAt.formatted(date: .abbreviated, time: .omitted)) · \(top.trigger)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if medal.isRetroactive {
                Text("Earned from your travel history").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

/// Keeps medals current (after pipeline passes, imports and edits all change `VisitedPlace`) and
/// presents newly earned medals the next time the app is in front of the user.
struct MedalAwardsModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var places: [VisitedPlace]
    @Query(filter: #Predicate<EarnedMedal> { $0.surfacedAt == nil }) private var unseen: [EarnedMedal]
    @State private var showingSheet = false
    @State private var presented: [EarnedMedal] = []

    private var signature: Int {
        var hasher = Hasher()
        hasher.combine(places.count)
        for place in places {
            hasher.combine(place.lastModifiedAt)
        }
        return hasher.finalize()
    }

    func body(content: Content) -> some View {
        content
            .task { evaluate() }
            .onChange(of: signature) { evaluate() }
            .onChange(of: unseen.count) { presentIfNeeded() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { evaluate() }
            }
            .sheet(isPresented: $showingSheet, onDismiss: dismiss) {
                MedalSurfacingSheet(medals: presented) { showingSheet = false }
            }
    }

    private func evaluate() {
        MedalService.shared.evaluate(in: modelContext)
        presentIfNeeded()
    }

    private func presentIfNeeded() {
        guard !showingSheet, !unseen.isEmpty, !CommandLine.arguments.contains("-UITestingMode") else { return }
        let catalog = MedalService.shared.catalog
        presented = unseen.sorted { a, b in
            let rankA = catalog?.rank(of: a.tierLevel) ?? 0, rankB = catalog?.rank(of: b.tierLevel) ?? 0
            if rankA != rankB { return rankA > rankB }
            let familyA = catalog?.medals.first { $0.id == a.medalId }?.family ?? ""
            let familyB = catalog?.medals.first { $0.id == b.medalId }?.family ?? ""
            return MedalFamily.rank(familyA) < MedalFamily.rank(familyB)
        }
        showingSheet = true
    }

    private func dismiss() {
        MedalService.shared.markSurfaced(presented, in: modelContext)
        presented = []
    }
}

extension View {
    func medalAwards() -> some View { modifier(MedalAwardsModifier()) }
}
