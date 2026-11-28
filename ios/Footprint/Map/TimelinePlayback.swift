import Foundation

/// The first time a place was visited: one frame of the timeline movie.
struct PlaybackEvent: Sendable, Equatable, Identifiable {
    /// `regionType:regionCode`, unique per place.
    let id: String
    let date: Date
    let regionType: String
    let regionCode: String
    let regionName: String
    /// Country used for the flag (the parent country for subdivisions).
    let countryCode: String
    let isCountry: Bool

    init(
        date: Date, regionType: String, regionCode: String, regionName: String,
        countryCode: String, isCountry: Bool
    ) {
        self.id = "\(regionType):\(regionCode)"
        self.date = date
        self.regionType = regionType
        self.regionCode = regionCode
        self.regionName = regionName
        self.countryCode = countryCode
        self.isCountry = isCountry
    }
}

enum PlaybackSpeed: Double, CaseIterable, Sendable {
    case half = 0.5
    case normal = 1
    case double = 2
    case quadruple = 4

    var label: String {
        switch self {
        case .half: return "0.5×"
        case .normal: return "1×"
        case .double: return "2×"
        case .quadruple: return "4×"
        }
    }

    var next: PlaybackSpeed {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

struct TimelinePlaybackConfig: Sendable, Equatable {
    static let day: TimeInterval = 86_400

    /// Quiet stretches longer than this are compressed to it, so the movie never idles for years.
    var maxGap: TimeInterval = 120 * day
    /// Empty map shown before the first visit, and the hold after the last one.
    var bookend: TimeInterval = 30 * day
    /// Playback seconds at 1× per place, clamped to `minDuration...maxDuration`.
    var secondsPerEvent: TimeInterval = 1.2
    var minDuration: TimeInterval = 8
    var maxDuration: TimeInterval = 30
}

/// A place revealed within the recent-arrivals window; `age` runs 0 (just appeared) to 1 (leaving).
struct RecentPlaybackEvent: Sendable, Equatable {
    let event: PlaybackEvent
    let age: Double
}

/// A scrubber tick at January 1st of `year`.
struct PlaybackYearMarker: Sendable, Equatable {
    let year: Int
    let progress: Double
}

/// Maps playback progress (0...1) to dates and to the set of places visited by then.
///
/// Time runs on a compressed axis: real time, except each gap between consecutive visit
/// dates is capped at `maxGap`, with a `bookend` before the first and after the last visit.
struct TimelinePlaybackTimeline: Sendable {
    private struct Knot: Sendable {
        let position: TimeInterval
        let date: Date
    }

    /// Sorted by date, one per place (its earliest visit).
    let events: [PlaybackEvent]
    let config: TimelinePlaybackConfig
    /// Playback length in seconds at 1×.
    let duration: TimeInterval

    private let knots: [Knot]
    /// Length of the compressed axis.
    private let span: TimeInterval
    /// Each event's position on the compressed axis, ascending.
    private let eventPositions: [TimeInterval]
    /// `countryCounts[n]` = countries among the first `n` events.
    private let countryCounts: [Int]

    /// Returns nil when there is nothing to play.
    init?(events: [PlaybackEvent], config: TimelinePlaybackConfig = TimelinePlaybackConfig()) {
        var earliest: [String: PlaybackEvent] = [:]
        for event in events {
            if let existing = earliest[event.id], existing.date <= event.date { continue }
            earliest[event.id] = event
        }
        let sorted = earliest.values.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
        guard let first = sorted.first, let last = sorted.last else { return nil }

        self.events = sorted
        self.config = config

        let bookend = max(config.bookend, 1)
        let maxGap = max(config.maxGap, 1)
        var knots = [Knot(position: 0, date: first.date.addingTimeInterval(-bookend))]
        var position = bookend
        knots.append(Knot(position: position, date: first.date))
        for event in sorted.dropFirst() where event.date > knots[knots.count - 1].date {
            position += min(event.date.timeIntervalSince(knots[knots.count - 1].date), maxGap)
            knots.append(Knot(position: position, date: event.date))
        }
        position += bookend
        knots.append(Knot(position: position, date: last.date))
        self.knots = knots
        self.span = position

        var positions: [TimeInterval] = []
        var counts = [0]
        var knotIndex = 1
        for event in sorted {
            while knots[knotIndex].date < event.date { knotIndex += 1 }
            positions.append(knots[knotIndex].position)
            counts.append(counts[counts.count - 1] + (event.isCountry ? 1 : 0))
        }
        self.eventPositions = positions
        self.countryCounts = counts

        self.duration = min(
            max(Double(sorted.count) * config.secondsPerEvent, config.minDuration),
            config.maxDuration
        )
    }

    var startDate: Date { knots[0].date }
    var endDate: Date { knots[knots.count - 1].date }

    // MARK: Time window

    /// The calendar date shown at `progress`.
    func date(at progress: Double) -> Date {
        let target = Self.clamp(progress) * span
        guard let upper = knots.firstIndex(where: { $0.position >= target }), upper > 0 else {
            return knots[0].date
        }
        let a = knots[upper - 1]
        let b = knots[upper]
        let width = b.position - a.position
        guard width > 0 else { return b.date }
        let fraction = (target - a.position) / width
        return a.date.addingTimeInterval(b.date.timeIntervalSince(a.date) * fraction)
    }

    /// The progress at which the timeline reaches `date` (first reach, for the hold at the end).
    func progress(at date: Date) -> Double {
        if date <= knots[0].date { return 0 }
        guard let upper = knots.firstIndex(where: { $0.date >= date }) else { return 1 }
        let a = knots[upper - 1]
        let b = knots[upper]
        let realWidth = b.date.timeIntervalSince(a.date)
        let fraction = realWidth > 0 ? date.timeIntervalSince(a.date) / realWidth : 1
        return (a.position + (b.position - a.position) * fraction) / span
    }

    /// The progress at which `events[index]` appears.
    func appearanceProgress(ofEventAt index: Int) -> Double {
        eventPositions[index] / span
    }

    /// Number of places visited by `progress` (a prefix of `events`).
    func revealedCount(at progress: Double) -> Int {
        let target = Self.clamp(progress) * span + Self.epsilon
        var low = 0
        var high = eventPositions.count
        while low < high {
            let mid = (low + high) / 2
            if eventPositions[mid] <= target { low = mid + 1 } else { high = mid }
        }
        return low
    }

    func revealedEvents(at progress: Double) -> ArraySlice<PlaybackEvent> {
        events.prefix(revealedCount(at: progress))
    }

    /// Countries among the places visited by `progress`.
    func countryCount(at progress: Double) -> Int {
        countryCounts[revealedCount(at: progress)]
    }

    /// Places that appeared within the last `window` playback seconds (at 1×), newest first.
    func recentEvents(at progress: Double, window: TimeInterval, limit: Int = 3) -> [RecentPlaybackEvent] {
        guard window > 0, limit > 0 else { return [] }
        let target = Self.clamp(progress) * span
        let windowSpan = window / duration * span
        var result: [RecentPlaybackEvent] = []
        var index = revealedCount(at: progress) - 1
        while index >= 0, result.count < limit {
            let age = (target - eventPositions[index]) / windowSpan
            if age >= 1 { break }
            result.append(RecentPlaybackEvent(event: events[index], age: max(0, age)))
            index -= 1
        }
        return result
    }

    // MARK: Playback clock

    /// Progress after `elapsed` wall-clock seconds at `speed`, stopping at the end.
    func advanced(from progress: Double, elapsed: TimeInterval, speed: PlaybackSpeed) -> Double {
        Self.clamp(progress + max(0, elapsed) * speed.rawValue / duration)
    }

    /// Scrubber ticks: the progress of each January 1st inside the timeline.
    func yearMarkers(calendar: Calendar = .current) -> [PlaybackYearMarker] {
        let firstYear = calendar.component(.year, from: startDate)
        let lastYear = calendar.component(.year, from: endDate)
        guard lastYear > firstYear else { return [] }
        return (firstYear + 1...lastYear).compactMap { year in
            guard let newYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else {
                return nil
            }
            return PlaybackYearMarker(year: year, progress: progress(at: newYear))
        }
    }

    private static let epsilon = 1e-6

    private static func clamp(_ progress: Double) -> Double {
        progress.isFinite ? min(max(progress, 0), 1) : 0
    }
}
