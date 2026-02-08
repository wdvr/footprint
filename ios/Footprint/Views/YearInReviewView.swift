import SwiftUI

// MARK: - Year in Review Data Model

struct YearInReviewData {
    let year: Int
    // Places where visitedDate falls in this year (first visited)
    let newCountries: [VisitedPlace]
    let newUSStates: [VisitedPlace]
    let newCanadianProvinces: [VisitedPlace]
    let newOtherRegions: [VisitedPlace]
    // Places where the visit overlaps with this year (visited OR departureDate in year)
    let visitedCountries: [VisitedPlace]
    let visitedUSStates: [VisitedPlace]
    let visitedCanadianProvinces: [VisitedPlace]
    let visitedOtherRegions: [VisitedPlace]
    let allVisitedPlaces: [VisitedPlace]

    var totalNewPlaces: Int {
        newCountries.count + newUSStates.count + newCanadianProvinces.count + newOtherRegions.count
    }

    var totalVisitedPlaces: Int {
        visitedCountries.count + visitedUSStates.count + visitedCanadianProvinces.count + visitedOtherRegions.count
    }

    var newCountriesCount: Int { newCountries.count }
    var newUSStatesCount: Int { newUSStates.count }
    var newCanadianProvincesCount: Int { newCanadianProvinces.count }
    var newOtherRegionsCount: Int { newOtherRegions.count }

    var visitedCountriesCount: Int { visitedCountries.count }
    var visitedUSStatesCount: Int { visitedUSStates.count }
    var visitedCanadianProvincesCount: Int { visitedCanadianProvinces.count }
    var visitedOtherRegionsCount: Int { visitedOtherRegions.count }

    // Continent stats for this year's countries (all visited, not just new)
    // Also includes parent countries derived from visited states/provinces
    var continentBreakdown: [LocalContinentStats] {
        var countryCodes = Set(visitedCountries.map { $0.regionCode })
        // Derive parent countries from visited states/provinces
        for place in (visitedUSStates + visitedCanadianProvinces + visitedOtherRegions) {
            if let parentCountry = YearInReviewData.regionTypeToCountry[place.regionType] {
                countryCodes.insert(parentCountry)
            }
        }
        return LocalContinentStats.calculateStats(visitedCountries: Array(countryCodes))
    }

    var topContinent: LocalContinentStats? {
        continentBreakdown.first(where: { $0.visited > 0 })
    }

    // Map from region type to parent country code for timezone/continent/flag calculations
    private static let regionTypeToCountry: [String: String] = [
        VisitedPlace.RegionType.usState.rawValue: "US",
        VisitedPlace.RegionType.canadianProvince.rawValue: "CA",
        VisitedPlace.RegionType.belgianProvince.rawValue: "BE",
        VisitedPlace.RegionType.dutchProvince.rawValue: "NL",
        VisitedPlace.RegionType.frenchRegion.rawValue: "FR",
        VisitedPlace.RegionType.spanishCommunity.rawValue: "ES",
        VisitedPlace.RegionType.italianRegion.rawValue: "IT",
        VisitedPlace.RegionType.germanState.rawValue: "DE",
        VisitedPlace.RegionType.ukCountry.rawValue: "GB",
        VisitedPlace.RegionType.russianFederalSubject.rawValue: "RU",
        VisitedPlace.RegionType.argentineProvince.rawValue: "AR",
        VisitedPlace.RegionType.australianState.rawValue: "AU",
        VisitedPlace.RegionType.mexicanState.rawValue: "MX",
        VisitedPlace.RegionType.brazilianState.rawValue: "BR",
    ]

