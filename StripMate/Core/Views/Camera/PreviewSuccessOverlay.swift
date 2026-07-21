import SwiftUI

/// "Gönderildi!" success overlay shown over the photo preview after a
/// successful send. The parent flips `isVisible` and controls dismissal;
/// the view owns only the paperplane's internal beats — scale-in, a short
/// hold, then a lift-off toward the top-trailing corner while it fades.
/// Under Reduce Motion the plane simply fades with no travel.
struct PreviewSuccessOverlay: View {
    let isVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLiftingOff = false
    @State private var isPlaneFaded = false
    @State private var liftOffTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.white.opacity(0.15), radius: 30, y: 10)
                    .scaleEffect(isVisible ? 1.2 : 0.01)
                    .rotationEffect(.degrees(planeRotation))
                    .offset(planeOffset)
                    .opacity(isVisible && !isPlaneFaded ? 1 : 0)

                Text(String(localized: "gönderildi!"))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isVisible ? 1 : 0.5)
                    .opacity(isVisible ? 1 : 0)
            }
        }
        .accessibilityHidden(!isVisible)
        .onAppear {
            if isVisible { scheduleLiftOff() }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                scheduleLiftOff()
            } else {
                liftOffTask?.cancel()
                liftOffTask = nil
                isLiftingOff = false
                isPlaneFaded = false
            }
        }
        .onDisappear {
            liftOffTask?.cancel()
            liftOffTask = nil
        }
    }

    // MARK: - Lift-off beats

    private var planeRotation: Double {
        guard isVisible else { return -45 }
        return isLiftingOff ? -12 : 0
    }

    private var planeOffset: CGSize {
        isLiftingOff ? CGSize(width: 140, height: -180) : .zero
    }

    /// After the initial appear beat (~0.55s hold) the plane launches toward
    /// the top-trailing corner (bouncy) while fading out (fadeOutStandard,
    /// slightly delayed so the travel reads before the plane disappears).
    /// The "gönderildi!" text stays put until the parent dismisses, so the
    /// calling flow's timings are unchanged.
    private func scheduleLiftOff() {
        liftOffTask?.cancel()
        liftOffTask = Task {
            try? await Task.sleep(for: .seconds(0.55))
            guard !Task.isCancelled else { return }
            if reduceMotion {
                withAnimation(Brand.Animations.fadeOutStandard) {
                    isPlaneFaded = true
                }
            } else {
                withAnimation(Brand.Animations.bouncy) {
                    isLiftingOff = true
                }
                withAnimation(Brand.Animations.fadeOutStandard.delay(0.15)) {
                    isPlaneFaded = true
                }
            }
        }
    }
}

#Preview("Visible") {
    PreviewSuccessOverlay(isVisible: true)
        .background(Color.gray)
}

#Preview("Hidden") {
    PreviewSuccessOverlay(isVisible: false)
        .background(Color.gray)
}
