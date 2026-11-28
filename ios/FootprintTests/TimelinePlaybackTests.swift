import XCTest
@testable import Footprint

/// Time-window logic behind the timeline movie.
final class TimelinePlaybackTests: XCTestCase {
    private let day = TimelinePlaybackConfig.day
    /// 2027-01-15 08:00 UTC.
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func event(
        _ code: String, dayOffset: Double, type: String = "country", country: String? = nil
    ) -> PlaybackEvent {
        PlaybackEvent(
            date: t0.addingTimeInterval(dayOffset * day), regionType: type, regionCode: code,
            regionName: code, countryCode: country ?? code, isCountry: type == "country"
        )
    }

    private func timeline(
        _ events: [PlaybackEvent], config: TimelinePlaybackConfig = TimelinePlaybackConfig()
    ) throws -> TimelinePlaybackTimeline {
        try XCTUnwrap(TimelinePlaybackTimeline(events: events, config: config))
    }

    func testEmptyHistoryHasNothingToPlay() {
        XCTAssertNil(TimelinePlaybackTimeline(events: []))
    }

    func testEventsAreSortedAndDeduplicatedToEarliestVisit() throws {
        let t = try timeline([
            event("FR", dayOffset: 20),
            event("BE", dayOffset: 5),
            event("FR", dayOffset: 2),
            event("CA", dayOffset: 10, type: "us_state", country: "US"),
        ])
        XCTAssertEqual(t.events.map(\.id), ["country:FR", "country:BE", "us_state:CA"])
        XCTAssertEqual(t.events[0].date, t0.addingTimeInterval(2 * day))
    }

