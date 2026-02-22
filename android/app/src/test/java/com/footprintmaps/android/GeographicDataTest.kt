package com.footprintmaps.android

import com.footprintmaps.android.domain.model.Continent
import com.footprintmaps.android.domain.model.GeographicData
import com.footprintmaps.android.domain.model.RegionType
import org.junit.Assert.*
import org.junit.Test

class GeographicDataTest {

    // ==================== COUNTRIES ====================

    @Test
    fun `countries list is not empty`() {
        assertTrue(GeographicData.countries.isNotEmpty())
    }

    @Test
    fun `has at least 195 countries`() {
        assertTrue(
            "Expected at least 195 countries, got ${GeographicData.countries.size}",
            GeographicData.countries.size >= 195
        )
    }

    @Test
    fun `country codes are unique`() {
        val codes = GeographicData.countries.map { it.code }
        assertEquals("Duplicate country codes found", codes.size, codes.toSet().size)
    }

    @Test
    fun `all country codes are 2 letters uppercase`() {
        GeographicData.countries.forEach { country ->
            assertEquals(
                "Country ${country.name} should have 2-letter code, got '${country.code}'",
                2,
                country.code.length
            )
            assertTrue(
                "Country code ${country.code} should be uppercase",
                country.code == country.code.uppercase()
            )
        }
    }

    @Test
    fun `all country names are non-empty`() {
        GeographicData.countries.forEach { country ->
            assertTrue(
                "Country ${country.code} has empty name",
                country.name.isNotBlank()
            )
        }
    }

    @Test
    fun `can look up United States by code`() {
        val us = GeographicData.countryByCode("US")
        assertNotNull(us)
        assertEquals("United States", us?.name)
        assertEquals(Continent.NORTH_AMERICA, us?.continent)
        assertTrue("US should have states", us?.hasStates == true)
    }

    @Test
    fun `can look up France by code`() {
        val fr = GeographicData.countryByCode("FR")
        assertNotNull(fr)
        assertEquals("France", fr?.name)
        assertEquals(Continent.EUROPE, fr?.continent)
        assertTrue("France should have states", fr?.hasStates == true)
    }

    @Test
    fun `can look up Japan by code`() {
        val jp = GeographicData.countryByCode("JP")
        assertNotNull(jp)
        assertEquals("Japan", jp?.name)
        assertEquals(Continent.ASIA, jp?.continent)
    }

    @Test
    fun `can look up Brazil by code`() {
        val br = GeographicData.countryByCode("BR")
        assertNotNull(br)
        assertEquals("Brazil", br?.name)
        assertEquals(Continent.SOUTH_AMERICA, br?.continent)
        assertTrue("Brazil should have states", br?.hasStates == true)
    }

    @Test
    fun `can look up Australia by code`() {
        val au = GeographicData.countryByCode("AU")
        assertNotNull(au)
        assertEquals("Australia", au?.name)
        assertEquals(Continent.OCEANIA, au?.continent)
        assertTrue("Australia should have states", au?.hasStates == true)
    }

    @Test
    fun `invalid country code returns null`() {
        assertNull(GeographicData.countryByCode("XX"))
        assertNull(GeographicData.countryByCode(""))
        assertNull(GeographicData.countryByCode("A"))
        assertNull(GeographicData.countryByCode("ABC"))
    }

    // ==================== CONTINENTS ====================

    @Test
    fun `countries by continent covers all continents except Antarctica`() {
        val continentsWithCountries = GeographicData.countriesByContinent
        assertTrue(continentsWithCountries.containsKey(Continent.EUROPE))
        assertTrue(continentsWithCountries.containsKey(Continent.ASIA))
        assertTrue(continentsWithCountries.containsKey(Continent.AFRICA))
        assertTrue(continentsWithCountries.containsKey(Continent.NORTH_AMERICA))
        assertTrue(continentsWithCountries.containsKey(Continent.SOUTH_AMERICA))
        assertTrue(continentsWithCountries.containsKey(Continent.OCEANIA))
    }

    @Test
    fun `all continents except Antarctica have countries`() {
        Continent.entries.filter { it != Continent.ANTARCTICA }.forEach { continent ->
            val countries = GeographicData.countriesByContinent[continent]
            assertNotNull("$continent should have countries", countries)
            assertTrue("$continent should have at least one country", countries!!.isNotEmpty())
        }
    }

