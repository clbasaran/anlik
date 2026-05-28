import SwiftUI

/// Press-scale button style used throughout the app.
/// Scales down to 95% on press with a spring bounce-back for a tactile feel.
/// Respects Reduce Motion accessibility setting.
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? (reduceMotion ? 1.0 : scale) : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(reduceMotion ? .easeInOut(duration: 0.1) : .spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Convenience modifier for checking Reduce Motion preference in views
extension View {
    /// Returns `Brand.Animations.fadeFast` when Reduce Motion is on, otherwise the provided animation
    func adaptiveAnimation<V: Equatable>(_ animation: Animation, value: V, reduceMotion: Bool) -> some View {
        self.animation(reduceMotion ? Brand.Animations.fadeFast : animation, value: value)
    }
}
