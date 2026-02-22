package com.footprintmaps.android.data.repository

import com.footprintmaps.android.data.local.dao.VisitedPlaceDao
import com.footprintmaps.android.data.local.entity.VisitedPlace
import com.footprintmaps.android.data.remote.api.FootprintApi
import com.footprintmaps.android.data.remote.dto.CreatePlaceRequest
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PlacesRepository @Inject constructor(
    private val dao: VisitedPlaceDao,
    private val api: FootprintApi
) {
    fun getAllPlaces(): Flow<List<VisitedPlace>> = dao.getAllPlaces()

    fun getPlacesByStatus(status: String): Flow<List<VisitedPlace>> =
        dao.getPlacesByStatus(status)

    fun getPlacesByRegionType(regionType: String): Flow<List<VisitedPlace>> =
        dao.getPlacesByRegionType(regionType)

    fun getPlacesByRegionTypeAndStatus(regionType: String, status: String): Flow<List<VisitedPlace>> =
        dao.getPlacesByRegionTypeAndStatus(regionType, status)

    suspend fun getPlaceById(id: String): VisitedPlace? = dao.getPlaceById(id)

    suspend fun getPlaceByTypeAndCode(regionType: String, regionCode: String): VisitedPlace? =
        dao.getPlaceByTypeAndCode(regionType, regionCode)

    suspend fun addPlace(place: VisitedPlace) {
        dao.insertPlace(place)

        // Try to sync to server
        try {
            val request = CreatePlaceRequest(
                regionType = place.regionType,
                regionCode = place.regionCode,
                regionName = place.regionName,
                status = place.status,
                visitType = place.visitType
            )
            val response = api.createPlace(request)
            if (response.isSuccessful) {
                dao.markAsSynced(listOf(place.id))
            }
        } catch (_: Exception) {
            // Offline - will sync later
        }
    }

    suspend fun updatePlace(place: VisitedPlace) {
        dao.updatePlace(place.copy(isSynced = false, lastModifiedAt = System.currentTimeMillis()))
    }

    suspend fun removePlace(regionType: String, regionCode: String) {
        dao.softDeleteByTypeAndCode(regionType, regionCode)

        try {
            api.deletePlace(regionType, regionCode)
        } catch (_: Exception) {
            // Offline - will sync later
        }
    }

    suspend fun removePlace(id: String) {
        dao.softDelete(id)
    }

    fun getVisitedCountryCount(): Flow<Int> = dao.getVisitedCountryCount()
    fun getBucketListCountryCount(): Flow<Int> = dao.getBucketListCountryCount()
    fun getVisitedUsStateCount(): Flow<Int> = dao.getVisitedUsStateCount()
    fun getVisitedCountryCodes(): Flow<List<String>> = dao.getVisitedCountryCodes()

    suspend fun refreshFromServer() {
        try {
            val response = api.getPlaces()
            if (response.isSuccessful) {
                val remotePlaces = response.body() ?: return
                val localPlaces = remotePlaces.map { dto ->
                    VisitedPlace(
                        id = dto.id,
                        regionType = dto.regionType,
                        regionCode = dto.regionCode,
                        regionName = dto.regionName,
                        status = dto.status,
                        visitType = dto.visitType,
                        isDeleted = dto.isDeleted,
                        isSynced = true,
                        syncVersion = dto.syncVersion
                    )
                }
                dao.insertPlaces(localPlaces)
            }
        } catch (_: Exception) {
            // Offline mode
        }
    }
}
