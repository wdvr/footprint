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
        Country("BE", "Belgium", continent: "Europe", hasStates: true),
        Country("BA", "Bosnia and Herzegovina", continent: "Europe"),
        Country("BG", "Bulgaria", continent: "Europe"),
        Country("HR", "Croatia", continent: "Europe"),
        Country("CZ", "Czech Republic", continent: "Europe"),
        Country("DK", "Denmark", continent: "Europe"),
        Country("EE", "Estonia", continent: "Europe"),
        Country("FI", "Finland", continent: "Europe"),
        Country("FR", "France", continent: "Europe", hasStates: true),
        Country("DE", "Germany", continent: "Europe", hasStates: true),
        Country("GR", "Greece", continent: "Europe"),
        Country("HU", "Hungary", continent: "Europe"),
        Country("IS", "Iceland", continent: "Europe"),
        Country("IE", "Ireland", continent: "Europe"),
        Country("IT", "Italy", continent: "Europe", hasStates: true),
        Country("LV", "Latvia", continent: "Europe"),
        Country("LI", "Liechtenstein", continent: "Europe"),
        Country("LT", "Lithuania", continent: "Europe"),
        Country("LU", "Luxembourg", continent: "Europe"),
        Country("MT", "Malta", continent: "Europe"),
        Country("MD", "Moldova", continent: "Europe"),
        Country("MC", "Monaco", continent: "Europe"),
        Country("ME", "Montenegro", continent: "Europe"),
        Country("NL", "Netherlands", continent: "Europe", hasStates: true),
        Country("MK", "North Macedonia", continent: "Europe"),
        Country("NO", "Norway", continent: "Europe"),
        Country("PL", "Poland", continent: "Europe"),
        Country("PT", "Portugal", continent: "Europe"),
        Country("RO", "Romania", continent: "Europe"),
        Country("RU", "Russia", continent: "Europe", hasStates: true),
        Country("SM", "San Marino", continent: "Europe"),
        Country("RS", "Serbia", continent: "Europe"),
        Country("SK", "Slovakia", continent: "Europe"),
        Country("SI", "Slovenia", continent: "Europe"),
        Country("ES", "Spain", continent: "Europe", hasStates: true),
        Country("SE", "Sweden", continent: "Europe"),
        Country("CH", "Switzerland", continent: "Europe"),
        Country("UA", "Ukraine", continent: "Europe"),
        Country("GB", "United Kingdom", continent: "Europe", hasStates: true),
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
        Country("MX", "Mexico", continent: "North America", hasStates: true),
        Country("NI", "Nicaragua", continent: "North America"),
        Country("PA", "Panama", continent: "North America"),
        Country("KN", "Saint Kitts and Nevis", continent: "North America"),
        Country("LC", "Saint Lucia", continent: "North America"),
        Country("VC", "Saint Vincent and the Grenadines", continent: "North America"),
        Country("TT", "Trinidad and Tobago", continent: "North America"),
        Country("US", "United States", continent: "North America", hasStates: true),
        // Oceania
        Country("AU", "Australia", continent: "Oceania", hasStates: true),
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
        Country("AR", "Argentina", continent: "South America", hasStates: true),
        Country("BO", "Bolivia", continent: "South America"),
        Country("BR", "Brazil", continent: "South America", hasStates: true),
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

    // Australian States and Territories (8 total)
    static let australianStates: [StateProvince] = [
        StateProvince("ACT", "Australian Capital Territory", country: "AU"),
        StateProvince("NSW", "New South Wales", country: "AU"),
        StateProvince("NT", "Northern Territory", country: "AU"),
        StateProvince("QLD", "Queensland", country: "AU"),
        StateProvince("SA", "South Australia", country: "AU"),
        StateProvince("TAS", "Tasmania", country: "AU"),
        StateProvince("VIC", "Victoria", country: "AU"),
        StateProvince("WA", "Western Australia", country: "AU"),
    ]

    // Mexican States (32 total: 31 states + 1 federal district)
    static let mexicanStates: [StateProvince] = [
        StateProvince("AGU", "Aguascalientes", country: "MX"),
        StateProvince("BCN", "Baja California", country: "MX"),
        StateProvince("BCS", "Baja California Sur", country: "MX"),
        StateProvince("CAM", "Campeche", country: "MX"),
        StateProvince("CHP", "Chiapas", country: "MX"),
        StateProvince("CHH", "Chihuahua", country: "MX"),
        StateProvince("CMX", "Ciudad de Mexico", country: "MX"),
        StateProvince("COA", "Coahuila", country: "MX"),
        StateProvince("COL", "Colima", country: "MX"),
        StateProvince("DUR", "Durango", country: "MX"),
        StateProvince("GUA", "Guanajuato", country: "MX"),
        StateProvince("GRO", "Guerrero", country: "MX"),
        StateProvince("HID", "Hidalgo", country: "MX"),
        StateProvince("JAL", "Jalisco", country: "MX"),
        StateProvince("MEX", "Mexico", country: "MX"),
        StateProvince("MIC", "Michoacan", country: "MX"),
        StateProvince("MOR", "Morelos", country: "MX"),
        StateProvince("NAY", "Nayarit", country: "MX"),
        StateProvince("NLE", "Nuevo Leon", country: "MX"),
        StateProvince("OAX", "Oaxaca", country: "MX"),
        StateProvince("PUE", "Puebla", country: "MX"),
        StateProvince("QUE", "Queretaro", country: "MX"),
        StateProvince("ROO", "Quintana Roo", country: "MX"),
        StateProvince("SLP", "San Luis Potosi", country: "MX"),
        StateProvince("SIN", "Sinaloa", country: "MX"),
        StateProvince("SON", "Sonora", country: "MX"),
        StateProvince("TAB", "Tabasco", country: "MX"),
        StateProvince("TAM", "Tamaulipas", country: "MX"),
        StateProvince("TLA", "Tlaxcala", country: "MX"),
        StateProvince("VER", "Veracruz", country: "MX"),
        StateProvince("YUC", "Yucatan", country: "MX"),
        StateProvince("ZAC", "Zacatecas", country: "MX"),
    ]

    // Brazilian States (27 total: 26 states + 1 federal district)
    static let brazilianStates: [StateProvince] = [
        StateProvince("AC", "Acre", country: "BR"),
        StateProvince("AL", "Alagoas", country: "BR"),
        StateProvince("AP", "Amapa", country: "BR"),
        StateProvince("AM", "Amazonas", country: "BR"),
        StateProvince("BA", "Bahia", country: "BR"),
        StateProvince("CE", "Ceara", country: "BR"),
        StateProvince("DF", "Distrito Federal", country: "BR"),
        StateProvince("ES", "Espirito Santo", country: "BR"),
        StateProvince("GO", "Goias", country: "BR"),
        StateProvince("MA", "Maranhao", country: "BR"),
        StateProvince("MT", "Mato Grosso", country: "BR"),
        StateProvince("MS", "Mato Grosso do Sul", country: "BR"),
        StateProvince("MG", "Minas Gerais", country: "BR"),
        StateProvince("PA", "Para", country: "BR"),
        StateProvince("PB", "Paraiba", country: "BR"),
        StateProvince("PR", "Parana", country: "BR"),
        StateProvince("PE", "Pernambuco", country: "BR"),
        StateProvince("PI", "Piaui", country: "BR"),
        StateProvince("RJ", "Rio de Janeiro", country: "BR"),
        StateProvince("RN", "Rio Grande do Norte", country: "BR"),
        StateProvince("RS", "Rio Grande do Sul", country: "BR"),
        StateProvince("RO", "Rondonia", country: "BR"),
        StateProvince("RR", "Roraima", country: "BR"),
        StateProvince("SC", "Santa Catarina", country: "BR"),
        StateProvince("SP", "Sao Paulo", country: "BR"),
        StateProvince("SE", "Sergipe", country: "BR"),
        StateProvince("TO", "Tocantins", country: "BR"),
    ]

    // German States - Lander (16 total)
    static let germanStates: [StateProvince] = [
        StateProvince("BW", "Baden-Wurttemberg", country: "DE"),
        StateProvince("BY", "Bavaria", country: "DE"),
        StateProvince("BE", "Berlin", country: "DE"),
        StateProvince("BB", "Brandenburg", country: "DE"),
        StateProvince("HB", "Bremen", country: "DE"),
        StateProvince("HH", "Hamburg", country: "DE"),
        StateProvince("HE", "Hesse", country: "DE"),
        StateProvince("MV", "Mecklenburg-Vorpommern", country: "DE"),
        StateProvince("NI", "Lower Saxony", country: "DE"),
        StateProvince("NW", "North Rhine-Westphalia", country: "DE"),
        StateProvince("RP", "Rhineland-Palatinate", country: "DE"),
        StateProvince("SL", "Saarland", country: "DE"),
        StateProvince("SN", "Saxony", country: "DE"),
        StateProvince("ST", "Saxony-Anhalt", country: "DE"),
        StateProvince("SH", "Schleswig-Holstein", country: "DE"),
        StateProvince("TH", "Thuringia", country: "DE"),
    ]

    // French Regions (18 total: 13 metropolitan + 5 overseas)
    static let frenchRegions: [StateProvince] = [
        // Metropolitan France
        StateProvince("ARA", "Auvergne-Rhone-Alpes", country: "FR"),
        StateProvince("BFC", "Bourgogne-Franche-Comte", country: "FR"),
        StateProvince("BRE", "Brittany", country: "FR"),
        StateProvince("CVL", "Centre-Val de Loire", country: "FR"),
        StateProvince("COR", "Corsica", country: "FR"),
        StateProvince("GES", "Grand Est", country: "FR"),
        StateProvince("HDF", "Hauts-de-France", country: "FR"),
        StateProvince("IDF", "Ile-de-France", country: "FR"),
        StateProvince("NOR", "Normandy", country: "FR"),
        StateProvince("NAQ", "Nouvelle-Aquitaine", country: "FR"),
        StateProvince("OCC", "Occitanie", country: "FR"),
        StateProvince("PDL", "Pays de la Loire", country: "FR"),
        StateProvince("PAC", "Provence-Alpes-Cote d'Azur", country: "FR"),
        // Overseas regions
        StateProvince("GF", "French Guiana", country: "FR"),
        StateProvince("GP", "Guadeloupe", country: "FR"),
        StateProvince("MQ", "Martinique", country: "FR"),
        StateProvince("YT", "Mayotte", country: "FR"),
        StateProvince("RE", "Reunion", country: "FR"),
    ]

    // Spanish Autonomous Communities (19 total: 17 communities + 2 autonomous cities)
    static let spanishCommunities: [StateProvince] = [
        StateProvince("AN", "Andalusia", country: "ES"),
        StateProvince("AR", "Aragon", country: "ES"),
        StateProvince("AS", "Asturias", country: "ES"),
        StateProvince("IB", "Balearic Islands", country: "ES"),
        StateProvince("PV", "Basque Country", country: "ES"),
        StateProvince("CN", "Canary Islands", country: "ES"),
        StateProvince("CB", "Cantabria", country: "ES"),
        StateProvince("CL", "Castile and Leon", country: "ES"),
        StateProvince("CM", "Castilla-La Mancha", country: "ES"),
        StateProvince("CT", "Catalonia", country: "ES"),
        StateProvince("CE", "Ceuta", country: "ES"),
        StateProvince("EX", "Extremadura", country: "ES"),
        StateProvince("GA", "Galicia", country: "ES"),
        StateProvince("RI", "La Rioja", country: "ES"),
        StateProvince("MD", "Madrid", country: "ES"),
        StateProvince("ML", "Melilla", country: "ES"),
        StateProvince("MC", "Murcia", country: "ES"),
        StateProvince("NC", "Navarre", country: "ES"),
        StateProvince("VC", "Valencia", country: "ES"),
    ]

    // Italian Regions (20 total)
    static let italianRegions: [StateProvince] = [
        StateProvince("65", "Abruzzo", country: "IT"),
        StateProvince("77", "Basilicata", country: "IT"),
        StateProvince("78", "Calabria", country: "IT"),
        StateProvince("72", "Campania", country: "IT"),
        StateProvince("45", "Emilia-Romagna", country: "IT"),
        StateProvince("36", "Friuli Venezia Giulia", country: "IT"),
        StateProvince("62", "Lazio", country: "IT"),
        StateProvince("42", "Liguria", country: "IT"),
        StateProvince("25", "Lombardy", country: "IT"),
        StateProvince("57", "Marche", country: "IT"),
        StateProvince("67", "Molise", country: "IT"),
        StateProvince("21", "Piedmont", country: "IT"),
        StateProvince("75", "Apulia", country: "IT"),
        StateProvince("88", "Sardinia", country: "IT"),
        StateProvince("82", "Sicily", country: "IT"),
        StateProvince("52", "Tuscany", country: "IT"),
        StateProvince("32", "Trentino-Alto Adige", country: "IT"),
        StateProvince("55", "Umbria", country: "IT"),
        StateProvince("23", "Aosta Valley", country: "IT"),
        StateProvince("34", "Veneto", country: "IT"),
    ]

    // Dutch Provinces (12 total)
    static let dutchProvinces: [StateProvince] = [
        StateProvince("DR", "Drenthe", country: "NL"),
        StateProvince("FL", "Flevoland", country: "NL"),
        StateProvince("FR", "Friesland", country: "NL"),
        StateProvince("GE", "Gelderland", country: "NL"),
        StateProvince("GR", "Groningen", country: "NL"),
        StateProvince("LI", "Limburg", country: "NL"),
        StateProvince("NB", "North Brabant", country: "NL"),
        StateProvince("NH", "North Holland", country: "NL"),
        StateProvince("OV", "Overijssel", country: "NL"),
        StateProvince("UT", "Utrecht", country: "NL"),
        StateProvince("ZE", "Zeeland", country: "NL"),
        StateProvince("ZH", "South Holland", country: "NL"),
    ]

    // Belgian Provinces (10 provinces + Brussels Capital Region = 11 total)
    static let belgianProvinces: [StateProvince] = [
        StateProvince("VAN", "Antwerp", country: "BE"),
        StateProvince("BRU", "Brussels Capital Region", country: "BE"),
        StateProvince("VOV", "East Flanders", country: "BE"),
        StateProvince("VBR", "Flemish Brabant", country: "BE"),
        StateProvince("WHT", "Hainaut", country: "BE"),
        StateProvince("WLG", "Liege", country: "BE"),
        StateProvince("VLI", "Limburg", country: "BE"),
        StateProvince("WLX", "Luxembourg", country: "BE"),
        StateProvince("WNA", "Namur", country: "BE"),
        StateProvince("WBR", "Walloon Brabant", country: "BE"),
        StateProvince("VWV", "West Flanders", country: "BE"),
    ]

    // UK Countries (4 total)
    static let ukCountries: [StateProvince] = [
        StateProvince("ENG", "England", country: "GB"),
        StateProvince("NIR", "Northern Ireland", country: "GB"),
        StateProvince("SCT", "Scotland", country: "GB"),
        StateProvince("WLS", "Wales", country: "GB"),
    ]

    // Russian Federal Subjects (selected major regions - 85 total but listing key ones)
    static let russianFederalSubjects: [StateProvince] = [
        // Republics
        StateProvince("AD", "Adygea", country: "RU"),
        StateProvince("AL", "Altai Republic", country: "RU"),
        StateProvince("BA", "Bashkortostan", country: "RU"),
        StateProvince("BU", "Buryatia", country: "RU"),
        StateProvince("CE", "Chechnya", country: "RU"),
        StateProvince("CU", "Chuvashia", country: "RU"),
        StateProvince("DA", "Dagestan", country: "RU"),
        StateProvince("IN", "Ingushetia", country: "RU"),
        StateProvince("KB", "Kabardino-Balkaria", country: "RU"),
        StateProvince("KL", "Kalmykia", country: "RU"),
        StateProvince("KC", "Karachay-Cherkessia", country: "RU"),
        StateProvince("KR", "Karelia", country: "RU"),
        StateProvince("KK", "Khakassia", country: "RU"),
        StateProvince("KO", "Komi", country: "RU"),
        StateProvince("ME", "Mari El", country: "RU"),
        StateProvince("MO", "Mordovia", country: "RU"),
        StateProvince("SE", "North Ossetia-Alania", country: "RU"),
        StateProvince("SA", "Sakha (Yakutia)", country: "RU"),
        StateProvince("TA", "Tatarstan", country: "RU"),
        StateProvince("TY", "Tuva", country: "RU"),
        StateProvince("UD", "Udmurtia", country: "RU"),
        // Federal cities
        StateProvince("MOW", "Moscow", country: "RU"),
        StateProvince("SPE", "Saint Petersburg", country: "RU"),
        StateProvince("SEV", "Sevastopol", country: "RU"),
        // Krais (Administrative Territories)
        StateProvince("ALT", "Altai Krai", country: "RU"),
        StateProvince("KAM", "Kamchatka Krai", country: "RU"),
        StateProvince("KHA", "Khabarovsk Krai", country: "RU"),
        StateProvince("KDA", "Krasnodar Krai", country: "RU"),
        StateProvince("KYA", "Krasnoyarsk Krai", country: "RU"),
        StateProvince("PER", "Perm Krai", country: "RU"),
        StateProvince("PRI", "Primorsky Krai", country: "RU"),
        StateProvince("STA", "Stavropol Krai", country: "RU"),
        StateProvince("ZAB", "Zabaykalsky Krai", country: "RU"),
        // Oblasts (Administrative Regions)
        StateProvince("AMU", "Amur Oblast", country: "RU"),
        StateProvince("ARK", "Arkhangelsk Oblast", country: "RU"),
        StateProvince("AST", "Astrakhan Oblast", country: "RU"),
        StateProvince("BEL", "Belgorod Oblast", country: "RU"),
        StateProvince("BRY", "Bryansk Oblast", country: "RU"),
        StateProvince("CHE", "Chelyabinsk Oblast", country: "RU"),
        StateProvince("IRK", "Irkutsk Oblast", country: "RU"),
        StateProvince("IVA", "Ivanovo Oblast", country: "RU"),
        StateProvince("KGD", "Kaliningrad Oblast", country: "RU"),
        StateProvince("KLU", "Kaluga Oblast", country: "RU"),
        StateProvince("KEM", "Kemerovo Oblast", country: "RU"),
        StateProvince("KIR", "Kirov Oblast", country: "RU"),
        StateProvince("KOS", "Kostroma Oblast", country: "RU"),
        StateProvince("KGN", "Kurgan Oblast", country: "RU"),
        StateProvince("KRS", "Kursk Oblast", country: "RU"),
        StateProvince("LEN", "Leningrad Oblast", country: "RU"),
        StateProvince("LIP", "Lipetsk Oblast", country: "RU"),
        StateProvince("MAG", "Magadan Oblast", country: "RU"),
        StateProvince("MOS", "Moscow Oblast", country: "RU"),
        StateProvince("MUR", "Murmansk Oblast", country: "RU"),
        StateProvince("NIZ", "Nizhny Novgorod Oblast", country: "RU"),
        StateProvince("NGR", "Novgorod Oblast", country: "RU"),
        StateProvince("NVS", "Novosibirsk Oblast", country: "RU"),
        StateProvince("OMS", "Omsk Oblast", country: "RU"),
        StateProvince("ORE", "Orenburg Oblast", country: "RU"),
        StateProvince("ORL", "Oryol Oblast", country: "RU"),
        StateProvince("PNZ", "Penza Oblast", country: "RU"),
        StateProvince("PSK", "Pskov Oblast", country: "RU"),
        StateProvince("ROS", "Rostov Oblast", country: "RU"),
        StateProvince("RYA", "Ryazan Oblast", country: "RU"),
        StateProvince("SAK", "Sakhalin Oblast", country: "RU"),
        StateProvince("SAM", "Samara Oblast", country: "RU"),
        StateProvince("SAR", "Saratov Oblast", country: "RU"),
        StateProvince("SMO", "Smolensk Oblast", country: "RU"),
        StateProvince("SVE", "Sverdlovsk Oblast", country: "RU"),
        StateProvince("TAM", "Tambov Oblast", country: "RU"),
        StateProvince("TOM", "Tomsk Oblast", country: "RU"),
        StateProvince("TUL", "Tula Oblast", country: "RU"),
        StateProvince("TVE", "Tver Oblast", country: "RU"),
        StateProvince("TYU", "Tyumen Oblast", country: "RU"),
        StateProvince("ULY", "Ulyanovsk Oblast", country: "RU"),
        StateProvince("VLA", "Vladimir Oblast", country: "RU"),
        StateProvince("VGG", "Volgograd Oblast", country: "RU"),
        StateProvince("VLG", "Vologda Oblast", country: "RU"),
        StateProvince("VOR", "Voronezh Oblast", country: "RU"),
        StateProvince("YAR", "Yaroslavl Oblast", country: "RU"),
        // Autonomous Okrugs
        StateProvince("CHU", "Chukotka Autonomous Okrug", country: "RU"),
        StateProvince("KHM", "Khanty-Mansi Autonomous Okrug", country: "RU"),
        StateProvince("NEN", "Nenets Autonomous Okrug", country: "RU"),
        StateProvince("YAN", "Yamalo-Nenets Autonomous Okrug", country: "RU"),
        // Autonomous Oblast
        StateProvince("YEV", "Jewish Autonomous Oblast", country: "RU"),
    ]

    // Argentine Provinces (24 total: 23 provinces + 1 autonomous city)
    static let argentineProvinces: [StateProvince] = [
        StateProvince("C", "Buenos Aires City", country: "AR"),
        StateProvince("B", "Buenos Aires Province", country: "AR"),
        StateProvince("K", "Catamarca", country: "AR"),
        StateProvince("H", "Chaco", country: "AR"),
        StateProvince("U", "Chubut", country: "AR"),
        StateProvince("X", "Cordoba", country: "AR"),
        StateProvince("W", "Corrientes", country: "AR"),
        StateProvince("E", "Entre Rios", country: "AR"),
        StateProvince("P", "Formosa", country: "AR"),
        StateProvince("Y", "Jujuy", country: "AR"),
        StateProvince("L", "La Pampa", country: "AR"),
        StateProvince("F", "La Rioja", country: "AR"),
        StateProvince("M", "Mendoza", country: "AR"),
        StateProvince("N", "Misiones", country: "AR"),
        StateProvince("Q", "Neuquen", country: "AR"),
        StateProvince("R", "Rio Negro", country: "AR"),
        StateProvince("A", "Salta", country: "AR"),
        StateProvince("J", "San Juan", country: "AR"),
        StateProvince("D", "San Luis", country: "AR"),
        StateProvince("Z", "Santa Cruz", country: "AR"),
        StateProvince("S", "Santa Fe", country: "AR"),
        StateProvince("G", "Santiago del Estero", country: "AR"),
        StateProvince("V", "Tierra del Fuego", country: "AR"),
        StateProvince("T", "Tucuman", country: "AR"),
    ]

    static func states(for countryCode: String) -> [StateProvince] {
        switch countryCode {
        case "US": return usStates
        case "CA": return canadianProvinces
        case "AU": return australianStates
        case "MX": return mexicanStates
        case "BR": return brazilianStates
        case "DE": return germanStates
        case "FR": return frenchRegions
        case "ES": return spanishCommunities
        case "IT": return italianRegions
        case "NL": return dutchProvinces
        case "BE": return belgianProvinces
        case "GB": return ukCountries
        case "RU": return russianFederalSubjects
        case "AR": return argentineProvinces
        default: return []
        }
    }

    /// Get the appropriate RegionType for a country's subdivisions
    static func regionType(for countryCode: String) -> VisitedPlace.RegionType? {
        switch countryCode {
        case "US": return .usState
        case "CA": return .canadianProvince
        case "AU": return .australianState
        case "MX": return .mexicanState
        case "BR": return .brazilianState
        case "DE": return .germanState
        case "FR": return .frenchRegion
        case "ES": return .spanishCommunity
        case "IT": return .italianRegion
        case "NL": return .dutchProvince
        case "BE": return .belgianProvince
        case "GB": return .ukCountry
        case "RU": return .russianFederalSubject
        case "AR": return .argentineProvince
        default: return nil
        }
    }
}
