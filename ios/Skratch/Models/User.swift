import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: String
    var authProvider: String
    var authProviderID: String
    var email: String?
    var displayName: String?
    var profilePictureURL: String?

    // Travel statistics
    var countriesVisited: Int
    var usStatesVisited: Int
    var canadianProvincesVisited: Int

    // Settings
    var privacySettings: [String: Bool]
    var notificationSettings: [String: Bool]

    // Timestamps
    var createdAt: Date
    var updatedAt: Date
    var lastLoginAt: Date?

    // Sync metadata
    var syncVersion: Int
    var lastSyncAt: Date?

    init(
        id: String,
        authProvider: String,
        authProviderID: String,
        email: String? = nil,
        displayName: String? = nil,
        profilePictureURL: String? = nil
    ) {
        self.id = id
        self.authProvider = authProvider
        self.authProviderID = authProviderID
        self.email = email
        self.displayName = displayName
        self.profilePictureURL = profilePictureURL
        self.countriesVisited = 0
        self.usStatesVisited = 0
        self.canadianProvincesVisited = 0
        self.privacySettings = [:]
        self.notificationSettings = [:]
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncVersion = 1
    }
}