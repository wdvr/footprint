package com.footprintmaps.android.ui.screens.countries

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.footprintmaps.android.data.local.entity.VisitedPlace
import com.footprintmaps.android.data.repository.PlacesRepository
import com.footprintmaps.android.domain.model.Continent
import com.footprintmaps.android.domain.model.Country
import com.footprintmaps.android.domain.model.GeographicData
import com.footprintmaps.android.domain.model.SubRegion
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class CountryListUiState(
    val countriesByContinent: Map<Continent, List<Country>> = emptyMap(),
    val visitedPlaces: Map<String, VisitedPlace> = emptyMap(),
    val statePlaces: Map<String, VisitedPlace> = emptyMap(),  // key: "regionType:code"
    val expandedContinents: Set<Continent> = emptySet(),
    val expandedCountries: Set<String> = emptySet(),  // country codes with expanded state lists
    val searchQuery: String = "",
    val isLoading: Boolean = false
)

@HiltViewModel
class CountryListViewModel @Inject constructor(
    private val placesRepository: PlacesRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(CountryListUiState(
        countriesByContinent = GeographicData.countriesByContinent
    ))
    val uiState: StateFlow<CountryListUiState> = _uiState.asStateFlow()

    init {
        // Observe country places
        viewModelScope.launch {
            placesRepository.getPlacesByRegionType("country").collect { places ->
                val placesMap = places.associateBy { it.regionCode }
                _uiState.value = _uiState.value.copy(visitedPlaces = placesMap)
            }
        }

        // Observe all non-country places (states/provinces/regions)
        viewModelScope.launch {
            placesRepository.getAllPlaces().collect { allPlaces ->
                val stateMap = allPlaces
                    .filter { it.regionType != "country" && !it.isDeleted }
                    .associateBy { "${it.regionType}:${it.regionCode}" }
                _uiState.value = _uiState.value.copy(statePlaces = stateMap)
            }
        }
    }

    fun toggleContinent(continent: Continent) {
        val expanded = _uiState.value.expandedContinents.toMutableSet()
        if (continent in expanded) {
            expanded.remove(continent)
        } else {
            expanded.add(continent)
        }
        _uiState.value = _uiState.value.copy(expandedContinents = expanded)
    }

    fun toggleCountryExpanded(countryCode: String) {
        val expanded = _uiState.value.expandedCountries.toMutableSet()
        if (countryCode in expanded) {
            expanded.remove(countryCode)
        } else {
            expanded.add(countryCode)
        }
        _uiState.value = _uiState.value.copy(expandedCountries = expanded)
    }

    fun updateSearchQuery(query: String) {
        _uiState.value = _uiState.value.copy(searchQuery = query)
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

    fun toggleStateVisited(country: Country, subRegion: SubRegion) {
        viewModelScope.launch {
            val regionType = GeographicData.regionTypeForCountry(country.code)?.value ?: return@launch
            val existing = placesRepository.getPlaceByTypeAndCode(regionType, subRegion.code)
            if (existing != null && existing.status == "visited") {
                placesRepository.removePlace(regionType, subRegion.code)
            } else {
                placesRepository.addPlace(
                    VisitedPlace(
                        regionType = regionType,
                        regionCode = subRegion.code,
                        regionName = subRegion.name,
                        status = "visited"
                    )
                )
            }
        }
    }
}
