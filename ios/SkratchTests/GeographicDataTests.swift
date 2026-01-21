import XCTest

@testable import Skratch

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

    func testOtherCountriesDontHaveStates() {
        let countriesWithStates = GeographicData.countries.filter { $0.hasStates }
        XCTAssertEqual(countriesWithStates.count, 2, "Only US and Canada should have states/provinces")
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
        XCTAssertEqual(GeographicData.usStates.count, 51, "Should have 50 states + DC")
    }

    func testCanadianProvincesCount() {
        XCTAssertEqual(GeographicData.canadianProvinces.count, 13, "Should have 13 provinces/territories")
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

    func testStatesForCountry() {
        XCTAssertEqual(GeographicData.states(for: "US").count, 51)
        XCTAssertEqual(GeographicData.states(for: "CA").count, 13)
        XCTAssertTrue(GeographicData.states(for: "GB").isEmpty, "UK should have no states in our data")
        XCTAssertTrue(GeographicData.states(for: "XX").isEmpty, "Invalid country should return empty")
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
