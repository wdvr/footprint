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
                // Skip button
                HStack {
                    Spacer()
                    Button(L10n.Onboarding.skip) {
                        completeOnboarding()
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                }

                // Page content
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)

                    PhotoImportPage(permissionGranted: $photoPermissionGranted)
                        .tag(1)

                    LocationPage(permissionGranted: $locationPermissionGranted)
                        .tag(2)

                    ReadyPage(onGetStarted: completeOnboarding)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

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
                                    Text(L10n.Onboarding.back)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            withAnimation {
                                if currentPage < totalPages - 1 {
                                    currentPage += 1
                                } else {
                                    completeOnboarding()
                                }
                            }
                        } label: {
                            HStack {
                                Text(currentPage < totalPages - 1 ? L10n.Onboarding.next : L10n.Onboarding.getStarted)
                                if currentPage < totalPages - 1 {
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .clipShape(Capsule())
                        }
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

            VStack(spacing: 16) {
                Text(L10n.Onboarding.Welcome.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L10n.Onboarding.Welcome.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "map.fill", color: .blue, text: "onboarding.feature.map".localized)
                FeatureRow(icon: "star.fill", color: .orange, text: "onboarding.feature.bucket_list".localized)
                FeatureRow(icon: "photo.fill", color: .purple, text: "onboarding.feature.photos".localized)
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

            VStack(spacing: 16) {
                Text(L10n.Onboarding.Photos.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L10n.Onboarding.Photos.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(icon: "map.fill", text: "onboarding.photos.benefit.map".localized)
                BenefitRow(icon: "clock.fill", text: "onboarding.photos.benefit.automatic".localized)
                BenefitRow(icon: "lock.shield.fill", text: "onboarding.photos.benefit.privacy".localized)
            }
            .padding(.horizontal, 40)

            // Permission button
            if permissionGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.Onboarding.Photos.enabled)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            } else {
                Button {
                    requestPhotoPermission()
                } label: {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text(L10n.Onboarding.Photos.enable)
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

            Text(L10n.Onboarding.Photos.optional)
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

            VStack(spacing: 16) {
                Text(L10n.Onboarding.Location.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L10n.Onboarding.Location.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(icon: "flag.fill", text: "onboarding.location.benefit.auto_detect".localized)
                BenefitRow(icon: "bell.fill", text: "onboarding.location.benefit.notifications".localized)
                BenefitRow(icon: "battery.100", text: "onboarding.location.benefit.battery".localized)
            }
            .padding(.horizontal, 40)

            // Permission button
            if permissionGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(L10n.Onboarding.Location.enabled)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 10)
            } else {
                Button {
                    requestLocationPermission()
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                        Text(L10n.Onboarding.Location.enable)
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

            Text(L10n.Onboarding.Location.optional)
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

            VStack(spacing: 16) {
                Text(L10n.Onboarding.Complete.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(L10n.Onboarding.Complete.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Tips
            VStack(alignment: .leading, spacing: 16) {
                TipRow(icon: "hand.tap.fill", text: "onboarding.tip.tap_country".localized)
                TipRow(icon: "star.fill", text: "onboarding.tip.bucket_list".localized)
                TipRow(icon: "photo.stack.fill", text: "onboarding.tip.photo_import".localized)
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

            Text(text)
                .font(.subheadline)
        }
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

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
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

            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