    @Test
    fun `Africa has 54 countries`() {
        val african = GeographicData.countriesByContinent[Continent.AFRICA]
        assertNotNull(african)
        assertEquals("Expected 54 African countries", 54, african!!.size)
    }

    @Test
    fun `Asia has 49 countries`() {
        val asian = GeographicData.countriesByContinent[Continent.ASIA]
        assertNotNull(asian)
        assertEquals("Expected 49 Asian countries", 49, asian!!.size)
    }

    @Test
    fun `Europe has 44 countries`() {
        val european = GeographicData.countriesByContinent[Continent.EUROPE]
        assertNotNull(european)
        assertEquals("Expected 44 European countries", 44, european!!.size)
    }

    @Test
    fun `South America has 12 countries`() {
        val southAmerican = GeographicData.countriesByContinent[Continent.SOUTH_AMERICA]
        assertNotNull(southAmerican)
        assertEquals("Expected 12 South American countries", 12, southAmerican!!.size)
    }

    @Test
    fun `Oceania has 14 countries`() {
        val oceanian = GeographicData.countriesByContinent[Continent.OCEANIA]
        assertNotNull(oceanian)
        assertEquals("Expected 14 Oceanian countries", 14, oceanian!!.size)
    }

    @Test
    fun `all countries sum matches total`() {
        val total = GeographicData.countriesByContinent.values.sumOf { it.size }
        assertEquals(GeographicData.countries.size, total)
    }

    // ==================== US STATES ====================

    @Test
    fun `has 51 US states including DC`() {
        assertEquals(51, GeographicData.usStates.size)
    }

    @Test
    fun `us state codes are unique`() {
        val codes = GeographicData.usStates.map { it.code }
        assertEquals(codes.size, codes.toSet().size)
    }

    @Test
    fun `can look up California`() {
        val ca = GeographicData.usStateByCode("CA")
        assertNotNull(ca)
        assertEquals("California", ca?.name)
    }

    @Test
    fun `can look up District of Columbia`() {
        val dc = GeographicData.usStateByCode("DC")
        assertNotNull(dc)
        assertEquals("District of Columbia", dc?.name)
    }

    @Test
    fun `US states include all 50 states plus DC`() {
        val expectedStates = listOf(
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
            "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
            "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
            "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
            "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC"
        )
        val actualCodes = GeographicData.usStates.map { it.code }.toSet()
        expectedStates.forEach { code ->
            assertTrue("Missing US state code: $code", code in actualCodes)
        }
    }

    // ==================== CANADIAN PROVINCES ====================

    @Test
    fun `has 13 Canadian provinces and territories`() {
        assertEquals(13, GeographicData.canadianProvinces.size)
    }

    @Test
    fun `canadian province codes are unique`() {
        val codes = GeographicData.canadianProvinces.map { it.code }
        assertEquals(codes.size, codes.toSet().size)
    }

    @Test
    fun `can look up Ontario`() {
        val on = GeographicData.canadianProvinceByCode("ON")
        assertNotNull(on)
        assertEquals("Ontario", on?.name)
    }

    @Test
    fun `can look up British Columbia`() {
        val bc = GeographicData.canadianProvinceByCode("BC")
        assertNotNull(bc)
        assertEquals("British Columbia", bc?.name)
    }

    // ==================== STATES FOR ALL 14 COUNTRIES ====================

    @Test
    fun `statesFor US returns 51`() {
        val states = GeographicData.statesFor("US")
        assertEquals(51, states.size)
    }

    @Test
    fun `statesFor CA returns 13`() {
        val states = GeographicData.statesFor("CA")
        assertEquals(13, states.size)
    }

    @Test
    fun `statesFor AU returns 8`() {
        val states = GeographicData.statesFor("AU")
        assertEquals(8, states.size)
    }

    @Test
    fun `statesFor MX returns 32`() {
        val states = GeographicData.statesFor("MX")
        assertEquals(32, states.size)
    }

    @Test
    fun `statesFor BR returns 27`() {
        val states = GeographicData.statesFor("BR")
        assertEquals(27, states.size)
    }

