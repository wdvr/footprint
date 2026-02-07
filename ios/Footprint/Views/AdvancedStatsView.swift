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
                    .accessibilityHidden(true)
                Text("By Continent")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
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
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stat.name), \(stat.visited) of \(stat.total) countries visited, \(Int(stat.percentage)) percent")
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

        // Get visited states/provinces for multi-timezone countries
        let visitedStates = visitedPlaces.filter {
            $0.isVisited && !$0.isDeleted &&
            [VisitedPlace.RegionType.usState.rawValue,
             VisitedPlace.RegionType.canadianProvince.rawValue,
             VisitedPlace.RegionType.russianFederalSubject.rawValue,
             VisitedPlace.RegionType.australianState.rawValue,
             VisitedPlace.RegionType.mexicanState.rawValue,
             VisitedPlace.RegionType.brazilianState.rawValue].contains($0.regionType)
        }.map { ($0.regionType, $0.regionCode) }

        return TimeZoneLocalStats.calculate(visitedCountries: visitedCountries, visitedStates: visitedStates)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.purple)
                    .accessibilityHidden(true)
                Text("Time Zones")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(timeZoneStats.zonesVisited)/24")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Visual time zone bar
            TimeZoneBar(visitedZones: timeZoneStats.visitedZones)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(timeZoneStats.zonesVisited) of 24 time zones visited")

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
                    .accessibilityHidden(true)
                Text("Achievements")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
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
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        Image(systemName: nextBadge.icon)
                            .foregroundStyle(.gray)
                            .accessibilityHidden(true)
                        Text(nextBadge.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(nextBadge.progress)/\(nextBadge.progressTotal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(nextBadge.name), \(nextBadge.progress) of \(nextBadge.progressTotal)")

                    ProgressView(value: nextBadge.progressPercentage, total: 100)
                        .tint(.yellow)
                        .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement unlocked: \(badge.name)")
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
                    .accessibilityHidden(true)
                Text("Visit Types")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(fullVisits) full visits")

                Divider()
                    .frame(height: 40)
                    .accessibilityHidden(true)

                VStack {
                    Text("\(transitVisits)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    Text("Transit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(transitVisits) transit visits")
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

    // Countries with single timezone (or where we use main timezone)
    static let singleTimeZoneCountries: [String: Int] = [
        "GB": 0, "IE": 0, "IS": 0, "PT": 0,
        "FR": 1, "DE": 1, "IT": 1, "ES": 1, "NL": 1, "BE": 1, "PL": 1, "CZ": 1, "AT": 1, "CH": 1,
        "GR": 2, "EG": 2, "ZA": 2, "IL": 2, "FI": 2, "RO": 2, "BG": 2,
        "SA": 3, "KE": 3, "TR": 3, "IQ": 3,
        "AE": 4, "OM": 4,
        "IN": 5, "PK": 5, "LK": 5,
        "BD": 6, "KZ": 6,
        "TH": 7, "VN": 7, "KH": 7,
        "SG": 8, "MY": 8, "PH": 8, "HK": 8, "TW": 8,
        "JP": 9, "KR": 9,
        "NZ": 12, "FJ": 12,
        "AR": -3, "UY": -3,
        "CL": -4, "VE": -4, "BO": -4,
        "CO": -5, "PE": -5, "EC": -5, "PA": -5,
        "CR": -6, "GT": -6, "SV": -6,
        "CU": -5, "JM": -5,
    ]

    // Multi-timezone countries need state-level mapping
    static let multiTimeZoneCountries = Set(["US", "CA", "RU", "AU", "MX", "BR", "ID", "CN"])

    // US state timezones
    static let usStateTimeZones: [String: Int] = [
        "HI": -10, "AK": -9,
        "CA": -8, "WA": -8, "OR": -8, "NV": -8,
        "AZ": -7, "MT": -7, "ID": -7, "WY": -7, "UT": -7, "CO": -7, "NM": -7,
        "ND": -6, "SD": -6, "NE": -6, "KS": -6, "MN": -6, "IA": -6, "MO": -6,
        "WI": -6, "IL": -6, "TX": -6, "OK": -6, "AR": -6, "LA": -6, "MS": -6, "AL": -6,
        "MI": -5, "IN": -5, "OH": -5, "KY": -5, "TN": -5, "GA": -5, "FL": -5,
        "SC": -5, "NC": -5, "VA": -5, "WV": -5, "MD": -5, "DE": -5, "PA": -5,
        "NJ": -5, "NY": -5, "CT": -5, "RI": -5, "MA": -5, "VT": -5, "NH": -5, "ME": -5,
        "DC": -5,
    ]

    // Canadian province timezones
    static let canadianProvinceTimeZones: [String: Int] = [
        "BC": -8, "YT": -8,
        "AB": -7, "NT": -7,
        "SK": -6, "MB": -6, "NU": -6,
        "ON": -5, "QC": -5,
        "NB": -4, "NS": -4, "PE": -4,
        "NL": -3,
    ]

    // Russian federal subject timezones
    static let russianTimeZones: [String: Int] = [
        // UTC+2: Kaliningrad
        "KGD": 2,
        // UTC+3: Moscow, St Petersburg, and western regions
        "MOW": 3, "MOS": 3, "SPE": 3, "LEN": 3, "KR": 3, "MUR": 3, "ARK": 3,
        "VLG": 3, "KOS": 3, "IVA": 3, "TVE": 3, "YAR": 3, "SMO": 3, "BRY": 3,
        "ORL": 3, "TUL": 3, "KLU": 3, "RYA": 3, "VLA": 3, "NIZ": 3, "ME": 3,
        "MO": 3, "CU": 3, "TA": 3, "PNZ": 3, "ULY": 3, "SAR": 3, "VOR": 3,
        "LIP": 3, "TAM": 3, "BEL": 3, "KRS": 3, "AD": 3, "KDA": 3, "STA": 3,
        "KC": 3, "KB": 3, "SE": 3, "CE": 3, "IN": 3, "DA": 3, "KL": 3, "ROS": 3, "VGG": 3, "AST": 3,
        // UTC+4: Samara
        "SAM": 4, "UD": 4,
        // UTC+5: Yekaterinburg
        "SVE": 5, "PER": 5, "CHE": 5, "KGN": 5, "TYU": 5, "KHM": 5, "YAN": 5, "BA": 5, "ORE": 5,
        // UTC+6: Omsk
        "OMS": 6,
        // UTC+7: Novosibirsk, Tomsk, Altai
        "NVS": 7, "TOM": 7, "ALT": 7, "AL": 7, "KEM": 7, "KK": 7, "TY": 7,
        // UTC+8: Irkutsk
        "IRK": 8, "BU": 8,
        // UTC+9: Yakutsk
        "SA": 9, "ZAB": 9, "AMU": 9,
        // UTC+10: Vladivostok
        "PRI": 10, "KHA": 10, "YEV": 10,
        // UTC+11: Magadan
        "MAG": 11, "SAK": 11,
        // UTC+12: Kamchatka
        "KAM": 12, "CHU": 12,
    ]

    // Australian state timezones
    static let australianTimeZones: [String: Int] = [
        "WA": 8,
        "NT": 9, "SA": 9,
        "QLD": 10, "NSW": 10, "VIC": 10, "TAS": 10, "ACT": 10,
    ]

    // Mexican state timezones
    static let mexicanTimeZones: [String: Int] = [
        "BCN": -8,
        "BCS": -7, "SON": -7, "CHH": -7, "SIN": -7, "NAY": -7,
        // Rest of Mexico is UTC-6
    ]

    // Brazilian state timezones
    static let brazilianTimeZones: [String: Int] = [
        "AC": -5, "AM": -4, "RR": -4, "RO": -4, "MT": -4,
        // Rest of Brazil is UTC-3
    ]

    static func calculate(visitedCountries: [String], visitedStates: [(String, String)] = []) -> TimeZoneLocalStats {
        var zones: Set<Int> = []

        // Group visited states by region type
        var visitedUSStates: Set<String> = []
        var visitedCanadianProvinces: Set<String> = []
        var visitedRussianRegions: Set<String> = []
        var visitedAustralianStates: Set<String> = []
        var visitedMexicanStates: Set<String> = []
        var visitedBrazilianStates: Set<String> = []

        for (regionType, code) in visitedStates {
            switch regionType {
            case VisitedPlace.RegionType.usState.rawValue:
                visitedUSStates.insert(code)
            case VisitedPlace.RegionType.canadianProvince.rawValue:
                visitedCanadianProvinces.insert(code)
            case VisitedPlace.RegionType.russianFederalSubject.rawValue:
                visitedRussianRegions.insert(code)
            case VisitedPlace.RegionType.australianState.rawValue:
                visitedAustralianStates.insert(code)
            case VisitedPlace.RegionType.mexicanState.rawValue:
                visitedMexicanStates.insert(code)
            case VisitedPlace.RegionType.brazilianState.rawValue:
                visitedBrazilianStates.insert(code)
            default:
                break
            }
        }

        for country in visitedCountries {
            if multiTimeZoneCountries.contains(country) {
                // For multi-timezone countries, only add timezones for visited states
                switch country {
                case "US":
                    for state in visitedUSStates {
                        if let tz = usStateTimeZones[state] { zones.insert(tz) }
                    }
                case "CA":
                    for province in visitedCanadianProvinces {
                        if let tz = canadianProvinceTimeZones[province] { zones.insert(tz) }
                    }
                case "RU":
                    for region in visitedRussianRegions {
                        if let tz = russianTimeZones[region] { zones.insert(tz) }
                    }
                case "AU":
                    for state in visitedAustralianStates {
                        if let tz = australianTimeZones[state] { zones.insert(tz) }
                    }
                case "MX":
                    if visitedMexicanStates.isEmpty {
                        // Default to Mexico City timezone if no specific states visited
                        zones.insert(-6)
                    } else {
                        for state in visitedMexicanStates {
                            zones.insert(mexicanTimeZones[state] ?? -6)
                        }
                    }
                case "BR":
                    if visitedBrazilianStates.isEmpty {
                        // Default to Brasilia timezone if no specific states visited
                        zones.insert(-3)
                    } else {
                        for state in visitedBrazilianStates {
                            zones.insert(brazilianTimeZones[state] ?? -3)
                        }
                    }
                case "CN":
                    // China uses single timezone officially
                    zones.insert(8)
                case "ID":
                    // Indonesia - default to Jakarta timezone
                    zones.insert(7)
                default:
                    break
                }
            } else if let tz = singleTimeZoneCountries[country] {
                zones.insert(tz)
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
