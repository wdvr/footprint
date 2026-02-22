package com.footprintmaps.android.data.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "footprint_preferences")

@Singleton
class AppPreferences @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val dataStore = context.dataStore

    companion object {
        val ONBOARDING_COMPLETED = booleanPreferencesKey("onboarding_completed")
        val LAST_SYNC_AT = stringPreferencesKey("last_sync_at")
        val TRACKING_ENABLED = booleanPreferencesKey("tracking_enabled")
        val DARK_MODE = stringPreferencesKey("dark_mode") // "system", "light", "dark"
        val DEVICE_ID = stringPreferencesKey("device_id")
        val OFFLINE_MODE = booleanPreferencesKey("offline_mode")
    }

    val onboardingCompleted: Flow<Boolean> = dataStore.data.map { prefs ->
        prefs[ONBOARDING_COMPLETED] ?: false
    }

    suspend fun setOnboardingCompleted(completed: Boolean) {
        dataStore.edit { prefs ->
            prefs[ONBOARDING_COMPLETED] = completed
        }
    }

    val lastSyncAt: Flow<String?> = dataStore.data.map { prefs ->
        prefs[LAST_SYNC_AT]
    }

    suspend fun setLastSyncAt(timestamp: String) {
        dataStore.edit { prefs ->
            prefs[LAST_SYNC_AT] = timestamp
        }
    }

    val trackingEnabled: Flow<Boolean> = dataStore.data.map { prefs ->
        prefs[TRACKING_ENABLED] ?: false
    }

    suspend fun setTrackingEnabled(enabled: Boolean) {
        dataStore.edit { prefs ->
            prefs[TRACKING_ENABLED] = enabled
        }
    }

    val darkMode: Flow<String> = dataStore.data.map { prefs ->
        prefs[DARK_MODE] ?: "system"
    }

    suspend fun setDarkMode(mode: String) {
        dataStore.edit { prefs ->
            prefs[DARK_MODE] = mode
        }
    }

    val offlineMode: Flow<Boolean> = dataStore.data.map { prefs ->
        prefs[OFFLINE_MODE] ?: false
    }

    suspend fun setOfflineMode(enabled: Boolean) {
        dataStore.edit { prefs ->
            prefs[OFFLINE_MODE] = enabled
        }
    }

    val deviceId: Flow<String?> = dataStore.data.map { prefs ->
        prefs[DEVICE_ID]
    }

    suspend fun setDeviceId(id: String) {
        dataStore.edit { prefs ->
            prefs[DEVICE_ID] = id
        }
    }
}
