import Foundation

/// Where a location sample came from (§3.1).
enum SampleSource: String, Codable, Sendable, CaseIterable {
    case gps
    case photo
    case manual
}

/// All visit-detection thresholds (§3.3) in one place, so field tuning changes constants, not logic.
struct VisitDetectionConfig: Sendable, Equatable {
    /// A stay-point is a maximal run of samples within this radius of its first sample...
    var stayRadiusMeters: Double = 200
    /// ...spanning at least this long.
    var minStayDuration: TimeInterval = 5 * 60
    /// Dwell needed for a stay to confirm a country / subdivision / county.
    var placeDwell: TimeInterval = 10 * 60
    /// Dwell needed for a stay to confirm a city (Phase 3).
    var cityDwell: TimeInterval = 20 * 60
    /// In-boundary samples needed; a GPS photo in the same window counts as a sample.
    var minSamples = 2
    /// Samples less accurate than this are evidence of nothing and are dropped at ingest.
    var maxAccuracyMeters: Double = 1_000
    /// Accuracy required for county / city evidence (Phase 2+).
    var localMaxAccuracyMeters: Double = 250
    /// Below the dwell gate, presence spanning at least this long is a pass-through.
    var passThroughMinSpan: TimeInterval = 2 * 60
    /// Implied speed between fixes above which a leg is a flight.
    var flightSpeedKmh: Double = 250
    /// A stay between two flight legs is a layover: country-level transit if it lasts this long.
    var layoverDwell: TimeInterval = 45 * 60
    /// Owner ruling on spec Open Question 5: a ground pass-through (e.g. a highway drive-through)
    /// counts as a full visit, not transit. `false` restores the spec's transit default.
    var passThroughCountsAsVisit = true

    static let `default` = VisitDetectionConfig()
}

/// A location fix as the pure pipeline sees it (decoupled from SwiftData and CoreLocation).
struct EvidenceSample: Sendable, Equatable {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var source: SampleSource = .gps
}

/// The place a coordinate resolves to. `subdivisionCode` is the short code used by
/// `GeographicData.states(for:)` (e.g. "CA" for US-CA).
struct PlaceKey: Hashable, Sendable {
    let countryCode: String
    let subdivisionCode: String?
}

enum PlaceLevel: String, Sendable, CaseIterable {
    case country
    case subdivision
}

enum DetectedVisitKind: String, Sendable {
    case visited
    case transit
}

struct DetectedVisit: Sendable, Equatable {
    let level: PlaceLevel
    let countryCode: String
    let subdivisionCode: String?
    let kind: DetectedVisitKind
    let arrivedAt: Date
    let departedAt: Date
    let centroidLatitude: Double
    let centroidLongitude: Double
    let sampleCount: Int
    let source: SampleSource
}

/// A run of samples within `stayRadiusMeters` of its first sample, spanning `minStayDuration`.
struct StayPoint: Sendable, Equatable {
    /// Inclusive bounds into the clustered sample array.
    let range: ClosedRange<Int>
    let arrivedAt: Date
    let departedAt: Date
    let centroidLatitude: Double
    let centroidLongitude: Double

    var duration: TimeInterval { departedAt.timeIntervalSince(arrivedAt) }
}

enum GeoMath {
    static let earthRadiusMeters = 6_371_000.0

    static func distanceMeters(_ a: EvidenceSample, _ b: EvidenceSample) -> Double {
        distanceMeters(lat1: a.latitude, lon1: a.longitude, lat2: b.latitude, lon2: b.longitude)
    }

    static func distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    static func centroid(_ samples: ArraySlice<EvidenceSample>) -> (latitude: Double, longitude: Double) {
        let n = Double(samples.count)
        return (samples.map(\.latitude).reduce(0, +) / n, samples.map(\.longitude).reduce(0, +) / n)
    }
}

