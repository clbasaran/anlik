import SwiftUI

/// Netflix-style launch animation for anlık.
/// Logo fades in with cinematic zoom → subtle glow → text appears → fades out
struct SplashView: View {
    let onComplete: () -> Void

    @State private var phase: SplashPhase = .initial

    private enum SplashPhase: Int, Comparable {
        case initial     // Black screen
        case logoIn      // Logo zooms in from large
        case glow        // Logo glows
        case textIn      // "anlık." text appears below
        case holdAndFade // Hold then fade everything out

        static func < (lhs: SplashPhase, rhs: SplashPhase) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // App icon / logo
                ZStack {
                    // Glow circle behind logo
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(phase >= .glow ? 0.15 : 0),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 120
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(phase >= .glow ? 1.2 : 0.8)

                    // Logo image or placeholder
                    if let appIcon = UIImage(named: "AppIconMinimal") ?? UIImage(named: "AppIcon") {
                        Image(uiImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .white.opacity(phase >= .glow ? 0.3 : 0), radius: 20)
                    } else {
                        // Fallback: text-based logo
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(white: 0.12))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Text("a.")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: .white.opacity(phase >= .glow ? 0.3 : 0), radius: 20)
                    }
                }
                .scaleEffect(phase == .initial ? 2.0 : (phase == .logoIn ? 1.0 : 1.0))
                .opacity(phase == .initial ? 0 : (phase == .holdAndFade ? 0 : 1))

                // App name
                Text("anlık.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(phase >= .textIn ? 1 : 0)
                    .offset(y: phase >= .textIn ? 0 : 10)
                    .opacity(phase == .holdAndFade ? 0 : 1)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Phase 1: Logo zooms in (0 → 0.4s)
        withAnimation(.easeOut(duration: 0.5)) {
            phase = .logoIn
        }

        // Phase 2: Glow (0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                phase = .glow
            }
        }

        // Phase 3: Text appears (0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                phase = .textIn
            }
        }

        // Phase 4: Hold then fade (1.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.3)) {
                phase = .holdAndFade
            }
        }

        // Complete (1.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            onComplete()
        }
    }
}
