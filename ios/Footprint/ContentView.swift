import MapKit
import SwiftData
import SwiftUI
import WidgetKit

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
        .onChange(of: visitedPlaces.count) {
            updateWidgetData()
        }
        .onAppear {
            updateWidgetData()
        }
    }

    /// Update shared UserDefaults for widget
    private func updateWidgetData() {
        let countriesVisited = visitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
        }.count

        let statesVisited = visitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.usState.rawValue ||
            $0.regionType == VisitedPlace.RegionType.canadianProvince.rawValue
        }.count

        // Save to shared UserDefaults for widget
        if let defaults = UserDefaults(suiteName: "group.com.wd.footprint") {
            defaults.set(countriesVisited, forKey: "countriesVisited")
            defaults.set(statesVisited, forKey: "statesVisited")
        }

        // Tell widget to reload
        WidgetCenter.shared.reloadAllTimelines()
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
                .accessibilityLabel("Sync now")
                .accessibilityHint("Double tap to synchronize your travel data")
            }
        }
        .accessibilityElement(children: .combine)
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedCountry: String?
    @State private var showingCountryPopup = false
    @State private var showingStateMap = false
    @State private var stateMapCountry: String?
    @State private var showListView = false
    @State private var locationManager = LocationManager()
    @State private var centerOnUserLocation = false

    private var visitedCountryCodes: Set<String> {
        Set(
            visitedPlaces
                .filter { $0.regionType == VisitedPlace.RegionType.country.rawValue && !$0.isDeleted }
                .map { $0.regionCode }
        )
    }

    private var visitedStateCodes: Set<String> {
        var codes: Set<String> = []
        for place in visitedPlaces where !place.isDeleted {
            if place.regionType == VisitedPlace.RegionType.usState.rawValue {
                codes.insert("US-\(place.regionCode)")
            } else if place.regionType == VisitedPlace.RegionType.canadianProvince.rawValue {
                codes.insert("CA-\(place.regionCode)")
            }
        }
        return codes
    }

    private var selectedCountryInfo: Country? {
        guard let code = selectedCountry else { return nil }
        return GeographicData.countries.first { $0.id == code }
    }

    private var isSelectedCountryVisited: Bool {
        guard let code = selectedCountry else { return false }
        return visitedCountryCodes.contains(code)
    }

    private func visitedStateCodes(for countryCode: String) -> Set<String> {
        let regionType: String = countryCode == "US"
            ? VisitedPlace.RegionType.usState.rawValue
            : VisitedPlace.RegionType.canadianProvince.rawValue
        return Set(
            visitedPlaces
                .filter { $0.regionType == regionType }
                .map { $0.regionCode }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Show list view for VoiceOver users or when toggled
                if showListView || voiceOverEnabled {
                    AccessibleMapSummary(visitedPlaces: visitedPlaces)
                } else {
                    // Use the new CountryMapView with boundary overlays
                    CountryMapView(
                        visitedCountryCodes: visitedCountryCodes,
                        visitedStateCodes: visitedStateCodes,
                        selectedCountry: $selectedCountry,
                        centerOnUserLocation: $centerOnUserLocation,
                        onCountryTapped: { countryCode in
                            selectedCountry = countryCode
                        },
                        showUserLocation: locationManager.isTracking
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .onChange(of: selectedCountry) { _, newValue in
                        if newValue != nil {
                            showingCountryPopup = true
                        }
                    }

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
            }
            .navigationTitle("Footprint")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if locationManager.authorizationStatus == .notDetermined {
                            locationManager.requestPermission()
                        } else if locationManager.isTracking {
                            // When already tracking, center on user location
                            centerOnUserLocation = true
                        } else {
                            // Start tracking
                            locationManager.startTracking()
                        }
                    } label: {
                        Image(systemName: locationManager.isTracking ? "location.fill" : "location")
                            .foregroundStyle(locationManager.isTracking ? .blue : .primary)
                    }
                    .accessibilityLabel(locationManager.isTracking ? "Center on current location" : "Start tracking location")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        conditionalWithAnimation(.easeInOut, reduceMotion: reduceMotion) {
                            showListView.toggle()
                        }
                    } label: {
                        Image(systemName: showListView ? "map" : "list.bullet")
                    }
                    .accessibilityLabel(showListView ? "Show map" : "Show list")
                    .accessibilityHint("Double tap to switch to \(showListView ? "map" : "list") view")
                }
            }
            .onAppear {
                setupLocationCallbacks()
            }
            .sheet(isPresented: $showingCountryPopup) {
                if let country = selectedCountryInfo {
                    CountryInfoPopup(
                        country: country,
                        isVisited: isSelectedCountryVisited,
                        onToggle: {
                            toggleCountryVisited(country)
                        },
                        onDismiss: {
                            showingCountryPopup = false
                            selectedCountry = nil
                        },
                        onViewStates: country.hasStates ? {
                            stateMapCountry = country.id
                            showingStateMap = true
                        } : nil
                    )
                    .presentationDetents([.height(country.hasStates ? 280 : 200)])
                    .presentationDragIndicator(.visible)
                } else if let code = selectedCountry {
                    // Territory or region not in our country list (e.g., French Guiana, Greenland)
                    let territoryName = TerritoryMapping.territoryName(for: code)
                    let isTerritoryVisited = visitedPlaces.contains {
                        $0.regionType == VisitedPlace.RegionType.country.rawValue
                            && $0.regionCode == code
                            && !$0.isDeleted
                    }

                    TerritoryInfoPopup(
                        regionCode: code,
                        territoryName: territoryName,
                        isVisited: isTerritoryVisited,
                        onToggle: {
                            toggleTerritoryVisited(code: code, name: territoryName)
                        },
                        onDismiss: {
                            showingCountryPopup = false
                            selectedCountry = nil
                        }
                    )
                    .presentationDetents([.height(200)])
                    .presentationDragIndicator(.visible)
                }
            }
            .fullScreenCover(isPresented: $showingStateMap) {
                if let countryCode = stateMapCountry {
                    StateMapSheet(
                        countryCode: countryCode,
                        visitedPlaces: visitedPlaces,
                        onDismiss: {
                            showingStateMap = false
                            stateMapCountry = nil
                        }
                    )
                }
            }
        }
    }

    private func toggleCountryVisited(_ country: Country) {
        if isSelectedCountryVisited {
            // Remove from visited
            if let place = visitedPlaces.first(where: {
                $0.regionType == VisitedPlace.RegionType.country.rawValue
                    && $0.regionCode == country.id
            }) {
                place.isDeleted = true
                place.lastModifiedAt = Date()
            }
        } else {
            // Add to visited
            let place = VisitedPlace(
                regionType: .country,
                regionCode: country.id,
                regionName: country.name
            )
            modelContext.insert(place)
        }
    }

    private func toggleTerritoryVisited(code: String, name: String) {
        let existingPlace = visitedPlaces.first {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
                && $0.regionCode == code
                && !$0.isDeleted
        }

        if let place = existingPlace {
            // Remove from visited
            place.isDeleted = true
            place.lastModifiedAt = Date()
        } else {
            // Add to visited
            let place = VisitedPlace(
                regionType: .country,
                regionCode: code,
                regionName: name
            )
            modelContext.insert(place)
        }
    }

    private func setupLocationCallbacks() {
        locationManager.onCountryDetected = { countryCode in
            // Check if country is not already visited
            let isVisited = visitedPlaces.contains {
                $0.regionType == VisitedPlace.RegionType.country.rawValue
                    && $0.regionCode == countryCode
                    && !$0.isDeleted
            }
            if !isVisited {
                // Auto-mark country as visited
                if let country = GeographicData.countries.first(where: { $0.id == countryCode }) {
                    let place = VisitedPlace(
                        regionType: .country,
                        regionCode: country.id,
                        regionName: country.name
                    )
                    modelContext.insert(place)
                }
            }
        }

        locationManager.onStateDetected = { countryCode, stateCode in
            let regionType: VisitedPlace.RegionType = countryCode == "US" ? .usState : .canadianProvince
            let isVisited = visitedPlaces.contains {
                $0.regionType == regionType.rawValue
                    && $0.regionCode == stateCode
                    && !$0.isDeleted
            }
            if !isVisited {
                // Auto-mark state/province as visited
                let stateName = GeographicData.states(for: countryCode).first { $0.id == stateCode }?.name ?? stateCode
                let place = VisitedPlace(
                    regionType: regionType,
                    regionCode: stateCode,
                    regionName: stateName
                )
                modelContext.insert(place)
            }
        }
    }
}

