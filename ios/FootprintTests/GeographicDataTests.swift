import XCTest

@testable import Footprint

final class GeographicDataTests: XCTestCase {

    // MARK: - Country Data Tests

    func testCountriesAreNotEmpty() {
        XCTAssertFalse(GeographicData.countries.isEmpty, "Should have countries defined")
        XCTAssertGreaterThan(GeographicData.countries.count, 190, "Should have most world countries")
    }

    func testAllCountriesHaveValidData() {
        for country in GeographicData.countries {
            XCTAssertFalse(country.id.isEmpty, "Country \(country.name) should have ISO code")
            XCTAssertEqual(country.id.count, 2, "ISO code should be 2 characters for \(country.name)")
            XCTAssertFalse(country.name.isEmpty, "Country \(country.id) should have name")
            XCTAssertFalse(country.continent.isEmpty, "Country \(country.name) should have continent")
        }
    }

    func testCountryISOCodesAreUnique() {
        let codes = GeographicData.countries.map { $0.id }
        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "All ISO codes should be unique")
    }

    func testUSAndCanadaHaveStates() {
        let us = GeographicData.countries.first { $0.id == "US" }
        let canada = GeographicData.countries.first { $0.id == "CA" }

        XCTAssertNotNil(us)
        XCTAssertNotNil(canada)
        XCTAssertTrue(us?.hasStates ?? false, "US should have states")
        XCTAssertTrue(canada?.hasStates ?? false, "Canada should have provinces")
    }

    func testCountriesWithStates() {
        let countriesWithStates = Set(GeographicData.countries.filter { $0.hasStates }.map { $0.id })
        let countriesWithStateLists = Set(GeographicData.countries.map { $0.id }.filter {
            !GeographicData.states(for: $0).isEmpty
        })
        XCTAssertEqual(countriesWithStates, countriesWithStateLists, "hasStates should match countries with a subdivision list")

        let expectedCountries = ["US", "CA", "AU", "MX", "BR", "DE", "FR", "ES", "IT", "NL", "BE", "GB", "RU", "AR", "JP", "KR", "NO"]
        for code in expectedCountries {
            XCTAssertTrue(countriesWithStates.contains(code), "Country \(code) should have states/provinces")
        }
    }

    // MARK: - Continent Tests

    func testAllContinentsExist() {
        let continents = Set(GeographicData.countries.map { $0.continent })

        XCTAssertTrue(continents.contains("Africa"))
        XCTAssertTrue(continents.contains("Asia"))
        XCTAssertTrue(continents.contains("Europe"))
        XCTAssertTrue(continents.contains("North America"))
        XCTAssertTrue(continents.contains("South America"))
        XCTAssertTrue(continents.contains("Oceania"))
    }

    func testContinentEnumMatchesCountryData() {
        let countryContinent = Set(GeographicData.countries.map { $0.continent })
        let enumContinents = Set(Continent.allCases.map { $0.rawValue })

        // All continents used in country data should be in the enum
        for continent in countryContinent {
            XCTAssertTrue(
                enumContinents.contains(continent),
                "Continent '\(continent)' should be in Continent enum"
            )
        }
    }

    func testCountriesByContinentGrouping() {
        let grouped = GeographicData.countriesByContinent

        // Should have 6 continents (no Antarctica in country list)
        XCTAssertEqual(grouped.count, 6, "Should have 6 populated continents")

        // Each continent should have countries
        for (continent, countries) in grouped {
            XCTAssertFalse(countries.isEmpty, "\(continent.rawValue) should have countries")

            // Countries should be sorted alphabetically
            let names = countries.map { $0.name }
            let sortedNames = names.sorted()
            XCTAssertEqual(names, sortedNames, "\(continent.rawValue) countries should be sorted")

            // All countries should have the correct continent
            for country in countries {
                XCTAssertEqual(
                    country.continent, continent.rawValue,
                    "\(country.name) should be in \(continent.rawValue)"
                )
            }
        }
    }

    func testContinentCountsAreReasonable() {
        let grouped = GeographicData.countriesByContinent

        for (continent, countries) in grouped {
            switch continent {
            case .africa:
                XCTAssertGreaterThan(countries.count, 50, "Africa should have 50+ countries")
            case .asia:
                XCTAssertGreaterThan(countries.count, 40, "Asia should have 40+ countries")
            case .europe:
                XCTAssertGreaterThan(countries.count, 40, "Europe should have 40+ countries")
            case .northAmerica:
                XCTAssertGreaterThan(countries.count, 20, "North America should have 20+ countries")
            case .southAmerica:
                XCTAssertGreaterThan(countries.count, 10, "South America should have 10+ countries")
            case .oceania:
                XCTAssertGreaterThan(countries.count, 10, "Oceania should have 10+ countries")
            case .antarctica:
                break // No permanent population
            }
        }
    }

    // MARK: - State/Province Tests

    func testUSStatesCount() {
        XCTAssertEqual(GeographicData.usStates.count, boundaryCodes(for: "US").count, "US states should match us_states.geojson")
    }

    func testCanadianProvincesCount() {
        XCTAssertEqual(
            GeographicData.canadianProvinces.count, boundaryCodes(for: "CA").count,
            "Canadian provinces should match canadian_provinces.geojson"
        )
    }

    func testStatesHaveValidData() {
        for state in GeographicData.usStates {
            XCTAssertFalse(state.id.isEmpty, "State should have code")
            XCTAssertFalse(state.name.isEmpty, "State should have name")
            XCTAssertEqual(state.countryCode, "US")
        }

        for province in GeographicData.canadianProvinces {
            XCTAssertFalse(province.id.isEmpty, "Province should have code")
            XCTAssertFalse(province.name.isEmpty, "Province should have name")
            XCTAssertEqual(province.countryCode, "CA")
        }
    }

    /// Expected counts come from the bundled data files: the country's boundary file when it has
    /// one, otherwise world_states.json.
    func testStatesForCountry() throws {
        for country in GeographicData.countries where country.hasStates {
            let stateCount = GeographicData.states(for: country.id).count
            let boundary = boundaryCodes(for: country.id)

            if countriesPendingBoundaryDecision.contains(country.id) {
                XCTAssertGreaterThan(stateCount, 0, "\(country.id) should have subdivisions")
            } else if boundary.isEmpty {
                let expected = try worldStatesCount(for: country.id)
                XCTAssertEqual(stateCount, expected, "\(country.id) count should match world_states.json")
            } else {
                let exempt = codesWithoutGeometry[country.id]?.count ?? 0
                XCTAssertEqual(stateCount, boundary.count + exempt, "\(country.id) count should match its boundary file")
            }
        }
        XCTAssertTrue(GeographicData.states(for: "XX").isEmpty, "Invalid country should return empty")
    }

    /// Unique subdivision codes in a country's bundled boundary file (empty when it has none).
    private func boundaryCodes(for countryCode: String) -> Set<String> {
        Set(GeoJSONParser.parseStates(forCountry: countryCode).map { String($0.id.split(separator: "-").last ?? "") })
    }

    private func worldStatesCount(for countryCode: String) throws -> Int {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "world_states", withExtension: "json", subdirectory: "GeoData")
                ?? Bundle.main.url(forResource: "world_states", withExtension: "json"),
            "world_states.json should be bundled"
        )
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: [Any]]
        return try XCTUnwrap(json?[countryCode], "\(countryCode) missing from world_states.json").count
    }

    // MARK: - Boundary Data Tests

    /// Countries whose subdivision list and boundary file are known not to match, pending an
    /// owner decision: ES_states.geojson has 52 provinces but GeographicData has 19 communities.
    private let countriesPendingBoundaryDecision: Set<String> = ["ES"]

    /// Subdivisions intentionally listed without boundary geometry (manual entry only, pending decision).
    private let codesWithoutGeometry: [String: Set<String>] = ["RU": ["SEV"]]

    func testSubdivisionCodesMatchBoundaryFiles() {
        var countriesChecked = 0
        for country in GeographicData.countries where country.hasStates {
            let boundaries = GeoJSONParser.parseStates(forCountry: country.id)
            guard !boundaries.isEmpty, !countriesPendingBoundaryDecision.contains(country.id) else { continue }
            countriesChecked += 1

            let boundaryCodes = boundaries.map { String($0.id.split(separator: "-").last ?? "") }
            let stateCodes = Set(GeographicData.states(for: country.id).map { $0.id })
            let exempt = codesWithoutGeometry[country.id] ?? []

            XCTAssertEqual(boundaryCodes.count, Set(boundaryCodes).count, "\(country.id) boundary file has duplicate codes")
            XCTAssertEqual(
                stateCodes.subtracting(exempt).subtracting(boundaryCodes), [],
                "\(country.id) subdivisions without boundary geometry"
            )
            XCTAssertEqual(
                Set(boundaryCodes).subtracting(stateCodes), [],
                "\(country.id) boundary features without a GeographicData subdivision"
            )
        }
        XCTAssertGreaterThanOrEqual(countriesChecked, 12, "Boundary files should load for every mapped country")
    }

    // MARK: - Continent Emoji Tests

    func testContinentEmojis() {
        for continent in Continent.allCases {
            XCTAssertFalse(continent.emoji.isEmpty, "\(continent) should have emoji")
        }
    }

    // MARK: - Specific Country Tests

    func testSpecificCountriesExist() {
        let expectedCountries = ["US", "CA", "GB", "FR", "DE", "JP", "AU", "BR", "IN", "CN"]

        for code in expectedCountries {
            let country = GeographicData.countries.first { $0.id == code }
            XCTAssertNotNil(country, "Country \(code) should exist")
        }
    }

    func testCountriesInCorrectContinent() {
        // Spot check some countries are in the right continent
        let expectations: [(code: String, continent: String)] = [
            ("US", "North America"),
            ("CA", "North America"),
            ("MX", "North America"),
            ("GB", "Europe"),
            ("FR", "Europe"),
            ("DE", "Europe"),
            ("JP", "Asia"),
            ("CN", "Asia"),
            ("AU", "Oceania"),
            ("BR", "South America"),
            ("ZA", "Africa"),
            ("EG", "Africa"),
        ]

        for (code, expectedContinent) in expectations {
            let country = GeographicData.countries.first { $0.id == code }
            XCTAssertNotNil(country, "Country \(code) should exist")
            XCTAssertEqual(
                country?.continent, expectedContinent,
                "\(code) should be in \(expectedContinent)"
            )
        }
    }
}
