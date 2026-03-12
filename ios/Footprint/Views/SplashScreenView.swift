import MapKit
import SwiftUI

// MARK: - Splash Screen View

/// An animated launch screen that shows a real MapKit world map with a camera flyover
/// across continents, with the Footprint branding overlaid on top.
/// Lasts approximately 2 seconds and respects the "Reduce Motion" accessibility setting.
struct SplashScreenView: View {
    @Binding var isFinished: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Camera flyover positions
    private static let worldView = MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        distance: 40_000_000
    )
    private static let europeView = MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 48, longitude: 10),
        distance: 8_000_000
    )
    private static let asiaView = MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 35, longitude: 105),
        distance: 12_000_000
    )

    // Animation state
    @State private var cameraPosition: MapCameraPosition = .camera(SplashScreenView.worldView)
    @State private var phase = 0
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var fadeOut: Bool = false

    var body: some View {
        ZStack {
            // Map background
            Map(position: $cameraPosition) {}
                .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                .allowsHitTesting(false)
                .ignoresSafeArea()

            // Dark overlay for readability
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            // Branding content
            VStack(spacing: 0) {
                Spacer()

                // App icon
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                Spacer()
                    .frame(height: 32)

                // Title and subtitle
                VStack(spacing: 10) {
                    Text("Footprint")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)

                    Text("Your world. Your journey.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .opacity(subtitleOpacity)
                }

                Spacer()
                Spacer()
            }
        }
        .opacity(fadeOut ? 0 : 1)
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Animation Sequence

    private func startAnimations() {
        if reduceMotion {
            // Skip animations for accessibility -- show final state immediately
            iconScale = 1.0
            iconOpacity = 1.0
            titleOpacity = 1.0
            titleOffset = 0
            subtitleOpacity = 1.0

            // Transition out after a brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.2)) {
                    isFinished = true
                }
            }
            return
        }

        // Phase 1: Icon and title appear (0.0s - 0.4s)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
            titleOpacity = 1.0
            titleOffset = 0
        }

        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            subtitleOpacity = 1.0
        }

        // Phase 2: Fly to Europe (0.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .camera(SplashScreenView.europeView)
            }
        }

        // Phase 3: Fly to Asia (0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .camera(SplashScreenView.asiaView)
            }
        }

        // Phase 4: Fly back to world view (1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .camera(SplashScreenView.worldView)
            }
        }

        // Phase 5: Fade out and finish (2.0s - 2.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                fadeOut = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeOut(duration: 0.15)) {
                isFinished = true
            }
        }

        // Failsafe: ensure splash always finishes even if animations stall
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if !isFinished {
                isFinished = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Splash Screen") {
    SplashScreenView(isFinished: .constant(false))
}

#Preview("Splash Screen - Finished") {
    SplashScreenView(isFinished: .constant(true))
}
