import SwiftUI
import WidgetKit

/// Timeline entry for the Footprint widget
struct FootprintEntry: TimelineEntry {
    let date: Date
    let countriesVisited: Int
    let totalCountries: Int
    let statesVisited: Int
    let totalStates: Int
    let percentage: Int
}

/// Provider that supplies widget timeline entries
struct FootprintProvider: TimelineProvider {
    func placeholder(in context: Context) -> FootprintEntry {
        FootprintEntry(
            date: Date(),
            countriesVisited: 25,
            totalCountries: 195,
            statesVisited: 15,
            totalStates: 50,
            percentage: 13
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FootprintEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FootprintEntry>) -> Void) {
        let entry = loadEntry()
        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> FootprintEntry {
        // Load from shared UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: "group.com.wd.footprint") ?? UserDefaults.standard
        let countriesVisited = defaults.integer(forKey: "countriesVisited")
        let statesVisited = defaults.integer(forKey: "statesVisited")
        let totalCountries = 195
        let totalStates = 64 // 50 US states + DC + 13 CA provinces

        let percentage = totalCountries > 0 ? (countriesVisited * 100) / totalCountries : 0

        return FootprintEntry(
            date: Date(),
            countriesVisited: countriesVisited,
            totalCountries: totalCountries,
            statesVisited: statesVisited,
            totalStates: totalStates,
            percentage: percentage
        )
    }
}

/// The main widget
struct FootprintWidget: Widget {
    let kind: String = "FootprintWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FootprintProvider()) { entry in
            FootprintWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Travel Stats")
        .description("See your travel progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

/// Widget entry view
struct FootprintWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: FootprintProvider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: FootprintEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "globe.americas.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Spacer()
                Text("\(entry.percentage)%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }

            Text("\(entry.countriesVisited) countries")
                .font(.headline)

            Text("of \(entry.totalCountries)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(.green)
                        .frame(width: geo.size.width * CGFloat(entry.percentage) / 100, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: FootprintEntry

    var body: some View {
        HStack(spacing: 20) {
            // Countries
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "globe.americas.fill")
                        .foregroundStyle(.green)
                    Text("Countries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(entry.countriesVisited)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))

                Text("of \(entry.totalCountries)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(entry.countriesVisited), total: Double(entry.totalCountries))
                    .tint(.green)
            }

            Divider()

            // States
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundStyle(.blue)
                    Text("States")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(entry.statesVisited)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))

                Text("of \(entry.totalStates)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(entry.statesVisited), total: Double(entry.totalStates))
                    .tint(.blue)
            }
        }
        .padding()
    }
}

// MARK: - Circular Widget (Watch/Lock Screen)

struct CircularWidgetView: View {
    let entry: FootprintEntry

    var body: some View {
        Gauge(value: Double(entry.countriesVisited), in: 0...Double(entry.totalCountries)) {
            Image(systemName: "globe.americas.fill")
        } currentValueLabel: {
            Text("\(entry.countriesVisited)")
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
        }
        .gaugeStyle(.accessoryCircular)
    }
}

// MARK: - Rectangular Widget (Watch/Lock Screen)

struct RectangularWidgetView: View {
    let entry: FootprintEntry

    var body: some View {
        HStack {
            Image(systemName: "globe.americas.fill")
                .font(.title2)

            VStack(alignment: .leading) {
                Text("\(entry.countriesVisited) countries")
                    .font(.headline)
                Text("\(entry.percentage)% of the world")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    FootprintWidget()
} timeline: {
    FootprintEntry(date: .now, countriesVisited: 25, totalCountries: 195, statesVisited: 15, totalStates: 64, percentage: 13)
    FootprintEntry(date: .now, countriesVisited: 50, totalCountries: 195, statesVisited: 30, totalStates: 64, percentage: 26)
}

#Preview(as: .systemMedium) {
    FootprintWidget()
} timeline: {
    FootprintEntry(date: .now, countriesVisited: 25, totalCountries: 195, statesVisited: 15, totalStates: 64, percentage: 13)
}
