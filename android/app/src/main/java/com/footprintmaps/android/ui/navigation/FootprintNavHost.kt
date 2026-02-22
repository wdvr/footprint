package com.footprintmaps.android.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.footprintmaps.android.ui.screens.countries.CountryDetailScreen
import com.footprintmaps.android.ui.screens.countries.CountryListScreen
import com.footprintmaps.android.ui.screens.feedback.FeedbackScreen
import com.footprintmaps.android.ui.screens.friends.FriendsScreen
import com.footprintmaps.android.ui.screens.login.LoginScreen
import com.footprintmaps.android.ui.screens.map.WorldMapScreen
import com.footprintmaps.android.ui.screens.memories.MemoriesScreen
import com.footprintmaps.android.ui.screens.onboarding.OnboardingScreen
import com.footprintmaps.android.ui.screens.settings.SettingsScreen
import com.footprintmaps.android.ui.screens.stats.StatsScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FootprintNavHost() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    val bottomNavScreens = BottomNavItem.entries.map { it.screen.route }
    val showBottomBar = currentDestination?.route in bottomNavScreens

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                NavigationBar {
                    BottomNavItem.entries.forEach { item ->
                        val selected = currentDestination?.hierarchy?.any {
                            it.route == item.screen.route
                        } == true

                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(item.screen.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = if (selected) item.selectedIcon else item.unselectedIcon,
                                    contentDescription = item.title
                                )
                            },
                            label = { Text(item.title) }
                        )
                    }
                }
            }
        }
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = Screen.Map.route,
            modifier = Modifier.padding(paddingValues)
        ) {
            composable(Screen.Login.route) {
                LoginScreen(
                    onLoginSuccess = {
                        navController.navigate(Screen.Map.route) {
                            popUpTo(Screen.Login.route) { inclusive = true }
                        }
                    },
                    onSkip = {
                        navController.navigate(Screen.Map.route) {
                            popUpTo(Screen.Login.route) { inclusive = true }
                        }
                    }
                )
            }

            composable(Screen.Onboarding.route) {
                OnboardingScreen(
                    onComplete = {
                        navController.navigate(Screen.Map.route) {
                            popUpTo(Screen.Onboarding.route) { inclusive = true }
                        }
                    }
                )
            }

            composable(Screen.Map.route) {
                WorldMapScreen(
                    onNavigateToCountry = { code ->
                        navController.navigate(Screen.CountryDetail.createRoute(code))
                    }
                )
            }

            composable(Screen.Countries.route) {
                CountryListScreen(
                    onNavigateToCountry = { code ->
                        navController.navigate(Screen.CountryDetail.createRoute(code))
                    }
                )
            }

            composable(Screen.Stats.route) {
                StatsScreen()
            }

            composable(Screen.Memories.route) {
                MemoriesScreen()
            }

            composable(Screen.Settings.route) {
                SettingsScreen(
                    onNavigateToLogin = {
                        navController.navigate(Screen.Login.route)
                    },
                    onNavigateToFriends = {
                        navController.navigate(Screen.Friends.route)
                    },
                    onNavigateToFeedback = {
                        navController.navigate(Screen.Feedback.route)
                    }
                )
            }

            composable(Screen.Friends.route) {
                FriendsScreen(
                    onBack = { navController.popBackStack() }
                )
            }

            composable(Screen.Feedback.route) {
                FeedbackScreen(
                    onBack = { navController.popBackStack() }
                )
            }

            composable(
                route = Screen.CountryDetail.route,
                arguments = listOf(navArgument("countryCode") { type = NavType.StringType })
            ) { backStackEntry ->
                val countryCode = backStackEntry.arguments?.getString("countryCode") ?: return@composable
                CountryDetailScreen(
                    countryCode = countryCode,
                    onBack = { navController.popBackStack() },
                    onNavigateToStateMap = { code ->
                        navController.navigate(Screen.StateMap.createRoute(code))
                    }
                )
            }

            composable(
                route = Screen.StateMap.route,
                arguments = listOf(navArgument("countryCode") { type = NavType.StringType })
            ) {
                // Placeholder for state map
                WorldMapScreen(
                    onNavigateToCountry = { code ->
                        navController.navigate(Screen.CountryDetail.createRoute(code))
                    }
                )
            }
        }
    }
}
