import SwiftData
import SwiftUI

extension VisitedPlace {
    var cityVisitRecord: CityVisitRecord {
        CityVisitRecord(
            regionType: regionType,
            regionCode: regionCode,
            isVisited: isVisited,
            isTransit: isTransit,
            isDeleted: isDeleted,
            visitedDate: visitedDate
        )
    }
}

/// City rows from the store plus the derived visit sets the city screens share.
struct CityVisitState {
    let places: [VisitedPlace]
    let visitedIDs: Set<String>
    let transitIDs: Set<String>
    let firstVisitDates: [String: Date]

    init(places: [VisitedPlace]) {
        let records = places.map(\.cityVisitRecord)
        self.places = places
        self.visitedIDs = CityCounting.visitedCityIDs(from: records)
        self.transitIDs = CityCounting.transitCityIDs(from: records)
        self.firstVisitDates = CityCounting.firstVisitDates(from: records)
    }

    func status(of city: GazetteerCity) -> CityVisitStatus {
        CityCounting.status(of: city.id, visitedIDs: visitedIDs, transitIDs: transitIDs)
    }

    func progress(_ collection: CityCollection, gazetteer: CityGazetteer = .shared) -> CityCollectionProgress {
        CityCounting.progress(for: collection, in: gazetteer, visitedIDs: visitedIDs)
    }
}

enum CityListSegment: String, CaseIterable, Identifiable {
    case visited = "Visited"
    case transit = "Transit"
    case notYet = "Not yet"

    var id: String { rawValue }

    func matches(_ status: CityVisitStatus) -> Bool {
        switch (self, status) {
        case (.visited, .visited), (.transit, .transit), (.notYet, .notYet): return true
        default: return false
        }
    }
}

/// Marks and unmarks gazetteer cities as visited, with the same date sheet the country list uses.
private struct CityVisitToggle: ViewModifier {
    @Binding var pending: PendingVisitAction?
    @Environment(\.modelContext) private var modelContext

