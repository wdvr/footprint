import Foundation

/// A named area that is not an administrative unit (spec §2.4): "the Bay Area", "Provence",
/// "the Alps". A region is a set of member place keys, not a polygon; it is visited when at
/// least one member is visited, and its coverage is visited members over total members.
struct NamedRegion: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case metro
        case cultural
        case geographic

        var displayName: String {
            switch self {
            case .metro: return "Metro Areas"
            case .cultural: return "Cultural Regions"
            case .geographic: return "Geographic Regions"
            }
        }
    }

    /// Slug, e.g. "us-bay-area".
    let id: String
    let name: String
    let kind: Kind
    /// Place keys: ISO country ("CH"), "CC-CODE" subdivision ("FR-13"), US county FIPS ("06001")
    /// or city id ("gn:5391959").
    let memberKeys: [String]
    let blurb: String
    /// Display name per member key ("Alameda County, CA").
    var memberNames: [String: String]?
    /// Census CBSA code for metros built from a CBSA county list.
    var cbsa: String?
    /// Marquee set that gets a completion medal (Phase 5 generates the definition).
    var medal: Bool?

    var isMedalSet: Bool { medal ?? false }

    func memberName(_ key: String) -> String {
        memberNames?[key] ?? key
    }
}

/// A place key parsed by level.
enum RegionMemberKey: Hashable, Sendable {
    case country(String)
    case subdivision(country: String, code: String)
    case usCounty(fips: String)
    case city(id: String)

    init?(_ key: String) {
        if key.hasPrefix("gn:") {
            self = .city(id: key)
        } else if key.count == 5, key.allSatisfy(\.isASCIIDigit) {
            self = .usCounty(fips: key)
        } else if let dash = key.firstIndex(of: "-") {
            let country = String(key[..<dash])
            let code = String(key[key.index(after: dash)...])
            guard country.count == 2, !code.isEmpty else { return nil }
            self = .subdivision(country: country, code: code)
        } else if key.count == 2 {
            self = .country(key)
        } else {
            return nil
        }
    }

    var key: String {
        switch self {
        case .country(let code): return code
        case .subdivision(let country, let code): return "\(country)-\(code)"
        case .usCounty(let fips): return fips
        case .city(let id): return id
        }
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

/// Visited/total members of one region.
struct RegionCoverage: Equatable, Sendable {
    let region: NamedRegion
    /// Visited member keys, in the region's member order.
    let visitedMembers: [String]

    var visitedCount: Int { visitedMembers.count }
    var totalMembers: Int { region.memberKeys.count }
    var fraction: Double { totalMembers == 0 ? 0 : Double(visitedCount) / Double(totalMembers) }
    var isVisited: Bool { visitedCount > 0 }
    var isComplete: Bool { totalMembers > 0 && visitedCount == totalMembers }

    func isMemberVisited(_ key: String) -> Bool { visitedMembers.contains(key) }
}

/// Maps `VisitedPlace` rows to place keys and computes region coverage. Regions are derived
/// from member visits, never stored, so they need no matching of their own.
enum RegionResolver {
    /// `VisitedPlace.regionType` raw value → country, for subdivision rows. Mirrors
    /// `GeographicData.regionType(for:)` (checked by a test).
    static let subdivisionCountries: [String: String] = [
        "us_state": "US",
        "canadian_province": "CA",
        "australian_state": "AU",
        "mexican_state": "MX",
        "brazilian_state": "BR",
        "german_state": "DE",
        "french_region": "FR",
        "spanish_community": "ES",
        "italian_region": "IT",
        "dutch_province": "NL",
        "belgian_province": "BE",
        "uk_country": "GB",
        "russian_federal_subject": "RU",
        "argentine_province": "AR",
        "japanese_prefecture": "JP",
        "south_korean_province": "KR",
        "norwegian_county": "NO",
    ]
    static let countryType = "country"
    static let usCountyType = "us_county"
    static let cityType = "city"

    /// The place key of a saved row, or nil for rows that are not region members (regions,
    /// landmarks). Subdivision codes saved in boundary form ("GB-MAN") are reduced to the
    /// short code first.
    static func placeKey(regionType: String, regionCode: String) -> String? {
        switch regionType {
        case countryType:
            return regionCode
        case usCountyType, cityType:
            return regionCode
        default:
            guard let country = subdivisionCountries[regionType] else { return nil }
            let prefix = "\(country)-"
            let code = regionCode.hasPrefix(prefix) ? String(regionCode.dropFirst(prefix.count)) : regionCode
            return "\(country)-\(code)"
        }
    }

    /// Place keys of the given rows. Pass only live, fully visited rows: the caller filters out
    /// bucket-list and transit rows (transit does not count toward coverage, §2.5).
    static func visitedKeys(_ rows: [(regionType: String, regionCode: String)]) -> Set<String> {
        Set(rows.compactMap { placeKey(regionType: $0.regionType, regionCode: $0.regionCode) })
    }

    static func coverage(of region: NamedRegion, visitedKeys: Set<String>) -> RegionCoverage {
        RegionCoverage(region: region, visitedMembers: region.memberKeys.filter(visitedKeys.contains))
    }
}

/// The bundled named-region dataset (`GeoData/named_regions.json`, built by
/// `scripts/build_named_regions.py`).
struct NamedRegionCatalog: Sendable {
    let regions: [NamedRegion]

    private struct File: Decodable {
        let regions: [NamedRegion]
    }

    init(regions: [NamedRegion]) {
        self.regions = regions
    }

    init(data: Data) throws {
        regions = try JSONDecoder().decode(File.self, from: data).regions
    }

    static let fileName = "named_regions"

    static let bundled: NamedRegionCatalog = {
        let url = Bundle.main.url(forResource: fileName, withExtension: "json", subdirectory: "GeoData")
            ?? Bundle.main.url(forResource: fileName, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url), let catalog = try? NamedRegionCatalog(data: data)
        else { return NamedRegionCatalog(regions: []) }
        return catalog
    }()

    func region(id: String) -> NamedRegion? {
        regions.first { $0.id == id }
    }

    func regions(of kind: NamedRegion.Kind) -> [NamedRegion] {
        regions.filter { $0.kind == kind }
    }

    /// Regions that list `key` as a member.
    func regions(containing key: String) -> [NamedRegion] {
        regions.filter { $0.memberKeys.contains(key) }
    }

    func coverage(visitedKeys: Set<String>) -> [RegionCoverage] {
        regions.map { RegionResolver.coverage(of: $0, visitedKeys: visitedKeys) }
    }
}

#if canImport(SwiftData)
extension RegionResolver {
    /// Place keys of the live, fully visited places: bucket-list and transit rows do not count
    /// toward coverage (§2.5 transit rule).
    static func visitedKeys(from places: [VisitedPlace]) -> Set<String> {
        visitedKeys(places.filter { !$0.isDeleted && $0.isVisited && !$0.isTransit }.map { ($0.regionType, $0.regionCode) })
    }
}
#endif
