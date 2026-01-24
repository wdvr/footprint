import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Manages push notification registration and handling
@MainActor
@Observable
class PushNotificationManager: NSObject {
    static let shared = PushNotificationManager()

    var isRegistered = false
    var deviceToken: String?
    var permissionStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        Task {
            await checkPermissionStatus()
        }
    }

    /// Check current notification permission status
    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
        isRegistered = settings.authorizationStatus == .authorized
    }

    /// Request notification permission and register for remote notifications
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )

            if granted {
                await registerForRemoteNotifications()
            }

            await checkPermissionStatus()
            return granted
        } catch {
            print("[Push] Permission request failed: \(error)")
            return false
        }
    }

    /// Register for remote notifications with APNs
    func registerForRemoteNotifications() async {
        #if canImport(UIKit)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        #endif
    }

    /// Handle successful APNs registration
    func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = token
        self.isRegistered = true

        print("[Push] Device token: \(token)")

        // Register with backend
        Task {
            await registerTokenWithBackend(token)
        }
    }

    /// Handle APNs registration failure
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[Push] Registration failed: \(error)")
        isRegistered = false
    }

    /// Register device token with backend
    private func registerTokenWithBackend(_ token: String) async {
        guard await APIClient.shared.isAuthenticated else {
            print("[Push] Not authenticated, skipping backend registration")
            return
        }

        do {
            let response = try await APIClient.shared.registerDeviceToken(token)
            print("[Push] Backend registration: \(response.message)")
        } catch {
            print("[Push] Backend registration failed: \(error)")
        }
    }

    /// Setup notification categories for actionable notifications
    func setupNotificationCategories() {
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_IMPORT",
            title: "Review",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )

        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM_LOCATION",
            title: "Add to Map",
            options: [.foreground]
        )

        let importCategory = UNNotificationCategory(
            identifier: "IMPORT_REVIEW",
            actions: [reviewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let locationCategory = UNNotificationCategory(
            identifier: "NEW_LOCATION",
            actions: [confirmAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let errorCategory = UNNotificationCategory(
            identifier: "IMPORT_ERROR",
            actions: [dismissAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            importCategory,
            locationCategory,
            errorCategory,
        ])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner even when app is in foreground
        return [.banner, .sound, .badge]
    }

    /// Handle notification tap or action
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        print("[Push] Action: \(actionIdentifier), UserInfo: \(userInfo)")

        // Handle based on action
        switch actionIdentifier {
        case "REVIEW_IMPORT", UNNotificationDefaultActionIdentifier:
            if let action = userInfo["action"] as? String, action == "review_import" {
                await handleReviewImport()
            }

        case "CONFIRM_LOCATION":
            if let regionName = userInfo["region_name"] as? String,
               let regionType = userInfo["region_type"] as? String {
                await handleConfirmLocation(regionName: regionName, regionType: regionType)
            }

        default:
            break
        }
    }

    @MainActor
    private func handleReviewImport() {
        // Post notification to open import review
        NotificationCenter.default.post(name: .openImportReview, object: nil)
    }

    @MainActor
    private func handleConfirmLocation(regionName: String, regionType: String) {
        // Post notification to confirm location
        NotificationCenter.default.post(
            name: .confirmNewLocation,
            object: nil,
            userInfo: ["regionName": regionName, "regionType": regionType]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openImportReview = Notification.Name("openImportReview")
    static let confirmNewLocation = Notification.Name("confirmNewLocation")
}
