package com.footprintmaps.android

import com.footprintmaps.android.domain.model.Continent
import com.footprintmaps.android.domain.model.PlaceStatus
import com.footprintmaps.android.domain.model.RegionType
import com.footprintmaps.android.domain.model.VisitType
import org.junit.Assert.*
import org.junit.Test

class EnumsTest {

    // ==================== RegionType ====================

    @Test
    fun `RegionType has 15 entries`() {
        assertEquals(15, RegionType.entries.size)
    }

    @Test
    fun `RegionType fromValue works for all valid values`() {
        assertEquals(RegionType.COUNTRY, RegionType.fromValue("country"))
        assertEquals(RegionType.US_STATE, RegionType.fromValue("us_state"))
        assertEquals(RegionType.CANADIAN_PROVINCE, RegionType.fromValue("canadian_province"))
        assertEquals(RegionType.AUSTRALIAN_STATE, RegionType.fromValue("australian_state"))
        assertEquals(RegionType.MEXICAN_STATE, RegionType.fromValue("mexican_state"))
        assertEquals(RegionType.BRAZILIAN_STATE, RegionType.fromValue("brazilian_state"))
        assertEquals(RegionType.GERMAN_STATE, RegionType.fromValue("german_state"))
        assertEquals(RegionType.FRENCH_REGION, RegionType.fromValue("french_region"))
        assertEquals(RegionType.SPANISH_COMMUNITY, RegionType.fromValue("spanish_community"))
        assertEquals(RegionType.ITALIAN_REGION, RegionType.fromValue("italian_region"))
        assertEquals(RegionType.DUTCH_PROVINCE, RegionType.fromValue("dutch_province"))
        assertEquals(RegionType.BELGIAN_PROVINCE, RegionType.fromValue("belgian_province"))
        assertEquals(RegionType.UK_COUNTRY, RegionType.fromValue("uk_country"))
        assertEquals(RegionType.RUSSIAN_FEDERAL_SUBJECT, RegionType.fromValue("russian_federal_subject"))
        assertEquals(RegionType.ARGENTINE_PROVINCE, RegionType.fromValue("argentine_province"))
    }

    @Test
    fun `RegionType fromValue returns null for invalid`() {
        assertNull(RegionType.fromValue("invalid"))
        assertNull(RegionType.fromValue(""))
        assertNull(RegionType.fromValue("COUNTRY"))  // case-sensitive
    }

    @Test
    fun `RegionType value property matches expected strings`() {
        assertEquals("country", RegionType.COUNTRY.value)
        assertEquals("us_state", RegionType.US_STATE.value)
        assertEquals("canadian_province", RegionType.CANADIAN_PROVINCE.value)
        assertEquals("australian_state", RegionType.AUSTRALIAN_STATE.value)
        assertEquals("mexican_state", RegionType.MEXICAN_STATE.value)
        assertEquals("brazilian_state", RegionType.BRAZILIAN_STATE.value)
        assertEquals("german_state", RegionType.GERMAN_STATE.value)
        assertEquals("french_region", RegionType.FRENCH_REGION.value)
        assertEquals("spanish_community", RegionType.SPANISH_COMMUNITY.value)
        assertEquals("italian_region", RegionType.ITALIAN_REGION.value)
        assertEquals("dutch_province", RegionType.DUTCH_PROVINCE.value)
        assertEquals("belgian_province", RegionType.BELGIAN_PROVINCE.value)
        assertEquals("uk_country", RegionType.UK_COUNTRY.value)
        assertEquals("russian_federal_subject", RegionType.RUSSIAN_FEDERAL_SUBJECT.value)
        assertEquals("argentine_province", RegionType.ARGENTINE_PROVINCE.value)
    }

    // ==================== PlaceStatus ====================

    @Test
    fun `PlaceStatus has 2 entries`() {
        assertEquals(2, PlaceStatus.entries.size)
    }

    @Test
    fun `PlaceStatus fromValue works`() {
        assertEquals(PlaceStatus.VISITED, PlaceStatus.fromValue("visited"))
        assertEquals(PlaceStatus.BUCKET_LIST, PlaceStatus.fromValue("bucket_list"))
        assertNull(PlaceStatus.fromValue("invalid"))
    }

    @Test
    fun `PlaceStatus value property`() {
        assertEquals("visited", PlaceStatus.VISITED.value)
        assertEquals("bucket_list", PlaceStatus.BUCKET_LIST.value)
    }

    // ==================== VisitType ====================

    @Test
    fun `VisitType has 2 entries`() {
        assertEquals(2, VisitType.entries.size)
    }

    @Test
    fun `VisitType fromValue works`() {
        assertEquals(VisitType.VISITED, VisitType.fromValue("visited"))
        assertEquals(VisitType.TRANSIT, VisitType.fromValue("transit"))
        assertNull(VisitType.fromValue("invalid"))
    }

    @Test
    fun `VisitType value property`() {
        assertEquals("visited", VisitType.VISITED.value)
        assertEquals("transit", VisitType.TRANSIT.value)
    }

    // ==================== Continent ====================

    @Test
    fun `Continent has 7 entries`() {
        assertEquals(7, Continent.entries.size)
    }

    @Test
    fun `Continent display names are correct`() {
        assertEquals("Europe", Continent.EUROPE.displayName)
        assertEquals("Asia", Continent.ASIA.displayName)
        assertEquals("North America", Continent.NORTH_AMERICA.displayName)
        assertEquals("South America", Continent.SOUTH_AMERICA.displayName)
        assertEquals("Africa", Continent.AFRICA.displayName)
        assertEquals("Oceania", Continent.OCEANIA.displayName)
        assertEquals("Antarctica", Continent.ANTARCTICA.displayName)
    }

    @Test
    fun `all Continent display names are non-empty`() {
        Continent.entries.forEach { continent ->
            assertTrue("${continent.name} has empty display name", continent.displayName.isNotBlank())
        }
    }
}
