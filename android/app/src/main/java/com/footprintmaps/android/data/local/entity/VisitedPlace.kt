package com.footprintmaps.android.data.local.entity

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

@Entity(tableName = "visited_places")
data class VisitedPlace(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val regionType: String,   // "country", "us_state", "canadian_province", etc.
    val regionCode: String,
    val regionName: String,
    val status: String = "visited",       // "visited" or "bucket_list"
    val visitType: String = "visited",    // "visited" or "transit"
    val visitedDate: Long? = null,
    val departureDate: Long? = null,
    val notes: String? = null,
    val markedAt: Long = System.currentTimeMillis(),
    val syncVersion: Int = 1,
    val lastModifiedAt: Long = System.currentTimeMillis(),
    val isDeleted: Boolean = false,
    val isSynced: Boolean = false
)