    /// Convert country code to flag emoji
    static func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var flag = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                flag.append(String(unicode))
            }
        }
        return flag
    }

    // Time zone stats for this year (using all visited places, not just new)
    var timeZoneStats: TimeZoneLocalStats {
        // Start with explicitly visited countries
        var countryCodes = Set(visitedCountries.map { $0.regionCode })

        // Derive parent country codes from visited states/provinces
        // This ensures that e.g. visiting Belgian provinces counts Belgium's timezone
        let allStates = visitedUSStates + visitedCanadianProvinces + visitedOtherRegions
        for place in allStates {
            if let parentCountry = YearInReviewData.regionTypeToCountry[place.regionType] {
                countryCodes.insert(parentCountry)
            }
        }

        // Build state tuples for multi-timezone country resolution
        let stateTuples = allStates.map {
            ($0.regionType, $0.regionCode)
        }

        return TimeZoneLocalStats.calculate(
            visitedCountries: Array(countryCodes),
            visitedStates: stateTuples
        )
    }

    // Fun facts
    var continentPercentages: [(name: String, percentage: Double)] {
        continentBreakdown
            .filter { $0.visited > 0 }
            .map { (name: $0.name, percentage: $0.percentage) }
    }

    var mostVisitedContinentPercentage: (name: String, percentage: Double)? {
        // Of all visited countries (lifetime), find continents with most coverage
        let allCountryCodes = allVisitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
            && $0.isVisited && !$0.isDeleted
        }.map { $0.regionCode }

        let lifetimeStats = LocalContinentStats.calculateStats(visitedCountries: allCountryCodes)
        return lifetimeStats
            .filter { $0.visited > 0 }
            .map { (name: $0.name, percentage: $0.percentage) }
            .max(by: { $0.percentage < $1.percentage })
    }

    /// Country flags for all countries visited this year (including parent countries from states)
    var countryFlags: String {
        var countryCodes = Set(visitedCountries.map { $0.regionCode })
        for place in (visitedUSStates + visitedCanadianProvinces + visitedOtherRegions) {
            if let parentCountry = YearInReviewData.regionTypeToCountry[place.regionType] {
                countryCodes.insert(parentCountry)
            }
        }
        return countryCodes.sorted().map { Self.flagEmoji(for: $0) }.joined(separator: " ")
    }

    /// Unique country count including parent countries derived from states
    var uniqueCountryCount: Int {
        var countryCodes = Set(visitedCountries.map { $0.regionCode })
        for place in (visitedUSStates + visitedCanadianProvinces + visitedOtherRegions) {
            if let parentCountry = YearInReviewData.regionTypeToCountry[place.regionType] {
                countryCodes.insert(parentCountry)
            }
        }
        return countryCodes.count
    }

    /// Breakdown of "other regions" by their specific type (e.g., "Belgian Provinces", "French Regions")
    var otherRegionsByType: [(label: String, icon: String, color: String, count: Int, newCount: Int, places: [VisitedPlace], newPlaces: [VisitedPlace])] {
        let typeInfo: [(type: VisitedPlace.RegionType, label: String, icon: String, color: String)] = [
            (.australianState, "Australian States", "kangaroo", "orange"),
            (.mexicanState, "Mexican States", "map.fill", "green"),
            (.brazilianState, "Brazilian States", "map.fill", "green"),
            (.germanState, "German States", "map.fill", "yellow"),
            (.frenchRegion, "French Regions", "map.fill", "blue"),
            (.spanishCommunity, "Spanish Communities", "map.fill", "red"),
            (.italianRegion, "Italian Regions", "map.fill", "green"),
            (.dutchProvince, "Dutch Provinces", "map.fill", "orange"),
            (.belgianProvince, "Belgian Provinces", "map.fill", "yellow"),
            (.ukCountry, "UK Countries", "map.fill", "red"),
            (.russianFederalSubject, "Russian Regions", "map.fill", "blue"),
            (.argentineProvince, "Argentine Provinces", "map.fill", "blue"),
        ]

        var result: [(label: String, icon: String, color: String, count: Int, newCount: Int, places: [VisitedPlace], newPlaces: [VisitedPlace])] = []
        for info in typeInfo {
            let visited = visitedOtherRegions.filter { $0.regionType == info.type.rawValue }
            let new = newOtherRegions.filter { $0.regionType == info.type.rawValue }
            if !visited.isEmpty {
                result.append((label: info.label, icon: info.icon, color: info.color, count: visited.count, newCount: new.count, places: visited, newPlaces: new))
            }
        }
        return result
    }

    var hasData: Bool {
        totalVisitedPlaces > 0
    }

    /// Check if a place's visit overlaps with the given year.
    /// Only uses visitedDate - places without a visitedDate are excluded from Year in Review.
    private static func visitOverlapsYear(_ place: VisitedPlace, year: Int, calendar: Calendar) -> Bool {
        guard place.isVisited && !place.isDeleted else { return false }
        guard let visitedDate = place.visitedDate else { return false }

        let visitYear = calendar.component(.year, from: visitedDate)

        // If visitedDate is in this year, it overlaps
        if visitYear == year { return true }

        // If visitedDate is before this year, check if departureDate extends into this year
        if visitYear < year {
            if let departure = place.departureDate {
                let departureYear = calendar.component(.year, from: departure)
                return departureYear >= year
            }
        }

        return false
    }

    // Compute available years from all visited places that have a visitedDate set
    static func availableYears(from places: [VisitedPlace]) -> [Int] {
        let calendar = Calendar.current
        var years = Set<Int>()
        for place in places where place.isVisited && !place.isDeleted {
            guard let visitedDate = place.visitedDate else { continue }
            years.insert(calendar.component(.year, from: visitedDate))
            if let departureDate = place.departureDate {
                years.insert(calendar.component(.year, from: departureDate))
            }
        }
        return years.sorted(by: >)
    }

    /// Check if a region type belongs to a country tracked at country level (not state level)
    private static func isCountryLevelTracked(regionType: String) -> Bool {
        // Map region types to their parent country codes
        let regionToCountry: [String: String] = [
            VisitedPlace.RegionType.usState.rawValue: "US",
            VisitedPlace.RegionType.canadianProvince.rawValue: "CA",
            VisitedPlace.RegionType.australianState.rawValue: "AU",
            VisitedPlace.RegionType.mexicanState.rawValue: "MX",
            VisitedPlace.RegionType.brazilianState.rawValue: "BR",
            VisitedPlace.RegionType.germanState.rawValue: "DE",
            VisitedPlace.RegionType.frenchRegion.rawValue: "FR",
            VisitedPlace.RegionType.spanishCommunity.rawValue: "ES",
            VisitedPlace.RegionType.italianRegion.rawValue: "IT",
            VisitedPlace.RegionType.dutchProvince.rawValue: "NL",
            VisitedPlace.RegionType.belgianProvince.rawValue: "BE",
            VisitedPlace.RegionType.ukCountry.rawValue: "GB",
            VisitedPlace.RegionType.russianFederalSubject.rawValue: "RU",
            VisitedPlace.RegionType.argentineProvince.rawValue: "AR",
        ]
        guard let countryCode = regionToCountry[regionType] else { return false }
        return !AppSettings.shared.shouldTrackStates(for: countryCode)
    }

    static func compute(for year: Int, allPlaces: [VisitedPlace]) -> YearInReviewData {
        let calendar = Calendar.current

        // "New" places: visitedDate falls in this year (places without visitedDate are excluded)
        let newPlacesThisYear = allPlaces.filter { place in
            guard place.isVisited && !place.isDeleted else { return false }
            guard let visitedDate = place.visitedDate else { return false }
            return calendar.component(.year, from: visitedDate) == year
        }

        // "Visited" places: visit period overlaps with this year
        let visitedPlacesThisYear = allPlaces.filter { place in
            visitOverlapsYear(place, year: year, calendar: calendar)
        }

        // Categorize new places - exclude state-level data for countries tracked at country level
        let newCountriesArr = newPlacesThisYear.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
        }
        let newUSStatesArr = newPlacesThisYear.filter {
            $0.regionType == VisitedPlace.RegionType.usState.rawValue
            && !isCountryLevelTracked(regionType: $0.regionType)
        }
        let newCanadianProvincesArr = newPlacesThisYear.filter {
            $0.regionType == VisitedPlace.RegionType.canadianProvince.rawValue
            && !isCountryLevelTracked(regionType: $0.regionType)
        }
        let newOtherRegionsArr = newPlacesThisYear.filter { place in
            place.regionType != VisitedPlace.RegionType.country.rawValue
            && place.regionType != VisitedPlace.RegionType.usState.rawValue
            && place.regionType != VisitedPlace.RegionType.canadianProvince.rawValue
            && !isCountryLevelTracked(regionType: place.regionType)
        }

        // Categorize visited places - same filtering
        let visitedCountriesArr = visitedPlacesThisYear.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
        }
        let visitedUSStatesArr = visitedPlacesThisYear.filter {
            $0.regionType == VisitedPlace.RegionType.usState.rawValue
            && !isCountryLevelTracked(regionType: $0.regionType)
        }
        let visitedCanadianProvincesArr = visitedPlacesThisYear.filter {
            $0.regionType == VisitedPlace.RegionType.canadianProvince.rawValue
            && !isCountryLevelTracked(regionType: $0.regionType)
        }
        let visitedOtherRegionsArr = visitedPlacesThisYear.filter { place in
            place.regionType != VisitedPlace.RegionType.country.rawValue
            && place.regionType != VisitedPlace.RegionType.usState.rawValue
            && place.regionType != VisitedPlace.RegionType.canadianProvince.rawValue
            && !isCountryLevelTracked(regionType: place.regionType)
        }

        return YearInReviewData(
            year: year,
            newCountries: newCountriesArr,
            newUSStates: newUSStatesArr,
            newCanadianProvinces: newCanadianProvincesArr,
            newOtherRegions: newOtherRegionsArr,
            visitedCountries: visitedCountriesArr,
            visitedUSStates: visitedUSStatesArr,
            visitedCanadianProvinces: visitedCanadianProvincesArr,
            visitedOtherRegions: visitedOtherRegionsArr,
            allVisitedPlaces: allPlaces
        )
    }
}

