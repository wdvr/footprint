package com.footprintmaps.android.di

import android.content.Context
import com.footprintmaps.android.data.preferences.AppPreferences
import com.footprintmaps.android.data.preferences.SecureTokenStore
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideAppPreferences(@ApplicationContext context: Context): AppPreferences {
        return AppPreferences(context)
    }

    @Provides
    @Singleton
    fun provideSecureTokenStore(@ApplicationContext context: Context): SecureTokenStore {
        return SecureTokenStore(context)
    }
}
