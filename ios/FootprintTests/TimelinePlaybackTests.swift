import CoreLocation
import XCTest

@testable import Footprint

@MainActor
final class TimelinePlaybackTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_600_000_000)

    private func stop(_ code: String, day: Int, type: VisitedPlace.RegionType = .country, country: String? = nil,
                      at point: GeoPoint? = nil) -> TimelineStop {
        TimelineStop(id: "\(type.rawValue):\(code)", date: t0.addingTimeInterval(Double(day) * 86_400),
                     regionType: type.rawValue, regionCode: code, regionName: code,
                     countryCode: country ?? code, coordinate: point)
    }

    private func stops(_ count: Int) -> [TimelineStop] {
        (0..<count).map { stop("C\($0)", day: $0, at: GeoPoint(latitude: 0, longitude: Double($0))) }
    }

    /// Plays at 30 frames a second, like the view, for `seconds`.
    private func play(_ playback: inout TimelinePlayback, seconds: Double, speed: Double = 1) {
        for _ in 0..<Int(seconds * 30) { playback.advance(by: 1.0 / 30, speed: speed) }
    }

    // MARK: - Playback

    /// The shipped player kept an integer index and dropped each tick's fractional advance, so with
    /// fewer than 360 places it never got past the first one.
    func testPlayReachesTheEndWithFewPlaces() {
        var playback = TimelinePlayback(stops: stops(20))
        play(&playback, seconds: 4)
        XCTAssertGreaterThan(playback.revealedCount, 1)
        play(&playback, seconds: playback.duration)
        XCTAssertTrue(playback.isAtEnd)
        XCTAssertEqual(playback.revealedCount, 20)
        XCTAssertEqual(playback.progress, 1, accuracy: 1e-9)
    }

    func testEveryFrameMovesForward() {
        var playback = TimelinePlayback(stops: stops(3))
        var last = playback.progress
        for _ in 0..<30 {
            playback.advance(by: 1.0 / 30)
            XCTAssertGreaterThan(playback.progress, last)
            last = playback.progress
        }
    }

    func testSpeedShortensPlayback() {
        var playback = TimelinePlayback(stops: stops(20))
        play(&playback, seconds: playback.duration / 4 + 0.1, speed: 4)
        XCTAssertTrue(playback.isAtEnd)
    }

    func testDurationIsBounded() {
        XCTAssertEqual(TimelinePlayback(stops: stops(2)).duration, 8)
        XCTAssertEqual(TimelinePlayback(stops: stops(10)).duration, 12, accuracy: 1e-9)
        XCTAssertEqual(TimelinePlayback(stops: stops(500)).duration, 60)
    }

    func testSeekRewindAndSkip() {
        var playback = TimelinePlayback(stops: stops(4))
        XCTAssertEqual(playback.revealedCount, 0)
        playback.seek(toProgress: 0.5)
        XCTAssertEqual(playback.revealedCount, 2)
        playback.seek(toProgress: 1)
        XCTAssertTrue(playback.isAtEnd)
        playback.rewind()
        XCTAssertEqual(playback.revealedCount, 0)
        XCTAssertTrue(playback.journeyPath.isEmpty)
        playback.skipToEnd()
        XCTAssertEqual(playback.revealedCount, 4)
    }

    func testEmptyTimelineDoesNothing() {
        var playback = TimelinePlayback(stops: [])
        playback.advance(by: 10)
        playback.seek(toProgress: 1)
        XCTAssertEqual(playback.revealedCount, 0)
        XCTAssertFalse(playback.isAtEnd)
        XCTAssertTrue(playback.journeyPath.isEmpty)
    }

    // MARK: - Journey line

    func testJourneyLineFliesTowardTheNextPlace() {
        let a = GeoPoint(latitude: 0, longitude: 0), b = GeoPoint(latitude: 0, longitude: 10)
        var playback = TimelinePlayback(stops: [stop("A", day: 0, at: a), stop("B", day: 1, at: b)])
        playback.seek(toProgress: 0.75)  // A shown, halfway to B
        let path = playback.journeyPath
        XCTAssertEqual(path.count, 2)
        XCTAssertEqual(path[0], a)
        XCTAssertEqual(path[1].longitude, 5, accuracy: 0.01)
        playback.skipToEnd()
        XCTAssertEqual(playback.journeyPath, [a, b])
    }

    func testJourneyLineSkipsPlacesWithoutALocationAndRepeats() {
        let a = GeoPoint(latitude: 10, longitude: 10)
        var playback = TimelinePlayback(stops: [stop("A", day: 0, at: a), stop("B", day: 1), stop("C", day: 2, at: a)])
        playback.skipToEnd()
        XCTAssertEqual(playback.journeyPath, [a])
    }

    func testGreatCircleCrossesTheAntimeridianTheShortWay() {
        let mid = GeoPoint(latitude: 0, longitude: 170).interpolated(to: GeoPoint(latitude: 0, longitude: -170), fraction: 0.5)
        XCTAssertEqual(abs(mid.longitude), 180, accuracy: 0.01)
        let start = GeoPoint(latitude: 51.5, longitude: -0.1)
        XCTAssertEqual(start.interpolated(to: GeoPoint(latitude: 40.7, longitude: -74), fraction: 0), start)
    }

    func testInteriorPointWhenTheBoxMiddleIsOutside() {
        // A "C": the bounding-box middle (5, 5) is in the gap.
        let ring = [(0, 0), (0, 10), (10, 10), (10, 8), (2, 8), (2, 2), (10, 2), (10, 0)]
            .map { GeoPoint(latitude: Double($0.0), longitude: Double($0.1)) }
        guard let point = GeoPoint.interiorPoint(of: ring) else { return XCTFail("no interior point") }
        XCTAssertTrue(GeoPoint.contains(point, in: ring))
    }

    func testRegionCentersFallInsideTheirCountry() {
        let codes = ["NO", "VN", "HR", "FR", "US", "CL", "IT"]
        let centers = RegionCenters.centers(for: codes.enumerated().map { stop($1, day: $0) })
        GeoLocationMatcher.shared.loadBoundariesIfNeeded()
        for code in codes {
            let point = centers["country:\(code)"]
            XCTAssertNotNil(point, code)
            guard let point else { continue }
            let match = GeoLocationMatcher.shared.matchCoordinate(
                CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
            XCTAssertEqual(match?.countryCode, code, code)
        }
    }

    func testSubdivisionsWithoutBoundaryFilesGetTheirOwnPoints() {
        let stops = [stop("DE", day: 0), stop("BE", day: 1, type: .germanState, country: "DE"),
                     stop("BY", day: 2, type: .germanState, country: "DE")]
        let centers = RegionCenters.centers(for: stops)
        let germany = centers["country:DE"], berlin = centers["german_state:BE"], bavaria = centers["german_state:BY"]
        XCTAssertNotNil(berlin)
        XCTAssertNotNil(bavaria)
        XCTAssertNotEqual(berlin, bavaria)
        XCTAssertNotEqual(berlin, germany)
    }

    // MARK: - Stops

    func testStopsAreVisitedPlacesInDateOrder() {
        let places = [
            VisitedPlace(regionType: .country, regionCode: "FR", regionName: "France", visitedDate: t0.addingTimeInterval(86_400)),
            VisitedPlace(regionType: .usState, regionCode: "CA", regionName: "California", visitedDate: t0),
            VisitedPlace(regionType: .country, regionCode: "JP", regionName: "Japan", status: .bucketList, visitedDate: t0),
            VisitedPlace(regionType: .country, regionCode: "DE", regionName: "Germany", visitedDate: t0, isDeleted: true),
            VisitedPlace(regionType: .usCounty, regionCode: "06075", regionName: "San Francisco County", visitedDate: t0),
            VisitedPlace(regionType: .country, regionCode: "IT", regionName: "Italy", markedAt: t0.addingTimeInterval(2 * 86_400)),
        ]
        let stops = TimelineStop.stops(from: places)
        XCTAssertEqual(stops.map(\.regionCode), ["CA", "FR", "IT"])
        XCTAssertEqual(stops.map(\.countryCode), ["US", "FR", "IT"])
    }

    func testVisibleStateCodes() {
        var playback = TimelinePlayback(stops: [
            stop("CA", day: 0, type: .usState, country: "US"),
            stop("BE", day: 1),
            stop("FR", day: 2),
        ])
        playback.skipToEnd()
        let codes = playback.visibleStateCodes(tracksStates: { $0 == "FR" }, subdivisions: { $0 == "BE" ? ["VAN", "WBR"] : ["IDF"] })
        XCTAssertEqual(codes, ["US-CA", "BE-VAN", "BE-WBR"])
        XCTAssertEqual(playback.visibleCountryCodes, ["BE", "FR"])
    }

    // MARK: - Landmarks

    func testLandmarksAppearWithTheirPlace() {
        var playback = TimelinePlayback(stops: [stop("FR", day: 0), stop("US", day: 1)])
        XCTAssertTrue(playback.visibleLandmarks().isEmpty)
        playback.seek(toProgress: 0.5)
        XCTAssertEqual(playback.visibleLandmarks().map(\.id), ["eiffel"])
        playback.skipToEnd()
        XCTAssertTrue(Set(playback.visibleLandmarks().map(\.id)).isSuperset(of: ["eiffel", "liberty", "goldengate"]))
    }

    func testStateLandmarksWaitForTheirStateWhenStatesAreTracked() {
        var playback = TimelinePlayback(stops: [stop("US", day: 0), stop("CA", day: 1, type: .usState, country: "US")])
        playback.skipToEnd()
        let ids = Set(playback.visibleLandmarks().map(\.id))
        XCTAssertTrue(ids.contains("goldengate"))
        XCTAssertFalse(ids.contains("liberty"))
    }

    func testLandmarkCatalogIsValid() {
        let catalog = Landmark.catalog
        XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count)
        let countries = Set(GeographicData.countries.map(\.id))
        GeoLocationMatcher.shared.loadBoundariesIfNeeded()
        for landmark in catalog {
            XCTAssertTrue(countries.contains(landmark.countryCode), landmark.id)
            if let sub = landmark.subdivisionCode {
                XCTAssertTrue(GeographicData.states(for: landmark.countryCode).contains { $0.id == sub }, landmark.id)
            }
            let match = GeoLocationMatcher.shared.matchCoordinateWithTolerance(
                CLLocationCoordinate2D(latitude: landmark.coordinate.latitude, longitude: landmark.coordinate.longitude),
                toleranceMeters: 3_000
            )
            XCTAssertEqual(match?.countryCode == "CN-TW" ? "TW" : match?.countryCode, landmark.countryCode, landmark.id)
        }
    }

    func testEveryLandmarkStyleRenders() {
        for style in Landmark.Style.allCases {
            XCTAssertNotNil(LandmarkAnnotationView.image(for: style), style.rawValue)
        }
    }
}
