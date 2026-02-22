package com.footprintmaps.android.worker

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.*
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import java.util.concurrent.TimeUnit

@HiltWorker
class PhotoScanWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        // TODO: Implement photo scanning
        // 1. Query MediaStore for photos with GPS EXIF data
        // 2. Reverse geocode to determine country/state
        // 3. Add to visited places database
        return Result.success()
    }

    companion object {
        const val WORK_NAME = "footprint_photo_scan"

        fun buildPeriodicRequest(): PeriodicWorkRequest {
            return PeriodicWorkRequestBuilder<PhotoScanWorker>(
                1, TimeUnit.DAYS
            )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiresCharging(true)
                        .build()
                )
                .build()
        }
    }
}
