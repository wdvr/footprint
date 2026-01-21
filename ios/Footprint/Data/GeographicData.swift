import Foundation

struct Country: Identifiable, Hashable {
    let id: String // ISO alpha-2 code
    let name: String
    let continent: String
    let hasStates: Bool

    init(_ code: String, _ name: String, continent: String, hasStates: Bool = false) {
        self.id = code
        self.name = name
        self.continent = continent
        self.hasStates = hasStates
    }
}

enum Continent: String, CaseIterable, Identifiable {
    case africa = "Africa"
    case antarctica = "Antarctica"
    case asia = "Asia"
    case europe = "Europe"
    case northAmerica = "North America"
    case oceania = "Oceania"
    case southAmerica = "South America"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .africa: return "🌍"
        case .antarctica: return "🧊"
        case .asia: return "🌏"
        case .europe: return "🌍"
        case .northAmerica: return "🌎"
        case .oceania: return "🌏"
        case .southAmerica: return "🌎"
        }
    }
}

struct StateProvince: Identifiable, Hashable {
    let id: String // State/province code
    let name: String
    let countryCode: String

    init(_ code: String, _ name: String, country: String) {
        self.id = code
        self.name = name
        self.countryCode = country
    }
}

enum GeographicData {
    static let countries: [Country] = [
        // Africa
        Country("DZ", "Algeria", continent: "Africa"),
        Country("AO", "Angola", continent: "Africa"),
        Country("BJ", "Benin", continent: "Africa"),
        Country("BW", "Botswana", continent: "Africa"),
        Country("BF", "Burkina Faso", continent: "Africa"),
        Country("BI", "Burundi", continent: "Africa"),
        Country("CV", "Cabo Verde", continent: "Africa"),
        Country("CM", "Cameroon", continent: "Africa"),
        Country("CF", "Central African Republic", continent: "Africa"),
        Country("TD", "Chad", continent: "Africa"),
        Country("KM", "Comoros", continent: "Africa"),
        Country("CG", "Congo", continent: "Africa"),
        Country("CD", "Congo (DRC)", continent: "Africa"),
        Country("CI", "Côte d'Ivoire", continent: "Africa"),
        Country("DJ", "Djibouti", continent: "Africa"),
        Country("EG", "Egypt", continent: "Africa"),
        Country("GQ", "Equatorial Guinea", continent: "Africa"),
        Country("ER", "Eritrea", continent: "Africa"),
        Country("SZ", "Eswatini", continent: "Africa"),
        Country("ET", "Ethiopia", continent: "Africa"),
        Country("GA", "Gabon", continent: "Africa"),
        Country("GM", "Gambia", continent: "Africa"),
        Country("GH", "Ghana", continent: "Africa"),
        Country("GN", "Guinea", continent: "Africa"),
        Country("GW", "Guinea-Bissau", continent: "Africa"),
        Country("KE", "Kenya", continent: "Africa"),
        Country("LS", "Lesotho", continent: "Africa"),
        Country("LR", "Liberia", continent: "Africa"),
        Country("LY", "Libya", continent: "Africa"),
        Country("MG", "Madagascar", continent: "Africa"),
        Country("MW", "Malawi", continent: "Africa"),
        Country("ML", "Mali", continent: "Africa"),
        Country("MR", "Mauritania", continent: "Africa"),
        Country("MU", "Mauritius", continent: "Africa"),
        Country("MA", "Morocco", continent: "Africa"),
        Country("MZ", "Mozambique", continent: "Africa"),
        Country("NA", "Namibia", continent: "Africa"),
        Country("NE", "Niger", continent: "Africa"),
        Country("NG", "Nigeria", continent: "Africa"),
        Country("RW", "Rwanda", continent: "Africa"),
        Country("ST", "São Tomé and Príncipe", continent: "Africa"),
        Country("SN", "Senegal", continent: "Africa"),
        Country("SC", "Seychelles", continent: "Africa"),
        Country("SL", "Sierra Leone", continent: "Africa"),
        Country("SO", "Somalia", continent: "Africa"),
        Country("ZA", "South Africa", continent: "Africa"),
        Country("SS", "South Sudan", continent: "Africa"),
        Country("SD", "Sudan", continent: "Africa"),
        Country("TZ", "Tanzania", continent: "Africa"),
        Country("TG", "Togo", continent: "Africa"),
        Country("TN", "Tunisia", continent: "Africa"),
        Country("UG", "Uganda", continent: "Africa"),
        Country("ZM", "Zambia", continent: "Africa"),
        Country("ZW", "Zimbabwe", continent: "Africa"),
        // Asia
        Country("AF", "Afghanistan", continent: "Asia"),
        Country("AM", "Armenia", continent: "Asia"),
        Country("AZ", "Azerbaijan", continent: "Asia"),
        Country("BH", "Bahrain", continent: "Asia"),
        Country("BD", "Bangladesh", continent: "Asia"),
        Country("BT", "Bhutan", continent: "Asia"),
        Country("BN", "Brunei", continent: "Asia"),
        Country("KH", "Cambodia", continent: "Asia"),
        Country("CN", "China", continent: "Asia"),
        Country("CY", "Cyprus", continent: "Asia"),
        Country("GE", "Georgia", continent: "Asia"),
        Country("IN", "India", continent: "Asia"),
        Country("ID", "Indonesia", continent: "Asia"),
        Country("IR", "Iran", continent: "Asia"),
        Country("IQ", "Iraq", continent: "Asia"),
        Country("IL", "Israel", continent: "Asia"),
        Country("JP", "Japan", continent: "Asia"),
        Country("JO", "Jordan", continent: "Asia"),
        Country("KZ", "Kazakhstan", continent: "Asia"),
        Country("KW", "Kuwait", continent: "Asia"),
        Country("KG", "Kyrgyzstan", continent: "Asia"),
        Country("LA", "Laos", continent: "Asia"),
        Country("LB", "Lebanon", continent: "Asia"),
        Country("MY", "Malaysia", continent: "Asia"),
        Country("MV", "Maldives", continent: "Asia"),
        Country("MN", "Mongolia", continent: "Asia"),
        Country("MM", "Myanmar", continent: "Asia"),
        Country("NP", "Nepal", continent: "Asia"),
        Country("KP", "North Korea", continent: "Asia"),
        Country("OM", "Oman", continent: "Asia"),
        Country("PK", "Pakistan", continent: "Asia"),
        Country("PS", "Palestine", continent: "Asia"),
        Country("PH", "Philippines", continent: "Asia"),
        Country("QA", "Qatar", continent: "Asia"),
        Country("SA", "Saudi Arabia", continent: "Asia"),
        Country("SG", "Singapore", continent: "Asia"),
        Country("KR", "South Korea", continent: "Asia"),
        Country("LK", "Sri Lanka", continent: "Asia"),
        Country("SY", "Syria", continent: "Asia"),
        Country("TW", "Taiwan", continent: "Asia"),
        Country("TJ", "Tajikistan", continent: "Asia"),
        Country("TH", "Thailand", continent: "Asia"),
        Country("TL", "Timor-Leste", continent: "Asia"),
        Country("TR", "Turkey", continent: "Asia"),
        Country("TM", "Turkmenistan", continent: "Asia"),
        Country("AE", "United Arab Emirates", continent: "Asia"),
        Country("UZ", "Uzbekistan", continent: "Asia"),
        Country("VN", "Vietnam", continent: "Asia"),
        Country("YE", "Yemen", continent: "Asia"),
        // Europe
        Country("AL", "Albania", continent: "Europe"),
        Country("AD", "Andorra", continent: "Europe"),
        Country("AT", "Austria", continent: "Europe"),
        Country("BY", "Belarus", continent: "Europe"),
        Country("BE", "Belgium", continent: "Europe"),
        Country("BA", "Bosnia and Herzegovina", continent: "Europe"),
        Country("BG", "Bulgaria", continent: "Europe"),
        Country("HR", "Croatia", continent: "Europe"),
        Country("CZ", "Czech Republic", continent: "Europe"),
        Country("DK", "Denmark", continent: "Europe"),
        Country("EE", "Estonia", continent: "Europe"),
        Country("FI", "Finland", continent: "Europe"),
        Country("FR", "France", continent: "Europe"),
        Country("DE", "Germany", continent: "Europe"),
        Country("GR", "Greece", continent: "Europe"),
        Country("HU", "Hungary", continent: "Europe"),
        Country("IS", "Iceland", continent: "Europe"),
        Country("IE", "Ireland", continent: "Europe"),
        Country("IT", "Italy", continent: "Europe"),
        Country("LV", "Latvia", continent: "Europe"),
        Country("LI", "Liechtenstein", continent: "Europe"),
        Country("LT", "Lithuania", continent: "Europe"),
        Country("LU", "Luxembourg", continent: "Europe"),
        Country("MT", "Malta", continent: "Europe"),
        Country("MD", "Moldova", continent: "Europe"),
        Country("MC", "Monaco", continent: "Europe"),
        Country("ME", "Montenegro", continent: "Europe"),
        Country("NL", "Netherlands", continent: "Europe"),
        Country("MK", "North Macedonia", continent: "Europe"),
        Country("NO", "Norway", continent: "Europe"),
        Country("PL", "Poland", continent: "Europe"),
        Country("PT", "Portugal", continent: "Europe"),
        Country("RO", "Romania", continent: "Europe"),
        Country("RU", "Russia", continent: "Europe"),
        Country("SM", "San Marino", continent: "Europe"),
        Country("RS", "Serbia", continent: "Europe"),
        Country("SK", "Slovakia", continent: "Europe"),
        Country("SI", "Slovenia", continent: "Europe"),
        Country("ES", "Spain", continent: "Europe"),
        Country("SE", "Sweden", continent: "Europe"),
        Country("CH", "Switzerland", continent: "Europe"),
        Country("UA", "Ukraine", continent: "Europe"),
        Country("GB", "United Kingdom", continent: "Europe"),
        Country("VA", "Vatican City", continent: "Europe"),
        // North America
        Country("AG", "Antigua and Barbuda", continent: "North America"),
        Country("BS", "Bahamas", continent: "North America"),
        Country("BB", "Barbados", continent: "North America"),
        Country("BZ", "Belize", continent: "North America"),
        Country("CA", "Canada", continent: "North America", hasStates: true),
        Country("CR", "Costa Rica", continent: "North America"),
        Country("CU", "Cuba", continent: "North America"),
        Country("DM", "Dominica", continent: "North America"),
        Country("DO", "Dominican Republic", continent: "North America"),
        Country("SV", "El Salvador", continent: "North America"),
        Country("GD", "Grenada", continent: "North America"),
        Country("GT", "Guatemala", continent: "North America"),
        Country("HT", "Haiti", continent: "North America"),
        Country("HN", "Honduras", continent: "North America"),
        Country("JM", "Jamaica", continent: "North America"),
        Country("MX", "Mexico", continent: "North America"),
        Country("NI", "Nicaragua", continent: "North America"),
        Country("PA", "Panama", continent: "North America"),
        Country("KN", "Saint Kitts and Nevis", continent: "North America"),
        Country("LC", "Saint Lucia", continent: "North America"),
        Country("VC", "Saint Vincent and the Grenadines", continent: "North America"),
        Country("TT", "Trinidad and Tobago", continent: "North America"),
        Country("US", "United States", continent: "North America", hasStates: true),
        // Oceania
        Country("AU", "Australia", continent: "Oceania"),
        Country("FJ", "Fiji", continent: "Oceania"),
        Country("KI", "Kiribati", continent: "Oceania"),
        Country("MH", "Marshall Islands", continent: "Oceania"),
        Country("FM", "Micronesia", continent: "Oceania"),
        Country("NR", "Nauru", continent: "Oceania"),
        Country("NZ", "New Zealand", continent: "Oceania"),
        Country("PW", "Palau", continent: "Oceania"),
        Country("PG", "Papua New Guinea", continent: "Oceania"),
        Country("WS", "Samoa", continent: "Oceania"),
        Country("SB", "Solomon Islands", continent: "Oceania"),
        Country("TO", "Tonga", continent: "Oceania"),
        Country("TV", "Tuvalu", continent: "Oceania"),
        Country("VU", "Vanuatu", continent: "Oceania"),
        // South America
        Country("AR", "Argentina", continent: "South America"),
        Country("BO", "Bolivia", continent: "South America"),
        Country("BR", "Brazil", continent: "South America"),
        Country("CL", "Chile", continent: "South America"),
        Country("CO", "Colombia", continent: "South America"),
        Country("EC", "Ecuador", continent: "South America"),
        Country("GY", "Guyana", continent: "South America"),
        Country("PY", "Paraguay", continent: "South America"),
        Country("PE", "Peru", continent: "South America"),
        Country("SR", "Suriname", continent: "South America"),
        Country("UY", "Uruguay", continent: "South America"),
        Country("VE", "Venezuela", continent: "South America"),
    ]

