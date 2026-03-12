import SwiftUI
import UIKit
import Photos
import CoreLocation

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var showPhotoSettingsAlert = false
    @State private var showLocationSettingsAlert = false

    private let totalPages = 4

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
                        PhotoExplanationPage()
                    case 2:
                        LocationExplanationPage()
                    case 3:
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

                    // Navigation — Next only, no Back, no Skip
                    HStack {
                        Spacer()

                        Button {
                            handleNextButton()
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
        .alert("Photo Access", isPresented: $showPhotoSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Continue Without Photos") {
                withAnimation { currentPage += 1 }
            }
        } message: {
            Text("Photo access was previously denied. To enable photo import, open Settings and allow photo access for Footprint.")
        }
        .alert("Location Access", isPresented: $showLocationSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Continue Without Location") {
                withAnimation { currentPage += 1 }
            }
        } message: {
            Text("Location access was previously denied. To enable automatic country detection, open Settings and allow location access for Footprint.")
        }
    }

    private func handleNextButton() {
        switch currentPage {
        case 1:
            let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            if currentStatus == .denied || currentStatus == .restricted {
                // Already denied — show settings alert
                showPhotoSettingsAlert = true
            } else if currentStatus == .notDetermined {
                // First time — trigger system dialog
                Task {
                    _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                    await MainActor.run {
                        withAnimation { currentPage += 1 }
                    }
                }
            } else {
                // Already authorized
                withAnimation { currentPage += 1 }
            }
        case 2:
            let currentStatus = LocationManager.shared.authorizationStatus
            if currentStatus == .denied || currentStatus == .restricted {
                // Already denied — show settings alert
                showLocationSettingsAlert = true
            } else if currentStatus == .notDetermined {
                // First time — trigger system dialog
                LocationManager.shared.requestPermission()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation { currentPage += 1 }
                }
            } else {
                // Already authorized
                withAnimation { currentPage += 1 }
            }
        case totalPages - 1:
            completeOnboarding()
        default:
            withAnimation {
                currentPage += 1
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

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "map.fill", color: .blue, text: "Visualize your travels on an interactive map")
                FeatureRow(icon: "star.fill", color: .orange, text: "Create a bucket list of places to visit")
                FeatureRow(icon: "chart.bar.fill", color: .red, text: "See your travel statistics")
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Photo Explanation Page

private struct PhotoExplanationPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 180, height: 180)

                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 80))
                    .foregroundStyle(.purple)
            }
            .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("Photo Import")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text("Footprint can scan your photo library to discover places you've been, based on where your photos were taken.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "map.fill", text: "See photo pins on your travel map")
                InfoRow(icon: "clock.fill", text: "Automatically find past travels")
                InfoRow(icon: "lock.shield.fill", text: "All processing happens on your device")
            }
            .padding(.horizontal, 40)

            Text("Tap Next to set up photo access.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Location Explanation Page

private struct LocationExplanationPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 180, height: 180)

                Image(systemName: "location.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
            }
            .accessibilityHidden(true)

            VStack(spacing: 16) {
                Text("Location Tracking")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text("Footprint can use your location to automatically detect when you visit a new country, so you never forget to log a trip.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "flag.fill", text: "Auto-detect new countries")
                InfoRow(icon: "bell.fill", text: "Get notified when visiting new places")
                InfoRow(icon: "battery.100", text: "Battery-efficient background tracking")
            }
            .padding(.horizontal, 40)

            Text("Tap Next to set up location access.")
                .font(.caption)
                .foregroundStyle(.secondary)

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

            VStack(alignment: .leading, spacing: 16) {
                TipRow(icon: "hand.tap.fill", text: "Tap any country to mark it as visited")
                TipRow(icon: "star.fill", text: "Long press to add to your bucket list")
                TipRow(icon: "gearshape.fill", text: "Change permissions anytime in Settings")
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

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
