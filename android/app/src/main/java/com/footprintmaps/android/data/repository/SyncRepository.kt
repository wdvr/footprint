package com.footprintmaps.android.data.repository

import com.footprintmaps.android.data.local.dao.VisitedPlaceDao
import com.footprintmaps.android.data.local.entity.VisitedPlace
import com.footprintmaps.android.data.preferences.AppPreferences
import com.footprintmaps.android.data.remote.api.FootprintApi
import com.footprintmaps.android.data.remote.dto.PlaceChange
import com.footprintmaps.android.data.remote.dto.SyncRequest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.firstOrNull
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SyncRepository @Inject constructor(
    private val dao: VisitedPlaceDao,
    private val api: FootprintApi,
    private val prefs: AppPreferences
) {
    fun getUnsyncedCount(): Flow<Int> = dao.getUnsyncedCount()

    suspend fun performSync(): Result<Int> {
        return try {
            val unsyncedPlaces = dao.getUnsyncedPlaces()
            val lastSyncAt = prefs.lastSyncAt.firstOrNull()

            val changes = unsyncedPlaces.map { place ->
                PlaceChange(
                    id = place.id,
                    regionType = place.regionType,
                    regionCode = place.regionCode,
                    regionName = place.regionName,
                    status = place.status,
                    visitType = place.visitType,
                    syncVersion = place.syncVersion,
                    isDeleted = place.isDeleted
                )
            }

            val request = SyncRequest(
                changes = changes,
                lastSyncAt = lastSyncAt
            )

            val response = api.syncPlaces(request)
            if (response.isSuccessful) {
                val syncResponse = response.body() ?: return Result.success(0)

                // Apply server changes locally
                val serverPlaces = syncResponse.changes.map { change ->
                    VisitedPlace(
                        id = change.id,
                        regionType = change.regionType,
                        regionCode = change.regionCode,
                        regionName = change.regionName,
                        status = change.status,
                        visitType = change.visitType,
                        syncVersion = change.syncVersion,
                        isDeleted = change.isDeleted,
                        isSynced = true
                    )
                }

                if (serverPlaces.isNotEmpty()) {
                    dao.insertPlaces(serverPlaces)
                }

                // Mark local changes as synced
                if (unsyncedPlaces.isNotEmpty()) {
                    dao.markAsSynced(unsyncedPlaces.map { it.id })
                }

                prefs.setLastSyncAt(syncResponse.serverTime)

                Result.success(syncResponse.changes.size + unsyncedPlaces.size)
            } else {
                Result.failure(Exception("Sync failed: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
