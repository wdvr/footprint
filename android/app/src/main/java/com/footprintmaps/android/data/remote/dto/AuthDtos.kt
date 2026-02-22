package com.footprintmaps.android.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class GoogleSignInRequest(
    @SerialName("id_token") val idToken: String,
    val platform: String = "android"
)

@Serializable
data class RefreshTokenRequest(
    @SerialName("refresh_token") val refreshToken: String
)

@Serializable
data class AuthResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    val user: UserResponse
)

@Serializable
data class TokensResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String
)

@Serializable
data class UserResponse(
    val id: String,
    val email: String,
    val name: String? = null,
    @SerialName("profile_picture") val profilePicture: String? = null,
    @SerialName("created_at") val createdAt: String? = null
)
