import Foundation

/// A gazetteer city (spec §2.3). `id` is the GeoNames key ("gn:5391959") and is what a `.city`
/// `VisitedPlace` stores as `regionCode`.
struct City: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// ISO 3166-1 alpha-2, or the app's own territory code (`XS`).
    let countryCode: String
    /// The country the bundled outlines put the centroid in, where it differs (border cities such as
    /// Laredo or Monaco); stays resolving to either code can match.
    let boundaryCountryCode: String?
    /// Place key of the subdivision holding the centroid, with the short code the matcher yields ("US-CA").
    let subdivisionCode: String?
    /// Further subdivisions the city spans (e.g. London's boroughs).
    let additionalSubdivisionCodes: [String]
    /// US county FIPS of the centroid ("06001"); nil outside the US.
    let countyFips: String?
    let latitude: Double
    let longitude: Double
    /// Match radius: f(population), clamped to 1.5–15 km at build time.
    let radiusMeters: Double
    let population: Int
    let isNationalCapital: Bool
    /// US state capital (incl. Washington for DC) at v1.
    let isSubdivisionCapital: Bool
    /// IANA time zone id.
    let timeZone: String

    var isCapital: Bool { isNationalCapital || isSubdivisionCapital }
    var isUSStateCapital: Bool { isSubdivisionCapital && countryCode == "US" }
    /// Every subdivision key a consistent stay may resolve to; empty = unknown.
    var subdivisionCodes: [String] { (subdivisionCode.map { [$0] } ?? []) + additionalSubdivisionCodes }

    enum CodingKeys: String, CodingKey {
        case id, name
        case countryCode = "cc"
        case boundaryCountryCode = "bcc"
        case subdivisionCode = "sub"
        case additionalSubdivisionCodes = "subs"
        case countyFips = "fips"
        case latitude = "lat"
        case longitude = "lon"
        case radiusMeters = "r"
        case population = "pop"
        case isNationalCapital = "nc"
        case isSubdivisionCapital = "sc"
        case timeZone = "tz"
    }

    init(
        id: String,
        name: String,
        countryCode: String,
        boundaryCountryCode: String? = nil,
        subdivisionCode: String? = nil,
        additionalSubdivisionCodes: [String] = [],
        countyFips: String? = nil,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        population: Int = 0,
        isNationalCapital: Bool = false,
        isSubdivisionCapital: Bool = false,
        timeZone: String = "UTC"
    ) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.boundaryCountryCode = boundaryCountryCode
        self.subdivisionCode = subdivisionCode
        self.additionalSubdivisionCodes = additionalSubdivisionCodes
        self.countyFips = countyFips
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.population = population
        self.isNationalCapital = isNationalCapital
        self.isSubdivisionCapital = isSubdivisionCapital
        self.timeZone = timeZone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        countryCode = try c.decode(String.self, forKey: .countryCode)
        boundaryCountryCode = try c.decodeIfPresent(String.self, forKey: .boundaryCountryCode)
        subdivisionCode = try c.decodeIfPresent(String.self, forKey: .subdivisionCode)
        additionalSubdivisionCodes = try c.decodeIfPresent([String].self, forKey: .additionalSubdivisionCodes) ?? []
        countyFips = try c.decodeIfPresent(String.self, forKey: .countyFips)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
        radiusMeters = try c.decode(Double.self, forKey: .radiusMeters)
        population = try c.decode(Int.self, forKey: .population)
        isNationalCapital = try c.decodeIfPresent(Bool.self, forKey: .isNationalCapital) ?? false
        isSubdivisionCapital = try c.decodeIfPresent(Bool.self, forKey: .isSubdivisionCapital) ?? false
        timeZone = try c.decodeIfPresent(String.self, forKey: .timeZone) ?? "UTC"
    }
}

/// The bundled city gazetteer (`cities_gazetteer.json`, built by `scripts/build_city_gazetteer.py`)
/// with a 1° grid index for radius lookups.
final class CityGazetteer: Sendable {
    static let resourceName = "cities_gazetteer"

    let version: String
    let cities: [City]
    private let indexById: [String: Int]
    private let grid: [GridCell: [Int]]
    private let maxRadiusMeters: Double

    private struct GridCell: Hashable, Sendable {
        let lat: Int
        let lon: Int
    }

    private struct File: Decodable {
        let version: String
        let cities: [City]
    }

    init(version: String = "test", cities: [City]) {
        self.version = version
        self.cities = cities
        var indexById: [String: Int] = [:]
        var grid: [GridCell: [Int]] = [:]
        for (i, city) in cities.enumerated() {
            indexById[city.id] = i
            grid[Self.cell(city.latitude, city.longitude), default: []].append(i)
        }
        self.indexById = indexById
        self.grid = grid
        self.maxRadiusMeters = cities.map(\.radiusMeters).max() ?? 0
    }

