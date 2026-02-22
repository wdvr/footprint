package com.footprintmaps.android.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import java.time.LocalDate
import java.time.Year
import java.time.format.DateTimeFormatter

sealed class VisitDateResult {
    data class ThisYear(val year: Int = Year.now().value) : VisitDateResult()
    data class PickedYear(val year: Int) : VisitDateResult()
    data class PickedDate(val date: LocalDate) : VisitDateResult()
    data object Skipped : VisitDateResult()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VisitDatePickerSheet(
    onResult: (VisitDateResult) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var mode by remember { mutableStateOf<DatePickerMode>(DatePickerMode.Main) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp)
        ) {
            Text(
                text = "When did you visit?",
                style = MaterialTheme.typography.headlineSmall,
                modifier = Modifier.padding(bottom = 20.dp)
            )

            when (mode) {
                is DatePickerMode.Main -> {
                    MainDateOptions(
                        onThisYear = {
                            onResult(VisitDateResult.ThisYear())
                        },
                        onPickYear = {
                            mode = DatePickerMode.YearPicker
                        },
                        onPickDate = {
                            mode = DatePickerMode.DatePicker
                        },
                        onSkip = {
                            onResult(VisitDateResult.Skipped)
                        }
                    )
                }
                is DatePickerMode.YearPicker -> {
                    YearPickerContent(
                        onYearSelected = { year ->
                            onResult(VisitDateResult.PickedYear(year))
                        },
                        onBack = {
                            mode = DatePickerMode.Main
                        }
                    )
                }
                is DatePickerMode.DatePicker -> {
                    FullDatePickerContent(
                        onDateSelected = { date ->
                            onResult(VisitDateResult.PickedDate(date))
                        },
                        onBack = {
                            mode = DatePickerMode.Main
                        }
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

private sealed class DatePickerMode {
    data object Main : DatePickerMode()
    data object YearPicker : DatePickerMode()
    data object DatePicker : DatePickerMode()
}

@Composable
private fun MainDateOptions(
    onThisYear: () -> Unit,
    onPickYear: () -> Unit,
    onPickDate: () -> Unit,
    onSkip: () -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // This year
        DateOptionButton(
            icon = Icons.Filled.CalendarToday,
            text = "This year",
            subtitle = "${Year.now().value}",
            onClick = onThisYear
        )

        // Pick a year
        DateOptionButton(
            icon = Icons.Filled.DateRange,
            text = "Pick a year",
            subtitle = "Choose the year you visited",
            onClick = onPickYear
        )

        // Pick a date
        DateOptionButton(
            icon = Icons.Filled.EditCalendar,
            text = "Pick a date",
            subtitle = "Choose the exact date",
            onClick = onPickDate
        )

        Spacer(modifier = Modifier.height(8.dp))

        // Skip
        TextButton(
            onClick = onSkip,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Skip")
        }
    }
}

@Composable
private fun DateOptionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    text: String,
    subtitle: String,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(24.dp)
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = text,
                    style = MaterialTheme.typography.titleMedium
                )
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun YearPickerContent(
    onYearSelected: (Int) -> Unit,
    onBack: () -> Unit
) {
    val currentYear = Year.now().value
    val years = (currentYear downTo 1950).toList()

    Column {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(bottom = 12.dp)
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
            Text(
                text = "Pick a year",
                style = MaterialTheme.typography.titleMedium
            )
        }

        LazyVerticalGrid(
            columns = GridCells.Fixed(4),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.heightIn(max = 400.dp)
        ) {
            items(years) { year ->
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onYearSelected(year) },
                    shape = MaterialTheme.shapes.medium,
                    color = if (year == currentYear) {
                        MaterialTheme.colorScheme.primaryContainer
                    } else {
                        MaterialTheme.colorScheme.surfaceVariant
                    }
                ) {
                    Text(
                        text = "$year",
                        modifier = Modifier.padding(12.dp),
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.bodyLarge,
                        fontWeight = if (year == currentYear) FontWeight.Bold else FontWeight.Normal,
                        color = if (year == currentYear) {
                            MaterialTheme.colorScheme.onPrimaryContainer
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FullDatePickerContent(
    onDateSelected: (LocalDate) -> Unit,
    onBack: () -> Unit
) {
    val datePickerState = rememberDatePickerState()

    Column {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(bottom = 12.dp)
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
            Text(
                text = "Pick a date",
                style = MaterialTheme.typography.titleMedium
            )
        }

        DatePicker(
            state = datePickerState,
            modifier = Modifier.fillMaxWidth(),
            showModeToggle = true
        )

        Spacer(modifier = Modifier.height(8.dp))

        Button(
            onClick = {
                datePickerState.selectedDateMillis?.let { millis ->
                    val date = java.time.Instant.ofEpochMilli(millis)
                        .atZone(java.time.ZoneId.systemDefault())
                        .toLocalDate()
                    onDateSelected(date)
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = datePickerState.selectedDateMillis != null
        ) {
            Text("Confirm")
        }
    }
}
