package com.footprintmaps.android.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.ui.graphics.vector.ImageVector

sealed class Screen(val route: String) {
    data object Login : Screen("login")
    data object Onboarding : Screen("onboarding")
    data object Map : Screen("map")
    data object Countries : Screen("countries")
    data object Stats : Screen("stats")
    data object Memories : Screen("memories")
    data object Settings : Screen("settings")
    data object Friends : Screen("friends")
    data object Feedback : Screen("feedback")
    data object CountryDetail : Screen("country_detail/{countryCode}") {
        fun createRoute(countryCode: String) = "country_detail/$countryCode"
    }
    data object StateMap : Screen("state_map/{countryCode}") {
        fun createRoute(countryCode: String) = "state_map/$countryCode"
    }
}

enum class BottomNavItem(
    val screen: Screen,
    val title: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    MAP(
        screen = Screen.Map,
        title = "Map",
        selectedIcon = Icons.Filled.Map,
        unselectedIcon = Icons.Outlined.Map
    ),
    COUNTRIES(
        screen = Screen.Countries,
        title = "Countries",
        selectedIcon = Icons.Filled.Public,
        unselectedIcon = Icons.Outlined.Public
    ),
    STATS(
        screen = Screen.Stats,
        title = "Stats",
        selectedIcon = Icons.Filled.BarChart,
        unselectedIcon = Icons.Outlined.BarChart
    ),
    MEMORIES(
        screen = Screen.Memories,
        title = "Memories",
        selectedIcon = Icons.Filled.PhotoLibrary,
        unselectedIcon = Icons.Outlined.PhotoLibrary
    ),
    SETTINGS(
        screen = Screen.Settings,
        title = "Settings",
        selectedIcon = Icons.Filled.Settings,
        unselectedIcon = Icons.Outlined.Settings
    )
}
