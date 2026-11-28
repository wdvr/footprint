import Foundation

/// On-device medal evaluation (§4.1): a pure function from dated evidence to earned tiers.
///
/// Facts are replayed in date order, so each tier's `earnedAt` is the date of the fact that first
/// crossed its threshold. That makes every evaluation retroactive and idempotent: running it again
/// over the same history yields the same awards.
enum MedalEngine {
    /// A visited place (`VisitedPlace` row, any level), dated by its first visit.
    struct PlaceFact: Sendable, Equatable {
        let regionType: String
        let regionCode: String
        let name: String
        let date: Date
        /// UTC offsets this place contributes (per the time-zone stats semantics).
        var timeZones: [Int] = []
    }

    /// A dated coordinate from a confirmed visit or a photo.
    struct CoordinateFact: Sendable, Equatable {
        let latitude: Double
        let longitude: Double
        let date: Date
        let label: String
    }

    /// First visit to a gazetteer city.
    struct CityHit: Sendable, Equatable {
        let id: String
        /// "city", "national" or "us_state".
        let kind: String
        let name: String
        let date: Date
    }

    struct Input: Sendable {
        var places: [PlaceFact] = []
        var coordinates: [CoordinateFact] = []
        var cities: [CityHit] = []
        /// Bucket-list places that were later visited.
        var bucketCompletions: [PlaceFact] = []
        /// Distance accumulated by the visit pipeline, known as of `distanceAsOf`.
        var distanceKm: Double = 0
        var distanceAsOf: Date?
    }

    struct TierAward: Sendable, Equatable {
        let level: String
        let threshold: Double
        let earnedAt: Date
        /// Name of the place (or other evidence) that crossed the threshold.
        let trigger: String
    }

    struct Result: Sendable, Identifiable {
        var id: String { definition.id }
        let definition: MedalCatalog.Definition
        let value: Double
        let awards: [TierAward]

        var highestAward: TierAward? { awards.last }
        var isEarned: Bool { !awards.isEmpty }
        var nextTier: MedalCatalog.Tier? { definition.tiers.first { $0.threshold > (highestAward?.threshold ?? -1) } }
        /// Threshold to show progress against: the next tier, or the top tier once complete.
        var progressTotal: Double { nextTier?.threshold ?? definition.tiers.last?.threshold ?? 1 }
        var progressFraction: Double { progressTotal > 0 ? min(1, value / progressTotal) : 0 }
    }

    // MARK: - Evaluation

    static func evaluate(_ input: Input, catalog: MedalCatalog, platform: String = "ios") -> [Result] {
        let medals = catalog.medals.filter { $0.platforms.contains(platform) }
        var state = State(catalog: catalog)
        var awards: [String: [TierAward]] = [:]

        func check(trigger: String, date: Date) {
            for medal in medals {
                let value = state.value(for: medal)
                let have = awards[medal.id]?.count ?? 0
                guard have < medal.tiers.count else { continue }
                for tier in medal.tiers.dropFirst(have) where value >= tier.threshold {
                    awards[medal.id, default: []].append(TierAward(level: tier.level, threshold: tier.threshold, earnedAt: date, trigger: trigger))
                }
            }
        }

        for event in events(input) {
            state.apply(event)
            check(trigger: event.label, date: event.date)
        }

        return medals.map { Result(definition: $0, value: state.value(for: $0), awards: awards[$0.id] ?? []) }
    }

    // MARK: - Events

    enum Event: Sendable {
        case place(PlaceFact)
        case coordinate(CoordinateFact)
        case city(CityHit)
        case bucket(PlaceFact)
        case distance(Double, Date)

        var date: Date {
            switch self {
            case .place(let f), .bucket(let f): return f.date
            case .coordinate(let c): return c.date
            case .city(let c): return c.date
            case .distance(_, let d): return d
            }
        }

        var label: String {
            switch self {
            case .place(let f), .bucket(let f): return f.name
            case .coordinate(let c): return c.label
            case .city(let c): return c.name
            case .distance(let km, _): return "\(Int(km)) km travelled"
            }
        }

        fileprivate var sortKey: String {
            switch self {
            case .place(let f): return "0|\(f.regionType)|\(f.regionCode)"
            case .bucket(let f): return "1|\(f.regionType)|\(f.regionCode)"
            case .city(let c): return "2|\(c.kind)|\(c.id)"
            case .coordinate(let c): return "3|\(c.latitude)|\(c.longitude)"
            case .distance: return "4"
            }
        }
    }