// MARK: - Year in Review View

struct YearInReviewView: View {
    let visitedPlaces: [VisitedPlace]
    @State private var selectedYear: Int
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss

    private let availableYears: [Int]
    private var data: YearInReviewData {
        YearInReviewData.compute(for: selectedYear, allPlaces: visitedPlaces)
    }

    init(visitedPlaces: [VisitedPlace], initialYear: Int? = nil) {
        self.visitedPlaces = visitedPlaces
        let years = YearInReviewData.availableYears(from: visitedPlaces)
        self.availableYears = years
        let defaultYear = initialYear ?? years.first ?? Calendar.current.component(.year, from: Date())
        self._selectedYear = State(initialValue: defaultYear)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                backgroundGradient
                    .ignoresSafeArea()

                if data.hasData {
                    TabView(selection: $currentPage) {
                        TitleCard(year: selectedYear)
                            .tag(0)

                        CountsCard(data: data)
                            .tag(1)

                        YearMapCard(data: data)
                            .tag(2)

                        TopContinentCard(data: data)
                            .tag(3)

                        TimeZonesCard(data: data)
                            .tag(4)

                        FunFactsCard(data: data)
                            .tag(5)

                        SummaryCard(data: data)
                            .tag(6)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                } else {
                    noDataView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .principal) {
                    if availableYears.count > 1 {
                        Menu {
                            ForEach(availableYears, id: \.self) { year in
                                Button(String(year)) {
                                    withAnimation {
                                        selectedYear = year
                                        currentPage = 0
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(String(selectedYear))
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var backgroundGradient: some View {
        let gradients: [Int: [Color]] = [
            0: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.2, green: 0.1, blue: 0.4)],
            1: [Color(red: 0.0, green: 0.2, blue: 0.3), Color(red: 0.0, green: 0.3, blue: 0.4)],
            2: [Color(red: 0.1, green: 0.2, blue: 0.15), Color(red: 0.05, green: 0.3, blue: 0.2)],
            3: [Color(red: 0.3, green: 0.15, blue: 0.05), Color(red: 0.4, green: 0.2, blue: 0.1)],
            4: [Color(red: 0.2, green: 0.1, blue: 0.3), Color(red: 0.3, green: 0.15, blue: 0.4)],
            5: [Color(red: 0.15, green: 0.15, blue: 0.3), Color(red: 0.25, green: 0.1, blue: 0.35)],
            6: [Color(red: 0.1, green: 0.15, blue: 0.3), Color(red: 0.15, green: 0.2, blue: 0.4)],
        ]

        let colors = gradients[currentPage] ?? [.black, .gray]

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .animation(.easeInOut(duration: 0.5), value: currentPage)
    }

    private var noDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.6))

            Text("No Travel Data for \(String(selectedYear))")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Text("Add visit dates to your places to see your year in review.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                    Text("Enable location sharing")
                }
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill")
                    Text("Grant photo library access")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 8)

            Text("Location and photo data are processed locally on your device for the most detailed year in review.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Card 1: Title Card

struct TitleCard: View {
    let year: Int
    @State private var globeRotation: Double = 0
    @State private var showTitle = false
    @State private var showSubtitle = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated globe
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 40,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)

                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(globeRotation))
                    .scaleEffect(showTitle ? 1.0 : 0.5)
            }

            VStack(spacing: 12) {
                Text("Your Year in Travel")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)

                Text(String(year))
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(showSubtitle ? 1 : 0)
                    .scaleEffect(showSubtitle ? 1 : 0.8)
            }

            Spacer()

            VStack(spacing: 8) {
                Text("Swipe to explore")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(showSubtitle ? 1 : 0)

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text("Share your location and photo library access for the most detailed review")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white.opacity(0.35))
                .opacity(showSubtitle ? 1 : 0)
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                showTitle = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                showSubtitle = true
            }
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                globeRotation = 360
            }
        }
    }
}

