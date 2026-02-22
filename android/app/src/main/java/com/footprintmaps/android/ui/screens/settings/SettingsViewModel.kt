package com.footprintmaps.android.ui.screens.settings

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.footprintmaps.android.data.local.dao.VisitedPlaceDao
import com.footprintmaps.android.data.preferences.AppPreferences
import com.footprintmaps.android.data.repository.AuthRepository
import com.footprintmaps.android.data.repository.PlacesRepository
import com.footprintmaps.android.data.repository.SyncRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val isLoggedIn: Boolean = false,
    val userName: String? = null,
    val userEmail: String? = null,
    val trackingEnabled: Boolean = false,
    val darkMode: String = "system",
    val unsyncedCount: Int = 0,
    val isSyncing: Boolean = false,
    val syncMessage: String? = null,
    val lastSyncAt: String? = null,
    val visitedCount: Int = 0,
    val appVersion: String = "",
    val appBuild: String = "",
    val showClearDataDialog: Boolean = false,
    val showDeleteAccountDialog: Boolean = false,
    val showSignOutDialog: Boolean = false,
    val backupMessage: String? = null,
    val offlineMode: Boolean = false
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val syncRepository: SyncRepository,
    private val appPreferences: AppPreferences,
    private val placesRepository: PlacesRepository,
    private val dao: VisitedPlaceDao,
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState(
        isLoggedIn = authRepository.isLoggedIn,
        userName = authRepository.userName,
        userEmail = authRepository.userEmail
    ))
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        // Get app version info
        try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            _uiState.value = _uiState.value.copy(
                appVersion = packageInfo.versionName ?: "1.0.0",
                appBuild = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    packageInfo.longVersionCode.toString()
                } else {
                    @Suppress("DEPRECATION")
                    packageInfo.versionCode.toString()
                }
            )
        } catch (_: PackageManager.NameNotFoundException) {
            _uiState.value = _uiState.value.copy(appVersion = "1.0.0", appBuild = "1")
        }

        viewModelScope.launch {
            appPreferences.trackingEnabled.collect { enabled ->
                _uiState.value = _uiState.value.copy(trackingEnabled = enabled)
            }
        }

        viewModelScope.launch {
            appPreferences.darkMode.collect { mode ->
                _uiState.value = _uiState.value.copy(darkMode = mode)
            }
        }

        viewModelScope.launch {
            syncRepository.getUnsyncedCount().collect { count ->
                _uiState.value = _uiState.value.copy(unsyncedCount = count)
            }
        }

        viewModelScope.launch {
            appPreferences.lastSyncAt.collect { timestamp ->
                _uiState.value = _uiState.value.copy(lastSyncAt = timestamp)
            }
        }

        viewModelScope.launch {
            placesRepository.getVisitedCountryCount().collect { count ->
                _uiState.value = _uiState.value.copy(visitedCount = count)
            }
        }

        viewModelScope.launch {
            appPreferences.offlineMode.collect { offline ->
                _uiState.value = _uiState.value.copy(offlineMode = offline)
            }
        }
    }

    fun toggleTracking(enabled: Boolean) {
        viewModelScope.launch {
            appPreferences.setTrackingEnabled(enabled)
        }
    }

    fun setDarkMode(mode: String) {
        viewModelScope.launch {
            appPreferences.setDarkMode(mode)
        }
    }

    fun toggleOfflineMode(enabled: Boolean) {
        viewModelScope.launch {
            appPreferences.setOfflineMode(enabled)
        }
    }

    fun syncNow() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSyncing = true, syncMessage = null)
            val result = syncRepository.performSync()
            result.fold(
                onSuccess = { count ->
                    _uiState.value = _uiState.value.copy(
                        isSyncing = false,
                        syncMessage = "Synced $count changes"
                    )
                },
                onFailure = { error ->
                    _uiState.value = _uiState.value.copy(
                        isSyncing = false,
                        syncMessage = "Sync failed: ${error.message}"
                    )
                }
            )
        }
    }

    fun showClearDataDialog() {
        _uiState.value = _uiState.value.copy(showClearDataDialog = true)
    }

    fun dismissClearDataDialog() {
        _uiState.value = _uiState.value.copy(showClearDataDialog = false)
    }

    fun clearAllData() {
        viewModelScope.launch {
            dao.deleteAllPlaces()
            _uiState.value = _uiState.value.copy(
                showClearDataDialog = false,
                syncMessage = "All data cleared"
            )
        }
    }

    fun showDeleteAccountDialog() {
        _uiState.value = _uiState.value.copy(showDeleteAccountDialog = true)
    }

    fun dismissDeleteAccountDialog() {
        _uiState.value = _uiState.value.copy(showDeleteAccountDialog = false)
    }

    fun deleteAccount() {
        viewModelScope.launch {
            dao.deleteAllPlaces()
            authRepository.signOut()
            _uiState.value = _uiState.value.copy(
                showDeleteAccountDialog = false,
                isLoggedIn = false,
                userName = null,
                userEmail = null
            )
        }
    }

    fun showSignOutDialog() {
        _uiState.value = _uiState.value.copy(showSignOutDialog = true)
    }

    fun dismissSignOutDialog() {
        _uiState.value = _uiState.value.copy(showSignOutDialog = false)
    }

    fun signOut() {
        authRepository.signOut()
        _uiState.value = _uiState.value.copy(
            isLoggedIn = false,
            userName = null,
            userEmail = null,
            showSignOutDialog = false
        )
    }
}
