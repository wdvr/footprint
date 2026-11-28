import Foundation
import SwiftData

/// City layer wiring for `VisitPipeline`. An opt-in data layer, off by default like counties.
struct CityLayer {
    static let enabledDefaultsKey = "citiesEnabled"

    static func isEnabled(_ defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: enabledDefaultsKey)
    }

    /// nil = the bundled gazetteer.
    var gazetteer: CityGazetteer?
    /// County FIPS for a coordinate, once a county matcher is available; nil skips the county tier.
    var countyResolver: CityVisitDetector.CountyResolver?

    var resolvedGazetteer: CityGazetteer? { gazetteer ?? .bundled }
}

extension Visit {
    var isCityVisit: Bool { levelRaw == DetectedCityVisit.visitLevelRaw }
}

extension CityCoverage {
    /// Coverage from the user's places: full visits only; transit does not count (§2.5).
    init(gazetteer: CityGazetteer, places: [VisitedPlace]) {
        let cityType = VisitedPlace.RegionType.city.rawValue
        let ids = places
            .filter { $0.regionType == cityType && !$0.isDeleted && $0.isVisited && $0.isFullVisit }
            .map(\.regionCode)
        self.init(gazetteer: gazetteer, visitedCityIds: Set(ids))
    }
}

extension VisitPipeline {
    /// Derives city visits from the window the boundary levels just processed: writes city `Visit`
    /// rows and upserts `.city` places. Returns the ids of cities newly marked visited.
    @discardableResult
    func recordCities(_ evidence: [EvidenceSample], windowStart: Date, in context: ModelContext, now: Date) -> [String] {
        guard let gazetteer = cityLayer.resolvedGazetteer else { return [] }
        let detected = CityVisitDetector.detect(
            evidence, matcher: CityMatcher(gazetteer: gazetteer), resolve: resolve,
            county: cityLayer.countyResolver, config: config, calendar: calendar
        )
        return CityVisitRecorder.upsert(detected, gazetteer: gazetteer, windowStart: windowStart, in: context, now: now)
    }
}

@MainActor
enum CityVisitRecorder {
    static func upsert(
        _ detected: [DetectedCityVisit],
        gazetteer: CityGazetteer,
        windowStart: Date,
        in context: ModelContext,
        now: Date
    ) -> [String] {
        let level = DetectedCityVisit.visitLevelRaw
        var existing = (try? context.fetch(FetchDescriptor<Visit>(
            predicate: #Predicate { $0.levelRaw == level && ($0.departedAt ?? $0.arrivedAt) >= windowStart }
        ))) ?? []
        var newCities: [String] = []

        for visit in detected {
            guard let city = gazetteer.city(id: visit.cityId) else { continue }
            if let row = existing.first(where: { overlaps($0, visit) }) {
                row.arrivedAt = min(row.arrivedAt, visit.arrivedAt)
                row.departedAt = max(row.departedAt ?? visit.departedAt, visit.departedAt)
                row.sampleCount = max(row.sampleCount, visit.sampleCount)
                row.centroidLat = visit.centroidLatitude
                row.centroidLon = visit.centroidLongitude
                if visit.kind == .visited, row.kind == .transit {
                    row.kindRaw = DetectedVisitKind.visited.rawValue
                    if upsertPlace(city, visit: visit, isNewVisit: false, in: context, now: now) {
                        newCities.append(city.id)
                    }
                }
            } else {
                let row = Visit(DetectedVisit(
                    level: .country, countryCode: visit.countryCode, subdivisionCode: visit.subdivisionCode,
                    kind: visit.kind, arrivedAt: visit.arrivedAt, departedAt: visit.departedAt,
                    centroidLatitude: visit.centroidLatitude, centroidLongitude: visit.centroidLongitude,
                    sampleCount: visit.sampleCount, source: visit.source
                ))
                row.levelRaw = level
                row.cityId = city.id
                context.insert(row)
                try? context.save()
                existing.append(row)
                if upsertPlace(city, visit: visit, isNewVisit: true, in: context, now: now) {
                    newCities.append(city.id)
                }
            }
        }
        return newCities
    }

    private static func overlaps(_ row: Visit, _ visit: DetectedCityVisit) -> Bool {
        row.cityId == visit.cityId
            && row.arrivedAt <= visit.departedAt
            && (row.departedAt ?? row.arrivedAt) >= visit.arrivedAt
    }

    /// Same rules as the boundary levels: a bucket-list city becomes visited; a city the user removed
    /// comes back only for a visit that started after the removal. True if newly marked visited.
    private static func upsertPlace(
        _ city: City,
        visit: DetectedCityVisit,
        isNewVisit: Bool,
        in context: ModelContext,
        now: Date
    ) -> Bool {
        let visitType: VisitedPlace.VisitType = visit.kind == .visited ? .visited : .transit
        let typeRaw = VisitedPlace.RegionType.city.rawValue
        let code = city.id
        let places = (try? context.fetch(FetchDescriptor<VisitedPlace>(
            predicate: #Predicate { $0.regionType == typeRaw && $0.regionCode == code }
        ))) ?? []

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
            return false
        }

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
            return true
        }
        if places.contains(where: { $0.isDeleted }) {
            return false
        }
        context.insert(VisitedPlace(
            regionType: .city,
            regionCode: code,
            regionName: city.name,
            visitType: visitType,
            visitedDate: visit.arrivedAt,
            markedAt: now,
            lastModifiedAt: now
        ))
        try? context.save()
        return true
    }
}
