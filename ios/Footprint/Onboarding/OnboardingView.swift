import SwiftUI
import Photos

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var photoPermissionGranted = false
    @State private var locationPermissionGranted = false

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
                // Top spacing (no skip button per App Store guidelines)
                Spacer()
                    .frame(height: 50)

                // Page content — no swipe gesture, navigation only via buttons
                Group {
                    switch currentPage {
                    case 0:
                        WelcomePage()
                    case 1:
                        PhotoImportPage(permissionGranted: $photoPermissionGranted)
                    case 2:
                        LocationPage(permissionGranted: $locationPermissionGranted)
                    case 3:
                        ReadyPage(onGetStarted: completeOnboarding)
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                            handleNextButton()
                        } label: {
                            HStack {
                                Text(nextButtonTitle)
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

    private var nextButtonTitle: String {
        switch currentPage {
        case 1 where !photoPermissionGranted:
            return "Enable & Continue"
        case 2 where !locationPermissionGranted:
            return "Enable & Continue"
        case totalPages - 1:
            return "Get Started"
        default:
            return "Next"
        }
    }

    private func handleNextButton() {
        switch currentPage {
        case 1 where !photoPermissionGranted:
            // Request photo permission before advancing
            Task {
                let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                await MainActor.run {
                    photoPermissionGranted = status == .authorized || status == .limited
                    withAnimation {
                        currentPage += 1
                    }
                }
            }
        case 2 where !locationPermissionGranted:
            // Request location permission before advancing
            LocationManager.shared.requestPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let status = LocationManager.shared.authorizationStatus
                locationPermissionGranted = status == .authorizedAlways || status == .authorizedWhenInUse
                withAnimation {
                    currentPage += 1
                }
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

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "map.fill", color: .blue, text: "Visualize your travels on an interactive map")
                FeatureRow(icon: "star.fill", color: .orange, text: "Create a bucket list of places to visit")
                FeatureRow(icon: "photo.fill", color: .purple, text: "Import locations from your photos")
            }
            .padding(.horizontal, 30)
            .padding(.top, 20)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Photo Import Page

private struct PhotoImportPage: View {
    @Binding var permissionGranted: Bool
    @State private var isRequesting = false

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
                Text("Import from Photos")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text("Footprint can scan your photo library to discover places you've been based on photo locations")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(icon: "map.fill", text: "See photo pins on your map")
                BenefitRow(icon: "clock.fill", text: "Automatically find past travels")
                BenefitRow(icon: "lock.shield.fill", text: "Photos stay on your device")
            }
            .padding(.horizontal, 40)

            // Permission button
            if permissionGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Photo access enabled")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            } else {
                Button {
                    requestPhotoPermission()
                } label: {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("Enable Photo Access")
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.purple)
                    .clipShape(Capsule())
                }
                .disabled(isRequesting)
                .padding(.top, 10)
            }

            Text("All processing happens on your device — no photos are uploaded")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
    }

    private func requestPhotoPermission() {
        isRequesting = true
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                permissionGranted = status == .authorized || status == .limited
                isRequesting = false
            }
        }
    }
}

// MARK: - Location Page

private struct LocationPage: View {
    @Binding var permissionGranted: Bool
    @State private var isRequesting = false

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
                Text("Track Your Location")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)

                Text("Enable location tracking to automatically mark countries as you travel")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(icon: "flag.fill", text: "Auto-detect new countries")
                BenefitRow(icon: "bell.fill", text: "Get notified when visiting new places")
                BenefitRow(icon: "battery.100", text: "Battery-efficient background tracking")
            }
            .padding(.horizontal, 40)

            // Permission button
            if permissionGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Location access enabled")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            } else {
                Button {
                    requestLocationPermission()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Enable Location Access")
                    }
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(Capsule())
                }
                .disabled(isRequesting)
                .padding(.top, 10)
            }

            Text("Uses battery-efficient tracking that runs in the background")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
    }

    private func requestLocationPermission() {
        isRequesting = true
        LocationManager.shared.requestPermission()
        // Check status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let status = LocationManager.shared.authorizationStatus
            permissionGranted = status == .authorizedAlways || status == .authorizedWhenInUse
            isRequesting = false
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
                TipRow(icon: "photo.stack.fill", text: "Import photos from Settings to see pins on the map")
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

private struct BenefitRow: View {
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
