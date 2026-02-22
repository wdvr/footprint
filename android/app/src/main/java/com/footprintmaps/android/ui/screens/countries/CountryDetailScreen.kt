package com.footprintmaps.android.ui.screens.countries

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.footprintmaps.android.domain.model.GeographicData
import com.footprintmaps.android.domain.model.SubRegion
import com.footprintmaps.android.ui.theme.BucketList
import com.footprintmaps.android.ui.theme.Visited

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CountryDetailScreen(
    countryCode: String,
    onBack: () -> Unit,
    onNavigateToStateMap: (String) -> Unit,
    viewModel: CountryListViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val country = GeographicData.countryByCode(countryCode) ?: return
    val place = uiState.visitedPlaces[countryCode]
    val states = GeographicData.statesFor(countryCode)
    val regionTypeEnum = GeographicData.regionTypeForCountry(countryCode)
    val regionType = regionTypeEnum?.value
    val regionLabel = when (regionTypeEnum) {
        com.footprintmaps.android.domain.model.RegionType.US_STATE -> "States"
        com.footprintmaps.android.domain.model.RegionType.CANADIAN_PROVINCE -> "Provinces & Territories"
        com.footprintmaps.android.domain.model.RegionType.AUSTRALIAN_STATE -> "States & Territories"
        com.footprintmaps.android.domain.model.RegionType.MEXICAN_STATE -> "States"
        com.footprintmaps.android.domain.model.RegionType.BRAZILIAN_STATE -> "States"
        com.footprintmaps.android.domain.model.RegionType.GERMAN_STATE -> "States"
        com.footprintmaps.android.domain.model.RegionType.FRENCH_REGION -> "Regions"
        com.footprintmaps.android.domain.model.RegionType.SPANISH_COMMUNITY -> "Autonomous Communities"
        com.footprintmaps.android.domain.model.RegionType.ITALIAN_REGION -> "Regions"
        com.footprintmaps.android.domain.model.RegionType.DUTCH_PROVINCE -> "Provinces"
        com.footprintmaps.android.domain.model.RegionType.BELGIAN_PROVINCE -> "Provinces"
        com.footprintmaps.android.domain.model.RegionType.UK_COUNTRY -> "Countries & Regions"
        com.footprintmaps.android.domain.model.RegionType.RUSSIAN_FEDERAL_SUBJECT -> "Federal Subjects"
        com.footprintmaps.android.domain.model.RegionType.ARGENTINE_PROVINCE -> "Provinces"
        com.footprintmaps.android.domain.model.RegionType.COUNTRY -> "Regions"
        null -> "Regions"
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = GeographicData.flagEmoji(countryCode),
                            style = MaterialTheme.typography.titleLarge
                        )
                        Text(country.name)
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Country info card
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Text(
                                text = GeographicData.flagEmoji(countryCode),
                                style = MaterialTheme.typography.displayMedium
                            )
                            Column {
                                Text(
                                    text = country.name,
                                    style = MaterialTheme.typography.headlineMedium
                                )
                                Text(
                                    text = "${country.continent.displayName} - ${country.code}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }

            // Status chips
            item {
                val isVisited = place?.status == "visited"
                val isBucketList = place?.status == "bucket_list"

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = isVisited,
                        onClick = { viewModel.toggleVisited(country) },
                        label = { Text("Visited") },
                        leadingIcon = {
                            if (isVisited) {
                                Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                            }
                        },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Visited.copy(alpha = 0.2f)
                        )
                    )

                    FilterChip(
                        selected = isBucketList,
                        onClick = { viewModel.toggleBucketList(country) },
                        label = { Text("Bucket List") },
                        leadingIcon = {
                            if (isBucketList) {
                                Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(18.dp))
                            }
                        },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = BucketList.copy(alpha = 0.2f)
                        )
                    )
                }
            }

            // Sub-regions section
            if (states.isNotEmpty() && regionType != null) {
                item {
                    val visitedCount = states.count { state ->
                        uiState.statePlaces["${regionType}:${state.code}"]?.status == "visited"
                    }

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = regionLabel,
                            style = MaterialTheme.typography.titleLarge
                        )
                        Text(
                            text = "$visitedCount / ${states.size}",
                            style = MaterialTheme.typography.titleMedium,
                            color = if (visitedCount > 0) Visited else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Spacer(modifier = Modifier.height(4.dp))

                    LinearProgressIndicator(
                        progress = { if (states.isNotEmpty()) visitedCount.toFloat() / states.size else 0f },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(6.dp),
                        color = Visited,
                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                }

                items(states, key = { it.code }) { subRegion ->
                    val statePlace = uiState.statePlaces["${regionType}:${subRegion.code}"]
                    val stateVisited = statePlace?.status == "visited"

                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                viewModel.toggleStateVisited(country, subRegion)
                            }
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = subRegion.name,
                                    style = MaterialTheme.typography.bodyLarge
                                )
                                Text(
                                    text = subRegion.code,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }

                            Icon(
                                imageVector = if (stateVisited) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                                contentDescription = if (stateVisited) "${subRegion.name} visited" else "Mark ${subRegion.name} visited",
                                tint = if (stateVisited) Visited else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}
