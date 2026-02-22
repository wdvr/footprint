package com.footprintmaps.android.di

import android.content.Context
import androidx.room.Room
import com.footprintmaps.android.data.local.FootprintDatabase
import com.footprintmaps.android.data.local.dao.VisitedPlaceDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): FootprintDatabase {
        return Room.databaseBuilder(
            context,
            FootprintDatabase::class.java,
            "footprint_database"
        )
            .fallbackToDestructiveMigration()
            .build()
    }

    @Provides
    @Singleton
    fun provideVisitedPlaceDao(database: FootprintDatabase): VisitedPlaceDao {
        return database.visitedPlaceDao()
    }
}
