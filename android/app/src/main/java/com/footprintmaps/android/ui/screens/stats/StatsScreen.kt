package com.footprintmaps.android.ui.screens.stats

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.footprintmaps.android.domain.model.Continent
import com.footprintmaps.android.domain.model.GeographicData
import com.footprintmaps.android.ui.theme.BucketList
import com.footprintmaps.android.ui.theme.Visited

@Composable
fun StatsScreen(
    viewModel: StatsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val localBadges by viewModel.localBadges.collectAsState()

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Header
        item {
            Text(
                text = "Your Travel Stats",
                style = MaterialTheme.typography.headlineMedium
            )
        }

        // Overview cards - Row 1: Countries + US States
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "Countries",
                    value = "${uiState.countriesVisited}",
                    subtitle = "of ${GeographicData.countries.size}",
                    icon = Icons.Filled.Public,
                    progress = uiState.countriesVisited.toFloat() / GeographicData.countries.size
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "US States",
                    value = "${uiState.usStatesVisited}",
                    subtitle = "of ${GeographicData.usStates.size}",
                    icon = Icons.Filled.Flag,
                    progress = uiState.usStatesVisited.toFloat() / GeographicData.usStates.size
                )
            }
        }

        // Row 2: Canadian Provinces + Continents
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "CA Provinces",
                    value = "${uiState.canadianProvincesVisited}",
                    subtitle = "of ${GeographicData.canadianProvinces.size}",
                    icon = Icons.Filled.Terrain,
                    progress = if (GeographicData.canadianProvinces.isNotEmpty())
                        uiState.canadianProvincesVisited.toFloat() / GeographicData.canadianProvinces.size
                    else 0f
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "Continents",
                    value = "${uiState.localStats.continentsVisited}",
                    subtitle = "of 6",
                    icon = Icons.Filled.Explore,
                    progress = uiState.localStats.continentsVisited.toFloat() / 6f
                )
            }
        }

        // Row 3: Bucket List + Total Regions
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "Bucket List",
                    value = "${uiState.countriesBucketList}",
                    subtitle = "countries",
                    icon = Icons.Filled.Bookmark,
                    valueColor = BucketList
                )
                StatCard(
                    modifier = Modifier.weight(1f),
                    title = "Total Regions",
                    value = "${uiState.totalRegionsVisited}",
                    subtitle = "visited",
                    icon = Icons.Filled.PinDrop
                )
            }
        }

        // Continent progress section
        item {
            Text(
                text = "By Continent",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(
            uiState.localStats.continentProgress.toList(),
            key = { it.first.name }
        ) { (continent, progress) ->
            ContinentProgressRow(
                continent = continent,
                visited = progress.first,
                total = progress.second
            )
        }

        // Visit types section
        if (uiState.visitTypeStats.isNotEmpty()) {
            item {
                Text(
                    text = "Visit Types",
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        val visited = uiState.visitTypeStats["visited"] ?: 0
                        val transit = uiState.visitTypeStats["transit"] ?: 0
                        val total = visited + transit

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceEvenly
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(
                                    Icons.Filled.CheckCircle,
                                    contentDescription = null,
                                    tint = Visited,
                                    modifier = Modifier.size(32.dp)
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = "$visited",
                                    style = MaterialTheme.typography.headlineSmall,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "Visited",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }

                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(
                                    Icons.Filled.Flight,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.tertiary,
                                    modifier = Modifier.size(32.dp)
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = "$transit",
                                    style = MaterialTheme.typography.headlineSmall,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "Transit",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }

        // Badges section
        item {
            Text(
                text = "Achievements",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(localBadges, key = { it.id }) { badge ->
            BadgeRow(badge = badge)
        }

        // Next achievement hint
        item {
            val nextBadge = localBadges.firstOrNull { !it.isEarned }
            if (nextBadge != null) {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer
                    )
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Icon(
                            Icons.Filled.EmojiEvents,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.size(32.dp)
                        )
                        Column {
                            Text(
                                text = "Next Achievement",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                            Text(
                                text = "${nextBadge.name}: ${nextBadge.description}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onPrimaryContainer
                            )
                            Text(
                                text = "${nextBadge.current} / ${nextBadge.requirement}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f)
                            )
                        }
                    }
                }
            }
        }

        // Bottom spacer
        item { Spacer(modifier = Modifier.height(16.dp)) }
    }
}

@Composable
private fun StatCard(
    modifier: Modifier = Modifier,
    title: String,
    value: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    progress: Float = 0f,
    valueColor: androidx.compose.ui.graphics.Color = MaterialTheme.colorScheme.onSurface
) {
    Card(modifier = modifier) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = title,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.headlineLarge,
                color = valueColor
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            if (progress > 0f) {
                Spacer(modifier = Modifier.height(8.dp))
                LinearProgressIndicator(
                    progress = { progress.coerceIn(0f, 1f) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(4.dp),
                    color = Visited,
                    trackColor = MaterialTheme.colorScheme.surfaceVariant
                )
            }
        }
    }
}

@Composable
private fun ContinentProgressRow(
    continent: Continent,
    visited: Int,
    total: Int
) {
    val progress = if (total > 0) visited.toFloat() / total else 0f
    val percentage = if (total > 0) (visited * 100) / total else 0

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = continent.displayName,
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = "$visited / $total ($percentage%)",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Spacer(modifier = Modifier.height(8.dp))
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(8.dp),
                color = Visited,
                trackColor = MaterialTheme.colorScheme.surfaceVariant
            )
        }
    }
}

@Composable
private fun BadgeRow(badge: LocalBadge) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = if (badge.isEarned) {
            CardDefaults.cardColors()
        } else {
            CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
            )
        }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Badge icon
            val badgeIcon = when (badge.icon) {
                "flag" -> Icons.Filled.Flag
                "compass" -> Icons.Filled.Explore
                "backpack" -> Icons.Filled.Backpack
                "globe" -> Icons.Filled.Public
                "airplane" -> Icons.Filled.Flight
                "trophy" -> Icons.Filled.EmojiEvents
                "earth" -> Icons.Filled.TravelExplore
                "us_flag" -> Icons.Filled.Flag
                else -> Icons.Filled.Star
            }

            Icon(
                imageVector = badgeIcon,
                contentDescription = null,
                modifier = Modifier.size(36.dp),
                tint = if (badge.isEarned) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
                }
            )

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = badge.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = if (badge.isEarned) FontWeight.Bold else FontWeight.Normal,
                    color = if (badge.isEarned) {
                        MaterialTheme.colorScheme.onSurface
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    }
                )
                Text(
                    text = badge.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (!badge.isEarned) {
                    Spacer(modifier = Modifier.height(4.dp))
                    LinearProgressIndicator(
                        progress = { (badge.current.toFloat() / badge.requirement).coerceIn(0f, 1f) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(4.dp),
                        color = MaterialTheme.colorScheme.primary,
                        trackColor = MaterialTheme.colorScheme.surfaceVariant
                    )
                    Text(
                        text = "${badge.current} / ${badge.requirement}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            if (badge.isEarned) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = "Earned",
                    tint = Visited,
                    modifier = Modifier.size(24.dp)
                )
            }
        }
    }
}
