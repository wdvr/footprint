package com.footprintmaps.android.ui.screens.countries

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.footprintmaps.android.domain.model.Continent
import com.footprintmaps.android.domain.model.Country
import com.footprintmaps.android.domain.model.GeographicData
import com.footprintmaps.android.domain.model.SubRegion
import com.footprintmaps.android.ui.theme.BucketList
import com.footprintmaps.android.ui.theme.Visited

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CountryListScreen(
    onNavigateToCountry: (String) -> Unit,
    viewModel: CountryListViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    Column(modifier = Modifier.fillMaxSize()) {
        // Search bar
        OutlinedTextField(
            value = uiState.searchQuery,
            onValueChange = { viewModel.updateSearchQuery(it) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            placeholder = { Text("Search countries...") },
            leadingIcon = { Icon(Icons.Filled.Search, contentDescription = "Search") },
            trailingIcon = {
                if (uiState.searchQuery.isNotEmpty()) {
                    IconButton(onClick = { viewModel.updateSearchQuery("") }) {
                        Icon(Icons.Filled.Clear, contentDescription = "Clear")
                    }
                }
            },
            singleLine = true
        )

        // Summary row
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            val totalVisited = uiState.visitedPlaces.count { it.value.status == "visited" }
            val totalBucket = uiState.visitedPlaces.count { it.value.status == "bucket_list" }
            Text(
                text = "$totalVisited visited",
                style = MaterialTheme.typography.bodySmall,
                color = Visited,
                fontWeight = FontWeight.Bold
            )
            if (totalBucket > 0) {
                Text(
                    text = "$totalBucket on bucket list",
                    style = MaterialTheme.typography.bodySmall,
                    color = BucketList,
                    fontWeight = FontWeight.Bold
                )
            }
            Text(
                text = "${GeographicData.countries.size} countries",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        if (uiState.searchQuery.isNotEmpty()) {
            // Show flat filtered list
            val filtered = uiState.countriesByContinent.values.flatten()
                .filter { it.name.contains(uiState.searchQuery, ignoreCase = true) }

            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(filtered, key = { it.code }) { country ->
                    CountryRow(
                        country = country,
                        place = uiState.visitedPlaces[country.code],
                        isExpanded = country.code in uiState.expandedCountries,
                        statePlaces = uiState.statePlaces,
                        onToggleVisited = { viewModel.toggleVisited(country) },
                        onToggleBucketList = { viewModel.toggleBucketList(country) },
                        onClick = { onNavigateToCountry(country.code) },
                        onToggleExpanded = { viewModel.toggleCountryExpanded(country.code) },
                        onToggleStateVisited = { subRegion -> viewModel.toggleStateVisited(country, subRegion) }
                    )
                }
            }
        } else {
            // Show grouped by continent
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                uiState.countriesByContinent.forEach { (continent, countries) ->
                    item(key = continent.name) {
                        ContinentHeader(
                            continent = continent,
                            countries = countries,
                            visitedCount = countries.count { c ->
                                uiState.visitedPlaces[c.code]?.status == "visited"
                            },
                            isExpanded = continent in uiState.expandedContinents,
                            onToggle = { viewModel.toggleContinent(continent) }
                        )
                    }

                    if (continent in uiState.expandedContinents) {
                        items(countries, key = { "${continent.name}_${it.code}" }) { country ->
                            CountryRow(
                                country = country,
                                place = uiState.visitedPlaces[country.code],
                                isExpanded = country.code in uiState.expandedCountries,
                                statePlaces = uiState.statePlaces,
                                onToggleVisited = { viewModel.toggleVisited(country) },
                                onToggleBucketList = { viewModel.toggleBucketList(country) },
                                onClick = { onNavigateToCountry(country.code) },
                                onToggleExpanded = { viewModel.toggleCountryExpanded(country.code) },
                                onToggleStateVisited = { subRegion -> viewModel.toggleStateVisited(country, subRegion) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ContinentHeader(
    continent: Continent,
    countries: List<Country>,
    visitedCount: Int,
    isExpanded: Boolean,
    onToggle: () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onToggle() },
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = continent.displayName,
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "$visitedCount / ${countries.size} visited",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Icon(
                imageVector = if (isExpanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                contentDescription = if (isExpanded) "Collapse" else "Expand"
            )
        }
    }
}

@Composable
private fun CountryRow(
    country: Country,
    place: com.footprintmaps.android.data.local.entity.VisitedPlace?,
    isExpanded: Boolean,
    statePlaces: Map<String, com.footprintmaps.android.data.local.entity.VisitedPlace>,
    onToggleVisited: () -> Unit,
    onToggleBucketList: () -> Unit,
    onClick: () -> Unit,
    onToggleExpanded: () -> Unit,
    onToggleStateVisited: (SubRegion) -> Unit
) {
    val isVisited = place?.status == "visited"
    val isBucketList = place?.status == "bucket_list"
    val hasStates = country.hasStates
    val states = if (hasStates) GeographicData.statesFor(country.code) else emptyList()
    val regionTypeValue = GeographicData.regionTypeForCountry(country.code)?.value ?: ""
    val visitedStateCount = if (hasStates) {
        states.count { state ->
            statePlaces["${regionTypeValue}:${state.code}"]?.status == "visited"
        }
    } else 0

    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onClick() }
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // Flag emoji
                Text(
                    text = GeographicData.flagEmoji(country.code),
                    style = MaterialTheme.typography.titleLarge
                )

                Column {
                    Text(
                        text = country.name,
                        style = MaterialTheme.typography.bodyLarge
                    )
                    if (hasStates && visitedStateCount > 0) {
                        Text(
                            text = "$visitedStateCount / ${states.size} regions",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                // Expand states button
                if (hasStates) {
                    IconButton(
                        onClick = onToggleExpanded,
                        modifier = Modifier.size(36.dp)
                    ) {
                        Icon(
                            imageVector = if (isExpanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                            contentDescription = if (isExpanded) "Collapse states" else "Expand states",
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }

                IconButton(onClick = onToggleVisited) {
                    Icon(
                        imageVector = if (isVisited) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                        contentDescription = if (isVisited) "Visited" else "Mark visited",
                        tint = if (isVisited) Visited else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                IconButton(onClick = onToggleBucketList) {
                    Icon(
                        imageVector = if (isBucketList) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                        contentDescription = if (isBucketList) "On bucket list" else "Add to bucket list",
                        tint = if (isBucketList) BucketList else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        // Expandable state sub-list
        AnimatedVisibility(visible = isExpanded && hasStates) {
            Column(
                modifier = Modifier.padding(start = 56.dp)
            ) {
                states.forEach { subRegion ->
                    val stateRegType = GeographicData.regionTypeForCountry(country.code)?.value ?: ""
                    val statePlace = statePlaces["${stateRegType}:${subRegion.code}"]
                    val stateVisited = statePlace?.status == "visited"

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onToggleStateVisited(subRegion) }
                            .padding(horizontal = 8.dp, vertical = 6.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = subRegion.name,
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f)
                        )

                        Icon(
                            imageVector = if (stateVisited) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                            contentDescription = if (stateVisited) "${subRegion.name} visited" else "Mark ${subRegion.name} visited",
                            tint = if (stateVisited) Visited else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }
            }
        }
    }
}
