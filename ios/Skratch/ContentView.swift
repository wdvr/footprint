import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var visitedPlaces: [VisitedPlace]

    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Welcome to Skratch")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Track your travels around the world")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(spacing: 20) {
                    StatCard(title: "Countries", count: countByRegionType(.country), total: 195)
                    StatCard(title: "US States", count: countByRegionType(.usState), total: 51)
                    StatCard(title: "Canadian Provinces", count: countByRegionType(.canadianProvince), total: 13)
                }
                .padding()

                Spacer()

                Button(action: addSamplePlace) {
                    Text("Add Sample Place")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .rounded()
                }
                .padding()
            }
            .navigationTitle("Skratch")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addSamplePlace) {
                        Label("Add Place", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func countByRegionType(_ type: VisitedPlace.RegionType) -> Int {
        visitedPlaces.filter { $0.regionType == type.rawValue && !$0.isDeleted }.count
    }

    private func addSamplePlace() {
        withAnimation {
            let samplePlace = VisitedPlace(
                userID: "sample-user",
                regionType: VisitedPlace.RegionType.country.rawValue,
                regionCode: "US",
                regionName: "United States",
                visitedDate: Date(),
                notes: "Sample visit"
            )
            modelContext.insert(samplePlace)
        }
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let total: Int

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(count)/\(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(count), total: Double(total))
                .tint(.accentColor)

            HStack {
                Spacer()
                Text("\(percentage, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary)
        .rounded()
    }
}

extension View {
    func rounded() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [User.self, VisitedPlace.self], inMemory: true)
}