package com.footprintmaps.android.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ExtendedStats(
    @SerialName("countries_visited") val countriesVisited: Int = 0,
    @SerialName("countries_bucket_list") val countriesBucketList: Int = 0,
    @SerialName("us_states_visited") val usStatesVisited: Int = 0,
    @SerialName("continents_visited") val continentsVisited: Int = 0,
    @SerialName("continent_stats") val continentStats: List<ContinentStats> = emptyList(),
    @SerialName("timezone_stats") val timezoneStats: TimeZoneStats? = null,
    val badges: List<Badge> = emptyList(),
    @SerialName("badge_progress") val badgeProgress: List<BadgeProgress> = emptyList()
)

@Serializable
data class ContinentStats(
    val continent: String,
    val visited: Int = 0,
    val total: Int = 0,
    val percentage: Double = 0.0
)

@Serializable
data class TimeZoneStats(
    @SerialName("timezones_visited") val timezonesVisited: Int = 0,
    @SerialName("total_timezones") val totalTimezones: Int = 0,
    val coverage: Double = 0.0
)

@Serializable
data class Badge(
    val id: String,
    val name: String,
    val description: String,
    val icon: String? = null,
    @SerialName("earned_at") val earnedAt: String? = null
)

@Serializable
data class BadgeProgress(
    @SerialName("badge_id") val badgeId: String,
    val name: String,
    val description: String,
    val progress: Double = 0.0,
    val target: Int = 0,
    val current: Int = 0
)

@Serializable
data class LeaderboardEntry(
    @SerialName("user_id") val userId: String,
    val name: String,
    @SerialName("profile_picture") val profilePicture: String? = null,
    @SerialName("countries_visited") val countriesVisited: Int = 0,
    val rank: Int = 0
)

@Serializable
data class FriendDto(
    val id: String,
    val name: String,
    val email: String? = null,
    @SerialName("profile_picture") val profilePicture: String? = null,
    @SerialName("countries_visited") val countriesVisited: Int = 0
)

@Serializable
data class FeedbackRequest(
    val type: String,  // "bug", "feature", "improvement"
    val message: String,
    @SerialName("app_version") val appVersion: String? = null,
    @SerialName("device_info") val deviceInfo: String? = null
)

@Serializable
data class HealthResponse(
    val status: String,
    val version: String? = null
)
