package com.footprintmaps.android.data.remote.api

import com.footprintmaps.android.data.remote.dto.*
import retrofit2.Response
import retrofit2.http.*

interface FootprintApi {

    // Auth
    @POST("auth/google")
    suspend fun googleSignIn(@Body request: GoogleSignInRequest): Response<AuthResponse>

    @POST("auth/refresh")
    suspend fun refreshToken(@Body request: RefreshTokenRequest): Response<TokensResponse>

    @GET("auth/me")
    suspend fun getCurrentUser(): Response<UserResponse>

    // Places
    @GET("places")
    suspend fun getPlaces(): Response<List<PlaceDto>>

    @POST("places")
    suspend fun createPlace(@Body request: CreatePlaceRequest): Response<PlaceDto>

    @DELETE("places/{type}/{code}")
    suspend fun deletePlace(
        @Path("type") type: String,
        @Path("code") code: String
    ): Response<Unit>

    // Sync
    @POST("sync/simple")
    suspend fun syncPlaces(@Body request: SyncRequest): Response<SyncResponse>

    // Stats
    @GET("places/stats")
    suspend fun getStats(): Response<ExtendedStats>

    // Friends
    @GET("friends")
    suspend fun getFriends(): Response<List<FriendDto>>

    // Feedback
    @POST("feedback")
    suspend fun submitFeedback(@Body request: FeedbackRequest): Response<Unit>

    // Health
    @GET("health")
    suspend fun healthCheck(): Response<HealthResponse>
}
