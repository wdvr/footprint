package com.footprintmaps.android.data.repository

import com.footprintmaps.android.data.preferences.SecureTokenStore
import com.footprintmaps.android.data.remote.api.FootprintApi
import com.footprintmaps.android.data.remote.dto.GoogleSignInRequest
import com.footprintmaps.android.data.remote.dto.UserResponse
import javax.inject.Inject
import javax.inject.Singleton

sealed class AuthResult<out T> {
    data class Success<T>(val data: T) : AuthResult<T>()
    data class Error(val message: String) : AuthResult<Nothing>()
}

@Singleton
class AuthRepository @Inject constructor(
    private val api: FootprintApi,
    private val tokenStore: SecureTokenStore
) {
    val isLoggedIn: Boolean get() = tokenStore.isLoggedIn()
    val userName: String? get() = tokenStore.getUserName()
    val userEmail: String? get() = tokenStore.getUserEmail()

    suspend fun signInWithGoogle(idToken: String): AuthResult<UserResponse> {
        return try {
            val response = api.googleSignIn(GoogleSignInRequest(idToken))
            if (response.isSuccessful) {
                val authResponse = response.body() ?: return AuthResult.Error("Empty response")
                tokenStore.saveTokens(authResponse.accessToken, authResponse.refreshToken)
                tokenStore.saveUser(
                    authResponse.user.id,
                    authResponse.user.email,
                    authResponse.user.name
                )
                AuthResult.Success(authResponse.user)
            } else {
                AuthResult.Error("Sign in failed: ${response.code()}")
            }
        } catch (e: Exception) {
            AuthResult.Error(e.message ?: "Unknown error")
        }
    }

    suspend fun getCurrentUser(): AuthResult<UserResponse> {
        return try {
            val response = api.getCurrentUser()
            if (response.isSuccessful) {
                AuthResult.Success(response.body()!!)
            } else {
                AuthResult.Error("Failed to get user: ${response.code()}")
            }
        } catch (e: Exception) {
            AuthResult.Error(e.message ?: "Unknown error")
        }
    }

    fun signOut() {
        tokenStore.clearTokens()
    }
}
