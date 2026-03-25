import SwiftUI

/// Full-screen overlay that plays when a secret moment gets unlocked.
/// Shows: lock pulse → shatter → light burst → blur dissolve → sparkles
struct SecretUnlockAnimation: View {
    let photoUrl: String
    let onComplete: () -> Void

    @State private var phase: AnimationPhase = .locked
    @State private var sparkles: [Sparkle] = []

    private enum AnimationPhase {
        case locked      // Lock icon visible, pulsing
        case shatter     // Lock breaks apart
        case burst       // Light expands
        case reveal      // Photo fades in, sparkles
        case done        // Animation complete
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Photo (always behind, revealed via opacity)
            CachedAsyncImage(url: URL(string: photoUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } placeholder: {
                Color.black
            }
            .opacity(phase == .reveal || phase == .done ? 1 : 0)
            .blur(radius: phase == .reveal ? 0 : 20)
            .animation(.easeOut(duration: 0.6), value: phase)

            // Blur overlay (fades out during reveal)
            if phase != .reveal && phase != .done {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Light burst circle
            if phase == .burst || phase == .reveal {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: phase == .burst ? 400 : 600
                        )
                    )
                    .scaleEffect(phase == .burst ? 0.1 : 3)
                    .opacity(phase == .reveal ? 0 : 1)
                    .animation(.easeOut(duration: 0.5), value: phase)
            }

            // Lock icon (pulsing → shattering)
            if phase == .locked || phase == .shatter {
                lockView
            }

            // Sparkles during reveal
            if phase == .reveal {
                ForEach(sparkles) { sparkle in
                    sparkleView(sparkle)
                }
            }
        }
        .onAppear {
            generateSparkles()
            startAnimation()
        }
    }

    // MARK: - Lock View

    private var lockView: some View {
        ZStack {
            // Lock body
            Image(systemName: "lock.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.white)
                .scaleEffect(phase == .locked ? 1.0 : 1.3)
                .opacity(phase == .shatter ? 0 : 1)
                .rotationEffect(.degrees(phase == .shatter ? -15 : 0))

            // Shatter particles
            if phase == .shatter {
                ForEach(0..<8, id: \.self) { i in
                    shatterParticle(index: i)
                }
            }
        }
        .modifier(PulseModifier(isActive: phase == .locked))
    }

    private func shatterParticle(index: Int) -> some View {
        let angle = Double(index) * 45.0
        let radians = angle * .pi / 180
        let distance: CGFloat = 120

        return Image(systemName: "lock.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white.opacity(0.6))
            .offset(
                x: cos(radians) * distance,
                y: sin(radians) * distance
            )
            .opacity(0)
            .rotationEffect(.degrees(angle))
            .animation(
                .easeOut(duration: 0.4).delay(Double(index) * 0.02),
                value: phase
            )
    }

    // MARK: - Sparkle

    struct Sparkle: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let delay: Double
        let duration: Double
    }

    private func generateSparkles() {
        sparkles = (0..<20).map { _ in
            Sparkle(
                x: CGFloat.random(in: -180...180),
                y: CGFloat.random(in: -350...350),
                size: CGFloat.random(in: 4...10),
                delay: Double.random(in: 0...0.4),
                duration: Double.random(in: 0.4...0.8)
            )
        }
    }

    @ViewBuilder
    private func sparkleView(_ sparkle: Sparkle) -> some View {
        Circle()
            .fill(.white)
            .frame(width: sparkle.size, height: sparkle.size)
            .offset(x: sparkle.x, y: sparkle.y)
            .opacity(phase == .reveal ? 1 : 0)
            .scaleEffect(phase == .reveal ? 1 : 0)
            .animation(
                .spring(response: sparkle.duration, dampingFraction: 0.5)
                .delay(sparkle.delay),
                value: phase
            )
    }

    // MARK: - Animation Sequence

    private func startAnimation() {
        // Phase 1: Pulse lock (0.6s)
        HapticsManager.playImpact(style: .medium)

        // Phase 2: Shatter (after 0.6s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                phase = .shatter
            }
            HapticsManager.playImpact(style: .heavy)
        }

        // Phase 3: Light burst (after 1.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .burst
            }
        }

        // Phase 4: Reveal photo + sparkles (after 1.3s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.6)) {
                phase = .reveal
            }
            HapticsManager.playNotification(type: .success)
        }

        // Phase 5: Done — auto dismiss (after 3.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            phase = .done
            onComplete()
        }
    }
}

// MARK: - Pulse Modifier

private struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.15 : 1.0)
            .shadow(color: .white.opacity(isPulsing ? 0.6 : 0.2), radius: isPulsing ? 20 : 8)
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}
