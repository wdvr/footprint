import Foundation
import Observation
import SwiftData

/// Glue between the pure `MedalEngine` and SwiftData (§4.1, §4.4): gathers evidence, runs the
/// retroactive backfill once, and keeps `EarnedMedal` rows up to date after every change.
@MainActor
@Observable
final class MedalService {
    static let shared = MedalService()

    static let backfillCompleteKey = "medals.backfillComplete.v"
    static let backfillFamiliesKey = "medals.backfillFamilies.v"
    static let bucketLedgerKey = "medals.bucketListLedger"

    /// Latest evaluation, for progress display.
    private(set) var results: [MedalEngine.Result] = []
    private(set) var lastEvaluatedAt: Date?

    let catalog: MedalCatalog?
    @ObservationIgnored var defaults: UserDefaults = .standard
    @ObservationIgnored var photoLocations: @MainActor () -> [PhotoLocation] = { PhotoLocationStore.shared.load() }
    @ObservationIgnored var distanceKm: @MainActor () -> Double = {
        UserDefaults.standard.double(forKey: VisitPipeline.distanceDefaultsKey) / 1000
    }
    @ObservationIgnored private var cityMatcherCache: CityMatcher?
    @ObservationIgnored var cityMatcherOverride: CityMatcher?

    init(catalog: MedalCatalog? = MedalService.bundledCatalog()) {
        self.catalog = catalog
    }

