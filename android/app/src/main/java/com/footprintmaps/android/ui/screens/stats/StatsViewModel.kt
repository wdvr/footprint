package com.footprintmaps.android.ui.screens.stats

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.footprintmaps.android.data.local.entity.VisitedPlace
import com.footprintmaps.android.data.remote.dto.Badge
import com.footprintmaps.android.data.remote.dto.BadgeProgress
import com.footprintmaps.android.data.repository.LocalStats
import com.footprintmaps.android.data.repository.PlacesRepository
import com.footprintmaps.android.data.repository.StatsRepository
import com.footprintmaps.android.domain.model.Continent
import com.footprintmaps.android.domain.model.GeographicData
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class StatsUiState(
    val localStats: LocalStats = LocalStats(),
    val countriesVisited: Int = 0,
    val countriesBucketList: Int = 0,
    val usStatesVisited: Int = 0,
    val canadianProvincesVisited: Int = 0,
    val totalRegionsVisited: Int = 0,
    val badges: List<Badge> = emptyList(),
    val badgeProgress: List<BadgeProgress> = emptyList(),
    val visitTypeStats: Map<String, Int> = emptyMap(),
    val isLoading: Boolean = false
)

// Local badge definitions matching iOS
data class LocalBadge(
    val id: String,
    val name: String,
    val description: String,
    val icon: String,
    val requirement: Int,
    val current: Int,
    val isEarned: Boolean
)

@HiltViewModel
class StatsViewModel @Inject constructor(
    private val statsRepository: StatsRepository,
    private val placesRepository: PlacesRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(StatsUiState())
    val uiState: StateFlow<StatsUiState> = _uiState.asStateFlow()

    private val _localBadges = MutableStateFlow<List<LocalBadge>>(emptyList())
    val localBadges: StateFlow<List<LocalBadge>> = _localBadges.asStateFlow()

    init {
        viewModelScope.launch {
            statsRepository.getLocalStats().collect { stats ->
                _uiState.value = _uiState.value.copy(localStats = stats)
            }
        }

        viewModelScope.launch {
            placesRepository.getVisitedCountryCount().collect { count ->
                _uiState.value = _uiState.value.copy(countriesVisited = count)
                updateBadges()
            }
        }

        viewModelScope.launch {
            placesRepository.getBucketListCountryCount().collect { count ->
                _uiState.value = _uiState.value.copy(countriesBucketList = count)
            }
        }

        viewModelScope.launch {
            placesRepository.getVisitedUsStateCount().collect { count ->
                _uiState.value = _uiState.value.copy(usStatesVisited = count)
            }
        }

        // Observe all places to compute total regions and Canadian provinces
        viewModelScope.launch {
            placesRepository.getAllPlaces().collect { allPlaces ->
                val activePlaces = allPlaces.filter { !it.isDeleted && it.status == "visited" }
                val caProvinces = activePlaces.count { it.regionType == "canadian_province" }
                val totalRegions = activePlaces.size
                val visitTypeMap = activePlaces.groupBy { it.visitType }.mapValues { it.value.size }
                _uiState.value = _uiState.value.copy(
                    canadianProvincesVisited = caProvinces,
                    totalRegionsVisited = totalRegions,
                    visitTypeStats = visitTypeMap
                )
                updateBadges()
            }
        }
    }

    private fun updateBadges() {
        val countriesVisited = _uiState.value.countriesVisited
        val continentsVisited = _uiState.value.localStats.continentsVisited
        val usStates = _uiState.value.usStatesVisited

        _localBadges.value = listOf(
            LocalBadge("first_country", "First Steps", "Visit your first country", "flag", 1, countriesVisited, countriesVisited >= 1),
            LocalBadge("five_countries", "Explorer", "Visit 5 countries", "compass", 5, countriesVisited, countriesVisited >= 5),
            LocalBadge("ten_countries", "Adventurer", "Visit 10 countries", "backpack", 10, countriesVisited, countriesVisited >= 10),
            LocalBadge("twenty_five_countries", "World Traveler", "Visit 25 countries", "globe", 25, countriesVisited, countriesVisited >= 25),
            LocalBadge("fifty_countries", "Globe Trotter", "Visit 50 countries", "airplane", 50, countriesVisited, countriesVisited >= 50),
            LocalBadge("hundred_countries", "Centurion", "Visit 100 countries", "trophy", 100, countriesVisited, countriesVisited >= 100),
            LocalBadge("all_continents", "Continental", "Visit all 6 continents", "earth", 6, continentsVisited, continentsVisited >= 6),
            LocalBadge("all_us_states", "American Explorer", "Visit all 50 US states + DC", "us_flag", 51, usStates, usStates >= 51)
        )
    }
}
