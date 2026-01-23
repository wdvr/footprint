import SwiftUI

/// A list-based alternative to the map view for VoiceOver users
/// Shows visited countries grouped by continent with easy navigation
struct AccessibleMapSummary: View {
    let visitedPlaces: [VisitedPlace]

    private var visitedCountryCodes: Set<String> {
        Set(
            visitedPlaces
                .filter { $0.regionType == VisitedPlace.RegionType.country.rawValue }
                .map { $0.regionCode }
        )
    }

    private var visitedCountriesByContinent: [(continent: Continent, countries: [Country])] {
        Continent.allCases.compactMap { continent in
            let visitedInContinent = GeographicData.countries
                .filter { $0.continent == continent.rawValue }
                .filter { visitedCountryCodes.contains($0.id) }
                .sorted { $0.name < $1.name }

            guard !visitedInContinent.isEmpty else { return nil }
            return (continent, visitedInContinent)
        }
    }

    var body: some View {
        List {
            // Summary section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Travel Summary")
                        .font(.headline)
                    Text("\(visitedCountryCodes.count) countries visited out of \(GeographicData.countries.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            // Countries by continent
            if visitedCountriesByContinent.isEmpty {
                Section {
                    Text("No countries visited yet")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("No countries visited yet. Go to the Countries tab to mark places you've visited.")
                }
            } else {
                ForEach(visitedCountriesByContinent, id: \.continent.id) { group in
                    Section {
                        ForEach(group.countries) { country in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .accessibilityHidden(true)
                                Text(country.name)
                                Spacer()
                                Text(country.id)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("\(country.name), visited")
                        }
                    } header: {
                        HStack {
                            Text(group.continent.emoji)
                                .accessibilityHidden(true)
                            Text(group.continent.rawValue)
                            Spacer()
                            Text("\(group.countries.count) visited")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("\(group.continent.rawValue), \(group.countries.count) countries visited")
                        .accessibilityAddTraits(.isHeader)
                    }
                }
            }

            // Unvisited continents
            let unvisitedContinents = Continent.allCases.filter { continent in
                !visitedCountriesByContinent.contains { $0.continent == continent }
            }

            if !unvisitedContinents.isEmpty {
                Section("Not Yet Visited") {
                    ForEach(unvisitedContinents) { continent in
                        HStack {
                            Text(continent.emoji)
                                .accessibilityHidden(true)
                            Text(continent.rawValue)
                            Spacer()
                            Text("\(GeographicData.countries.filter { $0.continent == continent.rawValue }.count) countries")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(continent.rawValue), no countries visited")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    AccessibleMapSummary(visitedPlaces: [])
        .modelContainer(for: VisitedPlace.self, inMemory: true)
}
