package com.footprintmaps.android.data.repository

import com.footprintmaps.android.data.remote.api.FootprintApi
import com.footprintmaps.android.data.remote.dto.FeedbackRequest
import com.footprintmaps.android.data.remote.dto.FriendDto
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FriendsRepository @Inject constructor(
    private val api: FootprintApi
) {
    suspend fun getFriends(): Result<List<FriendDto>> {
        return try {
            val response = api.getFriends()
            if (response.isSuccessful) {
                Result.success(response.body() ?: emptyList())
            } else {
                Result.failure(Exception("Failed to fetch friends: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun submitFeedback(type: String, message: String): Result<Unit> {
        return try {
            val response = api.submitFeedback(
                FeedbackRequest(type = type, message = message)
            )
            if (response.isSuccessful) {
                Result.success(Unit)
            } else {
                Result.failure(Exception("Failed to submit feedback: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
