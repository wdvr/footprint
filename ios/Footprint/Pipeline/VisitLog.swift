import Foundation

/// Why a `Visit` row exists.
enum VisitEvidenceKind: String, Sendable, CaseIterable {
    /// Derived from location samples by the dwell / accuracy gates (§3.3).
    case detected
    /// Mirrors a `VisitedPlace` that has no sample evidence: rows that predate the pipeline, or a
    /// place the user added by hand. Counted as visited as-is; never re-judged by the dwell gate (§2.5).
    case grandfathered
}

/// A `Visit` row as the pure log functions see it (decoupled from SwiftData).
struct VisitLogEntry: Sendable, Equatable {
    var level: PlaceLevel
    var countryCode: String
    var subdivisionCode: String?
    var kind: DetectedVisitKind
    var arrivedAt: Date
    var departedAt: Date?
    var centroidLatitude: Double
    var centroidLongitude: Double
    var source: SampleSource
    var evidence: VisitEvidenceKind = .detected
    /// False for grandfathered places saved without a visit date; `arrivedAt` is then only when
    /// the place was marked.
    var isDateKnown = true

    var placeID: VisitLog.PlaceID {
        VisitLog.PlaceID(level: level, countryCode: countryCode, subdivisionCode: subdivisionCode)
    }

    /// Has a real stay centroid: detected from GPS samples.
    var hasTrackPoint: Bool { evidence == .detected && source == .gps }
}

/// Stats derived from the `Visit` log alone (§4.2), so they survive sample retention and can be
/// recomputed at any time.
enum VisitLog {
    struct PlaceID: Hashable, Sendable {
        let level: PlaceLevel
        let countryCode: String
        let subdivisionCode: String?
    }

    enum Cadence: Sendable {
        case week
        case month

        var component: Calendar.Component {
            switch self {
            case .week: return .weekOfYear
            case .month: return .month
            }
        }
    }

    struct Streak: Sendable, Equatable {
        /// Longest run of consecutive periods with at least one new place.
        var longest = 0
        /// Run ending in the current period, or in the previous one while the current period has
        /// no new place yet (the streak is still alive).
        var current = 0
    }

    /// Earliest dated full visit per place. Transit does not count toward coverage or medals (§2.5).
    static func firstVisits(_ entries: [VisitLogEntry]) -> [PlaceID: Date] {
        var first: [PlaceID: Date] = [:]
        for entry in entries where entry.kind == .visited && entry.isDateKnown {
            first[entry.placeID] = min(first[entry.placeID] ?? entry.arrivedAt, entry.arrivedAt)
        }
        return first
    }

    /// `newPlaceStreakWeeks` / `newPlaceStreakMonths`: periods in a row in which the user first
    /// visited at least one place, at any level.
    static func newPlaceStreak(
        _ entries: [VisitLogEntry],
        cadence: Cadence,
        calendar: Calendar = .current,
        asOf now: Date = Date()
    ) -> Streak {
        let periods = Set(firstVisits(entries).values.compactMap {
            calendar.dateInterval(of: cadence.component, for: $0)?.start
        }).sorted()
        guard !periods.isEmpty else { return Streak() }

        func next(_ period: Date) -> Date? {
            calendar.date(byAdding: cadence.component, value: 1, to: period)
                .flatMap { calendar.dateInterval(of: cadence.component, for: $0)?.start }
        }

        var streak = Streak()
        var run = 0
        var previous: Date?
        for period in periods {
            run = previous.flatMap(next) == period ? run + 1 : 1
            streak.longest = max(streak.longest, run)
            previous = period
        }
        if let current = calendar.dateInterval(of: cadence.component, for: now)?.start,
           let last = periods.last,
           last == current || next(last) == current {
            streak.current = run
        }
        return streak
    }

    /// Great-circle length of the path through consecutive stay centroids, using the deepest level
    /// recorded at each time (a country row is replaced by the subdivision rows inside it).
    /// Grandfathered and photo rows have no honest track and add nothing (§4.2).
    static func distanceMeters(_ entries: [VisitLogEntry]) -> Double {
        let points = entries.filter(\.hasTrackPoint)
        let depth = { (level: PlaceLevel) in PlaceLevel.allCases.firstIndex(of: level) ?? 0 }
        let deepest = points.filter { entry in
            !points.contains { other in
                depth(other.level) > depth(entry.level)
                    && other.arrivedAt <= (entry.departedAt ?? entry.arrivedAt)
                    && (other.departedAt ?? other.arrivedAt) >= entry.arrivedAt
            }
        }.sorted { $0.arrivedAt < $1.arrivedAt }

        var total = 0.0
        for (a, b) in zip(deepest, deepest.dropFirst()) {
            total += GeoMath.distanceMeters(
                lat1: a.centroidLatitude, lon1: a.centroidLongitude,
                lat2: b.centroidLatitude, lon2: b.centroidLongitude
            )
        }
        return total
    }

    struct Stats: Sendable, Equatable {
        var placesVisited = 0
        var weeks = Streak()
        var months = Streak()
        var distanceMeters = 0.0
    }

    static func stats(_ entries: [VisitLogEntry], calendar: Calendar = .current, asOf now: Date = Date()) -> Stats {
        Stats(
            placesVisited: Set(entries.filter { $0.kind == .visited }.map(\.placeID)).count,
            weeks: newPlaceStreak(entries, cadence: .week, calendar: calendar, asOf: now),
            months: newPlaceStreak(entries, cadence: .month, calendar: calendar, asOf: now),
            distanceMeters: distanceMeters(entries)
        )
    }
}
