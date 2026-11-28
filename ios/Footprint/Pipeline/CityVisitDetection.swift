import Foundation

/// A confirmed or transit stay in a gazetteer city.
struct DetectedCityVisit: Sendable, Equatable {
    /// `Visit.levelRaw` of city evidence rows (kept out of `PlaceLevel`, which drives the boundary levels).
    static let visitLevelRaw = "city"

    let cityId: String
    let countryCode: String
    /// Short subdivision code ("CA"), as on `Visit`.
    let subdivisionCode: String?
    let kind: DetectedVisitKind
    let arrivedAt: Date
    let departedAt: Date
    let centroidLatitude: Double
    let centroidLongitude: Double
    let sampleCount: Int
    let source: SampleSource
}

/// City visits from raw samples (§3.3): only fixes within `localMaxAccuracyMeters` count, a visit
/// needs a stay of `cityDwell` (or one spanning local midnight) inside the radius, and anything
/// shorter is transit — a city you only drove through is not a city visit.
enum CityVisitDetector {
    typealias CountyResolver = (_ latitude: Double, _ longitude: Double) -> String?

    static func detect(
        _ samples: [EvidenceSample],
        matcher: CityMatcher,
        resolve: VisitDetector.Resolver,
        county: CountyResolver? = nil,
        config: VisitDetectionConfig = .default,
        calendar: Calendar = .current
    ) -> [DetectedCityVisit] {
        let full = VisitDetector.prepare(samples, config: config)
        let local = full.samples.indices.filter {
            !full.isAirborne($0) && full.samples[$0].horizontalAccuracy <= config.localMaxAccuracyMeters
        }
        let track = local.map { full.samples[$0] }
        let fastLegBefore = local.enumerated().map { n, i in
            n > 0 && full.fastLegBefore[(local[n - 1] + 1)...i].contains(true)
        }

        func city(_ latitude: Double, _ longitude: Double) -> City? {
            guard matcher.hasCandidate(latitude: latitude, longitude: longitude),
                  let key = resolve(latitude, longitude)
            else { return nil }
            let context = CityPlaceContext(key, countyFips: county?(latitude, longitude))
            return matcher.match(latitude: latitude, longitude: longitude, context: context)
        }
        let cities = track.map { city($0.latitude, $0.longitude) }

        var visits: [DetectedCityVisit] = []
        var start: Int?
        func close(_ end: Int) {
            guard let s = start else { return }
            if let visit = classify(s...end, track: track, fastLegBefore: fastLegBefore, cities: cities,
                                    cityAt: city, config: config, calendar: calendar) {
                visits.append(visit)
            }
            start = nil
        }
        for i in track.indices {
            if let s = start, cities[i]?.id != cities[s]?.id || fastLegBefore[i] {
                close(i - 1)
            }
            if start == nil, cities[i] != nil {
                start = i
            }
        }
        close(track.count - 1)
        return visits
    }

    private static func classify(
        _ run: ClosedRange<Int>,
        track: [EvidenceSample],
        fastLegBefore: [Bool],
        cities: [City?],
        cityAt: (Double, Double) -> City?,
        config: VisitDetectionConfig,
        calendar: Calendar
    ) -> DetectedCityVisit? {
        guard run.count >= config.minSamples, let city = cities[run.lowerBound] else { return nil }
        let runSamples = Array(track[run])
        let arrivedAt = runSamples[0].timestamp
        let departedAt = runSamples[runSamples.count - 1].timestamp
        let span = departedAt.timeIntervalSince(arrivedAt)
        var centroid = GeoMath.centroid(runSamples[...])

        let arrivedByAir = fastLegBefore[run.lowerBound]
        let leavesByAir = run.upperBound + 1 < fastLegBefore.count && fastLegBefore[run.upperBound + 1]
        let isOpen = run.upperBound == track.count - 1
        let stillAtArrivalPoint = runSamples.allSatisfy {
            GeoMath.distanceMeters(runSamples[0], $0) <= config.stayRadiusMeters
        }
        let kind: DetectedVisitKind
        if arrivedByAir, isOpen, stillAtArrivalPoint, span <= config.maxLayover {
            // Possible layover; the boundary analysis keeps these samples in the next window.
            return nil
        } else if arrivedByAir, leavesByAir, span <= config.maxLayover {
            guard span >= config.layoverDwell else { return nil }
            kind = .transit
        } else if let stay = StayPointClusterer.cluster(runSamples, config: config, calendar: calendar).first(where: {
            ($0.duration >= config.cityDwell || VisitDetector.spansLocalMidnight($0.arrivedAt, $0.departedAt, calendar: calendar))
                && cityAt($0.centroidLatitude, $0.centroidLongitude)?.id == city.id
        }) {
            kind = .visited
            centroid = (stay.centroidLatitude, stay.centroidLongitude)
        } else if span >= config.passThroughMinSpan {
            kind = .transit
        } else {
            return nil
        }

        let sources = Set(runSamples.map(\.source))
        return DetectedCityVisit(
            cityId: city.id,
            countryCode: city.countryCode,
            subdivisionCode: city.subdivisionCode.map { String($0.split(separator: "-").last ?? Substring($0)) },
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
