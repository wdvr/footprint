import XCTest
@testable import Footprint

/// Streaks and distance derived from the `Visit` log alone.
final class VisitLogTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func entry(
        _ code: String, _ arrivedAt: Date, level: PlaceLevel = .country, subdivision: String? = nil,
        kind: DetectedVisitKind = .visited, departedAt: Date? = nil, lat: Double = 0, lon: Double = 0,
        source: SampleSource = .gps, evidence: VisitEvidenceKind = .detected, isDateKnown: Bool = true
    ) -> VisitLogEntry {
        VisitLogEntry(
            level: level, countryCode: code, subdivisionCode: subdivision, kind: kind,
            arrivedAt: arrivedAt, departedAt: departedAt ?? arrivedAt.addingTimeInterval(3600),
            centroidLatitude: lat, centroidLongitude: lon, source: source, evidence: evidence, isDateKnown: isDateKnown
        )
    }

    // MARK: - Streaks

    func testMonthlyStreakCountsConsecutiveMonthsWithANewPlace() {
        let log = [
            entry("FR", date(2026, 1, 10)),
            entry("BE", date(2026, 2, 28)),
            entry("NL", date(2026, 3, 1)),
            entry("DE", date(2026, 5, 3)),
        ]
        let streak = { VisitLog.newPlaceStreak(log, cadence: .month, calendar: self.utc, asOf: $0) }
        XCTAssertEqual(streak(date(2026, 5, 20)), VisitLog.Streak(longest: 3, current: 1))
        // Still alive through the next month, broken after it.
        XCTAssertEqual(streak(date(2026, 6, 30)).current, 1)
        XCTAssertEqual(streak(date(2026, 7, 1)).current, 0)
    }

    func testRevisitsAreNotNewPlaces() {
        let log = [entry("FR", date(2026, 1, 10)), entry("FR", date(2026, 2, 10)), entry("FR", date(2026, 3, 10))]
        XCTAssertEqual(VisitLog.newPlaceStreak(log, cadence: .month, calendar: utc, asOf: date(2026, 3, 11)),
                       VisitLog.Streak(longest: 1, current: 0))
    }

    func testFirstVisitIsTheEarliestRowWhateverTheOrder() {
        let log = [entry("FR", date(2026, 3, 10)), entry("FR", date(2026, 1, 10))]
        XCTAssertEqual(VisitLog.firstVisits(log)[VisitLog.PlaceID(level: .country, countryCode: "FR", subdivisionCode: nil)],
                       date(2026, 1, 10))
    }

    func testAnyLevelCountsAsANewPlace() {
        let log = [
            entry("US", date(2026, 1, 5)),
            entry("US", date(2026, 2, 5), level: .subdivision, subdivision: "CA"),
            entry("US", date(2026, 3, 5), level: .subdivision, subdivision: "NV"),
        ]
        XCTAssertEqual(VisitLog.newPlaceStreak(log, cadence: .month, calendar: utc, asOf: date(2026, 3, 6)),
                       VisitLog.Streak(longest: 3, current: 3))
    }

    func testTransitAndUndatedRowsDoNotFeedStreaks() {
        let log = [
            entry("FR", date(2026, 1, 10)),
            entry("QA", date(2026, 2, 10), kind: .transit),
            entry("BE", date(2026, 3, 10), evidence: .grandfathered, isDateKnown: false),
        ]
        XCTAssertEqual(VisitLog.newPlaceStreak(log, cadence: .month, calendar: utc, asOf: date(2026, 3, 11)).longest, 1)
    }

    func testDatedGrandfatheredRowsFeedStreaks() {
        let log = [
            entry("FR", date(2019, 6, 1), source: .manual, evidence: .grandfathered),
            entry("BE", date(2019, 7, 1), source: .manual, evidence: .grandfathered),
        ]
        XCTAssertEqual(VisitLog.newPlaceStreak(log, cadence: .month, calendar: utc, asOf: date(2026, 1, 1)),
                       VisitLog.Streak(longest: 2, current: 0))
    }

    func testWeeklyStreakAcrossAYearBoundary() {
        var calendar = utc
        calendar.firstWeekday = 2
        let log = [
            entry("FR", date(2025, 12, 23)),
            entry("BE", date(2025, 12, 30)),
            entry("NL", date(2026, 1, 6)),
        ]
        XCTAssertEqual(VisitLog.newPlaceStreak(log, cadence: .week, calendar: calendar, asOf: date(2026, 1, 8)),
                       VisitLog.Streak(longest: 3, current: 3))
    }

    func testEmptyLogHasNoStreak() {
        XCTAssertEqual(VisitLog.newPlaceStreak([], cadence: .week, calendar: utc), VisitLog.Streak())
    }

    // MARK: - Distance

    func testDistanceFollowsTheDeepestLevelPath() {
        // One trip in country BB: stays in N then S, 1° of latitude (~111 km) apart. The country row
        // spans both and its centroid sits in the middle; it must not add a zig-zag.
        let morning = date(2026, 1, 10, hour: 8)
        let afternoon = date(2026, 1, 10, hour: 14)
        let log = [
            entry("BB", morning, departedAt: afternoon.addingTimeInterval(3600), lat: 0.5, lon: 10),
            entry("BB", morning, level: .subdivision, subdivision: "N", lat: 1, lon: 10),
            entry("BB", afternoon, level: .subdivision, subdivision: "S", lat: 0, lon: 10),
        ]
        XCTAssertEqual(VisitLog.distanceMeters(log), 111_195, accuracy: 100)
    }

    func testCountryOnlyStaysAreTrackPoints() {
        let log = [
            entry("AA", date(2026, 1, 10, hour: 8), lat: 0, lon: 0),
            entry("BB", date(2026, 1, 10, hour: 18), kind: .transit, lat: 0, lon: 1),
        ]
        XCTAssertEqual(VisitLog.distanceMeters(log), 111_195, accuracy: 100)
    }

    func testGrandfatheredAndPhotoRowsAddNoDistance() {
        let log = [
            entry("AA", date(2026, 1, 1), lat: 0, lon: 0),
            entry("BB", date(2026, 1, 2), lat: 0, lon: 90, source: .manual, evidence: .grandfathered),
            entry("CC", date(2026, 1, 3), lat: 0, lon: -90, source: .photo),
            entry("AA", date(2026, 1, 4), lat: 0, lon: 0),
        ]
        XCTAssertEqual(VisitLog.distanceMeters(log), 0)
    }

    func testStatsCountPlacesAndCombineDerivations() {
        let log = [
            entry("FR", date(2026, 1, 10), lat: 0, lon: 0),
            entry("FR", date(2026, 1, 20), lat: 0, lon: 1),
            entry("QA", date(2026, 2, 10), kind: .transit, lat: 0, lon: 1),
        ]
        let stats = VisitLog.stats(log, calendar: utc, asOf: date(2026, 1, 25))
        XCTAssertEqual(stats.placesVisited, 1)
        XCTAssertEqual(stats.months, VisitLog.Streak(longest: 1, current: 1))
        XCTAssertEqual(stats.distanceMeters, 111_195, accuracy: 100)
    }
}
