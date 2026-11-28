import Foundation

/// The medals v2 catalog (§4.1), decoded from the generated `medals.json`.
/// Source of truth: `scripts/build_medals_catalog.py`, which also writes the backend copy.
struct MedalCatalog: Codable, Sendable {
    struct Tier: Codable, Sendable, Equatable {
        let level: String
        let threshold: Double
    }

    struct Definition: Codable, Sendable, Identifiable, Equatable {
        let id: String
        let name: String
        let description: String
        let family: String
        let category: String
        let metric: String
        let tiers: [Tier]
        let icon: String
        let platforms: [String]
        let filter: [String: String]?
        let members: [String]?
        let legacyBadgeId: String?
        let legacyTier: String?
        let note: String?

        var isMilestone: Bool { tiers.count == 1 }
        var runsOnDevice: Bool { platforms.contains("ios") }
    }

    struct CountyState: Codable, Sendable {
        let fips: String
        let count: Int
    }

    let catalogVersion: Int
    let tierLevels: [String]
    let subdivisionRegionTypes: [String: String]
    let countyRegionType: String
    let namedRegionRegionType: String
    let countryContinents: [String: String]
    let subdivisionCounts: [String: Int]
    let countrySets: [String: [String]]
    let countyStates: [String: CountyState]
    let medals: [Definition]

    static func decode(_ data: Data) throws -> MedalCatalog {
        try JSONDecoder().decode(MedalCatalog.self, from: data)
    }

    /// Rank of a tier level (bronze = 0 … platinum = 3); unknown levels rank lowest.
    func rank(of level: String) -> Int {
        tierLevels.firstIndex(of: level) ?? -1
    }
}

enum MedalTierLevel: String, CaseIterable, Sendable {
    case bronze, silver, gold, platinum

    var displayName: String { rawValue.capitalized }
}