enum StayPointClusterer {
    /// Stay-points in time-ordered `samples`. Overnight runs (spanning local midnight) qualify
    /// regardless of `minStayDuration`.
    static func cluster(
        _ samples: [EvidenceSample],
        config: VisitDetectionConfig = .default,
        calendar: Calendar = .current
    ) -> [StayPoint] {
        var stays: [StayPoint] = []
        var i = 0
        while i < samples.count {
            var j = i + 1
            while j < samples.count, GeoMath.distanceMeters(samples[i], samples[j]) <= config.stayRadiusMeters {
                j += 1
            }
            let start = samples[i].timestamp
            let end = samples[j - 1].timestamp
            if j - i >= 2,
               end.timeIntervalSince(start) >= config.minStayDuration
                || VisitDetector.spansLocalMidnight(start, end, calendar: calendar) {
                let c = GeoMath.centroid(samples[i..<j])
                stays.append(StayPoint(
                    range: i...(j - 1), arrivedAt: start, departedAt: end,
                    centroidLatitude: c.latitude, centroidLongitude: c.longitude
                ))
                i = j
            } else {
                i += 1
            }
        }
        return stays
    }
}

/// Turns raw samples into confirmed / transit visits per §3.2–3.3, as a pure function.
enum VisitDetector {
    typealias Resolver = (_ latitude: Double, _ longitude: Double) -> PlaceKey?

    /// Samples kept after the accuracy gate, time-ordered, with flight legs marked.
    struct PreparedTrack: Sendable {
        let samples: [EvidenceSample]
        /// `fastLegBefore[i]`: the leg from sample i-1 to i implies flight speed.
        let fastLegBefore: [Bool]

        func isFastLeg(after index: Int) -> Bool {
            index + 1 < fastLegBefore.count && fastLegBefore[index + 1]
        }

        /// Mid-air: both legs touching the sample are flight-speed.
        func isAirborne(_ index: Int) -> Bool {
            fastLegBefore[index] && isFastLeg(after: index)
        }
    }

