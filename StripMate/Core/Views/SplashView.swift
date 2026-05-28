import SwiftUI

/// Cinematic launch animation — just brand text, nothing else.
struct SplashView: View {
    let onComplete: () -> Void

    @State private var phase: SplashPhase = .initial

    private enum SplashPhase: Int, Comparable {
        case initial     // Black screen
        case fadeIn      // Text fades in from slightly large
        case glow        // Subtle glow behind text
        case holdAndFade // Hold then fade out

        static func < (lhs: SplashPhase, rhs: SplashPhase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ZStack {
                // Glow behind text
                Text(Brand.name)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(phase >= .glow ? 0.15 : 0))
                    .blur(radius: 30)
                    .scaleEffect(phase >= .glow ? 1.3 : 1.0)

                // Main text
                Text(Brand.name)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(phase >= .glow ? 0.4 : 0), radius: 12)
            }
            .scaleEffect(phase == .initial ? 1.3 : 1.0)
            .opacity(phase == .initial ? 0 : (phase == .holdAndFade ? 0 : 1))
            .accessibilityLabel(Brand.name)
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Fade in + scale down
        withAnimation(.easeOut(duration: 0.4)) {
            phase = .fadeIn
        }

        Task {
            // Glow (after 0.4s)
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(Brand.Animations.fadeSlow) {
                phase = .glow
            }
            HapticsManager.playImpact(style: .light)

            // Fade out (after 0.6s more = 1.0s total)
            try? await Task.sleep(for: .seconds(0.6))
            withAnimation(.easeIn(duration: 0.25)) {
                phase = .holdAndFade
            }

            // Complete (after 0.25s more = 1.25s total)
            try? await Task.sleep(for: .seconds(0.25))
            onComplete()
        }
    }
}
