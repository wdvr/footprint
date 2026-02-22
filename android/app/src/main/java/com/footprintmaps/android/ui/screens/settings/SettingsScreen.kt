package com.footprintmaps.android.ui.screens.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@Composable
fun SettingsScreen(
    onNavigateToLogin: () -> Unit,
    onNavigateToFriends: () -> Unit,
    onNavigateToFeedback: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()

    // Clear data confirmation dialog
    if (uiState.showClearDataDialog) {
        AlertDialog(
            onDismissRequest = { viewModel.dismissClearDataDialog() },
            title = { Text("Clear All Data") },
            text = { Text("This will remove all visited places. This action cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = { viewModel.clearAllData() },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("Clear All")
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.dismissClearDataDialog() }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Delete account confirmation dialog
    if (uiState.showDeleteAccountDialog) {
        AlertDialog(
            onDismissRequest = { viewModel.dismissDeleteAccountDialog() },
            title = { Text("Delete Account") },
            text = { Text("This will permanently delete your account and all data. This action cannot be undone.") },
            confirmButton = {
                TextButton(
                    onClick = { viewModel.deleteAccount() },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("Delete")
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.dismissDeleteAccountDialog() }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Sign out confirmation dialog
    if (uiState.showSignOutDialog) {
        AlertDialog(
            onDismissRequest = { viewModel.dismissSignOutDialog() },
            title = { Text("Sign Out") },
            text = { Text("Are you sure you want to sign out? Your local data will be preserved.") },
            confirmButton = {
                TextButton(onClick = { viewModel.signOut() }) {
                    Text("Sign Out")
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.dismissSignOutDialog() }) {
                    Text("Cancel")
                }
            }
        )
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(vertical = 8.dp)
    ) {
        item {
            Text(
                text = "Settings",
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)
            )
        }

        // ==================== ACCOUNT ====================
        item { SectionHeader("Account") }

        if (uiState.isLoggedIn) {
            item {
                ListItem(
                    headlineContent = { Text(uiState.userName ?: "User") },
                    supportingContent = { Text(uiState.userEmail ?: "") },
                    leadingContent = {
                        Icon(Icons.Filled.AccountCircle, contentDescription = null)
                    }
                )
            }
        } else {
            item {
                ListItem(
                    headlineContent = { Text("Sign in") },
                    supportingContent = { Text("Sign in to sync across devices") },
                    leadingContent = {
                        Icon(Icons.Filled.AccountCircle, contentDescription = null)
                    },
                    modifier = Modifier.clickable { onNavigateToLogin() }
                )
            }

            item {
                ListItem(
                    headlineContent = { Text("Offline Mode") },
                    supportingContent = { Text("Data stored locally only") },
                    leadingContent = {
                        Icon(Icons.Filled.CloudOff, contentDescription = null)
                    },
                    trailingContent = {
                        Switch(
                            checked = uiState.offlineMode,
                            onCheckedChange = { viewModel.toggleOfflineMode(it) }
                        )
                    }
                )
            }
        }

        // ==================== SYNC ====================
        item { SectionHeader("Sync") }

        item {
            ListItem(
                headlineContent = { Text("Sync now") },
                supportingContent = {
                    when {
                        uiState.isSyncing -> Text("Syncing...")
                        uiState.syncMessage != null -> Text(uiState.syncMessage!!)
                        uiState.unsyncedCount > 0 -> Text("${uiState.unsyncedCount} unsynced changes")
                        else -> Text("All data is synced")
                    }
                },
                leadingContent = {
                    Icon(Icons.Filled.Sync, contentDescription = null)
                },
                trailingContent = {
                    if (uiState.isSyncing) {
                        CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    }
                },
                modifier = Modifier.clickable(enabled = !uiState.isSyncing) {
                    viewModel.syncNow()
                }
            )
        }

        item {
            ListItem(
                headlineContent = { Text("Last synced") },
                supportingContent = {
                    Text(uiState.lastSyncAt ?: "Never synced")
                },
                leadingContent = {
                    Icon(Icons.Filled.Schedule, contentDescription = null)
                }
            )
        }

        item {
            ListItem(
                headlineContent = { Text("Force full sync") },
                supportingContent = { Text("Re-download all data from server") },
                leadingContent = {
                    Icon(Icons.Filled.CloudDownload, contentDescription = null)
                },
                modifier = Modifier.clickable(enabled = !uiState.isSyncing) {
                    viewModel.syncNow()
                }
            )
        }

        // ==================== TRACKING ====================
        item { SectionHeader("Tracking") }

        item {
            ListItem(
                headlineContent = { Text("Auto-detect visits") },
                supportingContent = { Text("Use location to detect country visits") },
                leadingContent = {
                    Icon(Icons.Filled.MyLocation, contentDescription = null)
                },
                trailingContent = {
                    Switch(
                        checked = uiState.trackingEnabled,
                        onCheckedChange = { viewModel.toggleTracking(it) }
                    )
                }
            )
        }

        // ==================== APPEARANCE ====================
        item { SectionHeader("Appearance") }

        item {
            var expanded by remember { mutableStateOf(false) }
            ListItem(
                headlineContent = { Text("Theme") },
                supportingContent = {
                    Text(
                        when (uiState.darkMode) {
                            "light" -> "Light"
                            "dark" -> "Dark"
                            else -> "System"
                        }
                    )
                },
                leadingContent = {
                    Icon(Icons.Filled.Palette, contentDescription = null)
                },
                modifier = Modifier.clickable { expanded = true }
            )

            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                DropdownMenuItem(
                    text = { Text("System") },
                    onClick = { viewModel.setDarkMode("system"); expanded = false }
                )
                DropdownMenuItem(
                    text = { Text("Light") },
                    onClick = { viewModel.setDarkMode("light"); expanded = false }
                )
                DropdownMenuItem(
                    text = { Text("Dark") },
                    onClick = { viewModel.setDarkMode("dark"); expanded = false }
                )
            }
        }

        // ==================== SOCIAL ====================
        item { SectionHeader("Social") }

        item {
            ListItem(
                headlineContent = { Text("Friends") },
                supportingContent = { Text("Compare travel stats with friends") },
                leadingContent = {
                    Icon(Icons.Filled.People, contentDescription = null)
                },
                trailingContent = {
                    Icon(Icons.Filled.ChevronRight, contentDescription = null)
                },
                modifier = Modifier.clickable { onNavigateToFriends() }
            )
        }

        item {
            ListItem(
                headlineContent = { Text("Feedback") },
                supportingContent = { Text("Report bugs or suggest features") },
                leadingContent = {
                    Icon(Icons.Filled.Feedback, contentDescription = null)
                },
                trailingContent = {
                    Icon(Icons.Filled.ChevronRight, contentDescription = null)
                },
                modifier = Modifier.clickable { onNavigateToFeedback() }
            )
        }

        // ==================== DATA MANAGEMENT ====================
        item { SectionHeader("Data Management") }

        item {
            ListItem(
                headlineContent = { Text("Backup Data") },
                supportingContent = { Text("Export your data to a backup file") },
                leadingContent = {
                    Icon(Icons.Filled.Backup, contentDescription = null)
                },
                modifier = Modifier.clickable { /* TODO: Implement backup */ }
            )
        }

        item {
            ListItem(
                headlineContent = { Text("Restore Backup") },
                supportingContent = { Text("Import data from a backup file") },
                leadingContent = {
                    Icon(Icons.Filled.Restore, contentDescription = null)
                },
                modifier = Modifier.clickable { /* TODO: Implement restore */ }
            )
        }

        item {
            ListItem(
                headlineContent = {
                    Text("Clear All Visited Places", color = MaterialTheme.colorScheme.error)
                },
                supportingContent = {
                    Text("Remove all ${uiState.visitedCount} visited places")
                },
                leadingContent = {
                    Icon(
                        Icons.Filled.DeleteForever,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.error
                    )
                },
                modifier = Modifier.clickable { viewModel.showClearDataDialog() }
            )
        }

        // ==================== ABOUT ====================
        item { SectionHeader("About") }

        item {
            ListItem(
                headlineContent = { Text("Version") },
                supportingContent = { Text(uiState.appVersion) },
                leadingContent = {
                    Icon(Icons.Filled.Info, contentDescription = null)
                }
            )
        }

        item {
            ListItem(
                headlineContent = { Text("Build") },
                supportingContent = { Text(uiState.appBuild) },
                leadingContent = {
                    Icon(Icons.Filled.Build, contentDescription = null)
                }
            )
        }

        // ==================== DANGER ZONE ====================
        if (uiState.isLoggedIn) {
            item { SectionHeader("Account Actions") }

            item {
                ListItem(
                    headlineContent = {
                        Text("Sign out", color = MaterialTheme.colorScheme.error)
                    },
                    leadingContent = {
                        Icon(
                            Icons.AutoMirrored.Filled.Logout,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error
                        )
                    },
                    modifier = Modifier.clickable { viewModel.showSignOutDialog() }
                )
            }

            item {
                ListItem(
                    headlineContent = {
                        Text("Delete Account", color = MaterialTheme.colorScheme.error)
                    },
                    supportingContent = {
                        Text("Permanently delete your account and all data")
                    },
                    leadingContent = {
                        Icon(
                            Icons.Filled.PersonRemove,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error
                        )
                    },
                    modifier = Modifier.clickable { viewModel.showDeleteAccountDialog() }
                )
            }
        }

        // Bottom spacer
        item { Spacer(modifier = Modifier.height(32.dp)) }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
    )
}