    @Test
    fun `statesFor DE returns 16`() {
        val states = GeographicData.statesFor("DE")
        assertEquals(16, states.size)
    }

    @Test
    fun `statesFor FR returns regions`() {
        val states = GeographicData.statesFor("FR")
        assertTrue("France should have at least 13 regions, got ${states.size}", states.size >= 13)
    }

    @Test
    fun `statesFor ES returns communities`() {
        val states = GeographicData.statesFor("ES")
        assertTrue("Spain should have at least 17 communities, got ${states.size}", states.size >= 17)
    }

    @Test
    fun `statesFor IT returns regions`() {
        val states = GeographicData.statesFor("IT")
        assertTrue("Italy should have at least 20 regions, got ${states.size}", states.size >= 20)
    }

    @Test
    fun `statesFor NL returns provinces`() {
        val states = GeographicData.statesFor("NL")
        assertEquals(12, states.size)
    }

    @Test
    fun `statesFor BE returns provinces`() {
        val states = GeographicData.statesFor("BE")
        assertTrue("Belgium should have at least 10 provinces, got ${states.size}", states.size >= 10)
    }

    @Test
    fun `statesFor GB returns countries and regions`() {
        val states = GeographicData.statesFor("GB")
        assertTrue("UK should have at least 4 regions, got ${states.size}", states.size >= 4)
    }

    @Test
    fun `statesFor RU returns federal subjects`() {
        val states = GeographicData.statesFor("RU")
        assertTrue("Russia should have at least 80 federal subjects, got ${states.size}", states.size >= 80)
    }

    @Test
    fun `statesFor AR returns provinces`() {
        val states = GeographicData.statesFor("AR")
        assertEquals(24, states.size)
    }

    @Test
    fun `statesFor unknown country returns empty`() {
        val states = GeographicData.statesFor("JP")
        assertTrue("Non-state country should return empty list", states.isEmpty())
    }

    // ==================== REGION TYPE MAPPING ====================

    @Test
    fun `regionTypeForCountry US is US_STATE`() {
        assertEquals(RegionType.US_STATE, GeographicData.regionTypeForCountry("US"))
    }

    @Test
    fun `regionTypeForCountry CA is CANADIAN_PROVINCE`() {
        assertEquals(RegionType.CANADIAN_PROVINCE, GeographicData.regionTypeForCountry("CA"))
    }

    @Test
    fun `regionTypeForCountry AU is AUSTRALIAN_STATE`() {
        assertEquals(RegionType.AUSTRALIAN_STATE, GeographicData.regionTypeForCountry("AU"))
    }

    @Test
    fun `regionTypeForCountry MX is MEXICAN_STATE`() {
        assertEquals(RegionType.MEXICAN_STATE, GeographicData.regionTypeForCountry("MX"))
    }

    @Test
    fun `regionTypeForCountry BR is BRAZILIAN_STATE`() {
        assertEquals(RegionType.BRAZILIAN_STATE, GeographicData.regionTypeForCountry("BR"))
    }

    @Test
    fun `regionTypeForCountry DE is GERMAN_STATE`() {
        assertEquals(RegionType.GERMAN_STATE, GeographicData.regionTypeForCountry("DE"))
    }

    @Test
    fun `regionTypeForCountry FR is FRENCH_REGION`() {
        assertEquals(RegionType.FRENCH_REGION, GeographicData.regionTypeForCountry("FR"))
    }

    @Test
    fun `regionTypeForCountry ES is SPANISH_COMMUNITY`() {
        assertEquals(RegionType.SPANISH_COMMUNITY, GeographicData.regionTypeForCountry("ES"))
    }

    @Test
    fun `regionTypeForCountry IT is ITALIAN_REGION`() {
        assertEquals(RegionType.ITALIAN_REGION, GeographicData.regionTypeForCountry("IT"))
    }

    @Test
    fun `regionTypeForCountry NL is DUTCH_PROVINCE`() {
        assertEquals(RegionType.DUTCH_PROVINCE, GeographicData.regionTypeForCountry("NL"))
    }

