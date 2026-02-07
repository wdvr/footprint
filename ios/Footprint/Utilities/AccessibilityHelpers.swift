import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Reduce Motion Helper

extension View {
    /// Applies animation only when Reduce Motion is not enabled
    func conditionalAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        modifier(ConditionalAnimationModifier(animation: animation, value: value))
    }
}

private struct ConditionalAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: V

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.animation(animation, value: value)
        }
    }
}

// MARK: - Conditional withAnimation

/// Executes an animation block only if Reduce Motion is not enabled
/// - Parameters:
///   - animation: The animation to apply
///   - reduceMotion: Whether reduce motion is enabled
///   - body: The closure containing state changes to animate
func conditionalWithAnimation<Result>(
    _ animation: Animation? = .default,
    reduceMotion: Bool,
    _ body: () throws -> Result
) rethrows -> Result {
    if reduceMotion {
        return try body()
    } else {
        return try withAnimation(animation, body)
    }
}

// MARK: - VoiceOver Detection

struct VoiceOverReader: ViewModifier {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: voiceOverEnabled, initial: true) { _, newValue in
                action(newValue)
            }
    }
}

extension View {
    /// Calls the action whenever VoiceOver status changes
    func onVoiceOverChange(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(VoiceOverReader(action: action))
    }

    /// Adds a high-contrast border when Differentiate Without Color is enabled
    func highContrastBorder(_ color: Color = .primary, lineWidth: CGFloat = 1) -> some View {
        modifier(HighContrastBorderModifier(color: color, lineWidth: lineWidth))
    }

    /// Adds an accessibility value showing visited status for a place
    func accessibilityVisitedStatus(_ isVisited: Bool) -> some View {
        self.accessibilityValue(isVisited ? "Visited" : "Not visited")
    }
}

// MARK: - High Contrast Border

private struct HighContrastBorderModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    let color: Color
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        if differentiateWithoutColor {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: lineWidth)
                )
        } else {
            content
        }
    }
}

// MARK: - Accessibility Announcement

/// Posts an accessibility announcement for VoiceOver users
func announceForAccessibility(_ message: String) {
    #if canImport(UIKit)
    UIAccessibility.post(notification: .announcement, argument: message)
    #endif
}
