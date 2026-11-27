import CoreLocation
import Foundation
import SwiftData

/// Glue between the pure detector and SwiftData (§3.2): stores samples, derives `Visit` rows,
/// and upserts `VisitedPlace` (country / subdivision only in Phase 1).
@MainActor
final class VisitPipeline {
    static let shared = VisitPipeline()

    /// A place the pipeline recorded as visited for the first time (or again after removal).
    struct NewPlace: Hashable, Sendable {
        let countryCode: String
        let subdivisionCode: String?
    }

    struct Status: Equatable, Sendable {
        var pendingSamples = 0
        var storedSamples = 0
        var visits = 0
        var lastRunAt: Date?
        var distanceKm = 0.0
    }

    /// Re-derive this far back before the oldest pending sample, so ongoing stays keep growing.
    static let lookback: TimeInterval = 36 * 3600
    /// §3.1 retention: raw samples are kept for a rolling 13 months.
    static let sampleRetention: TimeInterval = 395 * 86_400
    static let distanceDefaultsKey = "visitPipeline.distanceMeters"
    static let lastRunDefaultsKey = "visitPipeline.lastRunAt"

    private(set) var container: ModelContainer?
    var config = VisitDetectionConfig.default
    var calendar = Calendar.current
    var resolve: VisitDetector.Resolver = VisitPipeline.boundaryResolver
    var defaults: UserDefaults = .standard

    init(container: ModelContainer? = nil) {
        self.container = container
    }

    func configure(container: ModelContainer) {
        self.container = container
    }

    /// On-device boundary matching; the geocoder is never the source of a record (§3.4).
    nonisolated static func boundaryResolver(_ latitude: Double, _ longitude: Double) -> PlaceKey? {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard let match = GeoLocationMatcher.matchCoordinateNonisolated(coordinate) else { return nil }
        let subdivision = match.stateCode.map { String($0.split(separator: "-").last ?? Substring($0)) }
        return PlaceKey(countryCode: match.countryCode, subdivisionCode: subdivision)
    }

    // MARK: - Ingest

    /// Stores samples (dropping ones too inaccurate to be evidence) and runs the pipeline.
    @discardableResult
    func record(_ samples: [EvidenceSample], now: Date = Date()) -> [NewPlace] {
        guard let context = container?.mainContext else { return [] }
        var inserted = 0
        for sample in samples where sample.horizontalAccuracy >= 0 && sample.horizontalAccuracy <= config.maxAccuracyMeters {
            context.insert(LocationSample(
                timestamp: sample.timestamp, latitude: sample.latitude, longitude: sample.longitude,
                horizontalAccuracy: sample.horizontalAccuracy, source: sample.source
            ))
            inserted += 1
        }
        guard inserted > 0 else { return [] }
        try? context.save()
        return run(now: now)
    }

    // MARK: - Run

