import SwiftUI

// MARK: - Continent Progress View

struct ContinentProgressView: View {
    let visitedPlaces: [VisitedPlace]

    private var continentStats: [LocalContinentStats] {
        // Group visited countries by continent
        let visitedCountries = visitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
            && $0.isVisited
            && !$0.isDeleted
        }.map { $0.regionCode }

        return LocalContinentStats.calculateStats(visitedCountries: visitedCountries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "globe.europe.africa")
                    .foregroundStyle(.blue)
                Text("By Continent")
                    .font(.headline)
            }

            ForEach(continentStats) { stat in
                ContinentRow(stat: stat)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ContinentRow: View {
    let stat: LocalContinentStats

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(stat.emoji)
                Text(stat.name)
                    .font(.subheadline)
                Spacer()
                Text("\(stat.visited)/\(stat.total)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: stat.percentage, total: 100)
                .tint(stat.visited > 0 ? .green : .gray)
        }
    }
}

// MARK: - Time Zone Progress View

struct TimeZoneProgressView: View {
    let visitedPlaces: [VisitedPlace]

    private var timeZoneStats: TimeZoneLocalStats {
        let visitedCountries = visitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
            && $0.isVisited
            && !$0.isDeleted
        }.map { $0.regionCode }

        return TimeZoneLocalStats.calculate(visitedCountries: visitedCountries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.purple)
                Text("Time Zones")
                    .font(.headline)
                Spacer()
                Text("\(timeZoneStats.zonesVisited)/24")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Visual time zone bar
            TimeZoneBar(visitedZones: timeZoneStats.visitedZones)

