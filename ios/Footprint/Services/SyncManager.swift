import Foundation
import SwiftData

@MainActor
@Observable
class SyncManager {
    static let shared = SyncManager()

    var isSyncing = false
    var lastSyncAt: Date?
    var error: String?

    private var modelContext: ModelContext?

    private init() {
        // Load last sync date from UserDefaults
        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncAt") as? Date {
            lastSyncAt = timestamp
        }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func sync() async {
        guard let context = modelContext else {
            error = "Model context not configured"
            return
        }

        guard await APIClient.shared.isAuthenticated else {
            error = "Not authenticated"
            return
        }

        isSyncing = true
        error = nil

        do {
            // Get all local changes since last sync
            let localChanges: [VisitedPlace]
            if let syncDate = self.lastSyncAt {
                let descriptor = FetchDescriptor<VisitedPlace>(
                    predicate: #Predicate<VisitedPlace> { place in
                        place.lastModifiedAt > syncDate
                    }
                )
                localChanges = try context.fetch(descriptor)
            } else {
                localChanges = try context.fetch(FetchDescriptor<VisitedPlace>())
            }

            // Convert to API format
            let changes = localChanges.map { place in
                APIClient.PlaceChange(
                    regionType: place.regionType,
                    regionCode: place.regionCode,
                    regionName: place.regionName,
                    status: place.status,
                    isDeleted: place.isDeleted,
                    lastModifiedAt: place.lastModifiedAt
                )
            }

            // Send sync request
            let response = try await APIClient.shared.syncPlaces(
                lastSyncAt: lastSyncAt,
                changes: changes
            )

            // Apply server changes to local database
            for serverPlace in response.serverChanges {
                // Find existing local place
                let serverType = serverPlace.regionType
                let serverCode = serverPlace.regionCode
                let existingDescriptor = FetchDescriptor<VisitedPlace>(
                    predicate: #Predicate<VisitedPlace> { place in
                        place.regionType == serverType && place.regionCode == serverCode
                    }
                )

                let existing = try context.fetch(existingDescriptor).first

                if let existing {
                    // Update existing
                    existing.regionName = serverPlace.regionName
                    existing.status = serverPlace.status ?? "visited"
                    existing.visitedDate = serverPlace.visitedDate
                    existing.notes = serverPlace.notes
                    existing.lastModifiedAt = serverPlace.updatedAt
                    existing.isSynced = true
                } else {
                    // Create new
                    let status = VisitedPlace.PlaceStatus(rawValue: serverPlace.status ?? "visited") ?? .visited
                    let newPlace = VisitedPlace(
                        regionType: VisitedPlace.RegionType(rawValue: serverPlace.regionType) ?? .country,
                        regionCode: serverPlace.regionCode,
                        regionName: serverPlace.regionName,
                        status: status
                    )
                    newPlace.visitedDate = serverPlace.visitedDate
                    newPlace.notes = serverPlace.notes
                    newPlace.isSynced = true
                    context.insert(newPlace)
                }
            }

            // Mark local changes as synced
            for place in localChanges {
                place.isSynced = true
            }

            // Save
            try context.save()

            // Update last sync timestamp
            lastSyncAt = response.syncedAt
            UserDefaults.standard.set(response.syncedAt, forKey: "lastSyncAt")

        } catch {
            self.error = "Sync failed: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    /// Reset sync state without triggering a sync. Call on account deletion / clear all data.
    func forceResetSyncState() {
        lastSyncAt = nil
        UserDefaults.standard.removeObject(forKey: "lastSyncAt")
        error = nil
    }

    func forceFullSync() async {
        forceResetSyncState()
        await sync()
    }
}