    /// Revives a removed row like the country list does, so a city keeps one row per code.
    private func markVisited(_ action: PendingVisitAction, date: Date?) {
        let code = action.regionCode
        let descriptor = FetchDescriptor<VisitedPlace>(
            predicate: #Predicate { $0.regionType == "city" && $0.regionCode == code }
        )
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.isDeleted = false
            existing.status = VisitedPlace.PlaceStatus.visited.rawValue
            existing.visitType = VisitedPlace.VisitType.visited.rawValue
            existing.visitedDate = date
            existing.lastModifiedAt = Date()
            existing.isSynced = false
        } else {
            modelContext.insert(
                VisitedPlace(regionType: .city, regionCode: code, regionName: action.regionName, visitedDate: date)
            )
        }
    }

    func body(content: Content) -> some View {
        content.sheet(item: $pending) { action in
            VisitDatePickerSheet(placeName: action.regionName) { date in
                markVisited(action, date: date)
                pending = nil
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

private func toggleCity(
    _ city: GazetteerCity,
    state: CityVisitState,
    pending: Binding<PendingVisitAction?>
) {
    if state.status(of: city) == .notYet {
        pending.wrappedValue = PendingVisitAction(regionType: .city, regionCode: city.id, regionName: city.name)
        return
    }
    for place in state.places where place.regionCode == city.id && !place.isDeleted {
        place.isDeleted = true
        place.lastModifiedAt = Date()
    }
}

private let countryNames = Dictionary(
    GeographicData.countries.map { ($0.id, $0.name) },
    uniquingKeysWith: { first, _ in first }
)
private let usStateNames = Dictionary(
    GeographicData.usStates.map { ("US-\($0.id)", $0.name) },
    uniquingKeysWith: { first, _ in first }
)

private func countryName(_ code: String) -> String {
    countryNames[code] ?? Locale.current.localizedString(forRegionCode: code) ?? code
}

private func stateName(_ subdivisionCode: String?) -> String? {
    subdivisionCode.flatMap { usStateNames[$0] }
}

/// Shown in the country-grouped list so same-named cities (e.g. the two Suzhous) are distinguishable.
private func populationLabel(_ city: GazetteerCity) -> String? {
    guard city.population > 0 else { return nil }
    return "Pop. " + city.population.formatted(.number.notation(.compactName))
}

private struct CountryCitySection: Identifiable {
    let countryCode: String
    let name: String
    let cities: [GazetteerCity]

    var id: String { countryCode }
}

// MARK: - Cities list

struct CitiesView: View {
    @Query(filter: #Predicate<VisitedPlace> { $0.regionType == "city" && !$0.isDeleted })
    private var cityPlaces: [VisitedPlace]

    @State private var segment: CityListSegment = .visited
    @State private var searchText = ""
    @State private var pending: PendingVisitAction?

    private let gazetteer = CityGazetteer.shared

    var body: some View {
        let state = CityVisitState(places: cityPlaces)
        let sections = groupedCities(state: state)

        List {
            Section {
                CollectionProgressRow(progress: state.progress(.allCities))
                ForEach(CityCollection.capitals) { collection in
                    NavigationLink {
                        CityCollectionView(collection: collection)
                    } label: {
                        CollectionProgressRow(progress: state.progress(collection))
                    }
                    .accessibilityIdentifier("cityCollection_\(collection.rawValue)")
                }
            } header: {
                Text("Collections")
            }

            Section {
                Picker("Show", selection: $segment) {
                    ForEach(CityListSegment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("citySegmentPicker")
            }

            if sections.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
            }

            ForEach(sections) { section in
                Section(section.name) {
                    ForEach(section.cities) { city in
                        CityRow(
                            city: city,
                            subtitle: [
                                city.isUSStateCapital ? stateName(city.subdivisionCode) : nil,
                                populationLabel(city),
                            ].compactMap { $0 }.joined(separator: " · "),
                            status: state.status(of: city),
                            firstVisit: state.firstVisitDates[city.id]
                        ) {
                            toggleCity(city, state: state, pending: $pending)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search cities")
        .navigationTitle("Cities")
        .modifier(CityVisitToggle(pending: $pending))
    }

    private var emptyMessage: String {
        if !searchText.isEmpty { return "No matching cities." }
        switch segment {
        case .visited: return "No cities visited yet. Mark one under Not yet."
        case .transit: return "No cities passed through."
        case .notYet: return "You've visited every city in the list."
        }
    }

    private func groupedCities(state: CityVisitState) -> [CountryCitySection] {
        let matches = gazetteer.cities.filter { city in
            segment.matches(state.status(of: city))
                && (searchText.isEmpty
                    || city.name.localizedCaseInsensitiveContains(searchText)
                    || countryName(city.countryCode).localizedCaseInsensitiveContains(searchText))
        }
        return Dictionary(grouping: matches, by: \.countryCode)
            .map {
                CountryCitySection(
                    countryCode: $0.key,
                    name: countryName($0.key),
                    cities: $0.value.sorted { $0.population > $1.population }
                )
            }
            .sorted { $0.name < $1.name }
    }
}

// MARK: - Capitals collection

struct CityCollectionView: View {
    let collection: CityCollection

    @Query(filter: #Predicate<VisitedPlace> { $0.regionType == "city" && !$0.isDeleted })
    private var cityPlaces: [VisitedPlace]

    @State private var segment: CityListSegment = .notYet
    @State private var searchText = ""
    @State private var pending: PendingVisitAction?

    var body: some View {
        let state = CityVisitState(places: cityPlaces)
        let progress = state.progress(collection)
        let members = filteredMembers(state: state)

        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(progress.visited) of \(progress.total)")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.tint)
                    Text(collection.unit.capitalized + " visited")
                        .foregroundStyle(.secondary)
                    ProgressView(value: progress.fraction)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(progress.summary)
                .accessibilityIdentifier("cityCollectionProgress")
            }

            Section {
                Picker("Show", selection: $segment) {
                    ForEach(CityListSegment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            ForEach(members) { city in
                CityRow(
                    city: city,
                    subtitle: collection == .usStateCapitals
                        ? stateName(city.subdivisionCode)
                        : countryName(city.countryCode),
                    status: state.status(of: city),
                    firstVisit: state.firstVisitDates[city.id]
                ) {
                    toggleCity(city, state: state, pending: $pending)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search \(collection.unit)")
        .navigationTitle(collection.title)
        .modifier(CityVisitToggle(pending: $pending))
    }

    private func filteredMembers(state: CityVisitState) -> [GazetteerCity] {
        let label: (GazetteerCity) -> String = { city in
            collection == .usStateCapitals ? (stateName(city.subdivisionCode) ?? city.name) : countryName(city.countryCode)
        }
        return CityGazetteer.shared.cities(in: collection)
            .filter { segment.matches(state.status(of: $0)) }
            .filter {
                searchText.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(searchText)
                    || label($0).localizedCaseInsensitiveContains(searchText)
            }
            .sorted { label($0) < label($1) }
    }
}

// MARK: - Rows

struct CollectionProgressRow: View {
    let progress: CityCollectionProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: progress.collection.icon)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(progress.collection.title)
                    .font(.headline)
                Spacer()
                Text("\(progress.visited)/\(progress.total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress.fraction)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(progress.collection.title): \(progress.summary)")
    }
}

struct CityRow: View {
    let city: GazetteerCity
    let subtitle: String?
    let status: CityVisitStatus
    let firstVisit: Date?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.title3)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(city.name)
                        if city.isCapital {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("Capital")
                        }
                    }
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(status == .notYet ? "Double tap to mark visited" : "Double tap to remove")
        .accessibilityIdentifier("cityRow_\(city.id)")
    }

    private var detail: String? {
        let date = firstVisit.map { $0.formatted(date: .abbreviated, time: .omitted) }
        let parts = [subtitle, date].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var statusIcon: String {
        switch status {
        case .visited: return "checkmark.circle.fill"
        case .transit: return "airplane.circle.fill"
        case .notYet: return "circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .visited: return .green
        case .transit: return .orange
        case .notYet: return .secondary
        }
    }
}
