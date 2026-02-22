package com.footprintmaps.android.data.remote.interceptor

import com.footprintmaps.android.data.preferences.SecureTokenStore
import okhttp3.Interceptor
import okhttp3.Response
import javax.inject.Inject

class AuthInterceptor @Inject constructor(
    private val tokenStore: SecureTokenStore
) : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()

        // Skip auth for endpoints that don't need it
        val path = request.url.encodedPath
        if (path.endsWith("/health") || path.endsWith("/auth/google") || path.endsWith("/auth/refresh")) {
            return chain.proceed(request)
        }

        val token = tokenStore.getAccessToken()
        if (token != null) {
            val authenticatedRequest = request.newBuilder()
                .header("Authorization", "Bearer $token")
                .build()
            return chain.proceed(authenticatedRequest)
        }

        return chain.proceed(request)
    }
}