            HStack {
                if let west = timeZoneStats.farthestWest {
                    VStack(alignment: .leading) {
                        Text("Farthest West")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("UTC\(west >= 0 ? "+" : "")\(west)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                Spacer()

                if let east = timeZoneStats.farthestEast {
                    VStack(alignment: .trailing) {
                        Text("Farthest East")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("UTC\(east >= 0 ? "+" : "")\(east)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }

            Text("\(Int(timeZoneStats.percentage))% of time zones visited")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TimeZoneBar: View {
    let visitedZones: Set<Int>

    var body: some View {
        HStack(spacing: 2) {
            ForEach(-12..<15, id: \.self) { offset in
                Rectangle()
                    .fill(visitedZones.contains(offset) ? Color.purple : Color.gray.opacity(0.3))
                    .frame(height: 24)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Badges Progress View

struct BadgesProgressView: View {
    let visitedPlaces: [VisitedPlace]

    private var badgeProgress: [LocalBadgeProgress] {
        LocalBadgeProgress.calculateProgress(visitedPlaces: visitedPlaces)
    }

    private var earnedBadges: [LocalBadgeProgress] {
        badgeProgress.filter { $0.unlocked }
    }

    private var inProgressBadges: [LocalBadgeProgress] {
        badgeProgress.filter { !$0.unlocked }
            .sorted { $0.progressPercentage > $1.progressPercentage }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trophy")
                    .foregroundStyle(.yellow)
                Text("Achievements")
                    .font(.headline)
                Spacer()
                Text("\(earnedBadges.count)/\(badgeProgress.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Earned badges
            if !earnedBadges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(earnedBadges) { badge in
                            EarnedBadgeIcon(badge: badge)
                        }
                    }
                }
            }

            // Next badges to earn
            if let nextBadge = inProgressBadges.first {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Achievement")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: nextBadge.icon)
                            .foregroundStyle(.gray)
                        Text(nextBadge.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(nextBadge.progress)/\(nextBadge.progressTotal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: nextBadge.progressPercentage, total: 100)
                        .tint(.yellow)
                }
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EarnedBadgeIcon: View {
    let badge: LocalBadgeProgress

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.yellow.gradient)
                    .frame(width: 50, height: 50)

                Image(systemName: badge.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            Text(badge.name)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 60)
        }
    }
}

// MARK: - Visit Type Stats View

struct VisitTypeStatsView: View {
    let visitedPlaces: [VisitedPlace]

    private var fullVisits: Int {
        visitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
            && $0.isVisited
            && !$0.isDeleted
            && $0.isFullVisit
        }.count
    }

    private var transitVisits: Int {
        visitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
            && $0.isVisited
            && !$0.isDeleted
            && $0.isTransit
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "airplane.arrival")
                    .foregroundStyle(.teal)
                Text("Visit Types")
                    .font(.headline)
            }

            HStack(spacing: 24) {
                VStack {
                    Text("\(fullVisits)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("Full Visits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text("\(transitVisits)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("Transit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Local Data Models (for offline calculation)

struct LocalContinentStats: Identifiable {
    var id: String { name }
    let name: String
    let emoji: String
    let visited: Int
    let total: Int

    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(visited) / Double(total) * 100
    }

    static let continentData: [(name: String, emoji: String, total: Int, codes: Set<String>)] = [
        ("Europe", "🏰", 44, Set(["AL", "AD", "AT", "BY", "BE", "BA", "BG", "HR", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IS", "IE", "IT", "LV", "LI", "LT", "LU", "MT", "MD", "MC", "ME", "NL", "MK", "NO", "PL", "PT", "RO", "RU", "SM", "RS", "SK", "SI", "ES", "SE", "CH", "UA", "GB", "VA"])),
        ("Asia", "🌏", 49, Set(["AF", "AM", "AZ", "BH", "BD", "BT", "BN", "KH", "CN", "CY", "GE", "IN", "ID", "IR", "IQ", "IL", "JP", "JO", "KZ", "KW", "KG", "LA", "LB", "MY", "MV", "MN", "MM", "NP", "KP", "OM", "PK", "PS", "PH", "QA", "SA", "SG", "KR", "LK", "SY", "TW", "TJ", "TH", "TL", "TR", "TM", "AE", "UZ", "VN", "YE"])),
        ("Africa", "🌍", 54, Set(["DZ", "AO", "BJ", "BW", "BF", "BI", "CV", "CM", "CF", "TD", "KM", "CG", "CD", "CI", "DJ", "EG", "GQ", "ER", "SZ", "ET", "GA", "GM", "GH", "GN", "GW", "KE", "LS", "LR", "LY", "MG", "MW", "ML", "MR", "MU", "MA", "MZ", "NA", "NE", "NG", "RW", "ST", "SN", "SC", "SL", "SO", "ZA", "SS", "SD", "TZ", "TG", "TN", "UG", "ZM", "ZW"])),
        ("North America", "🗽", 23, Set(["AG", "BS", "BB", "BZ", "CA", "CR", "CU", "DM", "DO", "SV", "GD", "GT", "HT", "HN", "JM", "MX", "NI", "PA", "KN", "LC", "VC", "TT", "US"])),
        ("South America", "🌴", 12, Set(["AR", "BO", "BR", "CL", "CO", "EC", "GY", "PY", "PE", "SR", "UY", "VE"])),
        ("Oceania", "🏝️", 14, Set(["AU", "FJ", "KI", "MH", "FM", "NR", "NZ", "PW", "PG", "WS", "SB", "TO", "TV", "VU"])),
    ]

    static func calculateStats(visitedCountries: [String]) -> [LocalContinentStats] {
        let visitedSet = Set(visitedCountries)
        return continentData.map { data in
            let visited = data.codes.intersection(visitedSet).count
            return LocalContinentStats(
                name: data.name,
                emoji: data.emoji,
                visited: visited,
                total: data.total
            )
        }.sorted { $0.visited > $1.visited }
    }
}

struct TimeZoneLocalStats {
    let zonesVisited: Int
    let visitedZones: Set<Int>
    let farthestEast: Int?
    let farthestWest: Int?
    let percentage: Double

    static let countryTimeZones: [String: [Int]] = [
        "US": [-10, -9, -8, -7, -6, -5],
        "CA": [-8, -7, -6, -5, -4, -3],
        "MX": [-8, -7, -6],
        "BR": [-5, -4, -3],
        "RU": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        "AU": [8, 9, 10, 11],
        "GB": [0], "IE": [0], "IS": [0],
        "FR": [1], "DE": [1], "IT": [1], "ES": [1], "NL": [1], "BE": [1],
        "JP": [9], "KR": [9], "CN": [8], "SG": [8], "IN": [5],
        "NZ": [12, 13], "FJ": [12],
        "EG": [2], "ZA": [2], "KE": [3], "NG": [1],
        "AR": [-3], "CL": [-4, -3], "CO": [-5], "PE": [-5],
        "AE": [4], "SA": [3], "IL": [2], "TR": [3],
        "TH": [7], "VN": [7], "PH": [8], "ID": [7, 8, 9],
    ]

    static func calculate(visitedCountries: [String]) -> TimeZoneLocalStats {
        var zones: Set<Int> = []
        for country in visitedCountries {
            if let countryZones = countryTimeZones[country] {
                zones.formUnion(countryZones)
            }
        }

        return TimeZoneLocalStats(
            zonesVisited: zones.count,
            visitedZones: zones,
            farthestEast: zones.max(),
            farthestWest: zones.min(),
            percentage: Double(zones.count) / 24.0 * 100
        )
    }
}

struct LocalBadgeProgress: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let progress: Int
    let progressTotal: Int
    let unlocked: Bool

    var progressPercentage: Double {
        guard progressTotal > 0 else { return 0 }
        return min(100, Double(progress) / Double(progressTotal) * 100)
    }

    static let badges: [(id: String, name: String, desc: String, icon: String, type: String, value: Int)] = [
        ("first_steps", "First Steps", "Visit your first country", "figure.walk", "countries", 1),
        ("explorer_10", "Explorer", "Visit 10 countries", "globe.americas", "countries", 10),
        ("globetrotter_25", "Globetrotter", "Visit 25 countries", "globe", "countries", 25),
        ("world_traveler_50", "World Traveler", "Visit 50 countries", "airplane", "countries", 50),
        ("us_starter", "US Starter", "Visit 10 US states", "flag", "us_states", 10),
        ("us_half", "Half the States", "Visit 25 US states", "star", "us_states", 25),
        ("us_complete", "All 50 States", "Visit all 50 US states", "star.fill", "us_states", 50),
        ("canada_explorer", "Canada Explorer", "Visit 5 Canadian provinces", "leaf.circle", "canada", 5),
    ]

    static func calculateProgress(visitedPlaces: [VisitedPlace]) -> [LocalBadgeProgress] {
        let countries = visitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.country.rawValue
            && $0.isVisited && !$0.isDeleted
        }.count

        let usStates = visitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.usState.rawValue
            && $0.isVisited && !$0.isDeleted
        }.count

        let canada = visitedPlaces.filter {
            $0.regionType == VisitedPlace.RegionType.canadianProvince.rawValue
            && $0.isVisited && !$0.isDeleted
        }.count

        return badges.map { badge in
            let progress: Int
            switch badge.type {
            case "countries": progress = countries
            case "us_states": progress = usStates
            case "canada": progress = canada
            default: progress = 0
            }

            return LocalBadgeProgress(
                id: badge.id,
                name: badge.name,
                description: badge.desc,
                icon: badge.icon,
                progress: progress,
                progressTotal: badge.value,
                unlocked: progress >= badge.value
            )
        }
    }
}
