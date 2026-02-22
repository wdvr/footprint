package com.footprintmaps.android.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import com.footprintmaps.android.data.local.dao.VisitedPlaceDao
import com.footprintmaps.android.data.local.entity.VisitedPlace

@Database(
    entities = [VisitedPlace::class],
    version = 1,
    exportSchema = true
)
abstract class FootprintDatabase : RoomDatabase() {
    abstract fun visitedPlaceDao(): VisitedPlaceDao
}
