import SwiftUI

// MARK: - Year in Review Data Model

struct YearInReviewData {
    let year: Int
    let newCountries: [VisitedPlace]
    let newUSStates: [VisitedPlace]
    let newCanadianProvinces: [VisitedPlace]
    let newOtherRegions: [VisitedPlace]
    let allVisitedPlaces: [VisitedPlace]

    var totalNewPlaces: Int {
        newCountries.count + newUSStates.count + newCanadianProvinces.count + newOtherRegions.count
    }

    var newCountriesCount: Int { newCountries.count }
    var newUSStatesCount: Int { newUSStates.count }
    var newCanadianProvincesCount: Int { newCanadianProvinces.count }

    // Continent stats for this year's countries
    var continentBreakdown: [LocalContinentStats] {
        let countryCodes = newCountries.map { $0.regionCode }
        return LocalContinentStats.calculateStats(visitedCountries: countryCodes)
    }

    var topContinent: LocalContinentStats? {
        continentBreakdown.first(where: { $0.visited > 0 })
    }

    // Time zone stats for this year
    var timeZoneStats: TimeZoneLocalStats {
        let countryCodes = newCountries.map { $0.regionCode }
        let stateTuples = (newUSStates + newCanadianProvinces + newOtherRegions).map {
            ($0.regionType, $0.regionCode)
        }
        return TimeZoneLocalStats.calculate(
            visitedCountries: countryCodes,
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

    var hasData: Bool {
        totalNewPlaces > 0
    }

    // Compute available years from all visited places
    static func availableYears(from places: [VisitedPlace]) -> [Int] {
        let calendar = Calendar.current
        let years = Set(
            places
                .filter { $0.isVisited && !$0.isDeleted }
                .compactMap { $0.visitedDate }
                .map { calendar.component(.year, from: $0) }
        )
        return years.sorted(by: >)
    }

    static func compute(for year: Int, allPlaces: [VisitedPlace]) -> YearInReviewData {
        let calendar = Calendar.current

        let placesThisYear = allPlaces.filter { place in
            guard place.isVisited && !place.isDeleted else { return false }
            guard let date = place.visitedDate else { return false }
            return calendar.component(.year, from: date) == year
        }

        let countries = placesThisYear.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
        }
        let usStates = placesThisYear.filter {
            $0.regionType == VisitedPlace.RegionType.usState.rawValue
        }
        let canadianProvinces = placesThisYear.filter {
            $0.regionType == VisitedPlace.RegionType.canadianProvince.rawValue
        }
        let otherRegions = placesThisYear.filter { place in
            place.regionType != VisitedPlace.RegionType.country.rawValue
            && place.regionType != VisitedPlace.RegionType.usState.rawValue
            && place.regionType != VisitedPlace.RegionType.canadianProvince.rawValue
        }

        return YearInReviewData(
            year: year,
            newCountries: countries,
            newUSStates: usStates,
            newCanadianProvinces: canadianProvinces,
            newOtherRegions: otherRegions,
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

            Text("Swipe to explore")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .opacity(showSubtitle ? 1 : 0)
                .padding(.bottom, 60)
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
    @State private var animatedCountries: Int = 0
    @State private var animatedStates: Int = 0
    @State private var animatedProvinces: Int = 0
    @State private var animatedTotal: Int = 0

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text("You explored")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.7))
                .opacity(showContent ? 1 : 0)

            // Total counter
            Text("\(animatedTotal)")
                .font(.system(size: 96, weight: .heavy))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .contentTransition(.numericText())

            Text("new places")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .opacity(showContent ? 1 : 0)

            // Breakdown
            VStack(spacing: 16) {
                if data.newCountriesCount > 0 {
                    CountBreakdownRow(
                        icon: "flag.fill",
                        label: "Countries",
                        count: animatedCountries,
                        color: .green
                    )
                }
                if data.newUSStatesCount > 0 {
                    CountBreakdownRow(
                        icon: "star.fill",
                        label: "US States",
                        count: animatedStates,
                        color: .blue
                    )
                }
                if data.newCanadianProvincesCount > 0 {
                    CountBreakdownRow(
                        icon: "leaf.fill",
                        label: "Canadian Provinces",
                        count: animatedProvinces,
                        color: .red
                    )
                }
                if data.newOtherRegions.count > 0 {
                    CountBreakdownRow(
                        icon: "map.fill",
                        label: "Other Regions",
                        count: data.newOtherRegions.count,
                        color: .orange
                    )
                }
            }
            .padding(.horizontal, 40)
            .opacity(showContent ? 1 : 0)

            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
            // Animate counters
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
                        // Ensure exact final values
                        animatedTotal = data.totalNewPlaces
                        animatedCountries = data.newCountriesCount
                        animatedStates = data.newUSStatesCount
                        animatedProvinces = data.newCanadianProvincesCount
                    } else {
                        let progress = Double(step) / Double(totalSteps)
                        // Use easeOut curve
                        let easedProgress = 1 - pow(1 - progress, 3)
                        animatedTotal = Int(Double(data.totalNewPlaces) * easedProgress)
                        animatedCountries = Int(Double(data.newCountriesCount) * easedProgress)
                        animatedStates = Int(Double(data.newUSStatesCount) * easedProgress)
                        animatedProvinces = Int(Double(data.newCanadianProvincesCount) * easedProgress)
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
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Card 3: Year Map Card

struct YearMapCard: View {
    let data: YearInReviewData
    @State private var showContent = false

    private var visitedCountryCodes: Set<String> {
        Set(data.newCountries.map { $0.regionCode })
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
            VStack(spacing: 8) {
                if !data.newCountries.isEmpty {
                    PlaceListSection(
                        title: "Countries",
                        places: data.newCountries.map { $0.regionName }.sorted(),
                        icon: "flag.fill",
                        color: .green
                    )
                }
                if !data.newUSStates.isEmpty {
                    PlaceListSection(
                        title: "US States",
                        places: data.newUSStates.map { $0.regionName }.sorted(),
                        icon: "star.fill",
                        color: .blue
                    )
                }
                if !data.newCanadianProvinces.isEmpty {
                    PlaceListSection(
                        title: "Canadian Provinces",
                        places: data.newCanadianProvinces.map { $0.regionName }.sorted(),
                        icon: "leaf.fill",
                        color: .red
                    )
                }
            }
            .padding(.horizontal, 24)
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
        if data.newCountriesCount > 0 {
            let plural = data.newCountriesCount == 1 ? "country" : "countries"
            result.append((
                icon: "flag.fill",
                text: "You added \(data.newCountriesCount) new \(plural) to your map this year."
            ))
        }

        // States this year
        if data.newUSStatesCount > 0 {
            let plural = data.newUSStatesCount == 1 ? "state" : "states"
            result.append((
                icon: "star.fill",
                text: "You visited \(data.newUSStatesCount) US \(plural)."
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
        if data.totalNewPlaces >= 5 {
            result.append((
                icon: "sparkles",
                text: "What a year! \(data.totalNewPlaces) new places explored."
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
                    value: "\(data.totalNewPlaces)",
                    label: "New Places",
                    icon: "mappin.and.ellipse",
                    color: .green
                )

                SummaryStatItem(
                    value: "\(data.newCountriesCount)",
                    label: "Countries",
                    icon: "flag.fill",
                    color: .cyan
                )

                if data.newUSStatesCount > 0 {
                    SummaryStatItem(
                        value: "\(data.newUSStatesCount)",
                        label: "US States",
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
            if !data.newCountries.isEmpty {
                VStack(spacing: 4) {
                    Text("Countries Visited")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

                    Text(data.newCountries.map { $0.regionName }.sorted().joined(separator: " \u{2022} "))
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
                ShareStatBox(value: "\(data.totalNewPlaces)", label: "New Places", color: .green)
                ShareStatBox(value: "\(data.newCountriesCount)", label: "Countries", color: .cyan)
                ShareStatBox(value: "\(data.timeZoneStats.zonesVisited)", label: "Time Zones", color: .purple)

                let continents = data.continentBreakdown.filter { $0.visited > 0 }.count
                ShareStatBox(value: "\(continents)", label: "Continents", color: .orange)
            }
            .padding(.horizontal, 16)

            if !data.newCountries.isEmpty {
                Text(data.newCountries.map { $0.regionName }.sorted().joined(separator: " \u{2022} "))
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
