import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@main
struct FootprintApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            VisitedPlace.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
                    .task {
                        // Configure sync manager and start sync
                        SyncManager.shared.configure(modelContext: modelContext)
                        await SyncManager.shared.sync()

                        // Request push notification permission once
                        if !hasRequestedNotifications {
                            hasRequestedNotifications = true
                            _ = await PushNotificationManager.shared.requestPermission()
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

                    #if DEBUG
                    // Dev mode login - bypasses Apple Sign In
                    Button(action: {
                        authManager.signInDevMode()
                    }) {
                        HStack {
                            Image(systemName: "hammer.fill")
                            Text("Dev Mode Login")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 40)
                    #endif
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
