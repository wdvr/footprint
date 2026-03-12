import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let totalPages = 3

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.green.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 50)

                // Page content — no swipe gesture, navigation only via buttons
                Group {
                    switch currentPage {
                    case 0:
                        WelcomePage()
                    case 1:
                        FeaturesPage()
                    case 2:
                        ReadyPage(onGetStarted: completeOnboarding)
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: 500, maxHeight: .infinity)

                // Page indicator and navigation
                VStack(spacing: 20) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")

                    // Navigation buttons
                    HStack {
                        if currentPage > 0 {
                            Button {
                                withAnimation {
                                    currentPage -= 1
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                            }
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Back")
                            .accessibilityHint("Go to previous page")
                        }

                        Spacer()

                        Button {
                            if currentPage == totalPages - 1 {
                                completeOnboarding()
                            } else {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                        } label: {
                            HStack {
                                Text(currentPage == totalPages - 1 ? "Get Started" : "Next")
                                if currentPage < totalPages - 1 {
                                    Image(systemName: "chevron.right")
                                        .accessibilityHidden(true)
                                }
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(Capsule())
                        }
                        .accessibilityHint(currentPage < totalPages - 1 ? "Go to next page" : "Complete onboarding and start using the app")
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Welcome Page

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // World map illustration
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 200, height: 200)

                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("Welcome to Footprint")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text("Track the places you've visited and create your personal travel map")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Features Page

private struct FeaturesPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 180, height: 180)

                Image(systemName: "map.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("What You Can Do")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text("Everything you need to track your travels")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "map.fill", color: .blue, text: "Visualize your travels on an interactive map")
                FeatureRow(icon: "star.fill", color: .orange, text: "Create a bucket list of places to visit")
                FeatureRow(icon: "photo.fill", color: .purple, text: "Import locations from your photos")
                FeatureRow(icon: "location.fill", color: .green, text: "Auto-detect countries as you travel")
                FeatureRow(icon: "chart.bar.fill", color: .red, text: "See your travel statistics")
            }
            .padding(.horizontal, 30)
            .padding(.top, 10)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Ready Page

private struct ReadyPage: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 200, height: 200)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(.green)
            }
            .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text("Start exploring the map and marking the places you've visited")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Tips
            VStack(alignment: .leading, spacing: 16) {
                TipRow(icon: "hand.tap.fill", text: "Tap any country to mark it as visited")
                TipRow(icon: "star.fill", text: "Long press to add to your bucket list")
                TipRow(icon: "gearshape.fill", text: "Enable location & photos in Settings")
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Helper Views

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