// MARK: - Country Info Popup

struct CountryInfoPopup: View {
    let country: Country
    let isVisited: Bool
    let onToggle: () -> Void
    let onDismiss: () -> Void
    var onViewStates: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(country.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(country.continent) • \(country.id)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            // Toggle Button
            Button(action: {
                onToggle()
                onDismiss()
            }) {
                HStack {
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                    Text(isVisited ? "Visited" : "Mark as Visited")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(isVisited ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(isVisited ? .green : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // View States/Provinces button for US and Canada
            if country.hasStates, let onViewStates = onViewStates {
                Button(action: {
                    onDismiss()
                    onViewStates()
                }) {
                    HStack {
                        Image(systemName: "map")
                            .font(.title2)
                        Text(country.id == "US" ? "View States" : "View Provinces")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Territory Info Popup (for regions not in our country list)

/// Mapping of territory codes to their parent country codes
enum TerritoryMapping {
    static let territories: [String: (name: String, parentCode: String)] = [
        // Denmark
        "GL": ("Greenland", "DK"),
        "FO": ("Faroe Islands", "DK"),

        // France
        "NC": ("New Caledonia", "FR"),
        "PF": ("French Polynesia", "FR"),
        "TF": ("French Southern Lands", "FR"),
        "WF": ("Wallis and Futuna", "FR"),
        "PM": ("Saint Pierre and Miquelon", "FR"),
        "BL": ("Saint Barthélemy", "FR"),
        "MF": ("Saint Martin", "FR"),
        "GF": ("French Guiana", "FR"),
        "GP": ("Guadeloupe", "FR"),
        "MQ": ("Martinique", "FR"),
        "RE": ("Réunion", "FR"),
        "YT": ("Mayotte", "FR"),

        // United Kingdom
        "FK": ("Falkland Islands", "GB"),
        "GI": ("Gibraltar", "GB"),
        "BM": ("Bermuda", "GB"),
        "KY": ("Cayman Islands", "GB"),
        "VG": ("British Virgin Islands", "GB"),
        "TC": ("Turks and Caicos Islands", "GB"),
        "MS": ("Montserrat", "GB"),
        "AI": ("Anguilla", "GB"),
        "SH": ("Saint Helena", "GB"),
        "PN": ("Pitcairn Islands", "GB"),
        "IO": ("British Indian Ocean Territory", "GB"),
        "GS": ("South Georgia and South Sandwich Islands", "GB"),
        "GG": ("Guernsey", "GB"),
        "JE": ("Jersey", "GB"),
        "IM": ("Isle of Man", "GB"),

        // United States
        "PR": ("Puerto Rico", "US"),
        "GU": ("Guam", "US"),
        "VI": ("U.S. Virgin Islands", "US"),
        "AS": ("American Samoa", "US"),
        "MP": ("Northern Mariana Islands", "US"),
        "UM": ("U.S. Minor Outlying Islands", "US"),

        // Netherlands
        "AW": ("Aruba", "NL"),
        "CW": ("Curaçao", "NL"),
        "SX": ("Sint Maarten", "NL"),
        "BQ": ("Caribbean Netherlands", "NL"),

        // Australia
        "NF": ("Norfolk Island", "AU"),
        "HM": ("Heard Island and McDonald Islands", "AU"),
        "CC": ("Cocos (Keeling) Islands", "AU"),
        "CX": ("Christmas Island", "AU"),
        "CS": ("Coral Sea Islands", "AU"),

        // New Zealand
        "CK": ("Cook Islands", "NZ"),
        "NU": ("Niue", "NZ"),
        "TK": ("Tokelau", "NZ"),

        // Norway
        "SJ": ("Svalbard and Jan Mayen", "NO"),
        "BV": ("Bouvet Island", "NO"),

        // China
        "HK": ("Hong Kong", "CN"),
        "MO": ("Macao", "CN"),

        // Finland
        "AX": ("Åland Islands", "FI"),

        // Disputed or special status (no parent)
        "AQ": ("Antarctica", ""),
        "CN-TW": ("Taiwan", ""),
        "TW": ("Taiwan", ""),
        "KO": ("Kosovo", ""),
        "EH": ("Western Sahara", ""),
        "PS": ("Palestine", ""),

        // Special cases
        "KA": ("Baikonur Cosmodrome", "KZ"),  // Leased to Russia but in Kazakhstan
        "SP": ("Southern Patagonian Ice Field", ""),  // Disputed Argentina/Chile
    ]

    static func parentCountry(for code: String) -> Country? {
        guard let info = territories[code],
              !info.parentCode.isEmpty else { return nil }
        return GeographicData.countries.first { $0.id == info.parentCode }
    }

    static func territoryName(for code: String) -> String {
        territories[code]?.name ?? "Unknown Territory"
    }
}

struct TerritoryInfoPopup: View {
    let regionCode: String
    let territoryName: String
    let isVisited: Bool
    let onToggle: () -> Void
    let onDismiss: () -> Void

    private var parentCountry: Country? {
        TerritoryMapping.parentCountry(for: regionCode)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(territoryName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    if let parent = parentCountry {
                        Text("Territory of \(parent.name) • \(regionCode)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Code: \(regionCode)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            // Allow marking this territory as visited
            Button(action: {
                onToggle()
                onDismiss()
            }) {
                HStack {
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                    Text(isVisited ? "Visited" : "Mark as Visited")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(isVisited ? Color.green.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(isVisited ? .green : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(territoryName), \(isVisited ? "visited" : "not visited")")
            .accessibilityHint("Double tap to toggle visited status")

            Spacer()
        }
        .padding()
    }
}

// MARK: - State Map Sheet

struct StateMapSheet: View {
    let countryCode: String
    let visitedPlaces: [VisitedPlace]
    let onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext

    @State private var selectedState: String?
    @State private var showingStatePopup = false

    private var visitedStateCodes: Set<String> {
        let regionType: String = countryCode == "US"
            ? VisitedPlace.RegionType.usState.rawValue
            : VisitedPlace.RegionType.canadianProvince.rawValue
        return Set(
            visitedPlaces
                .filter { $0.regionType == regionType && !$0.isDeleted }
                .map { $0.regionCode }
        )
    }

    private var countryName: String {
        countryCode == "US" ? "United States" : "Canada"
    }

    private var stateLabel: String {
        countryCode == "US" ? "States" : "Provinces"
    }

    private var selectedStateInfo: StateProvince? {
        guard let code = selectedState else { return nil }
        return GeographicData.states(for: countryCode).first { $0.id == code }
    }

    private var isSelectedStateVisited: Bool {
        guard let code = selectedState else { return false }
        return visitedStateCodes.contains(code)
    }

    @State private var showStateList = false

    private var allStates: [StateProvince] {
        GeographicData.states(for: countryCode).sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map view
                ZStack {
                    StateMapView(
                        countryCode: countryCode,
                        visitedStateCodes: visitedStateCodes,
                        selectedState: $selectedState,
                        onStateTapped: { stateCode in
                            selectedState = stateCode
                            showingStatePopup = true
                        }
                    )
                }
                .frame(maxHeight: showStateList ? UIScreen.main.bounds.height * 0.4 : .infinity)

                // Expandable state list
                VStack(spacing: 0) {
                    // Header bar - tap to expand/collapse
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showStateList.toggle()
                        }
                    } label: {
                        HStack {
                            Text("\(visitedStateCodes.count)/\(allStates.count) \(stateLabel)")
                                .font(.headline)
                            Spacer()
                            Image(systemName: showStateList ? "chevron.down" : "chevron.up")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                    }
                    .buttonStyle(.plain)

                    // State list (shown when expanded)
                    if showStateList {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(allStates) { state in
                                    let isVisited = visitedStateCodes.contains(state.id)
                                    Button {
                                        toggleStateDirectly(state)
                                    } label: {
                                        HStack {
                                            Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(isVisited ? .green : .secondary)
                                            Text(state.name)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text(state.id)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().padding(.leading)
                                }
                            }
                        }
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
                    }
                }
            }
            .navigationTitle(countryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showingStatePopup) {
                if let state = selectedStateInfo {
                    StateInfoPopup(
                        state: state,
                        isVisited: isSelectedStateVisited,
                        onToggle: {
                            toggleStateVisited(state)
                        },
                        onDismiss: {
                            showingStatePopup = false
                            selectedState = nil
                        }
                    )
                    .presentationDetents([.height(180)])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private func toggleStateDirectly(_ state: StateProvince) {
        let regionType: VisitedPlace.RegionType = countryCode == "US" ? .usState : .canadianProvince
        let isCurrentlyVisited = visitedStateCodes.contains(state.id)

        if isCurrentlyVisited {
            if let place = visitedPlaces.first(where: {
                $0.regionType == regionType.rawValue && $0.regionCode == state.id && !$0.isDeleted
            }) {
                place.isDeleted = true
                place.lastModifiedAt = Date()
            }
        } else {
            let place = VisitedPlace(
                regionType: regionType,
                regionCode: state.id,
                regionName: state.name
            )
            modelContext.insert(place)
        }
    }

    private func toggleStateVisited(_ state: StateProvince) {
        let regionType: VisitedPlace.RegionType = countryCode == "US" ? .usState : .canadianProvince

        if isSelectedStateVisited {
            if let place = visitedPlaces.first(where: {
                $0.regionType == regionType.rawValue && $0.regionCode == state.id
            }) {
                place.isDeleted = true
                place.lastModifiedAt = Date()
            }
        } else {
            let place = VisitedPlace(
                regionType: regionType,
                regionCode: state.id,
                regionName: state.name
            )
            modelContext.insert(place)
        }
    }
}

// MARK: - State Info Popup

struct StateInfoPopup: View {
    let state: StateProvince
    let isVisited: Bool
    let onToggle: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(state.id)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }

            // Toggle Button
            Button(action: {
                onToggle()
                onDismiss()
            }) {
                HStack {
                    Image(systemName: isVisited ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                    Text(isVisited ? "Visited" : "Mark as Visited")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(isVisited ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(isVisited ? .blue : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Country List View with Checkboxes

struct CountryListView: View {
    let visitedPlaces: [VisitedPlace]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                            let isExpanded = !collapsedContinents.contains(group.continent.id)
                            let visitedCount = visitedCountInContinent(group.continent)
                            let totalCount = totalCountInContinent(group.continent)

                            Button {
                                conditionalWithAnimation(.easeInOut(duration: 0.2), reduceMotion: reduceMotion) {
                                    if collapsedContinents.contains(group.continent.id) {
                                        collapsedContinents.remove(group.continent.id)
                                    } else {
                                        collapsedContinents.insert(group.continent.id)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(group.continent.emoji)
                                        .accessibilityHidden(true)
                                    Text(group.continent.rawValue)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(visitedCount)/\(totalCount)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(group.continent.rawValue), \(visitedCount) of \(totalCount) countries visited")
                            .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand")")
                            .accessibilityAddTraits(.isHeader)
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
                            .accessibilityHidden(true)

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
                                .accessibilityHidden(true)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(country.name), \(isVisited ? "visited" : "not visited")")
                .accessibilityHint("Double tap to toggle visited status")

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
                    .accessibilityLabel(isExpanded ? "Collapse states" : "Expand states")
                    .accessibilityHint("Double tap to \(isExpanded ? "hide" : "show") \(states.count) states")
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
                    .accessibilityHidden(true)

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
        .accessibilityLabel("\(state.name), \(isVisited ? "visited" : "not visited")")
        .accessibilityHint("Double tap to toggle visited status")
    }
}

// MARK: - Stats View

struct StatsView: View {
    let visitedPlaces: [VisitedPlace]

    @ScaledMetric(relativeTo: .largeTitle) private var globeSize: CGFloat = 60
    @ScaledMetric(relativeTo: .title) private var totalCountSize: CGFloat = 48

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
                            .font(.system(size: globeSize))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)

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
                            .font(.system(size: totalCountSize, weight: .bold))
                            .foregroundStyle(.tint)

                        Text("Total Regions Visited")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Total regions visited: \(countriesCount + usStatesCount + canadianProvincesCount)")

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
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(count)/\(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(count), total: Double(total))
                .tint(color)
                .accessibilityHidden(true)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(count) of \(total), \(String(format: "%.0f", percentage)) percent")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: VisitedPlace.self, inMemory: true)
}
