package com.footprintmaps.android.di

import com.footprintmaps.android.BuildConfig
import com.footprintmaps.android.data.preferences.SecureTokenStore
import com.footprintmaps.android.data.remote.api.FootprintApi
import com.footprintmaps.android.data.remote.interceptor.AuthInterceptor
import com.footprintmaps.android.data.remote.interceptor.TokenAuthenticator
import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import java.util.concurrent.TimeUnit
import javax.inject.Provider
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
        isLenient = true
    }

    @Provides
    @Singleton
    fun provideAuthInterceptor(tokenStore: SecureTokenStore): AuthInterceptor =
        AuthInterceptor(tokenStore)

    @Provides
    @Singleton
    fun provideTokenAuthenticator(
        tokenStore: SecureTokenStore,
        apiProvider: Provider<FootprintApi>
    ): TokenAuthenticator = TokenAuthenticator(tokenStore, apiProvider)

    @Provides
    @Singleton
    fun provideOkHttpClient(
        authInterceptor: AuthInterceptor,
        tokenAuthenticator: TokenAuthenticator
    ): OkHttpClient {
        val builder = OkHttpClient.Builder()
            .addInterceptor(authInterceptor)
            .authenticator(tokenAuthenticator)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)

        if (BuildConfig.DEBUG) {
            val loggingInterceptor = HttpLoggingInterceptor().apply {
                level = HttpLoggingInterceptor.Level.BODY
            }
            builder.addInterceptor(loggingInterceptor)
        }

        return builder.build()
    }

    @Provides
    @Singleton
    fun provideRetrofit(
        okHttpClient: OkHttpClient,
        json: Json
    ): Retrofit {
        val contentType = "application/json".toMediaType()
        return Retrofit.Builder()
            .baseUrl(BuildConfig.BASE_URL + "/")
            .client(okHttpClient)
            .addConverterFactory(json.asConverterFactory(contentType))
            .build()
    }

    @Provides
    @Singleton
    fun provideFootprintApi(retrofit: Retrofit): FootprintApi =
        retrofit.create(FootprintApi::class.java)
}
