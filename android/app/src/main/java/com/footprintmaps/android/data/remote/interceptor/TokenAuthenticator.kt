package com.footprintmaps.android.data.remote.interceptor

import com.footprintmaps.android.data.preferences.SecureTokenStore
import com.footprintmaps.android.data.remote.api.FootprintApi
import com.footprintmaps.android.data.remote.dto.RefreshTokenRequest
import kotlinx.coroutines.runBlocking
import okhttp3.Authenticator
import okhttp3.Request
import okhttp3.Response
import okhttp3.Route
import javax.inject.Inject
import javax.inject.Provider

class TokenAuthenticator @Inject constructor(
    private val tokenStore: SecureTokenStore,
    private val apiProvider: Provider<FootprintApi>
) : Authenticator {

    override fun authenticate(route: Route?, response: Response): Request? {
        // If we've already tried refreshing, give up
        if (response.request.header("X-Retry-Auth") != null) {
            return null
        }

        val refreshToken = tokenStore.getRefreshToken() ?: return null

        return runBlocking {
            try {
                val refreshResponse = apiProvider.get().refreshToken(
                    RefreshTokenRequest(refreshToken)
                )

                if (refreshResponse.isSuccessful) {
                    val tokens = refreshResponse.body() ?: return@runBlocking null
                    tokenStore.saveTokens(tokens.accessToken, tokens.refreshToken)

                    response.request.newBuilder()
                        .header("Authorization", "Bearer ${tokens.accessToken}")
                        .header("X-Retry-Auth", "true")
                        .build()
                } else {
                    // Refresh failed, clear tokens
                    tokenStore.clearTokens()
                    null
                }
            } catch (e: Exception) {
                null
            }
        }
    }
}
