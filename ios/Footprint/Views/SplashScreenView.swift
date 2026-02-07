import SwiftUI

// MARK: - Splash Screen View

/// An animated launch screen that shows the Footprint branding with the app icon
/// and an animated globe that reveals highlighted continents in a sweeping motion.
/// Lasts approximately 2 seconds and respects the "Reduce Motion" accessibility setting.
struct SplashScreenView: View {
    @Binding var isFinished: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation state
    @State private var iconScale: CGFloat = 0.3
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var outerRingScale: CGFloat = 0.3
    @State private var outerRingOpacity: Double = 0
    @State private var sweepProgress: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var fadeOut: Bool = false
    @State private var globeRotationPhase: Int = 0 // 0=americas, 1=europe, 2=asia

    /// The SF Symbol name for the current globe rotation phase
    private var currentGlobeSymbol: String {
        switch globeRotationPhase {
        case 0: return "globe.americas.fill"
        case 1: return "globe.europe.africa.fill"
        case 2: return "globe.asia.australia.fill"
        default: return "globe.americas.fill"
        }
    }

    var body: some View {
        ZStack {
            // Background
            backgroundGradient

            // Content
            VStack(spacing: 0) {
                Spacer()

                // App icon and globe area
                ZStack {
                    // Pulsing glow behind everything
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.25),
                                    Color.green.opacity(0.08),
                                    Color.clear,
                                ]),
                                center: .center,
                                startRadius: 30,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .opacity(glowOpacity)

                    // Outer glow ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.4),
                                    Color.green.opacity(0.3),
                                    Color.blue.opacity(0.1),
                                    Color.green.opacity(0.2),
                                    Color.blue.opacity(0.4),
                                ]),
                                center: .center
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 220, height: 220)
                        .scaleEffect(outerRingScale)
                        .opacity(outerRingOpacity)

                    // Inner ring
                    Circle()
                        .stroke(
                            Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                        .frame(width: 175, height: 175)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Animated globe with sweep reveal behind the app icon
                    AnimatedGlobeView(
                        sweepProgress: sweepProgress,
                        globeSymbol: currentGlobeSymbol
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity * 0.6) // Slightly transparent behind icon

                    // App icon on top of the globe
                    Image("AppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
                        .scaleEffect(iconScale)
                        .opacity(iconOpacity)
                }
                .frame(height: 280)

                Spacer()
                    .frame(height: 32)

                // App title
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

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            // Deep dark base
            Color(red: 0.04, green: 0.06, blue: 0.14)

            // Central radial accent
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.18),
                    Color.clear,
                ]),
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 40,
                endRadius: 350
            )

            // Subtle green accent bottom-right
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.green.opacity(0.06),
                    Color.clear,
                ]),
                center: UnitPoint(x: 0.7, y: 0.6),
                startRadius: 20,
                endRadius: 200
            )
        }
        .ignoresSafeArea()
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
            ringScale = 1.0
            ringOpacity = 1.0
            outerRingScale = 1.0
            outerRingOpacity = 1.0
            sweepProgress = 1.0
            glowOpacity = 1.0

            // Transition out after a brief pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.2)) {
                    isFinished = true
                }
            }
            return
        }

        // Phase 1: Icon and globe appear and scale up (0.0s - 0.5s)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            iconScale = 1.0
            iconOpacity = 1.0
            glowOpacity = 1.0
        }

        // Phase 2: Rings expand outward (0.1s - 0.6s)
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
            outerRingScale = 1.0
            outerRingOpacity = 1.0
        }

        // Phase 3: Sweep animation reveals the globe color (0.2s - 1.1s)
        withAnimation(.easeInOut(duration: 0.9).delay(0.2)) {
            sweepProgress = 1.0
        }

        // Phase 4: Title slides up into view (0.3s - 0.7s)
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            titleOpacity = 1.0
            titleOffset = 0
        }

        // Phase 5: Subtitle fades in (0.6s - 0.9s)
        withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
            subtitleOpacity = 1.0
        }

        // Phase 6: Globe rotates through continents (0.8s - 1.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.25)) {
                globeRotationPhase = 1 // Europe/Africa
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.25)) {
                globeRotationPhase = 2 // Asia/Australia
            }
        }

        // Phase 7: Fade out and finish (1.2s - 1.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                fadeOut = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.15)) {
                isFinished = true
            }
        }
    }
}

// MARK: - Animated Globe View

/// A globe composed of SF Symbol layers with a sweep-reveal animation
/// that progressively highlights continents. The globe symbol changes
/// to simulate rotation through different world views.
private struct AnimatedGlobeView: View {
    let sweepProgress: Double
    let globeSymbol: String

    var body: some View {
        ZStack {
            // Base globe outline (dimmed, always visible)
            Image(systemName: globeSymbol)
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    Color.white.opacity(0.08)
                )
                .contentTransition(.symbolEffect(.replace))

            // Revealed globe with blue-green gradient (masked by sweep)
            Image(systemName: globeSymbol)
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.55, blue: 1.0),
                            Color(red: 0.2, green: 0.75, blue: 0.55),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .contentTransition(.symbolEffect(.replace))
                .mask(
                    SweepRevealShape(progress: sweepProgress)
                )

            // Specular highlight for depth
            Image(systemName: globeSymbol)
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.25),
                            Color.clear,
                            Color.clear,
                        ],
                        startPoint: UnitPoint(x: 0.3, y: 0.0),
                        endPoint: UnitPoint(x: 0.7, y: 0.8)
                    )
                )
                .contentTransition(.symbolEffect(.replace))
                .mask(
                    SweepRevealShape(progress: sweepProgress)
                )
                .blendMode(.screen)
        }
    }
}

// MARK: - Sweep Reveal Shape

/// A shape that reveals content in a circular sweep from the top,
/// used to animate the globe "filling in".
private struct SweepRevealShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }
        guard progress < 1 else { return Path(rect) }

        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height)

        // Sweep from -90 degrees (top) clockwise
        let startAngle = Angle.degrees(-90)
        let endAngle = Angle.degrees(-90 + 360 * progress)

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview("Splash Screen") {
    SplashScreenView(isFinished: .constant(false))
}

#Preview("Splash Screen - Finished") {
    SplashScreenView(isFinished: .constant(true))
}