// MARK: - Card 2: Counts Card

struct CountsCard: View {
    let data: YearInReviewData
    @State private var showContent = false
    @State private var animatedTotal: Int = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("You explored")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.7))
                .opacity(showContent ? 1 : 0)

            // Total counter
            VStack(spacing: 4) {
                Text("\(animatedTotal)")
                    .font(.system(size: 80, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())

                Text("places visited")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .opacity(showContent ? 1 : 0)

                if data.totalNewPlaces > 0 && data.totalNewPlaces < data.totalVisitedPlaces {
                    Text("\(data.totalNewPlaces) new")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.6))
                        .opacity(showContent ? 1 : 0)
                }
            }

            // Country flags row
            if !data.countryFlags.isEmpty {
                Text(data.countryFlags)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                    .padding(.horizontal, 24)

                if data.uniqueCountryCount > 0 {
                    Text("\(data.uniqueCountryCount) \(data.uniqueCountryCount == 1 ? "country" : "countries")")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .opacity(showContent ? 1 : 0)
                }
            }

            // Breakdown by region type
            ScrollView {
                VStack(spacing: 10) {
                    if data.visitedCountriesCount > 0 {
                        CountBreakdownRow(
                            icon: "flag.fill",
                            label: "Countries",
                            count: data.visitedCountriesCount,
                            newCount: data.newCountriesCount,
                            totalCount: data.visitedCountriesCount,
                            color: .green
                        )
                    }
                    if data.visitedUSStatesCount > 0 {
                        CountBreakdownRow(
                            icon: "star.fill",
                            label: "US States",
                            count: data.visitedUSStatesCount,
                            newCount: data.newUSStatesCount,
                            totalCount: data.visitedUSStatesCount,
                            color: .blue
                        )
                    }
                    if data.visitedCanadianProvincesCount > 0 {
                        CountBreakdownRow(
                            icon: "leaf.fill",
                            label: "Canadian Provinces",
                            count: data.visitedCanadianProvincesCount,
                            newCount: data.newCanadianProvincesCount,
                            totalCount: data.visitedCanadianProvincesCount,
                            color: .red
                        )
                    }
                    // Show each "other region" type separately instead of one generic bucket
                    ForEach(data.otherRegionsByType, id: \.label) { regionGroup in
                        CountBreakdownRow(
                            icon: "map.fill",
                            label: regionGroup.label,
                            count: regionGroup.count,
                            newCount: regionGroup.newCount,
                            totalCount: regionGroup.count,
                            color: .orange
                        )
                    }
                }
                .padding(.horizontal, 40)
            }
            .opacity(showContent ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
            animateCounters()
        }
    }

    private func animateCounters() {
        let totalSteps = 30
        let duration = 1.5
        let stepDuration = duration / Double(totalSteps)

        for step in 0...totalSteps {
            let delay = Double(step) * stepDuration + 0.4
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: stepDuration)) {
                    if step == totalSteps {
                        animatedTotal = data.totalVisitedPlaces
                    } else {
                        let progress = Double(step) / Double(totalSteps)
                        let easedProgress = 1 - pow(1 - progress, 3)
                        animatedTotal = Int(Double(data.totalVisitedPlaces) * easedProgress)
                    }
                }
            }
        }
    }
}