    @discardableResult
    func run(now: Date = Date()) -> [NewPlace] {
        guard let context = container?.mainContext else { return [] }
        let pending = (try? context.fetch(FetchDescriptor<LocationSample>(
            predicate: #Predicate { $0.processedAt == nil },
            sortBy: [SortDescriptor(\.timestamp)]
        ))) ?? []
        var newPlaces: [NewPlace] = []

        if let oldestPending = pending.first?.timestamp {
            let windowStart = oldestPending.addingTimeInterval(-Self.lookback)
            let window = (try? context.fetch(FetchDescriptor<LocationSample>(
                predicate: #Predicate { $0.timestamp >= windowStart },
                sortBy: [SortDescriptor(\.timestamp)]
            ))) ?? []
            let evidence = window.map(\.evidence)
            let detected = VisitDetector.detect(evidence, resolve: resolve, config: config, calendar: calendar)
            newPlaces = upsert(detected, windowStart: windowStart, in: context, now: now)

            accumulateDistance(window: window, now: now)
            for sample in pending {
                sample.processedAt = now
            }
        }

        let retentionCutoff = now.addingTimeInterval(-Self.sampleRetention)
        try? context.delete(model: LocationSample.self, where: #Predicate { $0.timestamp < retentionCutoff })
        try? context.save()
        defaults.set(now, forKey: Self.lastRunDefaultsKey)
        return newPlaces
    }

    func status() -> Status {
        guard let context = container?.mainContext else { return Status() }
        return Status(
            pendingSamples: (try? context.fetchCount(FetchDescriptor<LocationSample>(
                predicate: #Predicate { $0.processedAt == nil }
            ))) ?? 0,
            storedSamples: (try? context.fetchCount(FetchDescriptor<LocationSample>())) ?? 0,
            visits: (try? context.fetchCount(FetchDescriptor<Visit>())) ?? 0,
            lastRunAt: defaults.object(forKey: Self.lastRunDefaultsKey) as? Date,
            distanceKm: defaults.double(forKey: Self.distanceDefaultsKey) / 1000
        )
    }

    // MARK: - Private

    /// Distance over newly processed legs only: the last already-processed sample anchors the track.
    private func accumulateDistance(window: [LocationSample], now: Date) {
        guard let firstPending = window.firstIndex(where: { $0.processedAt == nil }) else { return }
        let track = window[max(0, firstPending - 1)...].map(\.evidence)
        let meters = DistanceAccumulator.meters(track, config: config)
        defaults.set(defaults.double(forKey: Self.distanceDefaultsKey) + meters, forKey: Self.distanceDefaultsKey)
    }

    private func upsert(
        _ detected: [DetectedVisit],
        windowStart: Date,
        in context: ModelContext,
        now: Date
    ) -> [NewPlace] {
        // Visits re-derived from an overlapping window extend the row they came from.
        let horizon = windowStart.addingTimeInterval(-Self.lookback)
        var existing = (try? context.fetch(FetchDescriptor<Visit>(
            predicate: #Predicate { $0.arrivedAt >= horizon || $0.departedAt == nil }
        ))) ?? []
        var newPlaces: [NewPlace] = []

        for visit in detected {
            if let row = existing.first(where: { overlaps($0, visit) }) {
                row.arrivedAt = min(row.arrivedAt, visit.arrivedAt)
                row.departedAt = max(row.departedAt ?? visit.departedAt, visit.departedAt)
                row.sampleCount = max(row.sampleCount, visit.sampleCount)
                row.centroidLat = visit.centroidLatitude
                row.centroidLon = visit.centroidLongitude
                if visit.kind == .visited, row.kind == .transit {
                    row.kindRaw = DetectedVisitKind.visited.rawValue
                    if let place = upsertPlace(for: visit, isNewVisit: false, in: context, now: now) {
                        newPlaces.append(place)
                    }
                }
            } else {
                let row = Visit(visit)
                context.insert(row)
                try? context.save()
                existing.append(row)
                if let place = upsertPlace(for: visit, isNewVisit: true, in: context, now: now) {
                    newPlaces.append(place)
                }
            }
        }
        return newPlaces
    }

    private func overlaps(_ row: Visit, _ visit: DetectedVisit) -> Bool {
        row.levelRaw == visit.level.rawValue
            && row.countryCode == visit.countryCode
            && row.subdivisionCode == visit.subdivisionCode
            && row.arrivedAt <= visit.departedAt
            && (row.departedAt ?? row.arrivedAt) >= visit.arrivedAt
    }

    /// Returns the place if this visit newly marks it visited.
    private func upsertPlace(for visit: DetectedVisit, isNewVisit: Bool, in context: ModelContext, now: Date) -> NewPlace? {
        let regionType: VisitedPlace.RegionType
        let regionCode: String
        let regionName: String
        switch visit.level {
        case .country:
            guard let country = GeographicData.countries.first(where: { $0.id == visit.countryCode }) else { return nil }
            regionType = .country
            regionCode = country.id
            regionName = country.name
        case .subdivision:
            guard let code = visit.subdivisionCode,
                  let type = GeographicData.regionType(for: visit.countryCode),
                  let state = GeographicData.states(for: visit.countryCode).first(where: { $0.id == code })
            else { return nil }
            regionType = type
            regionCode = code
            regionName = state.name
        }
        let visitType: VisitedPlace.VisitType = visit.kind == .visited ? .visited : .transit
        let typeRaw = regionType.rawValue
        let places = (try? context.fetch(FetchDescriptor<VisitedPlace>(
            predicate: #Predicate { $0.regionType == typeRaw && $0.regionCode == regionCode }
        ))) ?? []
        let newPlace = NewPlace(countryCode: visit.countryCode, subdivisionCode: visit.level == .subdivision ? regionCode : nil)

        if let place = places.first(where: { !$0.isDeleted && $0.isVisited }) {
            var changed = false
            if isNewVisit {
                place.visitCount += 1
                changed = true
            }
            if place.visitedDate.map({ visit.arrivedAt < $0 }) ?? true {
                place.visitedDate = visit.arrivedAt
                changed = true
            }
            if visitType == .visited, place.isTransit {
                place.visitType = visitType.rawValue
                changed = true
            }
            if changed {
                place.lastModifiedAt = now
                place.isSynced = false
            }
            return nil
        }

        // A bucket-list entry becomes visited; a place the user removed comes back only for a visit
        // that started after they removed it.
        let reusable = places.first { !$0.isDeleted && $0.isBucketList }
            ?? places.first { $0.isDeleted && isNewVisit && visit.arrivedAt > $0.lastModifiedAt }
        if let place = reusable {
            place.status = VisitedPlace.PlaceStatus.visited.rawValue
            place.visitType = visitType.rawValue
            place.isDeleted = false
            place.visitedDate = visit.arrivedAt
            place.visitCount = 1
            place.lastModifiedAt = now
            place.isSynced = false
            return newPlace
        }
        if places.contains(where: { $0.isDeleted }) {
            return nil
        }
        context.insert(VisitedPlace(
            regionType: regionType,
            regionCode: regionCode,
            regionName: regionName,
            visitType: visitType,
            visitedDate: visit.arrivedAt,
            markedAt: now,
            lastModifiedAt: now
        ))
        try? context.save()
        return newPlace
    }
}