    static func prepare(_ samples: [EvidenceSample], config: VisitDetectionConfig = .default) -> PreparedTrack {
        let kept = samples
            .filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= config.maxAccuracyMeters }
            .sorted { $0.timestamp < $1.timestamp }
        var fast = Array(repeating: false, count: kept.count)
        for i in kept.indices.dropFirst() {
            let a = kept[i - 1], b = kept[i]
            let seconds = b.timestamp.timeIntervalSince(a.timestamp)
            guard seconds > 0 else { continue }
            // Discount positional uncertainty so jitter between close fixes never looks like flight.
            let meters = max(0, GeoMath.distanceMeters(a, b) - a.horizontalAccuracy - b.horizontalAccuracy)
            fast[i] = meters / seconds * 3.6 > config.flightSpeedKmh
        }
        return PreparedTrack(samples: kept, fastLegBefore: fast)
    }

    static func detect(
        _ samples: [EvidenceSample],
        resolve: Resolver,
        config: VisitDetectionConfig = .default,
        calendar: Calendar = .current
    ) -> [DetectedVisit] {
        let track = prepare(samples, config: config)
        let keys: [PlaceKey?] = track.samples.indices.map { i in
            track.isAirborne(i) ? nil : resolve(track.samples[i].latitude, track.samples[i].longitude)
        }
        var visits: [DetectedVisit] = []
        for level in PlaceLevel.allCases {
            for run in presenceRuns(track: track, keys: keys, level: level) {
                if let visit = classify(run: run, level: level, track: track, keys: keys,
                                        resolve: resolve, config: config, calendar: calendar) {
                    visits.append(visit)
                }
            }
        }
        return visits.sorted { ($0.arrivedAt, $0.level.rawValue) < ($1.arrivedAt, $1.level.rawValue) }
    }

    static func spansLocalMidnight(_ start: Date, _ end: Date, calendar: Calendar) -> Bool {
        !calendar.isDate(start, inSameDayAs: end)
    }

    private static func levelKey(_ key: PlaceKey?, _ level: PlaceLevel) -> PlaceKey? {
        guard let key else { return nil }
        switch level {
        case .country: return PlaceKey(countryCode: key.countryCode, subdivisionCode: nil)
        case .subdivision: return key.subdivisionCode == nil ? nil : key
        }
    }

    /// Maximal runs of consecutive ground samples resolving to the same place at `level`.
    /// Flight legs and unresolved samples break runs.
    private static func presenceRuns(track: PreparedTrack, keys: [PlaceKey?], level: PlaceLevel) -> [ClosedRange<Int>] {
        var runs: [ClosedRange<Int>] = []
        var start: Int?
        for i in track.samples.indices {
            let key = levelKey(keys[i], level)
            if let s = start, key == nil || key != levelKey(keys[s], level) || track.fastLegBefore[i] {
                runs.append(s...(i - 1))
                start = nil
            }
            if start == nil, key != nil {
                start = i
            }
        }
        if let s = start {
            runs.append(s...(track.samples.count - 1))
        }
        return runs
    }

    private static func classify(
        run: ClosedRange<Int>,
        level: PlaceLevel,
        track: PreparedTrack,
        keys: [PlaceKey?],
        resolve: Resolver,
        config: VisitDetectionConfig,
        calendar: Calendar
    ) -> DetectedVisit? {
        // Anti-phantom rule: a single fly-by sample records nothing.
        guard run.count >= config.minSamples, let key = levelKey(keys[run.lowerBound], level) else { return nil }
        let runSamples = Array(track.samples[run])
        let arrivedAt = runSamples[0].timestamp
        let departedAt = runSamples[runSamples.count - 1].timestamp
        let span = departedAt.timeIntervalSince(arrivedAt)

        let kind: DetectedVisitKind
        var centroid = GeoMath.centroid(runSamples[...])
        let isLayover = track.fastLegBefore[run.lowerBound] && track.isFastLeg(after: run.upperBound)
        if isLayover {
            // Between two flights: country-level transit only, and only for a real layover.
            guard level == .country, span >= config.layoverDwell else { return nil }
            kind = .transit
        } else if let stay = StayPointClusterer.cluster(runSamples, config: config, calendar: calendar).first(where: {
            ($0.duration >= config.placeDwell || spansLocalMidnight($0.arrivedAt, $0.departedAt, calendar: calendar))
                // Stability: the stay centroid itself must be inside the boundary.
                && levelKey(resolve($0.centroidLatitude, $0.centroidLongitude), level) == key
        }) {
            kind = .visited
            centroid = (stay.centroidLatitude, stay.centroidLongitude)
        } else if span >= config.passThroughMinSpan {
            kind = config.passThroughCountsAsVisit ? .visited : .transit
        } else {
            return nil
        }

        let sources = Set(runSamples.map(\.source))
        return DetectedVisit(
            level: level,
            countryCode: key.countryCode,
            subdivisionCode: level == .subdivision ? key.subdivisionCode : nil,
            kind: kind,
            arrivedAt: arrivedAt,
            departedAt: departedAt,
            centroidLatitude: centroid.latitude,
            centroidLongitude: centroid.longitude,
            sampleCount: runSamples.count,
            source: sources.count == 1 ? sources.first! : .gps
        )
    }
}

/// Track length for the distance medals (§4.2), robust to GPS jitter.
enum DistanceAccumulator {
    /// Sum of leg lengths between consecutive accepted samples; a leg shorter than the larger of its
    /// endpoints' accuracy radii is noise, not movement, and adds nothing.
    static func meters(_ samples: [EvidenceSample], config: VisitDetectionConfig = .default) -> Double {
        let track = VisitDetector.prepare(samples, config: config).samples
        var total = 0.0
        var anchor = track.first
        for sample in track.dropFirst() {
            guard let from = anchor else { break }
            let leg = GeoMath.distanceMeters(from, sample)
            if leg > max(from.horizontalAccuracy, sample.horizontalAccuracy) {
                total += leg
                anchor = sample
            }
        }
        return total
    }
}
