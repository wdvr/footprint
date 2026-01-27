import SwiftUI
import SwiftData
import Photos
#if canImport(UIKit)
import UIKit
#endif

@main
struct FootprintApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    // Check for UI testing and sample data mode
    private let isUITesting = CommandLine.arguments.contains("-UITestingMode")
    private let isSampleDataMode = CommandLine.arguments.contains("-SampleDataMode")

    init() {
        // Register background task for photo import (skip in testing)
        if !isUITesting {
            PhotoImportManager.registerBackgroundTask()
        }

        // Disable animations in testing
        if CommandLine.arguments.contains("-DisableAnimations") {
            #if canImport(UIKit)
            UIView.setAnimationsEnabled(false)
            UIApplication.shared.keyWindow?.layer.speed = 100
            #endif
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VisitedPlace.self,
        ])

        // Use in-memory storage for UI testing to avoid conflicts
        let isUITesting = CommandLine.arguments.contains("-UITestingMode")
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isUITesting
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Add sample data if in sample data mode (DEBUG only)
            #if DEBUG
            if CommandLine.arguments.contains("-SampleDataMode") {
                SampleDataHelper.addSampleData(to: container)
            }
            #endif

            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()


    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

#if canImport(UIKit)
/// AppDelegate to handle push notification callbacks
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = PushNotificationManager.shared

        // Set up notification categories
        PushNotificationManager.shared.setupNotificationCategories()

        // Resume background location tracking if it was enabled
        Task { @MainActor in
            LocationManager.shared.resumeBackgroundTrackingIfEnabled()

            // Start observing photo library if we have permission
            let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if photoStatus == .authorized || photoStatus == .limited {
                PhotoImportManager.shared.startObservingPhotoLibrary()
            }
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
    }
}
#endif

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authManager = AuthManager.shared
    @State private var hasRequestedNotifications = false

    // Check if we're in UI testing mode
    private let isUITesting = CommandLine.arguments.contains("-UITestingMode")

    var body: some View {
        Group {
            if authManager.isAuthenticated || isUITesting {
                ContentView()
                    .task {
                        // Skip network operations in UI testing
                        if !isUITesting {
                            // Configure sync manager and start sync
                            SyncManager.shared.configure(modelContext: modelContext)
                            await SyncManager.shared.sync()

                            // Request push notification permission once
                            if !hasRequestedNotifications {
                                hasRequestedNotifications = true
                                _ = await PushNotificationManager.shared.requestPermission()
                            }
                        }
                    }
            } else {
                LoginView()
            }
        }
        .environment(authManager)
    }
}

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)

                Text("Footprint")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track your travels around the world")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 16) {
                if authManager.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    SignInWithAppleButton()
                        .frame(height: 50)
                        .padding(.horizontal, 40)

                    SignInWithGoogleButton()
                        .frame(height: 50)
                        .padding(.horizontal, 40)
                }

                if let error = authManager.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }

            Spacer()

            // Skip for offline use
            Button("Continue without account") {
                authManager.continueWithoutAccount()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text("Your data will be stored locally and won't sync across devices")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
    }
}

struct SignInWithAppleButton: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Button(action: {
            authManager.signInWithApple()
        }) {
            HStack {
                Image(systemName: "apple.logo")
                Text("Sign in with Apple")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.black)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct SignInWithGoogleButton: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Button(action: {
            authManager.signInWithGoogle()
        }) {
            HStack(spacing: 12) {
                // Official Google "G" logo
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("Sign in with Google")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.white)
            .foregroundStyle(Color(red: 0.26, green: 0.26, blue: 0.26)) // Google's dark gray
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
        }
    }
}