    convenience init(data: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: data)
        self.init(version: file.version, cities: file.cities)
    }

    /// The gazetteer shipped in the app bundle; nil if missing or unreadable.
    static let bundled: CityGazetteer? = {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json", subdirectory: "GeoData")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else { return nil }
        return try? CityGazetteer(data: data)
    }()

    func city(id: String) -> City? {
        indexById[id].map { cities[$0] }
    }

    var nationalCapitals: [City] { cities.filter(\.isNationalCapital) }
    var usStateCapitals: [City] { cities.filter(\.isUSStateCapital) }

    func cities(inCountry countryCode: String) -> [City] {
        cities.filter { $0.countryCode == countryCode }
    }

    /// Cities whose radius contains the coordinate, nearest centroid first.
    func cities(containing latitude: Double, _ longitude: Double) -> [(city: City, distanceMeters: Double)] {
        guard maxRadiusMeters > 0 else { return [] }
        let center = Self.cell(latitude, longitude)
        let latSpan = Int((maxRadiusMeters / 111_320).rounded(.up))
        let metersPerLonDegree = 111_320 * max(0.01, cos(min(abs(latitude) + Double(latSpan), 90) * .pi / 180))
        let lonSpan = min(180, Int((maxRadiusMeters / metersPerLonDegree).rounded(.up)))
        var hits: [(city: City, distanceMeters: Double)] = []
        for dLat in -latSpan...latSpan {
            for dLon in -lonSpan...lonSpan {
                let lon = ((center.lon + dLon + 180) % 360 + 360) % 360 - 180
                for i in grid[GridCell(lat: center.lat + dLat, lon: lon)] ?? [] {
                    let city = cities[i]
                    let d = GeoMath.distanceMeters(lat1: latitude, lon1: longitude, lat2: city.latitude, lon2: city.longitude)
                    if d <= city.radiusMeters {
                        hits.append((city, d))
                    }
                }
            }
        }
        return hits.sorted { ($0.distanceMeters, $0.city.id) < ($1.distanceMeters, $1.city.id) }
    }

    private static func cell(_ latitude: Double, _ longitude: Double) -> GridCell {
        GridCell(lat: Int(latitude.rounded(.down)), lon: Int(longitude.rounded(.down)))
    }
}

/// What the levels above a city resolved to for a coordinate (§3.4 order: country → subdivision → county).
struct CityPlaceContext: Hashable, Sendable {
    let countryCode: String
    /// Short subdivision code as in `PlaceKey` ("CA").
    let subdivisionCode: String?
    var countyFips: String?

    init(countryCode: String, subdivisionCode: String? = nil, countyFips: String? = nil) {
        self.countryCode = countryCode
        self.subdivisionCode = subdivisionCode
        self.countyFips = countyFips
    }

    init(_ key: PlaceKey, countyFips: String? = nil) {
        self.init(countryCode: key.countryCode, subdivisionCode: key.subdivisionCode, countyFips: countyFips)
    }
}

/// Radius matching (§2.3, §3.4): a coordinate is in a city when it lies within the city's radius
/// and the city is consistent with the resolved country and subdivision. Among consistent
/// candidates, one in the resolved county wins; otherwise the nearest centroid wins.
struct CityMatcher: Sendable {
    /// Boundary codes the app normalizes to another country code.
    static let countryCodeAliases = ["CN-TW": "TW"]

    let gazetteer: CityGazetteer

    /// Cheap pre-check: is any city radius around this coordinate?
    func hasCandidate(latitude: Double, longitude: Double) -> Bool {
        !gazetteer.cities(containing: latitude, longitude).isEmpty
    }

    func match(latitude: Double, longitude: Double, context: CityPlaceContext?) -> City? {
        guard let context else { return nil }
        let consistent = gazetteer.cities(containing: latitude, longitude)
            .map(\.city)
            .filter { Self.isConsistent($0, with: context) }
        if let fips = context.countyFips, let inCounty = consistent.first(where: { $0.countyFips == fips }) {
            return inCounty
        }
        return consistent.first
    }

    static func isConsistent(_ city: City, with context: CityPlaceContext) -> Bool {
        let country = countryCodeAliases[context.countryCode] ?? context.countryCode
        guard city.countryCode == country || city.boundaryCountryCode == country else { return false }
        guard let subdivision = context.subdivisionCode, !city.subdivisionCodes.isEmpty else { return true }
        return city.subdivisionCodes.contains("\(context.countryCode)-\(subdivision)")
    }
}

/// "visited of total" against a gazetteer denominator (§2.5); never a bare count.
struct CoverageCount: Equatable, Sendable {
    let visited: Int
    let total: Int

    var fraction: Double { total == 0 ? 0 : Double(visited) / Double(total) }

    func label(_ noun: String) -> String { "\(visited) of \(total) \(noun)" }
}

/// City coverage for a set of visited gazetteer ids. Ids missing from the gazetteer are ignored,
/// so every count is visited-in-gazetteer over the gazetteer's own total.
struct CityCoverage: Sendable {
    let gazetteer: CityGazetteer
    let visitedCityIds: Set<String>

    init(gazetteer: CityGazetteer, visitedCityIds: Set<String>) {
        self.gazetteer = gazetteer
        self.visitedCityIds = visitedCityIds.filter { gazetteer.city(id: $0) != nil }
    }

    var cities: CoverageCount { count(gazetteer.cities) }
    var nationalCapitals: CoverageCount { count(gazetteer.nationalCapitals) }
    var usStateCapitals: CoverageCount { count(gazetteer.usStateCapitals) }

    func cities(inCountry countryCode: String) -> CoverageCount {
        count(gazetteer.cities(inCountry: countryCode))
    }

    private func count(_ cities: [City]) -> CoverageCount {
        CoverageCount(visited: cities.filter { visitedCityIds.contains($0.id) }.count, total: cities.count)
    }
}