    @Test
    fun `regionTypeForCountry BE is BELGIAN_PROVINCE`() {
        assertEquals(RegionType.BELGIAN_PROVINCE, GeographicData.regionTypeForCountry("BE"))
    }

    @Test
    fun `regionTypeForCountry GB is UK_COUNTRY`() {
        assertEquals(RegionType.UK_COUNTRY, GeographicData.regionTypeForCountry("GB"))
    }

    @Test
    fun `regionTypeForCountry RU is RUSSIAN_FEDERAL_SUBJECT`() {
        assertEquals(RegionType.RUSSIAN_FEDERAL_SUBJECT, GeographicData.regionTypeForCountry("RU"))
    }

    @Test
    fun `regionTypeForCountry AR is ARGENTINE_PROVINCE`() {
        assertEquals(RegionType.ARGENTINE_PROVINCE, GeographicData.regionTypeForCountry("AR"))
    }

    @Test
    fun `regionTypeForCountry unknown returns null`() {
        assertNull(GeographicData.regionTypeForCountry("JP"))
        assertNull(GeographicData.regionTypeForCountry("NG"))
    }

    // ==================== FLAG EMOJI ====================

    @Test
    fun `flagEmoji for US returns US flag`() {
        val flag = GeographicData.flagEmoji("US")
        assertTrue(flag.isNotEmpty())
    }

    @Test
    fun `flagEmoji for invalid code returns empty`() {
        assertEquals("", GeographicData.flagEmoji(""))
        assertEquals("", GeographicData.flagEmoji("A"))
        assertEquals("", GeographicData.flagEmoji("ABC"))
    }

    // ==================== COUNTRIES WITH STATES ====================

    @Test
    fun `countriesWithStates returns 14 countries`() {
        assertEquals(14, GeographicData.countriesWithStates.size)
    }

    @Test
    fun `all countriesWithStates have hasStates true`() {
        GeographicData.countriesWithStates.forEach { country ->
            assertTrue("${country.name} should have hasStates=true", country.hasStates)
        }
    }

    @Test
    fun `countriesWithStates includes expected countries`() {
        val codes = GeographicData.countriesWithStates.map { it.code }.toSet()
        listOf("US", "CA", "AU", "MX", "BR", "DE", "FR", "ES", "IT", "NL", "BE", "GB", "RU", "AR").forEach {
            assertTrue("Missing country with states: $it", it in codes)
        }
    }

    // ==================== STATE CODES UNIQUE PER COUNTRY ====================

    @Test
    fun `all state codes unique within each country`() {
        listOf("US", "CA", "AU", "MX", "BR", "DE", "FR", "ES", "IT", "NL", "BE", "GB", "RU", "AR").forEach { countryCode ->
            val states = GeographicData.statesFor(countryCode)
            val codes = states.map { it.code }
            assertEquals(
                "Duplicate state codes in $countryCode: ${codes.groupBy { it }.filter { it.value.size > 1 }.keys}",
                codes.size,
                codes.toSet().size
            )
        }
    }

    @Test
    fun `all state names non-empty`() {
        listOf("US", "CA", "AU", "MX", "BR", "DE", "FR", "ES", "IT", "NL", "BE", "GB", "RU", "AR").forEach { countryCode ->
            GeographicData.statesFor(countryCode).forEach { state ->
                assertTrue(
                    "Empty state name in $countryCode for code ${state.code}",
                    state.name.isNotBlank()
                )
            }
        }
    }

    // ==================== CONTINENT STAT DATA ====================

    @Test
    fun `continentStatData is not empty`() {
        assertTrue(GeographicData.continentStatData.isNotEmpty())
    }

    @Test
    fun `continentStatData country codes match actual countries`() {
        val allCodes = GeographicData.countries.map { it.code }.toSet()
        GeographicData.continentStatData.forEach { stat ->
            stat.codes.forEach { code ->
                assertTrue(
                    "Continent ${stat.name} has unknown country code: $code",
                    code in allCodes
                )
            }
        }
    }

    @Test
    fun `continentStatData totals match actual country counts`() {
        GeographicData.continentStatData.forEach { stat ->
            assertEquals(
                "Continent ${stat.name} total mismatch",
                stat.codes.size,
                stat.total
            )
        }
    }
}
