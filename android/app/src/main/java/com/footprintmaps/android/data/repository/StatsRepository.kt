package com.footprintmaps.android.data.repository

import com.footprintmaps.android.data.local.dao.VisitedPlaceDao
import com.footprintmaps.android.data.remote.api.FootprintApi
import com.footprintmaps.android.data.remote.dto.ExtendedStats
import com.footprintmaps.android.domain.model.Continent
import com.footprintmaps.android.domain.model.GeographicData
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

data class LocalStats(
    val countriesVisited: Int = 0,
    val countriesBucketList: Int = 0,
    val usStatesVisited: Int = 0,
    val continentsVisited: Int = 0,
    val continentProgress: Map<Continent, Pair<Int, Int>> = emptyMap()  // visited to total
)

@Singleton
class StatsRepository @Inject constructor(
    private val dao: VisitedPlaceDao,
    private val api: FootprintApi
) {
    fun getLocalStats(): Flow<LocalStats> {
        return dao.getVisitedCountryCodes().map { visitedCodes ->
            val visitedCountries = visitedCodes.mapNotNull { code ->
                GeographicData.countryByCode(code)
            }

            val continentProgress = Continent.entries
                .filter { it != Continent.ANTARCTICA }
                .associateWith { continent ->
                    val total = GeographicData.countriesByContinent[continent]?.size ?: 0
                    val visited = visitedCountries.count { it.continent == continent }
                    visited to total
                }

            LocalStats(
                countriesVisited = visitedCodes.size,
                continentsVisited = continentProgress.count { it.value.first > 0 },
                continentProgress = continentProgress
            )
        }
    }

    suspend fun getRemoteStats(): Result<ExtendedStats> {
        return try {
            val response = api.getStats()
            if (response.isSuccessful) {
                Result.success(response.body()!!)
            } else {
                Result.failure(Exception("Failed to fetch stats: ${response.code()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
