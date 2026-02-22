package com.footprintmaps.android.data.local.dao

import androidx.room.*
import com.footprintmaps.android.data.local.entity.VisitedPlace
import kotlinx.coroutines.flow.Flow

@Dao
interface VisitedPlaceDao {

    @Query("SELECT * FROM visited_places WHERE isDeleted = 0 ORDER BY lastModifiedAt DESC")
    fun getAllPlaces(): Flow<List<VisitedPlace>>

    @Query("SELECT * FROM visited_places WHERE isDeleted = 0 AND status = :status ORDER BY regionName ASC")
    fun getPlacesByStatus(status: String): Flow<List<VisitedPlace>>

    @Query("SELECT * FROM visited_places WHERE isDeleted = 0 AND regionType = :regionType ORDER BY regionName ASC")
    fun getPlacesByRegionType(regionType: String): Flow<List<VisitedPlace>>

    @Query("SELECT * FROM visited_places WHERE isDeleted = 0 AND regionType = :regionType AND status = :status ORDER BY regionName ASC")
    fun getPlacesByRegionTypeAndStatus(regionType: String, status: String): Flow<List<VisitedPlace>>

    @Query("SELECT * FROM visited_places WHERE id = :id")
    suspend fun getPlaceById(id: String): VisitedPlace?

    @Query("SELECT * FROM visited_places WHERE regionType = :regionType AND regionCode = :regionCode AND isDeleted = 0 LIMIT 1")
    suspend fun getPlaceByTypeAndCode(regionType: String, regionCode: String): VisitedPlace?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlace(place: VisitedPlace)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPlaces(places: List<VisitedPlace>)

    @Update
    suspend fun updatePlace(place: VisitedPlace)

    @Query("UPDATE visited_places SET isDeleted = 1, lastModifiedAt = :timestamp, isSynced = 0 WHERE id = :id")
    suspend fun softDelete(id: String, timestamp: Long = System.currentTimeMillis())

    @Query("UPDATE visited_places SET isDeleted = 1, lastModifiedAt = :timestamp, isSynced = 0 WHERE regionType = :regionType AND regionCode = :regionCode")
    suspend fun softDeleteByTypeAndCode(regionType: String, regionCode: String, timestamp: Long = System.currentTimeMillis())

    @Delete
    suspend fun deletePlace(place: VisitedPlace)

    @Query("DELETE FROM visited_places")
    suspend fun deleteAllPlaces()

    // Sync queries
    @Query("SELECT * FROM visited_places WHERE isSynced = 0")
    suspend fun getUnsyncedPlaces(): List<VisitedPlace>

    @Query("UPDATE visited_places SET isSynced = 1 WHERE id IN (:ids)")
    suspend fun markAsSynced(ids: List<String>)

    @Query("SELECT COUNT(*) FROM visited_places WHERE isSynced = 0")
    fun getUnsyncedCount(): Flow<Int>

    // Stats queries
    @Query("SELECT COUNT(*) FROM visited_places WHERE isDeleted = 0 AND regionType = 'country' AND status = 'visited'")
    fun getVisitedCountryCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM visited_places WHERE isDeleted = 0 AND regionType = 'country' AND status = 'bucket_list'")
    fun getBucketListCountryCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM visited_places WHERE isDeleted = 0 AND regionType = 'us_state' AND status = 'visited'")
    fun getVisitedUsStateCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM visited_places WHERE isDeleted = 0 AND regionType = 'canadian_province' AND status = 'visited'")
    fun getVisitedCanadianProvinceCount(): Flow<Int>

    @Query("SELECT DISTINCT regionCode FROM visited_places WHERE isDeleted = 0 AND regionType = 'country' AND status = 'visited'")
    fun getVisitedCountryCodes(): Flow<List<String>>

    @Query("SELECT COUNT(*) FROM visited_places WHERE isDeleted = 0 AND status = 'visited'")
    fun getTotalVisitedCount(): Flow<Int>
}
