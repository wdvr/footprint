package com.footprintmaps.android

import com.footprintmaps.android.data.local.entity.VisitedPlace
import org.junit.Assert.*
import org.junit.Test

class VisitedPlaceTest {

    @Test
    fun `default status is visited`() {
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "US",
            regionName = "United States"
        )
        assertEquals("visited", place.status)
    }

    @Test
    fun `default visitType is visited`() {
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "FR",
            regionName = "France"
        )
        assertEquals("visited", place.visitType)
    }

    @Test
    fun `isDeleted defaults to false`() {
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "JP",
            regionName = "Japan"
        )
        assertFalse(place.isDeleted)
    }

    @Test
    fun `isSynced defaults to false`() {
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "DE",
            regionName = "Germany"
        )
        assertFalse(place.isSynced)
    }

    @Test
    fun `id is auto generated`() {
        val place1 = VisitedPlace(
            regionType = "country",
            regionCode = "US",
            regionName = "United States"
        )
        val place2 = VisitedPlace(
            regionType = "country",
            regionCode = "US",
            regionName = "United States"
        )
        assertNotEquals(place1.id, place2.id)
    }

    @Test
    fun `bucket list status`() {
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "NZ",
            regionName = "New Zealand",
            status = "bucket_list"
        )
        assertEquals("bucket_list", place.status)
    }

    @Test
    fun `transit visit type`() {
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "TR",
            regionName = "Turkey",
            visitType = "transit"
        )
        assertEquals("transit", place.visitType)
    }

    @Test
    fun `us state region type`() {
        val place = VisitedPlace(
            regionType = "us_state",
            regionCode = "CA",
            regionName = "California"
        )
        assertEquals("us_state", place.regionType)
    }

    @Test
    fun `canadian province region type`() {
        val place = VisitedPlace(
            regionType = "canadian_province",
            regionCode = "ON",
            regionName = "Ontario"
        )
        assertEquals("canadian_province", place.regionType)
    }

    @Test
    fun `australian state region type`() {
        val place = VisitedPlace(
            regionType = "australian_state",
            regionCode = "NSW",
            regionName = "New South Wales"
        )
        assertEquals("australian_state", place.regionType)
    }

    @Test
    fun `mexican state region type`() {
        val place = VisitedPlace(
            regionType = "mexican_state",
            regionCode = "JAL",
            regionName = "Jalisco"
        )
        assertEquals("mexican_state", place.regionType)
    }

    @Test
    fun `markedAt is set automatically`() {
        val before = System.currentTimeMillis()
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "IT",
            regionName = "Italy"
        )
        val after = System.currentTimeMillis()
        assertTrue(place.markedAt in before..after)
    }

    @Test
    fun `lastModifiedAt is set automatically`() {
        val before = System.currentTimeMillis()
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "ES",
            regionName = "Spain"
        )
        val after = System.currentTimeMillis()
        assertTrue(place.lastModifiedAt in before..after)
    }

    @Test
    fun `syncVersion defaults to 1`() {
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "PT",
            regionName = "Portugal"
        )
        assertEquals(1, place.syncVersion)
    }

    @Test
    fun `visitedDate defaults to null`() {
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "GR",
            regionName = "Greece"
        )
        assertNull(place.visitedDate)
    }

    @Test
    fun `notes defaults to null`() {
        val place = VisitedPlace(
            regionType = "country",
            regionCode = "SE",
            regionName = "Sweden"
        )
        assertNull(place.notes)
    }

    @Test
    fun `copy preserves all fields`() {
        val original = VisitedPlace(
            regionType = "country",
            regionCode = "GB",
            regionName = "United Kingdom",
            status = "visited",
            visitType = "visited",
            notes = "Great trip"
        )
        val copied = original.copy(status = "bucket_list")
        assertEquals("bucket_list", copied.status)
        assertEquals(original.id, copied.id)
        assertEquals(original.regionCode, copied.regionCode)
        assertEquals(original.notes, copied.notes)
    }

    @Test
    fun `all 15 region types can be set`() {
        val types = listOf(
            "country", "us_state", "canadian_province", "australian_state",
            "mexican_state", "brazilian_state", "german_state", "french_region",
            "spanish_community", "italian_region", "dutch_province", "belgian_province",
            "uk_country", "russian_federal_subject", "argentine_province"
        )
        types.forEach { type ->
            val place = VisitedPlace(
                regionType = type,
                regionCode = "XX",
                regionName = "Test"
            )
            assertEquals(type, place.regionType)
        }
    }
}