    /// Chronological event stream; each place counts once, at its earliest date.
    static func events(_ input: Input) -> [Event] {
        var firstPlace: [String: PlaceFact] = [:]
        for fact in input.places {
            let key = "\(fact.regionType)|\(fact.regionCode)"
            if let existing = firstPlace[key], existing.date <= fact.date { continue }
            firstPlace[key] = fact
        }
        var firstBucket: [String: PlaceFact] = [:]
        for fact in input.bucketCompletions {
            let key = "\(fact.regionType)|\(fact.regionCode)"
            if let existing = firstBucket[key], existing.date <= fact.date { continue }
            firstBucket[key] = fact
        }
        var events: [Event] = firstPlace.values.map { .place($0) }
            + firstBucket.values.map { .bucket($0) }
            + input.cities.map { .city($0) }
            + input.coordinates.map { .coordinate($0) }
        if input.distanceKm > 0, let asOf = input.distanceAsOf {
            events.append(.distance(input.distanceKm, asOf))
        }
        return events.sorted { ($0.date, $0.sortKey) < ($1.date, $1.sortKey) }
    }

    // MARK: - Calendar math (UTC, shared with the backend engine)

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Foundation.TimeZone(identifier: "UTC")!
        return calendar
    }()

    static func monthIndex(_ date: Date) -> Int {
        let c = utc.dateComponents([.year, .month], from: date)
        return c.year! * 12 + c.month!
    }

    /// Monday-based week number since the epoch (1970-01-01 was a Thursday).
    static func weekIndex(_ date: Date) -> Int {
        let days = Int(floor(date.timeIntervalSince1970 / 86_400))
        return Int(floor(Double(days + 3) / 7))
    }

    static func wholeYears(from start: Date, to end: Date) -> Int {
        let a = utc.dateComponents([.year, .month, .day], from: start)
        let b = utc.dateComponents([.year, .month, .day], from: end)
        let beforeAnniversary = (b.month!, b.day!) < (a.month!, a.day!)
        return max(0, b.year! - a.year! - (beforeAnniversary ? 1 : 0))
    }

    // MARK: - Accumulated state

    struct State {
        let catalog: MedalCatalog
        private let subdivisionCountry: [String: String]
        private var countries: Set<String> = []
        private var subdivisions: [String: Set<String>] = [:]
        private var counties: Set<String> = []
        private var regions: Set<String> = []
        private var zones: Set<Int> = []
        private var touchedAntarctica = false
        private var cities: [String: Set<String>] = [:]
        private var northern = false, southern = false, eastern = false, western = false
        private var coordinates: [CoordinateFact] = []
        private var bucket = 0
        private var distance = 0.0
        private var months = Streak(), weeks = Streak()
        private var years: Set<Int> = []
        private var first: Date?, last: Date?

        init(catalog: MedalCatalog) {
            self.catalog = catalog
            self.subdivisionCountry = catalog.subdivisionRegionTypes
        }

        mutating func apply(_ event: Event) {
            switch event {
            case .place(let fact):
                if fact.regionType == "country" {
                    countries.insert(fact.regionCode)
                } else if let country = subdivisionCountry[fact.regionType] {
                    subdivisions[country, default: []].insert(fact.regionCode)
                } else if fact.regionType == catalog.countyRegionType {
                    counties.insert(fact.regionCode)
                } else if fact.regionType == catalog.namedRegionRegionType {
                    regions.insert(fact.regionCode)
                }
                zones.formUnion(fact.timeZones)
                months.add(MedalEngine.monthIndex(fact.date))
                weeks.add(MedalEngine.weekIndex(fact.date))
                years.insert(MedalEngine.utc.component(.year, from: fact.date))
                first = min(first ?? fact.date, fact.date)
                last = max(last ?? fact.date, fact.date)
            case .coordinate(let c):
                coordinates.append(c)
                if c.latitude > 0 { northern = true }
                if c.latitude < 0 { southern = true }
                if c.longitude > 0 { eastern = true }
                if c.longitude < 0 { western = true }
                if c.latitude < -60 { touchedAntarctica = true }
            case .city(let hit):
                cities[hit.kind, default: []].insert(hit.id)
            case .bucket:
                bucket += 1
            case .distance(let km, _):
                distance = km
            }
        }

        private var continentCounts: [String: Int] {
            var counts: [String: Int] = [:]
            for code in countries {
                if let continent = catalog.countryContinents[code] { counts[continent, default: 0] += 1 }
            }
            return counts
        }

        func value(for medal: MedalCatalog.Definition) -> Double {
            let filter = medal.filter ?? [:]
            switch medal.metric {
            case "countriesVisited":
                return Double(countries.count)
            case "subdivisionsVisited":
                if let country = filter["country"] { return Double(subdivisions[country]?.count ?? 0) }
                return Double(subdivisions.values.reduce(0) { $0 + $1.count })
            case "subdivisionSet":
                let visited = subdivisions[filter["country"] ?? ""] ?? []
                return Double((medal.members ?? []).filter { visited.contains($0) }.count)
            case "homeCountryCompletion":
                // Home = the tracked country with the most visited subdivisions (ties: alphabetical).
                guard let home = subdivisions.filter({ !$0.value.isEmpty })
                    .max(by: { ($0.value.count, $1.key) < ($1.value.count, $0.key) }),
                    let total = catalog.subdivisionCounts[home.key], total > 0
                else { return 0 }
                return (Double(home.value.count) / Double(total) * 100).rounded(.down)
            case "countiesVisited":
                return Double(counties.count)
            case "countiesInState":
                guard let prefix = catalog.countyStates[filter["state"] ?? ""]?.fips else { return 0 }
                return Double(counties.filter { $0.hasPrefix(prefix) }.count)
            case "regionsVisited":
                return Double(regions.count)
            case "continentCountries":
                let wanted = (filter["continents"] ?? "").split(separator: ",").map(String.init)
                let counts = continentCounts
                return Double(wanted.reduce(0) { $0 + (counts[$1] ?? 0) })
            case "continentsTouched":
                return Double(continentCounts.count + (touchedAntarctica ? 1 : 0))
            case "countriesInSet":
                let set = Set(catalog.countrySets[filter["set"] ?? ""] ?? [])
                return Double(countries.intersection(set).count)
            case "timeZonesVisited":
                return Double(zones.count)
            case "dateLineCrossed":
                return zones.contains(where: { $0 >= 12 }) && zones.contains(where: { $0 <= -11 }) ? 1 : 0
            case "hemispheresTouched":
                switch filter["axis"] {
                case "lat": return Double([northern, southern].filter { $0 }.count)
                case "lon": return Double([eastern, western].filter { $0 }.count)
                default: return Double([northern, southern, eastern, western].filter { $0 }.count)
                }
            case "coordinateInBand":
                let minLat = filter["minLat"].flatMap(Double.init) ?? -90
                let maxLat = filter["maxLat"].flatMap(Double.init) ?? 90
                return Double(coordinates.filter { $0.latitude >= minLat && $0.latitude <= maxLat }.count)
            case "citiesVisited":
                return Double(cities["city"]?.count ?? 0)
            case "capitalsVisited":
                return Double(cities[filter["kind"] ?? "national"]?.count ?? 0)
            case "distanceKm":
                return distance
            case "bucketListCompleted":
                return Double(bucket)
            case "newPlaceStreakMonths":
                return Double(months.best)
            case "newPlaceStreakWeeks":
                return Double(weeks.best)
            case "distinctYearsActive":
                return Double(years.count)
            case "yearsSpan":
                guard let first, let last else { return 0 }
                return Double(MedalEngine.wholeYears(from: first, to: last))
            default:
                return 0
            }
        }
    }

    /// Longest run of consecutive periods, fed period indices in non-decreasing order.
    struct Streak: Sendable {
        private(set) var best = 0
        private var current = 0
        private var lastIndex: Int?

        mutating func add(_ index: Int) {
            if let lastIndex, index == lastIndex { return }
            current = (lastIndex.map { index == $0 + 1 } ?? false) ? current + 1 : 1
            lastIndex = index
            best = max(best, current)
        }
    }
}

extension MedalEngine {
    /// Only full visits count (§2.5 transit rule): bucket-list, transit and deleted places do not.
    static func countsTowardMedals(status: String, visitType: String, isDeleted: Bool) -> Bool {
        !isDeleted && status == "visited" && visitType == "visited"
    }

    /// v1 badge rules (any visited place, transit included), used only to honour badges a user
    /// already had (§4.4 step 3).
    static func countsTowardLegacyBadges(status: String, isDeleted: Bool) -> Bool {
        !isDeleted && status == "visited"
    }
}
