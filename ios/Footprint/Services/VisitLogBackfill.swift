import Foundation
import SwiftData

/// Keeps the `Visit` log complete for places that have no sample evidence (§2.5, §4.4): every
/// visited `VisitedPlace` whose date is not explained by a detected visit gets one grandfathered
/// row mirroring it, so streaks and counts derive from the log alone. Place records are never
/// changed. Idempotent; runs at launch and before log stats are read.
enum VisitLogBackfill {
    struct Result: Equatable {
        var inserted = 0
        var updated = 0
        var removed = 0

        var changed: Bool { inserted + updated + removed > 0 }
    }

    static let subdivisionCountry: [String: String] = {
        var map: [String: String] = [:]
        for country in GeographicData.countries {
            if let type = GeographicData.regionType(for: country.id) {
                map[type.rawValue] = country.id
            }
        }
        return map
    }()

    /// The log key a place record maps to; nil for region types the log has no level for yet.
    static func placeID(regionType: String, regionCode: String) -> VisitLog.PlaceID? {
        if regionType == VisitedPlace.RegionType.country.rawValue {
            return VisitLog.PlaceID(level: .country, countryCode: regionCode, subdivisionCode: nil)
        }
        guard let country = subdivisionCountry[regionType] else { return nil }
        // Tolerate ISO-prefixed codes ("GB-WRL"): the log always uses the short code.
        let code = String(regionCode.split(separator: "-").last ?? Substring(regionCode))
        return VisitLog.PlaceID(level: .subdivision, countryCode: country, subdivisionCode: code)
    }

    @MainActor
    @discardableResult
    static func run(in context: ModelContext) -> Result {
        guard let places = try? context.fetch(FetchDescriptor<VisitedPlace>(
                  predicate: #Predicate { !$0.isDeleted },
                  sortBy: [SortDescriptor(\.markedAt)]
              )),
              let visits = try? context.fetch(FetchDescriptor<Visit>())
        else { return Result() }

        var wanted: [VisitLog.PlaceID: VisitedPlace] = [:]
        for place in places where place.isVisited {
            guard let id = placeID(regionType: place.regionType, regionCode: place.regionCode) else { continue }
            // Duplicate records of one place: the earliest dated one speaks for the place.
            if let other = wanted[id], (other.visitedDate ?? .distantFuture) <= (place.visitedDate ?? .distantFuture) {
                continue
            }
            wanted[id] = place
        }

        var earliestDetected: [VisitLog.PlaceID: Date] = [:]
        var fullyDetected: Set<VisitLog.PlaceID> = []
        var mirrors: [VisitLog.PlaceID: [Visit]] = [:]
        for visit in visits {
            let id = visit.logEntry.placeID
            switch visit.evidence {
            case .detected:
                earliestDetected[id] = min(earliestDetected[id] ?? visit.arrivedAt, visit.arrivedAt)
                if visit.kind == .visited { fullyDetected.insert(id) }
            case .grandfathered:
                mirrors[id, default: []].append(visit)
            }
        }

        // Evidence explains a place when it accounts for both its date (detected at or before it)
        // and its status (a visited place needs a full detected visit, not only a layover).
        func explained(_ place: VisitedPlace, _ id: VisitLog.PlaceID) -> Bool {
            guard let detected = earliestDetected[id], detected <= (place.visitedDate ?? .distantFuture) else {
                return false
            }
            return place.isTransit || fullyDetected.contains(id)
        }

        var result = Result()
        for (id, rows) in mirrors {
            let place = wanted[id]
            let keep = (place.map { !explained($0, id) } ?? false) ? Array(rows.prefix(1)) : []
            for row in rows.dropFirst(keep.count) {
                context.delete(row)
                result.removed += 1
            }
            if let row = keep.first, let place, mirror(place, into: row) {
                result.updated += 1
            }
        }
        for (id, place) in wanted where mirrors[id] == nil {
            if explained(place, id) { continue }
            let row = Visit(DetectedVisit(
                level: id.level, countryCode: id.countryCode, subdivisionCode: id.subdivisionCode,
                kind: .visited, arrivedAt: .distantPast, departedAt: .distantPast,
                centroidLatitude: 0, centroidLongitude: 0, sampleCount: 0, source: .manual
            ))
            row.evidenceRaw = VisitEvidenceKind.grandfathered.rawValue
            mirror(place, into: row)
            context.insert(row)
            result.inserted += 1
        }
        if result.changed {
            try? context.save()
        }
        return result
    }

    /// Copies the place's history onto its grandfathered row; returns whether anything changed.
    /// Visited unless the user marked the place as transit: missing dwell evidence never demotes it.
    @MainActor
    @discardableResult
    private static func mirror(_ place: VisitedPlace, into row: Visit) -> Bool {
        let arrivedAt = place.visitedDate ?? place.markedAt
        let kind: DetectedVisitKind = place.isTransit ? .transit : .visited
        let isDateKnown = place.visitedDate != nil
        guard row.arrivedAt != arrivedAt || row.departedAt != place.departureDate
                || row.kind != kind || row.isDateKnown != isDateKnown
        else { return false }
        row.arrivedAt = arrivedAt
        row.departedAt = place.departureDate
        row.kindRaw = kind.rawValue
        row.isDateKnown = isDateKnown
        return true
    }
}

extension VisitPipeline {
    /// Every `Visit` row as a pure log entry, oldest first.
    func logEntries() -> [VisitLogEntry] {
        guard let context = container?.mainContext else { return [] }
        let rows = (try? context.fetch(FetchDescriptor<Visit>(sortBy: [SortDescriptor(\.arrivedAt)]))) ?? []
        return rows.map(\.logEntry)
    }

    /// Distance along detected GPS stays only; read-only, so `status()` can call it.
    func logDistanceMeters() -> Double {
        guard let context = container?.mainContext else { return 0 }
        let detected = VisitEvidenceKind.detected.rawValue
        let gps = SampleSource.gps.rawValue
        let rows = (try? context.fetch(FetchDescriptor<Visit>(
            predicate: #Predicate { $0.evidenceRaw == detected && $0.sourceRaw == gps }
        ))) ?? []
        return VisitLog.distanceMeters(rows.map(\.logEntry))
    }

    /// Streaks, distance and place counts derived from the log, after bringing it up to date with
    /// places added by hand since launch.
    func travelStats(now: Date = Date()) -> VisitLog.Stats {
        guard let context = container?.mainContext else { return VisitLog.Stats() }
        VisitLogBackfill.run(in: context)
        return VisitLog.stats(logEntries(), calendar: calendar, asOf: now)
    }
}
