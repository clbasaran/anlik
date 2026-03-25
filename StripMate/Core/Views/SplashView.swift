import SwiftUI

/// Cinematic launch animation — just "anlık." text, nothing else.
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
                Text("anlık.")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(phase >= .glow ? 0.15 : 0))
                    .blur(radius: 30)
                    .scaleEffect(phase >= .glow ? 1.3 : 1.0)

                // Main text
                Text("anlık.")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(phase >= .glow ? 0.4 : 0), radius: 12)
            }
            .scaleEffect(phase == .initial ? 1.3 : 1.0)
            .opacity(phase == .initial ? 0 : (phase == .holdAndFade ? 0 : 1))
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Fade in + scale down
        withAnimation(.easeOut(duration: 0.5)) {
            phase = .fadeIn
        }

        // Glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                phase = .glow
            }
        }

        // Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeIn(duration: 0.3)) {
                phase = .holdAndFade
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            onComplete()
        }
    }
}