    static func bundledCatalog() -> MedalCatalog? {
        guard let url = Bundle.main.url(forResource: "medals", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        do {
            return try MedalCatalog.decode(data)
        } catch {
            Log.app.error("Failed to decode medals catalog: \(error)")
            return nil
        }
    }

    var isBackfillComplete: Bool {
        guard let catalog else { return false }
        return defaults.bool(forKey: Self.backfillCompleteKey + "\(catalog.catalogVersion)")
    }

    // MARK: - Evaluate

    /// Evaluates every medal and merges the awards into `EarnedMedal` rows. The first run is the
    /// §4.4 backfill: checkpointed per family so an interrupted pass resumes where it stopped.
    /// `stopAfterFamilies` simulates the app being killed mid-pass (tests only).
    @discardableResult
    func evaluate(in context: ModelContext, now: Date = Date(), stopAfterFamilies: Int? = nil) -> [EarnedMedal] {
        guard let catalog else { return [] }
        let places = (try? context.fetch(FetchDescriptor<VisitedPlace>())) ?? []
        let input = makeInput(places: places, context: context, now: now)
        let results = MedalEngine.evaluate(input, catalog: catalog)
        lastEvaluatedAt = now

        var rows = Dictionary(((try? context.fetch(FetchDescriptor<EarnedMedal>())) ?? []).map { ($0.medalId, $0) },
                              uniquingKeysWith: { first, _ in first })
        var changed: [EarnedMedal] = []
        let version = catalog.catalogVersion
        // Show what the user holds, not only what today's evidence supports: kept tiers (removed
        // places, v1 grants under v1 rules) stay earned in the cabinet.
        defer { self.results = Self.withStoredAwards(results, rows: rows, catalog: catalog) }

        if isBackfillComplete {
            for result in results {
                if let row = merge(result.awards, into: rows[result.id], medalId: result.id, retroactive: false, context: context, now: now) {
                    rows[result.id] = row
                    changed.append(row)
                }
            }
        } else {
            let legacy = legacyAwards(places: places, catalog: catalog)
            let familiesKey = Self.backfillFamiliesKey + "\(version)"
            var done = Set(defaults.stringArray(forKey: familiesKey) ?? [])
            var families: [String] = []
            for medal in catalog.medals where !families.contains(medal.family) {
                families.append(medal.family)
            }
            var processed = 0
            for family in families where !done.contains(family) {
                if let stopAfterFamilies, processed >= stopAfterFamilies { return changed }
                for result in results where result.definition.family == family {
                    let awards = combine(result.awards, legacy[result.id], catalog: catalog)
                    if let row = merge(awards, into: rows[result.id], medalId: result.id, retroactive: true, context: context, now: now, catalog: catalog) {
                        rows[result.id] = row
                        changed.append(row)
                    }
                }
                try? context.save()
                done.insert(family)
                defaults.set(Array(done).sorted(), forKey: familiesKey)
                processed += 1
            }
            defaults.set(true, forKey: Self.backfillCompleteKey + "\(version)")
        }
        try? context.save()
        return changed
    }

    private static func withStoredAwards(
        _ results: [MedalEngine.Result], rows: [String: EarnedMedal], catalog: MedalCatalog
    ) -> [MedalEngine.Result] {
        results.map { result in
            guard let row = rows[result.id] else { return result }
            let awards = row.tierHistory.compactMap { tier -> MedalEngine.TierAward? in
                guard let threshold = result.definition.tiers.first(where: { $0.level == tier.level })?.threshold else { return nil }
                return MedalEngine.TierAward(level: tier.level, threshold: threshold, earnedAt: tier.earnedAt, trigger: tier.trigger)
            }
            return MedalEngine.Result(definition: result.definition, value: result.value, awards: awards)
        }
    }

    /// Forgets every medal on this device (account deletion / clear all data), so the next account
    /// starts with a fresh backfill and never sees the previous account's history.
    func reset(in context: ModelContext) {
        for medal in (try? context.fetch(FetchDescriptor<EarnedMedal>())) ?? [] {
            context.delete(medal)
        }
        try? context.save()
        if let catalog {
            defaults.removeObject(forKey: Self.backfillCompleteKey + "\(catalog.catalogVersion)")
            defaults.removeObject(forKey: Self.backfillFamiliesKey + "\(catalog.catalogVersion)")
        }
        defaults.removeObject(forKey: Self.bucketLedgerKey)
        results = []
        lastEvaluatedAt = nil
    }

    /// Medals to show: device medals, minus opt-in layers the user has no data for
    /// (counties stay hidden while the county layer is off; named regions until Phase 4 data).
    func visibleResults(places: [VisitedPlace]) -> [MedalEngine.Result] {
        guard let catalog else { return [] }
        let types = Set(places.filter { !$0.isDeleted }.map(\.regionType))
        return results.filter { result in
            switch result.definition.metric {
            case "countiesVisited", "countiesInState": return types.contains(catalog.countyRegionType)
            case "regionsVisited": return types.contains(catalog.namedRegionRegionType)
            default: return true
            }
        }
    }

    func markSurfaced(_ medals: [EarnedMedal], in context: ModelContext, now: Date = Date()) {
        for medal in medals { medal.surfacedAt = now }
        try? context.save()
    }

    // MARK: - Evidence

    func makeInput(places: [VisitedPlace], context: ModelContext, now: Date) -> MedalEngine.Input {
        let counted = places.filter {
            MedalEngine.countsTowardMedals(status: $0.status, visitType: $0.visitType, isDeleted: $0.isDeleted)
        }
        var input = MedalEngine.Input()
        input.places = Self.placeFacts(counted)

        let visits = (try? context.fetch(FetchDescriptor<Visit>())) ?? []
        input.coordinates = visits.filter { $0.kind == .visited }.map { visit in
            MedalEngine.CoordinateFact(
                latitude: visit.centroidLat, longitude: visit.centroidLon, date: visit.arrivedAt,
                label: GeographicData.countries.first { $0.id == visit.countryCode }?.name ?? "Visit"
            )
        }
        input.coordinates += photoLocations().compactMap { photo in
            guard let date = photo.earliestDate else { return nil }
            return MedalEngine.CoordinateFact(latitude: photo.latitude, longitude: photo.longitude, date: date, label: photo.regionName ?? "Photo")
        }
        input.cities = cityMatcher().hits(input.coordinates)
        input.bucketCompletions = bucketCompletions(places: places, now: now)
        input.distanceKm = distanceKm()
        input.distanceAsOf = now
        return input
    }

    /// Place facts dated by first visit (manual marks without a date use when they were marked),
    /// with the time zones each place contributes (the Advanced Stats semantics).
    static func placeFacts(_ places: [VisitedPlace]) -> [MedalEngine.PlaceFact] {
        let subdivisionTypes = Set(GeographicData.countries.compactMap { GeographicData.regionType(for: $0.id)?.rawValue })
        let countriesWithStates = Set(places.compactMap { place in
            subdivisionTypes.contains(place.regionType) ? countryCode(forSubdivisionType: place.regionType) : nil
        })
        return places.map { place in
            var zones: Set<Int> = []
            if place.regionType == VisitedPlace.RegionType.country.rawValue {
                // MX/BR count their main zone only when no state was visited, as in the stats screen.
                if !(["MX", "BR"].contains(place.regionCode) && countriesWithStates.contains(place.regionCode)) {
                    zones = TimeZoneLocalStats.calculate(visitedCountries: [place.regionCode]).visitedZones
                }
            } else if let country = countryCode(forSubdivisionType: place.regionType) {
                zones = TimeZoneLocalStats.calculate(visitedCountries: [country], visitedStates: [(place.regionType, place.regionCode)]).visitedZones
            }
            return MedalEngine.PlaceFact(
                regionType: place.regionType, regionCode: place.regionCode, name: place.regionName,
                date: place.visitedDate ?? place.markedAt, timeZones: zones.sorted()
            )
        }
    }

    private static func countryCode(forSubdivisionType type: String) -> String? {
        GeographicData.countries.first { GeographicData.regionType(for: $0.id)?.rawValue == type }?.id
    }

    /// Bucket-list places seen on this device are remembered, so checking one off later counts.
    private func bucketCompletions(places: [VisitedPlace], now: Date) -> [MedalEngine.PlaceFact] {
        var ledger = defaults.dictionary(forKey: Self.bucketLedgerKey) as? [String: Date] ?? [:]
        for place in places where !place.isDeleted && place.isBucketList {
            let key = "\(place.regionType)|\(place.regionCode)"
            if ledger[key] == nil { ledger[key] = now }
        }
        defaults.set(ledger, forKey: Self.bucketLedgerKey)
        return places.compactMap { place in
            guard MedalEngine.countsTowardMedals(status: place.status, visitType: place.visitType, isDeleted: place.isDeleted),
                  let listedAt = ledger["\(place.regionType)|\(place.regionCode)"]
            else { return nil }
            let date = max(place.visitedDate ?? place.lastModifiedAt, listedAt)
            return MedalEngine.PlaceFact(regionType: place.regionType, regionCode: place.regionCode, name: place.regionName, date: date)
        }
    }

    private func cityMatcher() -> CityMatcher {
        if let cityMatcherOverride { return cityMatcherOverride }
        if let cityMatcherCache { return cityMatcherCache }
        let matcher = CityMatcher(gazetteer: CityGazetteer.bundled ?? CityGazetteer(cities: []))
        cityMatcherCache = matcher
        return matcher
    }

    // MARK: - v1 badges (§4.4 step 3)

    /// The v2 rung of each v1 badge the user had earned under v1 rules (transit counted), dated by
    /// the earliest qualifying visit.
    func legacyAwards(places: [VisitedPlace], catalog: MedalCatalog) -> [String: MedalEngine.TierAward] {
        let legacyPlaces = places.filter { MedalEngine.countsTowardLegacyBadges(status: $0.status, isDeleted: $0.isDeleted) }
        let results = MedalEngine.evaluate(MedalEngine.Input(places: Self.placeFacts(legacyPlaces)), catalog: catalog)
        var awards: [String: MedalEngine.TierAward] = [:]
        for result in results {
            guard let level = result.definition.legacyTier,
                  let award = result.awards.first(where: { $0.level == level })
            else { continue }
            awards[result.id] = award
        }
        return awards
    }

    private func combine(_ awards: [MedalEngine.TierAward], _ legacy: MedalEngine.TierAward?, catalog: MedalCatalog) -> [EarnedMedalTier] {
        var tiers = awards.map { EarnedMedalTier(level: $0.level, earnedAt: $0.earnedAt, trigger: $0.trigger) }
        if let legacy, !tiers.contains(where: { $0.level == legacy.level }) {
            tiers.append(EarnedMedalTier(level: legacy.level, earnedAt: legacy.earnedAt, trigger: legacy.trigger, isLegacy: true))
        }
        return tiers.sorted { catalog.rank(of: $0.level) < catalog.rank(of: $1.level) }
    }

    // MARK: - Merge

    private func merge(
        _ awards: [MedalEngine.TierAward], into row: EarnedMedal?, medalId: String,
        retroactive: Bool, context: ModelContext, now: Date
    ) -> EarnedMedal? {
        guard let catalog else { return nil }
        let tiers = awards.map { EarnedMedalTier(level: $0.level, earnedAt: $0.earnedAt, trigger: $0.trigger) }
        return merge(tiers, into: row, medalId: medalId, retroactive: retroactive, context: context, now: now, catalog: catalog)
    }

    /// Tiers are never taken away; a tier's date only moves earlier (e.g. older photos imported).
    /// Returns the row when something changed.
    private func merge(
        _ awards: [EarnedMedalTier], into row: EarnedMedal?, medalId: String,
        retroactive: Bool, context: ModelContext, now: Date, catalog: MedalCatalog
    ) -> EarnedMedal? {
        guard !awards.isEmpty else { return nil }
        var history = row?.tierHistory ?? []
        var changed = row == nil
        for award in awards {
            if let index = history.firstIndex(where: { $0.level == award.level }) {
                if award.earnedAt < history[index].earnedAt {
                    history[index].earnedAt = award.earnedAt
                    history[index].trigger = award.trigger
                    changed = true
                }
            } else {
                history.append(award)
                changed = true
            }
        }
        guard changed else { return nil }
        history.sort { catalog.rank(of: $0.level) < catalog.rank(of: $1.level) }
        let top = history.last!
        let first = history.min { $0.earnedAt < $1.earnedAt }!
        let target: EarnedMedal
        if let row {
            target = row
            if catalog.rank(of: top.level) > catalog.rank(of: row.tierLevel) {
                target.surfacedAt = nil
            }
        } else {
            target = EarnedMedal(medalId: medalId, tierLevel: top.level, earnedAt: first.earnedAt, isRetroactive: retroactive,
                                 catalogVersion: catalog.catalogVersion, triggerName: first.trigger)
            context.insert(target)
        }
        target.tierLevel = top.level
        target.earnedAt = first.earnedAt
        target.triggerName = first.trigger
        target.tierHistory = history
        target.catalogVersion = catalog.catalogVersion
        target.lastModifiedAt = now
        return target
    }
}