    /// Countries grouped by continent, sorted alphabetically within each continent
    static var countriesByContinent: [(continent: Continent, countries: [Country])] {
        Continent.allCases.compactMap { continent in
            let countriesInContinent = countries
                .filter { $0.continent == continent.rawValue }
                .sorted { $0.name < $1.name }
            guard !countriesInContinent.isEmpty else { return nil }
            return (continent, countriesInContinent)
        }
    }

    static let usStates: [StateProvince] = [
        StateProvince("AL", "Alabama", country: "US"),
        StateProvince("AK", "Alaska", country: "US"),
        StateProvince("AZ", "Arizona", country: "US"),
        StateProvince("AR", "Arkansas", country: "US"),
        StateProvince("CA", "California", country: "US"),
        StateProvince("CO", "Colorado", country: "US"),
        StateProvince("CT", "Connecticut", country: "US"),
        StateProvince("DE", "Delaware", country: "US"),
        StateProvince("DC", "District of Columbia", country: "US"),
        StateProvince("FL", "Florida", country: "US"),
        StateProvince("GA", "Georgia", country: "US"),
        StateProvince("HI", "Hawaii", country: "US"),
        StateProvince("ID", "Idaho", country: "US"),
        StateProvince("IL", "Illinois", country: "US"),
        StateProvince("IN", "Indiana", country: "US"),
        StateProvince("IA", "Iowa", country: "US"),
        StateProvince("KS", "Kansas", country: "US"),
        StateProvince("KY", "Kentucky", country: "US"),
        StateProvince("LA", "Louisiana", country: "US"),
        StateProvince("ME", "Maine", country: "US"),
        StateProvince("MD", "Maryland", country: "US"),
        StateProvince("MA", "Massachusetts", country: "US"),
        StateProvince("MI", "Michigan", country: "US"),
        StateProvince("MN", "Minnesota", country: "US"),
        StateProvince("MS", "Mississippi", country: "US"),
        StateProvince("MO", "Missouri", country: "US"),
        StateProvince("MT", "Montana", country: "US"),
        StateProvince("NE", "Nebraska", country: "US"),
        StateProvince("NV", "Nevada", country: "US"),
        StateProvince("NH", "New Hampshire", country: "US"),
        StateProvince("NJ", "New Jersey", country: "US"),
        StateProvince("NM", "New Mexico", country: "US"),
        StateProvince("NY", "New York", country: "US"),
        StateProvince("NC", "North Carolina", country: "US"),
        StateProvince("ND", "North Dakota", country: "US"),
        StateProvince("OH", "Ohio", country: "US"),
        StateProvince("OK", "Oklahoma", country: "US"),
        StateProvince("OR", "Oregon", country: "US"),
        StateProvince("PA", "Pennsylvania", country: "US"),
        StateProvince("RI", "Rhode Island", country: "US"),
        StateProvince("SC", "South Carolina", country: "US"),
        StateProvince("SD", "South Dakota", country: "US"),
        StateProvince("TN", "Tennessee", country: "US"),
        StateProvince("TX", "Texas", country: "US"),
        StateProvince("UT", "Utah", country: "US"),
        StateProvince("VT", "Vermont", country: "US"),
        StateProvince("VA", "Virginia", country: "US"),
        StateProvince("WA", "Washington", country: "US"),
        StateProvince("WV", "West Virginia", country: "US"),
        StateProvince("WI", "Wisconsin", country: "US"),
        StateProvince("WY", "Wyoming", country: "US"),
    ]

    static let canadianProvinces: [StateProvince] = [
        StateProvince("AB", "Alberta", country: "CA"),
        StateProvince("BC", "British Columbia", country: "CA"),
        StateProvince("MB", "Manitoba", country: "CA"),
        StateProvince("NB", "New Brunswick", country: "CA"),
        StateProvince("NL", "Newfoundland and Labrador", country: "CA"),
        StateProvince("NS", "Nova Scotia", country: "CA"),
        StateProvince("NT", "Northwest Territories", country: "CA"),
        StateProvince("NU", "Nunavut", country: "CA"),
        StateProvince("ON", "Ontario", country: "CA"),
        StateProvince("PE", "Prince Edward Island", country: "CA"),
        StateProvince("QC", "Quebec", country: "CA"),
        StateProvince("SK", "Saskatchewan", country: "CA"),
        StateProvince("YT", "Yukon", country: "CA"),
    ]

    static func states(for countryCode: String) -> [StateProvince] {
        switch countryCode {
        case "US": return usStates
        case "CA": return canadianProvinces
        default: return []
        }
    }
}
