package com.footprintmaps.android.ui.screens.map

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.footprintmaps.android.domain.model.GeographicData
import com.footprintmaps.android.ui.theme.BucketList
import com.footprintmaps.android.ui.theme.Visited
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorldMapScreen(
    onNavigateToCountry: (String) -> Unit,
    viewModel: WorldMapViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    Box(modifier = Modifier.fillMaxSize()) {
        // Google Maps with markers
        val cameraPositionState = rememberCameraPositionState {
            position = CameraPosition.fromLatLngZoom(LatLng(20.0, 0.0), 2f)
        }

        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            uiSettings = MapUiSettings(
                zoomControlsEnabled = false,
                mapToolbarEnabled = false,
                myLocationButtonEnabled = false
            ),
            properties = MapProperties(
                mapType = MapType.NORMAL
            )
        ) {
            // Visited country markers (green)
            uiState.visitedCountryCodes.forEach { code ->
                val centroid = CountryCentroids.centroids[code]
                val country = GeographicData.countryByCode(code)
                if (centroid != null && country != null) {
                    Marker(
                        state = MarkerState(position = centroid),
                        title = country.name,
                        snippet = "Visited",
                        icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN),
                        onClick = {
                            viewModel.selectCountry(code)
                            true
                        }
                    )
                }
            }

            // Bucket list country markers (orange)
            uiState.bucketListCountryCodes.forEach { code ->
                val centroid = CountryCentroids.centroids[code]
                val country = GeographicData.countryByCode(code)
                if (centroid != null && country != null) {
                    Marker(
                        state = MarkerState(position = centroid),
                        title = country.name,
                        snippet = "Bucket List",
                        icon = BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_ORANGE),
                        onClick = {
                            viewModel.selectCountry(code)
                            true
                        }
                    )
                }
            }
        }

        // Stats overlay at top
        Card(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.9f)
            )
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                val visitedCount = uiState.visitedCountryCodes.size
                val bucketCount = uiState.bucketListCountryCodes.size
                val totalCount = GeographicData.countries.size

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "$visitedCount",
                        style = MaterialTheme.typography.titleLarge,
                        color = Visited
                    )
                    Text(
                        text = "visited",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Text(
                    text = "/",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "$totalCount",
                        style = MaterialTheme.typography.titleLarge
                    )
                    Text(
                        text = "countries",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                if (bucketCount > 0) {
                    Text(
                        text = "|",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "$bucketCount",
                            style = MaterialTheme.typography.titleLarge,
                            color = BucketList
                        )
                        Text(
                            text = "bucket list",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }

        // Country info bottom sheet
        if (uiState.showCountrySheet && uiState.selectedCountryCode != null) {
            val country = GeographicData.countryByCode(uiState.selectedCountryCode!!)
            if (country != null) {
                val place = uiState.allPlaces[country.code]
                val isVisited = place?.status == "visited"
                val isBucketList = place?.status == "bucket_list"

                ModalBottomSheet(
                    onDismissRequest = { viewModel.dismissCountrySheet() },
                    sheetState = sheetState
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 24.dp, vertical = 16.dp)
                    ) {
                        // Flag + name
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Text(
                                text = GeographicData.flagEmoji(country.code),
                                style = MaterialTheme.typography.headlineLarge
                            )
                            Column {
                                Text(
                                    text = country.name,
                                    style = MaterialTheme.typography.headlineSmall
                                )
                                Text(
                                    text = country.continent.displayName,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(20.dp))

                        // Action buttons
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            // Mark visited button
                            FilledTonalButton(
                                onClick = { viewModel.toggleVisited(country) },
                                modifier = Modifier.weight(1f),
                                colors = if (isVisited) {
                                    ButtonDefaults.filledTonalButtonColors(
                                        containerColor = Visited.copy(alpha = 0.2f),
                                        contentColor = Visited
                                    )
                                } else {
                                    ButtonDefaults.filledTonalButtonColors()
                                }
                            ) {
                                Icon(
                                    imageVector = if (isVisited) Icons.Filled.CheckCircle else Icons.Filled.AddCircleOutline,
                                    contentDescription = null,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(if (isVisited) "Visited" else "Mark Visited")
                            }

                            // Bucket list button
                            FilledTonalButton(
                                onClick = { viewModel.toggleBucketList(country) },
                                modifier = Modifier.weight(1f),
                                colors = if (isBucketList) {
                                    ButtonDefaults.filledTonalButtonColors(
                                        containerColor = BucketList.copy(alpha = 0.2f),
                                        contentColor = BucketList
                                    )
                                } else {
                                    ButtonDefaults.filledTonalButtonColors()
                                }
                            ) {
                                Icon(
                                    imageVector = if (isBucketList) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder,
                                    contentDescription = null,
                                    modifier = Modifier.size(18.dp)
                                )
                                Spacer(modifier = Modifier.width(6.dp))
                                Text(if (isBucketList) "Bucket List" else "Add to List")
                            }
                        }

                        // View details button
                        if (country.hasStates) {
                            Spacer(modifier = Modifier.height(8.dp))
                            OutlinedButton(
                                onClick = {
                                    viewModel.dismissCountrySheet()
                                    onNavigateToCountry(country.code)
                                },
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Icon(Icons.Filled.Map, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("View ${when (GeographicData.regionTypeForCountry(country.code)) {
                                    com.footprintmaps.android.domain.model.RegionType.US_STATE -> "States"
                                    com.footprintmaps.android.domain.model.RegionType.CANADIAN_PROVINCE -> "Provinces"
                                    com.footprintmaps.android.domain.model.RegionType.AUSTRALIAN_STATE -> "States"
                                    com.footprintmaps.android.domain.model.RegionType.MEXICAN_STATE -> "States"
                                    com.footprintmaps.android.domain.model.RegionType.BRAZILIAN_STATE -> "States"
                                    com.footprintmaps.android.domain.model.RegionType.GERMAN_STATE -> "States"
                                    com.footprintmaps.android.domain.model.RegionType.FRENCH_REGION -> "Regions"
                                    com.footprintmaps.android.domain.model.RegionType.SPANISH_COMMUNITY -> "Communities"
                                    com.footprintmaps.android.domain.model.RegionType.ITALIAN_REGION -> "Regions"
                                    com.footprintmaps.android.domain.model.RegionType.DUTCH_PROVINCE -> "Provinces"
                                    com.footprintmaps.android.domain.model.RegionType.BELGIAN_PROVINCE -> "Provinces"
                                    com.footprintmaps.android.domain.model.RegionType.UK_COUNTRY -> "Countries"
                                    com.footprintmaps.android.domain.model.RegionType.RUSSIAN_FEDERAL_SUBJECT -> "Federal Subjects"
                                    com.footprintmaps.android.domain.model.RegionType.ARGENTINE_PROVINCE -> "Provinces"
                                    com.footprintmaps.android.domain.model.RegionType.COUNTRY -> "Regions"
                                    null -> "Regions"
                                }}")
                            }
                        }

                        // Remove button
                        if (isVisited || isBucketList) {
                            Spacer(modifier = Modifier.height(8.dp))
                            TextButton(
                                onClick = {
                                    viewModel.removePlace(country)
                                    viewModel.dismissCountrySheet()
                                },
                                modifier = Modifier.fillMaxWidth(),
                                colors = ButtonDefaults.textButtonColors(
                                    contentColor = MaterialTheme.colorScheme.error
                                )
                            ) {
                                Icon(Icons.Filled.Delete, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Remove")
                            }
                        }

                        // More details link
                        TextButton(
                            onClick = {
                                viewModel.dismissCountrySheet()
                                onNavigateToCountry(country.code)
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text("View Details")
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(Icons.Filled.ChevronRight, contentDescription = null, modifier = Modifier.size(18.dp))
                        }

                        Spacer(modifier = Modifier.height(16.dp))
                    }
                }
            }
        }
    }
}

/**
 * Centroids for country markers on the map.
 * These are approximate geographic centers used for marker placement.
 */
object CountryCentroids {
    val centroids: Map<String, LatLng> = mapOf(
        // Africa
        "DZ" to LatLng(28.0339, 1.6596),
        "AO" to LatLng(-11.2027, 17.8739),
        "BJ" to LatLng(9.3077, 2.3158),
        "BW" to LatLng(-22.3285, 24.6849),
        "BF" to LatLng(12.2383, -1.5616),
        "BI" to LatLng(-3.3731, 29.9189),
        "CV" to LatLng(16.5388, -23.0418),
        "CM" to LatLng(7.3697, 12.3547),
        "CF" to LatLng(6.6111, 20.9394),
        "TD" to LatLng(15.4542, 18.7322),
        "KM" to LatLng(-11.6455, 43.3333),
        "CG" to LatLng(-0.2280, 15.8277),
        "CD" to LatLng(-4.0383, 21.7587),
        "CI" to LatLng(7.5400, -5.5471),
        "DJ" to LatLng(11.5721, 43.1456),
        "EG" to LatLng(26.8206, 30.8025),
        "GQ" to LatLng(1.6508, 10.2679),
        "ER" to LatLng(15.1794, 39.7823),
        "SZ" to LatLng(-26.5225, 31.4659),
        "ET" to LatLng(9.1450, 40.4897),
        "GA" to LatLng(-0.8037, 11.6094),
        "GM" to LatLng(13.4432, -15.3101),
        "GH" to LatLng(7.9465, -1.0232),
        "GN" to LatLng(9.9456, -9.6966),
        "GW" to LatLng(11.8037, -15.1804),
        "KE" to LatLng(-0.0236, 37.9062),
        "LS" to LatLng(-29.6100, 28.2336),
        "LR" to LatLng(6.4281, -9.4295),
        "LY" to LatLng(26.3351, 17.2283),
        "MG" to LatLng(-18.7669, 46.8691),
        "MW" to LatLng(-13.2543, 34.3015),
        "ML" to LatLng(17.5707, -3.9962),
        "MR" to LatLng(21.0079, -10.9408),
        "MU" to LatLng(-20.3484, 57.5522),
        "MA" to LatLng(31.7917, -7.0926),
        "MZ" to LatLng(-18.6657, 35.5296),
        "NA" to LatLng(-22.9576, 18.4904),
        "NE" to LatLng(17.6078, 8.0817),
        "NG" to LatLng(9.0820, 8.6753),
        "RW" to LatLng(-1.9403, 29.8739),
        "ST" to LatLng(0.1864, 6.6131),
        "SN" to LatLng(14.4974, -14.4524),
        "SC" to LatLng(-4.6796, 55.4920),
        "SL" to LatLng(8.4606, -11.7799),
        "SO" to LatLng(5.1521, 46.1996),
        "ZA" to LatLng(-30.5595, 22.9375),
        "SS" to LatLng(6.8770, 31.3070),
        "SD" to LatLng(12.8628, 30.2176),
        "TZ" to LatLng(-6.3690, 34.8888),
        "TG" to LatLng(8.6195, 0.8248),
        "TN" to LatLng(33.8869, 9.5375),
        "UG" to LatLng(1.3733, 32.2903),
        "ZM" to LatLng(-13.1339, 27.8493),
        "ZW" to LatLng(-19.0154, 29.1549),

        // Asia
        "AF" to LatLng(33.9391, 67.7100),
        "AM" to LatLng(40.0691, 45.0382),
        "AZ" to LatLng(40.1431, 47.5769),
        "BH" to LatLng(26.0667, 50.5577),
        "BD" to LatLng(23.6850, 90.3563),
        "BT" to LatLng(27.5142, 90.4336),
        "BN" to LatLng(4.5353, 114.7277),
        "KH" to LatLng(12.5657, 104.9910),
        "CN" to LatLng(35.8617, 104.1954),
        "CY" to LatLng(35.1264, 33.4299),
        "GE" to LatLng(42.3154, 43.3569),
        "IN" to LatLng(20.5937, 78.9629),
        "ID" to LatLng(-0.7893, 113.9213),
        "IR" to LatLng(32.4279, 53.6880),
        "IQ" to LatLng(33.2232, 43.6793),
        "IL" to LatLng(31.0461, 34.8516),
        "JP" to LatLng(36.2048, 138.2529),
        "JO" to LatLng(30.5852, 36.2384),
        "KZ" to LatLng(48.0196, 66.9237),
        "KW" to LatLng(29.3117, 47.4818),
        "KG" to LatLng(41.2044, 74.7661),
        "LA" to LatLng(19.8563, 102.4955),
        "LB" to LatLng(33.8547, 35.8623),
        "MY" to LatLng(4.2105, 101.9758),
        "MV" to LatLng(3.2028, 73.2207),
        "MN" to LatLng(46.8625, 103.8467),
        "MM" to LatLng(21.9162, 95.9560),
        "NP" to LatLng(28.3949, 84.1240),
        "KP" to LatLng(40.3399, 127.5101),
        "OM" to LatLng(21.4735, 55.9754),
        "PK" to LatLng(30.3753, 69.3451),
        "PS" to LatLng(31.9522, 35.2332),
        "PH" to LatLng(12.8797, 121.7740),
        "QA" to LatLng(25.3548, 51.1839),
        "SA" to LatLng(23.8859, 45.0792),
        "SG" to LatLng(1.3521, 103.8198),
        "KR" to LatLng(35.9078, 127.7669),
        "LK" to LatLng(7.8731, 80.7718),
        "SY" to LatLng(34.8021, 38.9968),
        "TW" to LatLng(23.6978, 120.9605),
        "TJ" to LatLng(38.8610, 71.2761),
        "TH" to LatLng(15.8700, 100.9925),
        "TL" to LatLng(-8.8742, 125.7275),
        "TR" to LatLng(38.9637, 35.2433),
        "TM" to LatLng(38.9697, 59.5563),
        "AE" to LatLng(23.4241, 53.8478),
        "UZ" to LatLng(41.3775, 64.5853),
        "VN" to LatLng(14.0583, 108.2772),
        "YE" to LatLng(15.5527, 48.5164),

        // Europe
        "AL" to LatLng(41.1533, 20.1683),
        "AD" to LatLng(42.5063, 1.5218),
        "AT" to LatLng(47.5162, 14.5501),
        "BY" to LatLng(53.7098, 27.9534),
        "BE" to LatLng(50.5039, 4.4699),
        "BA" to LatLng(43.9159, 17.6791),
        "BG" to LatLng(42.7339, 25.4858),
        "HR" to LatLng(45.1000, 15.2000),
        "CZ" to LatLng(49.8175, 15.4730),
        "DK" to LatLng(56.2639, 9.5018),
        "EE" to LatLng(58.5953, 25.0136),
        "FI" to LatLng(61.9241, 25.7482),
        "FR" to LatLng(46.2276, 2.2137),
        "DE" to LatLng(51.1657, 10.4515),
        "GR" to LatLng(39.0742, 21.8243),
        "HU" to LatLng(47.1625, 19.5033),
        "IS" to LatLng(64.9631, -19.0208),
        "IE" to LatLng(53.1424, -7.6921),
        "IT" to LatLng(41.8719, 12.5674),
        "LV" to LatLng(56.8796, 24.6032),
        "LI" to LatLng(47.1660, 9.5554),
        "LT" to LatLng(55.1694, 23.8813),
        "LU" to LatLng(49.8153, 6.1296),
        "MT" to LatLng(35.9375, 14.3754),
        "MD" to LatLng(47.4116, 28.3699),
        "MC" to LatLng(43.7384, 7.4246),
        "ME" to LatLng(42.7087, 19.3744),
        "NL" to LatLng(52.1326, 5.2913),
        "MK" to LatLng(41.5124, 21.7453),
        "NO" to LatLng(60.4720, 8.4689),
        "PL" to LatLng(51.9194, 19.1451),
        "PT" to LatLng(39.3999, -8.2245),
        "RO" to LatLng(45.9432, 24.9668),
        "RU" to LatLng(61.5240, 105.3188),
        "SM" to LatLng(43.9424, 12.4578),
        "RS" to LatLng(44.0165, 21.0059),
        "SK" to LatLng(48.6690, 19.6990),
        "SI" to LatLng(46.1512, 14.9955),
        "ES" to LatLng(40.4637, -3.7492),
        "SE" to LatLng(60.1282, 18.6435),
        "CH" to LatLng(46.8182, 8.2275),
        "UA" to LatLng(48.3794, 31.1656),
        "GB" to LatLng(55.3781, -3.4360),
        "VA" to LatLng(41.9029, 12.4534),

        // North America
        "AG" to LatLng(17.0608, -61.7964),
        "BS" to LatLng(25.0343, -77.3963),
        "BB" to LatLng(13.1939, -59.5432),
        "BZ" to LatLng(17.1899, -88.4976),
        "CA" to LatLng(56.1304, -106.3468),
        "CR" to LatLng(9.7489, -83.7534),
        "CU" to LatLng(21.5218, -77.7812),
        "DM" to LatLng(15.4150, -61.3710),
        "DO" to LatLng(18.7357, -70.1627),
        "SV" to LatLng(13.7942, -88.8965),
        "GD" to LatLng(12.1165, -61.6790),
        "GT" to LatLng(15.7835, -90.2308),
        "HT" to LatLng(18.9712, -72.2852),
        "HN" to LatLng(15.2000, -86.2419),
        "JM" to LatLng(18.1096, -77.2975),
        "MX" to LatLng(23.6345, -102.5528),
        "NI" to LatLng(12.8654, -85.2072),
        "PA" to LatLng(8.5380, -80.7821),
        "KN" to LatLng(17.3578, -62.7830),
        "LC" to LatLng(13.9094, -60.9789),
        "VC" to LatLng(12.9843, -61.2872),
        "TT" to LatLng(10.6918, -61.2225),
        "US" to LatLng(37.0902, -95.7129),

        // South America
        "AR" to LatLng(-38.4161, -63.6167),
        "BO" to LatLng(-16.2902, -63.5887),
        "BR" to LatLng(-14.2350, -51.9253),
        "CL" to LatLng(-35.6751, -71.5430),
        "CO" to LatLng(4.5709, -74.2973),
        "EC" to LatLng(-1.8312, -78.1834),
        "GY" to LatLng(4.8604, -58.9302),
        "PY" to LatLng(-23.4425, -58.4438),
        "PE" to LatLng(-9.1900, -75.0152),
        "SR" to LatLng(3.9193, -56.0278),
        "UY" to LatLng(-32.5228, -55.7658),
        "VE" to LatLng(6.4238, -66.5897),

        // Oceania
        "AU" to LatLng(-25.2744, 133.7751),
        "FJ" to LatLng(-17.7134, 178.0650),
        "KI" to LatLng(-3.3704, -168.7340),
        "MH" to LatLng(7.1315, 171.1845),
        "FM" to LatLng(7.4256, 150.5508),
        "NR" to LatLng(-0.5228, 166.9315),
        "NZ" to LatLng(-40.9006, 174.8860),
        "PW" to LatLng(7.5150, 134.5825),
        "PG" to LatLng(-6.3150, 143.9555),
        "WS" to LatLng(-13.7590, -172.1046),
        "SB" to LatLng(-9.6457, 160.1562),
        "TO" to LatLng(-21.1790, -175.1982),
        "TV" to LatLng(-7.1095, 177.6493),
        "VU" to LatLng(-15.3767, 166.9592)
    )
}