struct CountBreakdownRow: View {
    let icon: String
    let label: String
    let count: Int
    var newCount: Int = 0
    var totalCount: Int = 0
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                if newCount > 0 && newCount < totalCount {
                    Text("(\(newCount) new)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }
}

// MARK: - Card 3: Year Map Card

struct YearMapCard: View {
    let data: YearInReviewData
    @State private var showContent = false

    private var visitedCountryCodes: Set<String> {
        Set(data.visitedCountries.map { $0.regionCode })
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Your \(String(data.year)) Map")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .opacity(showContent ? 1 : 0)

            // List the places visited
            ScrollView {
                VStack(spacing: 8) {
                    if !data.visitedCountries.isEmpty {
                        PlaceListSection(
                            title: "Countries",
                            places: data.visitedCountries.map { $0.regionName }.sorted(),
                            icon: "flag.fill",
                            color: .green
                        )
                    }
                    if !data.visitedUSStates.isEmpty {
                        PlaceListSection(
                            title: "US States",
                            places: data.visitedUSStates.map { $0.regionName }.sorted(),
                            icon: "star.fill",
                            color: .blue
                        )
                    }
                    if !data.visitedCanadianProvinces.isEmpty {
                        PlaceListSection(
                            title: "Canadian Provinces",
                            places: data.visitedCanadianProvinces.map { $0.regionName }.sorted(),
                            icon: "leaf.fill",
                            color: .red
                        )
                    }
                    ForEach(data.otherRegionsByType, id: \.label) { regionGroup in
                        PlaceListSection(
                            title: regionGroup.label,
                            places: regionGroup.places.map { $0.regionName }.sorted(),
                            icon: "map.fill",
                            color: .orange
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 30)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                showContent = true
            }
        }
    }
}

struct PlaceListSection: View {
    let title: String
    let places: [String]
    let icon: String
    let color: Color

    @State private var expanded = false

    private var displayPlaces: [String] {
        if expanded || places.count <= 5 {
            return places
        }
        return Array(places.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(places.count)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }

            FlowLayout(spacing: 6) {
                ForEach(displayPlaces, id: \.self) { place in
                    Text(place)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.2))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                if places.count > 5 && !expanded {
                    Button {
                        withAnimation { expanded = true }
                    } label: {
                        Text("+\(places.count - 5) more")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.15))
                            .foregroundStyle(.white.opacity(0.7))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Flow Layout for tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            guard index < subviews.count else { break }
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.origin.x, y: bounds.minY + frame.origin.y),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

// MARK: - Card 4: Top Continent Card

struct TopContinentCard: View {
    let data: YearInReviewData
    @State private var showContent = false
    @State private var showBars = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if let top = data.topContinent {
                Text("Your Top Continent")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(showContent ? 1 : 0)

                VStack(spacing: 8) {
                    Text(top.emoji)
                        .font(.system(size: 64))
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.5)

                    Text(top.name)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(showContent ? 1 : 0)

                    Text("\(top.visited) \(top.visited == 1 ? "country" : "countries") visited this year")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .opacity(showContent ? 1 : 0)
                }

                // Continent bars
                VStack(spacing: 12) {
                    ForEach(data.continentBreakdown.filter { $0.visited > 0 }) { stat in
                        ContinentBarRow(stat: stat, isTop: stat.name == top.name, showBar: showBars)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
            } else {
                Text("No continents visited in \(String(data.year))")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
                showBars = true
            }
        }
    }
}

struct ContinentBarRow: View {
    let stat: LocalContinentStats
    let isTop: Bool
    let showBar: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(stat.emoji)
                    .font(.caption)
                Text(stat.name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(stat.visited)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(isTop ? .orange : .white.opacity(0.7))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            isTop ?
                            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.6)], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: showBar ? geo.size.width * CGFloat(stat.percentage / 100) : 0, height: 8)
                        .animation(.easeOut(duration: 0.8), value: showBar)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Card 5: Time Zones Card

struct TimeZonesCard: View {
    let data: YearInReviewData
    @State private var showContent = false
    @State private var showZones = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Time Zones Crossed")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .opacity(showContent ? 1 : 0)

            Text("\(data.timeZoneStats.zonesVisited)")
                .font(.system(size: 80, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.5)

            Text("time zones")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .opacity(showContent ? 1 : 0)

            // Time zone bar
            HStack(spacing: 2) {
                ForEach(-12..<15, id: \.self) { offset in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            data.timeZoneStats.visitedZones.contains(offset) ?
                            Color.purple :
                            Color.white.opacity(0.15)
                        )
                        .frame(height: 32)
                        .opacity(showZones ? 1 : 0.3)
                        .scaleEffect(y: showZones && data.timeZoneStats.visitedZones.contains(offset) ? 1 : 0.5)
                        .animation(
                            .easeOut(duration: 0.4).delay(Double(offset + 12) * 0.03),
                            value: showZones
                        )
                }
            }
            .padding(.horizontal, 24)

            HStack {
                if let west = data.timeZoneStats.farthestWest {
                    VStack(alignment: .leading) {
                        Text("Farthest West")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("UTC\(west >= 0 ? "+" : "")\(west)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                }
                Spacer()
                if let east = data.timeZoneStats.farthestEast {
                    VStack(alignment: .trailing) {
                        Text("Farthest East")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Text("UTC\(east >= 0 ? "+" : "")\(east)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 32)
            .opacity(showContent ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                showZones = true
            }
        }
    }
}

// MARK: - Card 6: Fun Facts Card

struct FunFactsCard: View {
    let data: YearInReviewData
    @State private var showFacts: [Bool] = Array(repeating: false, count: 5)

    private var facts: [(icon: String, text: String)] {
        var result: [(icon: String, text: String)] = []

        // Best continent coverage
        if let best = data.mostVisitedContinentPercentage {
            result.append((
                icon: "globe.europe.africa.fill",
                text: "You've visited \(Int(best.percentage))% of \(best.name)!"
            ))
        }

        // Countries this year
        if data.visitedCountriesCount > 0 {
            let plural = data.visitedCountriesCount == 1 ? "country" : "countries"
            if data.newCountriesCount > 0 && data.newCountriesCount < data.visitedCountriesCount {
                result.append((
                    icon: "flag.fill",
                    text: "You visited \(data.visitedCountriesCount) \(plural), with \(data.newCountriesCount) new."
                ))
            } else {
                result.append((
                    icon: "flag.fill",
                    text: "You visited \(data.visitedCountriesCount) \(plural) this year."
                ))
            }
        }

        // States this year
        if data.visitedUSStatesCount > 0 {
            let plural = data.visitedUSStatesCount == 1 ? "state" : "states"
            result.append((
                icon: "star.fill",
                text: "You visited \(data.visitedUSStatesCount) US \(plural)."
            ))
        }

        // Other regions this year - be specific about each type
        for regionGroup in data.otherRegionsByType {
            result.append((
                icon: "map.fill",
                text: "You explored \(regionGroup.count) \(regionGroup.label)."
            ))
        }

        // Time zones
        if data.timeZoneStats.zonesVisited > 1 {
            result.append((
                icon: "clock.fill",
                text: "Your travels spanned \(data.timeZoneStats.zonesVisited) time zones!"
            ))
        }

        // Continents visited
        let continentsVisited = data.continentBreakdown.filter { $0.visited > 0 }.count
        if continentsVisited > 1 {
            result.append((
                icon: "airplane",
                text: "You visited places across \(continentsVisited) different continents."
            ))
        }

        // Total places
        if data.totalVisitedPlaces >= 5 {
            result.append((
                icon: "sparkles",
                text: "What a year! \(data.totalVisitedPlaces) places explored."
            ))
        }

        return result
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Fun Facts")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            VStack(spacing: 16) {
                ForEach(Array(facts.prefix(5).enumerated()), id: \.offset) { index, fact in
                    HStack(spacing: 16) {
                        Image(systemName: fact.icon)
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: factGradientColors(for: index),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36)

                        Text(fact.text)
                            .font(.body)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                    .padding()
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .opacity(index < showFacts.count && showFacts[index] ? 1 : 0)
                    .offset(x: index < showFacts.count && showFacts[index] ? 0 : -30)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            for index in 0..<min(facts.count, showFacts.count) {
                withAnimation(.easeOut(duration: 0.5).delay(0.3 + Double(index) * 0.15)) {
                    showFacts[index] = true
                }
            }
        }
    }

    private func factGradientColors(for index: Int) -> [Color] {
        let palettes: [[Color]] = [
            [.cyan, .blue],
            [.green, .mint],
            [.orange, .yellow],
            [.purple, .pink],
            [.red, .orange],
        ]
        return palettes[index % palettes.count]
    }
}

// MARK: - Card 7: Summary Card (Shareable)

struct SummaryCard: View {
    let data: YearInReviewData
    @State private var showContent = false
    @State private var showConfetti = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var showShareSheet = false
    @State private var renderedImage: UIImage?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Summary content (this is what gets shared)
            summaryContent
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.9)

            // Share button
            Button {
                renderShareImage()
                if renderedImage != nil {
                    showShareSheet = true
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Your Year")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .opacity(showContent ? 1 : 0)

            Spacer()
        }
        .overlay {
            // Confetti particles
            if showConfetti {
                ConfettiView(particles: confettiParticles)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                showContent = true
            }
            // Start confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                confettiParticles = ConfettiParticle.generate(count: 50)
                showConfetti = true
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = renderedImage {
                ActivityShareSheet(items: [image])
            }
        }
    }

    @MainActor
    private func renderShareImage() {
        let renderer = ImageRenderer(content: shareableContent)
        renderer.scale = 3.0
        renderedImage = renderer.uiImage
    }

    private var summaryContent: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("My \(String(data.year)) in Travel")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("Footprint")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                SummaryStatItem(
                    value: "\(data.totalVisitedPlaces)",
                    label: data.totalNewPlaces < data.totalVisitedPlaces
                        ? "Places (\(data.totalNewPlaces) new)"
                        : "Places Visited",
                    icon: "mappin.and.ellipse",
                    color: .green
                )

                SummaryStatItem(
                    value: "\(data.visitedCountriesCount)",
                    label: data.newCountriesCount < data.visitedCountriesCount
                        ? "Countries (\(data.newCountriesCount) new)"
                        : "Countries",
                    icon: "flag.fill",
                    color: .cyan
                )

                if data.visitedUSStatesCount > 0 {
                    SummaryStatItem(
                        value: "\(data.visitedUSStatesCount)",
                        label: data.newUSStatesCount < data.visitedUSStatesCount
                            ? "US States (\(data.newUSStatesCount) new)"
                            : "US States",
                        icon: "star.fill",
                        color: .blue
                    )
                }

                SummaryStatItem(
                    value: "\(data.timeZoneStats.zonesVisited)",
                    label: "Time Zones",
                    icon: "clock.fill",
                    color: .purple
                )

                if let top = data.topContinent {
                    SummaryStatItem(
                        value: top.emoji,
                        label: top.name,
                        icon: "globe.europe.africa",
                        color: .orange
                    )
                }

                let continents = data.continentBreakdown.filter { $0.visited > 0 }.count
                if continents > 0 {
                    SummaryStatItem(
                        value: "\(continents)",
                        label: "Continents",
                        icon: "globe",
                        color: .teal
                    )
                }
            }
            .padding(.horizontal, 8)

            // Country list
            if !data.visitedCountries.isEmpty {
                VStack(spacing: 4) {
                    Text("Countries Visited")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

                    Text(data.visitedCountries.map { $0.regionName }.sorted().joined(separator: " \u{2022} "))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding(.horizontal)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    @MainActor
    private var shareableContent: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.cyan)

                Text("My \(String(data.year)) in Travel")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ShareStatBox(
                    value: "\(data.totalVisitedPlaces)",
                    label: data.totalNewPlaces < data.totalVisitedPlaces
                        ? "Places (\(data.totalNewPlaces) new)" : "Places Visited",
                    color: .green
                )
                ShareStatBox(
                    value: "\(data.visitedCountriesCount)",
                    label: data.newCountriesCount < data.visitedCountriesCount
                        ? "Countries (\(data.newCountriesCount) new)" : "Countries",
                    color: .cyan
                )
                ShareStatBox(value: "\(data.timeZoneStats.zonesVisited)", label: "Time Zones", color: .purple)

                let continents = data.continentBreakdown.filter { $0.visited > 0 }.count
                ShareStatBox(value: "\(continents)", label: "Continents", color: .orange)
            }
            .padding(.horizontal, 16)

            if !data.visitedCountries.isEmpty {
                Text(data.visitedCountries.map { $0.regionName }.sorted().joined(separator: " \u{2022} "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
            }

            Text("Tracked with Footprint")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(32)
        .frame(width: 400)
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.2, green: 0.15, blue: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SummaryStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ShareStatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Confetti Effect

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let size: CGFloat
    let speed: Double
    let delay: Double
    let rotation: Double
    let shape: Int // 0 = circle, 1 = rectangle, 2 = triangle

    static func generate(count: Int) -> [ConfettiParticle] {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .cyan, .mint, .teal]
        return (0..<count).map { _ in
            ConfettiParticle(
                color: colors.randomElement()!,
                x: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 4...10),
                speed: Double.random(in: 2...4),
                delay: Double.random(in: 0...1.5),
                rotation: Double.random(in: 0...360),
                shape: Int.random(in: 0...2)
            )
        }
    }
}

struct ConfettiView: View {
    let particles: [ConfettiParticle]
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { particle in
                confettiShape(for: particle)
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * (particle.shape == 1 ? 2 : 1))
                    .rotationEffect(.degrees(animate ? particle.rotation + 360 : particle.rotation))
                    .position(
                        x: geo.size.width * particle.x,
                        y: animate ? geo.size.height + 50 : -50
                    )
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeIn(duration: particle.speed)
                        .delay(particle.delay),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }

    private func confettiShape(for particle: ConfettiParticle) -> some Shape {
        switch particle.shape {
        case 0:
            return AnyShape(Circle())
        case 1:
            return AnyShape(RoundedRectangle(cornerRadius: 1))
        default:
            return AnyShape(Triangle())
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