    func testSameDateTiesAreOrderedDeterministically() throws {
        let a = try timeline([event("NL", dayOffset: 0), event("BE", dayOffset: 0)])
        let b = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 0)])
        XCTAssertEqual(a.events.map(\.id), b.events.map(\.id))
    }

    func testStartsEmptyAndEndsWithEverythingRevealed() throws {
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 40), event("DE", dayOffset: 90)])
        XCTAssertEqual(t.revealedCount(at: 0), 0)
        XCTAssertEqual(t.revealedCount(at: 1), 3)
        XCTAssertEqual(t.startDate, t0.addingTimeInterval(-30 * day))
        XCTAssertEqual(t.endDate, t0.addingTimeInterval(90 * day))
        XCTAssertEqual(t.date(at: 0), t.startDate)
        XCTAssertEqual(t.date(at: 1), t.endDate)
    }

    func testEachPlaceAppearsExactlyAtItsVisitDate() throws {
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 40), event("DE", dayOffset: 90)])
        for index in t.events.indices {
            let p = t.appearanceProgress(ofEventAt: index)
            XCTAssertEqual(t.revealedCount(at: p), index + 1, "event \(index) at its own progress")
            XCTAssertEqual(t.revealedCount(at: p - 0.001), index, "event \(index) just before")
            XCTAssertEqual(
                t.date(at: p).timeIntervalSince1970, t.events[index].date.timeIntervalSince1970, accuracy: 1
            )
        }
    }

    func testDateAdvancesMonotonically() throws {
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 3000), event("DE", dayOffset: 3010)])
        var previous = t.date(at: 0)
        for step in 1...200 {
            let date = t.date(at: Double(step) / 200)
            XCTAssertGreaterThanOrEqual(date, previous)
            previous = date
        }
    }

    func testShortGapsPlayInRealTime() throws {
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 10)])
        let midpoint = (t.appearanceProgress(ofEventAt: 0) + t.appearanceProgress(ofEventAt: 1)) / 2
        XCTAssertEqual(
            t.date(at: midpoint).timeIntervalSince1970, t0.addingTimeInterval(5 * day).timeIntervalSince1970,
            accuracy: 1
        )
    }

    func testLongQuietStretchesAreCompressed() throws {
        var config = TimelinePlaybackConfig()
        config.maxGap = 100 * day
        config.bookend = 50 * day
        // Ten years without travel, then a 50-day trip.
        let t = try timeline(
            [event("BE", dayOffset: 0), event("JP", dayOffset: 3650), event("KR", dayOffset: 3700)], config: config
        )
        // Axis = 50 lead-in + 100 compressed gap + 50 trip + 50 hold = 250 days.
        XCTAssertEqual(t.appearanceProgress(ofEventAt: 0), 50.0 / 250, accuracy: 1e-9)
        XCTAssertEqual(t.appearanceProgress(ofEventAt: 1), 150.0 / 250, accuracy: 1e-9)
        XCTAssertEqual(t.appearanceProgress(ofEventAt: 2), 200.0 / 250, accuracy: 1e-9)
        // Within the compressed gap the date still sweeps through the decade.
        XCTAssertEqual(
            t.date(at: 100.0 / 250).timeIntervalSince1970, t0.addingTimeInterval(1825 * day).timeIntervalSince1970,
            accuracy: 1
        )
    }

    func testFinalHoldKeepsTheLastDate() throws {
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 10)])
        let last = t.appearanceProgress(ofEventAt: 1)
        XCTAssertLessThan(last, 1)
        XCTAssertEqual(t.date(at: (last + 1) / 2), t.endDate)
        XCTAssertEqual(t.revealedCount(at: (last + 1) / 2), 2)
    }

    func testSameDayVisitsAppearTogether() throws {
        let t = try timeline([
            event("BE", dayOffset: 0), event("NL", dayOffset: 7), event("DE", dayOffset: 7), event("FR", dayOffset: 9),
        ])
        XCTAssertEqual(t.appearanceProgress(ofEventAt: 1), t.appearanceProgress(ofEventAt: 2))
        XCTAssertEqual(t.revealedCount(at: t.appearanceProgress(ofEventAt: 1)), 3)
    }

    func testSingleVisitPlaysFromAnEmptyMap() throws {
        let t = try timeline([event("BE", dayOffset: 0)])
        XCTAssertEqual(t.revealedCount(at: 0), 0)
        XCTAssertEqual(t.appearanceProgress(ofEventAt: 0), 0.5, accuracy: 1e-9)
        XCTAssertEqual(t.revealedCount(at: 1), 1)
    }

    func testProgressAndDateRoundTrip() throws {
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 400), event("DE", dayOffset: 420)])
        for step in 0...20 {
            let p = Double(step) / 20 * t.appearanceProgress(ofEventAt: 2)
            XCTAssertEqual(t.progress(at: t.date(at: p)), p, accuracy: 1e-9)
        }
        XCTAssertEqual(t.progress(at: .distantPast), 0)
        XCTAssertEqual(t.progress(at: .distantFuture), 1)
    }

    func testOutOfRangeProgressIsClamped() throws {
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 10)])
        XCTAssertEqual(t.revealedCount(at: -3), 0)
        XCTAssertEqual(t.revealedCount(at: 7), 2)
        XCTAssertEqual(t.revealedCount(at: .nan), 0)
        XCTAssertEqual(t.date(at: 7), t.endDate)
    }

    func testCountryCountIgnoresSubdivisions() throws {
        let t = try timeline([
            event("US", dayOffset: 0),
            event("CA", dayOffset: 1, type: "us_state", country: "US"),
            event("NY", dayOffset: 2, type: "us_state", country: "US"),
            event("MX", dayOffset: 3),
        ])
        XCTAssertEqual(t.countryCount(at: 0), 0)
        XCTAssertEqual(t.countryCount(at: t.appearanceProgress(ofEventAt: 2)), 1)
        XCTAssertEqual(t.countryCount(at: 1), 2)
        XCTAssertEqual(t.revealedEvents(at: t.appearanceProgress(ofEventAt: 2)).map(\.regionCode), ["US", "CA", "NY"])
    }

    func testRecentEventsWindow() throws {
        var config = TimelinePlaybackConfig()
        config.maxGap = 10 * day
        config.bookend = 10 * day
        config.minDuration = 10
        config.maxDuration = 10
        // Axis: 10 lead-in + 10 + 10 + 10 hold = 40 days over 10 s, so 1 s = 4 days.
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 10), event("DE", dayOffset: 20)], config: config)
        XCTAssertEqual(t.duration, 10)

        XCTAssertTrue(t.recentEvents(at: 0, window: 2).isEmpty)

        // At DE's arrival with a 3 s (12-day) window: DE (age 0), NL (10 of 12 days), not BE.
        let atDE = t.recentEvents(at: t.appearanceProgress(ofEventAt: 2), window: 3)
        XCTAssertEqual(atDE.map(\.event.regionCode), ["DE", "NL"])
        XCTAssertEqual(atDE[0].age, 0, accuracy: 1e-9)
        XCTAssertEqual(atDE[1].age, 10.0 / 12, accuracy: 1e-9)

        XCTAssertEqual(t.recentEvents(at: 1, window: 3, limit: 1).map(\.event.regionCode), ["DE"])
        XCTAssertTrue(t.recentEvents(at: 1, window: 0).isEmpty)
    }

    func testAdvancingRespectsSpeedAndStopsAtTheEnd() throws {
        var config = TimelinePlaybackConfig()
        config.minDuration = 20
        config.maxDuration = 20
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 10)], config: config)
        XCTAssertEqual(t.advanced(from: 0, elapsed: 1, speed: .normal), 0.05, accuracy: 1e-12)
        XCTAssertEqual(t.advanced(from: 0, elapsed: 1, speed: .half), 0.025, accuracy: 1e-12)
        XCTAssertEqual(t.advanced(from: 0, elapsed: 1, speed: .quadruple), 0.2, accuracy: 1e-12)
        XCTAssertEqual(t.advanced(from: 0.9, elapsed: 5, speed: .double), 1)
        XCTAssertEqual(t.advanced(from: 0.4, elapsed: -1, speed: .normal), 0.4)
    }

    func testDurationScalesWithHistoryWithinBounds() throws {
        let config = TimelinePlaybackConfig()
        XCTAssertEqual(try timeline([event("BE", dayOffset: 0)]).duration, config.minDuration)
        let many = (0..<200).map { event("X\($0)", dayOffset: Double($0)) }
        XCTAssertEqual(try timeline(many).duration, config.maxDuration)
        let some = (0..<10).map { event("X\($0)", dayOffset: Double($0)) }
        XCTAssertEqual(try timeline(some).duration, 10 * config.secondsPerEvent, accuracy: 1e-9)
    }

    func testYearMarkersFallOnNewYear() throws {
        // The 30-day lead-in starts 2026-12-16; the last visit is 2029-01-15.
        let t = try timeline([event("BE", dayOffset: 0), event("NL", dayOffset: 731)])
        let markers = t.yearMarkers(calendar: utc)
        XCTAssertEqual(markers.map(\.year), [2027, 2028, 2029])
        for marker in markers {
            XCTAssertEqual(utc.component(.year, from: t.date(at: marker.progress)), marker.year)
            let date = utc.dateComponents([.month, .day], from: t.date(at: marker.progress))
            XCTAssertEqual([date.month, date.day], [1, 1])
        }
        XCTAssertEqual(markers.map(\.progress), markers.map(\.progress).sorted())
        XCTAssertTrue(try timeline([event("BE", dayOffset: 100)]).yearMarkers(calendar: utc).isEmpty)
    }

    func testSpeedCyclesThroughAllOptions() {
        XCTAssertEqual(PlaybackSpeed.half.next, .normal)
        XCTAssertEqual(PlaybackSpeed.quadruple.next, .half)
        XCTAssertEqual(PlaybackSpeed.allCases.map(\.rawValue), [0.5, 1, 2, 4])
    }
}
