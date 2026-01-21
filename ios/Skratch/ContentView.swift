import MapKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<VisitedPlace> { !$0.isDeleted })
    private var visitedPlaces: [VisitedPlace]

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WorldMapView(visitedPlaces: visitedPlaces)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(0)

            CountryListView(visitedPlaces: visitedPlaces)
                .tabItem {
                    Label("Countries", systemImage: "checklist")
                }
                .tag(1)

            StatsView(visitedPlaces: visitedPlaces)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Account") {
                    if Task { await APIClient.shared.isAuthenticated } != nil {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text("Signed In")
                                    .font(.headline)
                                Text("Apple ID")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // Sync Section
                Section("Sync") {
                    SyncStatusRow()

                    Button {
                        Task {
                            await SyncManager.shared.forceFullSync()
                        }
                    } label: {
                        Label("Force Full Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                // App Info Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                            .foregroundStyle(.secondary)
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingDeleteAccountAlert = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                } footer: {
                    Text("This will permanently delete your account and all data. This action cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? Your local data will be preserved.")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
        }
    }

    private func signOut() {
        Task {
            await APIClient.shared.clearTokens()
            // Post notification to reset app state if needed
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        }
    }

    private func deleteAccount() {
        // TODO: Implement account deletion through API
        // For now, just sign out
        signOut()
    }
}

// MARK: - Sync Status Row

struct SyncStatusRow: View {
    @State private var syncManager = SyncManager.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if syncManager.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Syncing...")
                    } else if let error = syncManager.error {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Sync Error")
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Synced")
                    }
                }
                .font(.subheadline)

                if let lastSync = syncManager.lastSyncAt {
                    Text("Last: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Never synced")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = syncManager.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            if !syncManager.isSyncing {
                Button {
                    Task {
                        await syncManager.sync()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

// MARK: - Sync Indicator (compact for toolbar)

struct SyncIndicator: View {
    @State private var syncManager = SyncManager.shared

    var body: some View {
        Group {
            if syncManager.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
            } else if syncManager.error != nil {
                Image(systemName: "exclamationmark.icloud.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
            } else if syncManager.lastSyncAt != nil {
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Image(systemName: "icloud.slash")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userDidSignOut = Notification.Name("userDidSignOut")
}

// MARK: - World Map View with Country Boundaries

struct WorldMapView: View {
    let visitedPlaces: [VisitedPlace]

    @State private var selectedCountry: String?

    private var visitedCountryCodes: Set<String> {
        Set(
            visitedPlaces
                .filter { $0.regionType == VisitedPlace.RegionType.country.rawValue }
                .map { $0.regionCode }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Use the new CountryMapView with boundary overlays
                CountryMapView(
                    visitedCountryCodes: visitedCountryCodes,
                    selectedCountry: $selectedCountry
                )
                .ignoresSafeArea(edges: .bottom)

                // Overlay showing visited count
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(visitedCountryCodes.count) countries")
                                .font(.headline)
                            Text("\(visitedPlaces.count) total places")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Skratch")
        }
    }
}

// MARK: - Country List View with Checkboxes

struct CountryListView: View {
    let visitedPlaces: [VisitedPlace]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var expandedCountries: Set<String> = []
    // Start with all continents collapsed
    @State private var collapsedContinents: Set<String> = Set(Continent.allCases.map { $0.id })
    @State private var isRefreshing = false

    private var visitedCodes: Set<String> {
        Set(visitedPlaces.map { "\($0.regionType):\($0.regionCode)" })
    }

    private var isSearching: Bool {
        !searchText.isEmpty
    }

    private var filteredCountries: [Country] {
        if searchText.isEmpty {
            return GeographicData.countries
        }
        return GeographicData.countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func visitedCountInContinent(_ continent: Continent) -> Int {
        GeographicData.countries
            .filter { $0.continent == continent.rawValue }
            .filter { isVisited(country: $0.id) }
            .count
    }

    private func totalCountInContinent(_ continent: Continent) -> Int {
        GeographicData.countries
            .filter { $0.continent == continent.rawValue }
            .count
    }

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    // Flat list when searching
                    ForEach(filteredCountries.sorted { $0.name < $1.name }) { country in
                        CountryRow(
                            country: country,
                            isVisited: isVisited(country: country.id),
                            isExpanded: expandedCountries.contains(country.id),
                            visitedStates: visitedStatesFor(country: country.id),
                            onToggleCountry: { toggleCountry(country) },
                            onToggleExpand: { toggleExpand(country.id) },
                            onToggleState: { state in toggleState(state, country: country) }
                        )
                    }
                } else {
                    // Grouped by continent with collapsible sections
                    ForEach(GeographicData.countriesByContinent, id: \.continent.id) { group in
                        Section {
                            if !collapsedContinents.contains(group.continent.id) {
                                ForEach(group.countries) { country in
                                    CountryRow(
                                        country: country,
                                        isVisited: isVisited(country: country.id),
                                        isExpanded: expandedCountries.contains(country.id),
                                        visitedStates: visitedStatesFor(country: country.id),
                                        onToggleCountry: { toggleCountry(country) },
                                        onToggleExpand: { toggleExpand(country.id) },
                                        onToggleState: { state in toggleState(state, country: country) }
                                    )
                                }
                            }
                        } header: {
                            Button {
                                withAnimation {
                                    if collapsedContinents.contains(group.continent.id) {
                                        collapsedContinents.remove(group.continent.id)
                                    } else {
                                        collapsedContinents.insert(group.continent.id)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(group.continent.emoji)
                                    Text(group.continent.rawValue)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(visitedCountInContinent(group.continent))/\(totalCountInContinent(group.continent))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: collapsedContinents.contains(group.continent.id) ? "chevron.right" : "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search countries")
            .refreshable {
                await refreshData()
            }
            .navigationTitle("Countries")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        SyncIndicator()
                        Text("\(countVisitedCountries())/\(GeographicData.countries.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func refreshData() async {
        isRefreshing = true
        await SyncManager.shared.sync()
        isRefreshing = false
    }

    private func isVisited(country code: String) -> Bool {
        visitedCodes.contains("country:\(code)")
    }

    private func visitedStatesFor(country code: String) -> Set<String> {
        let type =
            code == "US"
            ? VisitedPlace.RegionType.usState.rawValue
            : VisitedPlace.RegionType.canadianProvince.rawValue
        return Set(
            visitedPlaces
                .filter { $0.regionType == type }
                .map { $0.regionCode }
        )
    }

    private func countVisitedCountries() -> Int {
        visitedPlaces.filter { $0.regionType == VisitedPlace.RegionType.country.rawValue }.count
    }

    private func toggleCountry(_ country: Country) {
        let code = "country:\(country.id)"
        if visitedCodes.contains(code) {
            // Remove
            if let place = visitedPlaces.first(where: {
                $0.regionType == VisitedPlace.RegionType.country.rawValue
                    && $0.regionCode == country.id
            }) {
                place.isDeleted = true
                place.lastModifiedAt = Date()
            }
        } else {
            // Add
            let place = VisitedPlace(
                regionType: .country,
                regionCode: country.id,
                regionName: country.name
            )
            modelContext.insert(place)
        }
    }

    private func toggleExpand(_ countryCode: String) {
        if expandedCountries.contains(countryCode) {
            expandedCountries.remove(countryCode)
        } else {
            expandedCountries.insert(countryCode)
        }
    }

    private func toggleState(_ state: StateProvince, country: Country) {
        let type: VisitedPlace.RegionType =
            country.id == "US" ? .usState : .canadianProvince
        let code = "\(type.rawValue):\(state.id)"

        if visitedCodes.contains(code) {
            // Remove
            if let place = visitedPlaces.first(where: {
                $0.regionType == type.rawValue && $0.regionCode == state.id
            }) {
                place.isDeleted = true
                place.lastModifiedAt = Date()
            }
        } else {
            // Add
            let place = VisitedPlace(
                regionType: type,
                regionCode: state.id,
                regionName: state.name
            )
            modelContext.insert(place)
        }
    }
}

struct CountryRow: View {
    let country: Country
    let isVisited: Bool
    let isExpanded: Bool
    let visitedStates: Set<String>
    let onToggleCountry: () -> Void
    let onToggleExpand: () -> Void
    let onToggleState: (StateProvince) -> Void

    private var states: [StateProvince] {
        GeographicData.states(for: country.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Country row - entire row is tappable
            HStack {
                Button(action: onToggleCountry) {
                    HStack {
                        Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isVisited ? .green : .secondary)
                            .font(.title2)

                        VStack(alignment: .leading) {
                            Text(country.name)
                                .foregroundStyle(.primary)
                            Text(country.id)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if country.hasStates {
                            // States indicator (tapping this area still toggles country)
                            Text("\(visitedStates.count)/\(states.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Expand/collapse button for states (separate tap target)
                if country.hasStates {
                    Button(action: onToggleExpand) {
                        Image(
                            systemName: isExpanded
                                ? "chevron.down" : "chevron.right"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)

            // States (if expanded)
            if country.hasStates && isExpanded {
                VStack(spacing: 0) {
                    ForEach(states) { state in
                        StateRow(
                            state: state,
                            isVisited: visitedStates.contains(state.id),
                            onToggle: { onToggleState(state) }
                        )
                    }
                }
                .padding(.leading, 32)
            }
        }
    }
}

struct StateRow: View {
    let state: StateProvince
    let isVisited: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isVisited ? .blue : .secondary)

                Text(state.name)
                    .foregroundStyle(.primary)

                Text(state.id)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats View

struct StatsView: View {
    let visitedPlaces: [VisitedPlace]

    private var countriesCount: Int {
        visitedPlaces.filter { $0.regionType == VisitedPlace.RegionType.country.rawValue }.count
    }

    private var usStatesCount: Int {
        visitedPlaces.filter { $0.regionType == VisitedPlace.RegionType.usState.rawValue }.count
    }

    private var canadianProvincesCount: Int {
        visitedPlaces.filter { $0.regionType == VisitedPlace.RegionType.canadianProvince.rawValue }
            .count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.tint)

                        Text("Your Travel Stats")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 20)

                    // Stats Cards
                    VStack(spacing: 16) {
                        StatCard(
                            title: "Countries",
                            count: countriesCount,
                            total: GeographicData.countries.count,
                            icon: "flag.fill",
                            color: .green
                        )
                        StatCard(
                            title: "US States",
                            count: usStatesCount,
                            total: GeographicData.usStates.count,
                            icon: "star.fill",
                            color: .blue
                        )
                        StatCard(
                            title: "Canadian Provinces",
                            count: canadianProvincesCount,
                            total: GeographicData.canadianProvinces.count,
                            icon: "leaf.fill",
                            color: .red
                        )
                    }
                    .padding(.horizontal)

                    // Total
                    VStack(spacing: 4) {
                        Text("\(countriesCount + usStatesCount + canadianProvincesCount)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(.tint)

                        Text("Total Regions Visited")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    Spacer()
                }
            }
            .navigationTitle("Statistics")
        }
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let total: Int
    let icon: String
    let color: Color

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(count)/\(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(count), total: Double(total))
                .tint(color)

            HStack {
                Spacer()
                Text("\(percentage, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: VisitedPlace.self, inMemory: true)
}
