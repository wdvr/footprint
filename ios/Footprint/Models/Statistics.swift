import Foundation

// MARK: - Country Coverage

struct CountryCoverage {
    let countryCode: String
    let countryName: String
    let visitedCount: Int
    let totalCount: Int

    var percentage: Double {
        guard totalCount > 0 else { return 0 }
        return (Double(visitedCount) / Double(totalCount)) * 100
    }

    /// Localized subdivision label (e.g., "states", "provinces", "regions")
    var subdivisionLabel: String {
        switch countryCode {
        case "US": return "states"
        case "CA": return "provinces"
        case "AU": return "states"
        case "MX": return "states"
        case "BR": return "states"
        case "DE": return "states"
        case "FR": return "regions"
        case "ES": return "communities"
        case "IT": return "regions"
        case "NL": return "provinces"
        case "BE": return "provinces"
        case "GB": return "countries"
        case "RU": return "subjects"
        case "AR": return "provinces"
        case "JP": return "prefectures"
        case "KR": return "provinces"
        case "NO": return "counties"
        default: return "regions"
        }
    }

    /// Calculate coverage for a country with subdivision tracking
    static func coverage(
        for countryCode: String,
        visitedPlaces: [VisitedPlace]
    ) -> CountryCoverage? {
        let allStates = GeographicData.states(for: countryCode)
        guard !allStates.isEmpty else { return nil }
        guard let regionType = GeographicData.regionType(for: countryCode) else { return nil }

        let countryName = GeographicData.countries.first { $0.id == countryCode }?.name ?? countryCode

        let visitedCount = visitedPlaces.filter {
            $0.regionType == regionType.rawValue
                && !$0.isDeleted
                && $0.isVisited
        }.count

        return CountryCoverage(
            countryCode: countryCode,
            countryName: countryName,
            visitedCount: visitedCount,
            totalCount: allStates.count
        )
    }
}

// MARK: - Continent Statistics

struct ContinentStats: Identifiable, Codable {
    var id: String { continent }
    let continent: String
    let countriesVisited: Int
    let countriesTotal: Int
    let percentage: Double
    let visitedCountries: [String]

    enum CodingKeys: String, CodingKey {
        case continent
        case countriesVisited = "countries_visited"
        case countriesTotal = "countries_total"
        case percentage
        case visitedCountries = "visited_countries"
    }

    var emoji: String {
        switch continent {
        case "Africa": return "🌍"
        case "Asia": return "🌏"
        case "Europe": return "🏰"
        case "North America": return "🗽"
        case "Oceania": return "🏝️"
        case "South America": return "🌴"
        default: return "🌐"
        }
    }
}

struct ContinentStatsResponse: Codable {
    let continents: [ContinentStats]
    let totalContinentsVisited: Int

    enum CodingKeys: String, CodingKey {
        case continents
        case totalContinentsVisited = "total_continents_visited"
    }
}

// MARK: - Time Zone Statistics

struct TimeZone: Identifiable, Codable {
    var id: Int { offset }
    let offset: Int
    let name: String
    let visited: Bool
    let countries: [String]

    var displayName: String {
        if offset >= 0 {
            return "UTC+\(offset)"
        } else {
            return "UTC\(offset)"
        }
    }
}

struct TimeZoneStats: Codable {
    let totalZones: Int
    let zonesVisited: Int
    let percentage: Double
    let zones: [TimeZone]
    let farthestEast: Int?
    let farthestWest: Int?

    enum CodingKeys: String, CodingKey {
        case totalZones = "total_zones"
        case zonesVisited = "zones_visited"
        case percentage
        case zones
        case farthestEast = "farthest_east"
        case farthestWest = "farthest_west"
    }
}

// MARK: - Badge System

enum BadgeCategory: String, Codable, CaseIterable {
    case countries
    case regions
    case continents
    case special
    case states

    var displayName: String {
        switch self {
        case .countries: return "Countries"
        case .regions: return "Regions"
        case .continents: return "Continents"
        case .special: return "Special"
        case .states: return "States"
        }
    }

    var icon: String {
        switch self {
        case .countries: return "globe"
        case .regions: return "map"
        case .continents: return "globe.europe.africa"
        case .special: return "star"
        case .states: return "flag"
        }
    }
}

struct Badge: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let category: BadgeCategory
    let icon: String
    let requirementType: String
    let requirementValue: Int
    let requirementFilter: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, icon
        case requirementType = "requirement_type"
        case requirementValue = "requirement_value"
        case requirementFilter = "requirement_filter"
    }
}

struct BadgeProgress: Identifiable, Codable {
    var id: String { badge.id }
    let badge: Badge
    let unlocked: Bool
    let unlockedAt: Date?
    let progress: Int
    let progressTotal: Int
    let progressPercentage: Double

    enum CodingKeys: String, CodingKey {
        case badge, unlocked
        case unlockedAt = "unlocked_at"
        case progress
        case progressTotal = "progress_total"
        case progressPercentage = "progress_percentage"
    }
}

struct BadgesResponse: Codable {
    let earned: [BadgeProgress]
    let inProgress: [BadgeProgress]
    let totalEarned: Int
    let totalBadges: Int

    enum CodingKeys: String, CodingKey {
        case earned
        case inProgress = "in_progress"
        case totalEarned = "total_earned"
        case totalBadges = "total_badges"
    }
}

// MARK: - Leaderboard

struct LeaderboardEntry: Identifiable, Codable {
    var id: String { userId }
    let userId: String
    let displayName: String?
    let countriesVisited: Int
    let usStatesVisited: Int
    let canadianProvincesVisited: Int
    let totalRegions: Int
    let rank: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case countriesVisited = "countries_visited"
        case usStatesVisited = "us_states_visited"
        case canadianProvincesVisited = "canadian_provinces_visited"
        case totalRegions = "total_regions"
        case rank
    }
}

struct LeaderboardResponse: Codable {
    let entries: [LeaderboardEntry]
    let userRank: Int?
    let totalFriends: Int

    enum CodingKeys: String, CodingKey {
        case entries
        case userRank = "user_rank"
        case totalFriends = "total_friends"
    }
}

// MARK: - Extended Stats

struct ExtendedStats: Codable {
    let countriesVisited: Int
    let countriesTransit: Int
    let usStatesVisited: Int
    let usStatesTransit: Int
    let canadianProvincesVisited: Int
    let canadianProvincesTransit: Int
    let continents: ContinentStatsResponse?
    let timeZones: TimeZoneStats?
    let badgesEarned: Int
    let badgesTotal: Int
    let firstVisitDate: String?
    let latestVisitDate: String?
    let countriesThisYear: Int

    enum CodingKeys: String, CodingKey {
        case countriesVisited = "countries_visited"
        case countriesTransit = "countries_transit"
        case usStatesVisited = "us_states_visited"
        case usStatesTransit = "us_states_transit"
        case canadianProvincesVisited = "canadian_provinces_visited"
        case canadianProvincesTransit = "canadian_provinces_transit"
        case continents
        case timeZones = "time_zones"
        case badgesEarned = "badges_earned"
        case badgesTotal = "badges_total"
        case firstVisitDate = "first_visit_date"
        case latestVisitDate = "latest_visit_date"
        case countriesThisYear = "countries_this_year"
    }
}
