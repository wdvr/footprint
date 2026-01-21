import SwiftUI
import SwiftData

@main
struct SkratchApp: App {
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

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authManager = AuthManager.shared

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ContentView()
                    .task {
                        // Configure sync manager and start sync
                        SyncManager.shared.configure(modelContext: modelContext)
                        await SyncManager.shared.sync()
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

                Text("Skratch")
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
                // Allow offline use with local data only
                // This won't set isAuthenticated but will dismiss login
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
