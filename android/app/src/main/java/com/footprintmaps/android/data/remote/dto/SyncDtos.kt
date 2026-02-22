package com.footprintmaps.android.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class SyncRequest(
    val changes: List<PlaceChange>,
    @SerialName("last_sync_at") val lastSyncAt: String? = null,
    @SerialName("device_id") val deviceId: String? = null
)

@Serializable
data class SyncResponse(
    val changes: List<PlaceChange> = emptyList(),
    @SerialName("server_time") val serverTime: String,
    val conflicts: List<PlaceChange> = emptyList()
)

@Serializable
data class PlaceChange(
    val id: String,
    @SerialName("region_type") val regionType: String,
    @SerialName("region_code") val regionCode: String,
    @SerialName("region_name") val regionName: String,
    val status: String = "visited",
    @SerialName("visit_type") val visitType: String = "visited",
    @SerialName("visited_date") val visitedDate: String? = null,
    @SerialName("departure_date") val departureDate: String? = null,
    val notes: String? = null,
    @SerialName("sync_version") val syncVersion: Int = 1,
    @SerialName("last_modified_at") val lastModifiedAt: String? = null,
    @SerialName("is_deleted") val isDeleted: Boolean = false
)
