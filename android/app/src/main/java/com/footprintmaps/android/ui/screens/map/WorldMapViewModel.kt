package com.footprintmaps.android.ui.screens.map

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.footprintmaps.android.data.local.entity.VisitedPlace
import com.footprintmaps.android.data.repository.PlacesRepository
import com.footprintmaps.android.domain.model.Country
import com.footprintmaps.android.domain.model.GeographicData
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class MapUiState(
    val visitedPlaces: List<VisitedPlace> = emptyList(),
    val allPlaces: Map<String, VisitedPlace> = emptyMap(),
    val selectedCountryCode: String? = null,
    val showCountrySheet: Boolean = false,
    val isLoading: Boolean = false,
    val visitedCountryCodes: Set<String> = emptySet(),
    val bucketListCountryCodes: Set<String> = emptySet()
)

@HiltViewModel
class WorldMapViewModel @Inject constructor(
    private val placesRepository: PlacesRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(MapUiState())
    val uiState: StateFlow<MapUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            placesRepository.getPlacesByRegionType("country").collect { places ->
                val placesMap = places.associateBy { it.regionCode }
                val visited = places.filter { it.status == "visited" }.map { it.regionCode }.toSet()
                val bucketList = places.filter { it.status == "bucket_list" }.map { it.regionCode }.toSet()
                _uiState.value = _uiState.value.copy(
                    visitedPlaces = places,
                    allPlaces = placesMap,
                    visitedCountryCodes = visited,
                    bucketListCountryCodes = bucketList
                )
            }
        }
    }

    fun selectCountry(code: String?) {
        _uiState.value = _uiState.value.copy(
            selectedCountryCode = code,
            showCountrySheet = code != null
        )
    }

    fun dismissCountrySheet() {
        _uiState.value = _uiState.value.copy(showCountrySheet = false)
    }

    fun toggleVisited(country: Country) {
        viewModelScope.launch {
            val existing = placesRepository.getPlaceByTypeAndCode("country", country.code)
            if (existing != null && existing.status == "visited") {
                placesRepository.removePlace("country", country.code)
            } else {
                placesRepository.addPlace(
                    VisitedPlace(
                        regionType = "country",
                        regionCode = country.code,
                        regionName = country.name,
                        status = "visited"
                    )
                )
            }
        }
    }

    fun toggleBucketList(country: Country) {
        viewModelScope.launch {
            val existing = placesRepository.getPlaceByTypeAndCode("country", country.code)
            if (existing != null && existing.status == "bucket_list") {
                placesRepository.removePlace("country", country.code)
            } else {
                placesRepository.addPlace(
                    VisitedPlace(
                        regionType = "country",
                        regionCode = country.code,
                        regionName = country.name,
                        status = "bucket_list"
                    )
                )
            }
        }
    }

    fun removePlace(country: Country) {
        viewModelScope.launch {
            placesRepository.removePlace("country", country.code)
        }
    }
}
