import SwiftUI

/// Big centered numeral that ticks down before the shutter fires when the
/// self-timer is enabled. Pulses scale + opacity each second so the user
/// feels the rhythm without needing a beep.
struct TimerCountdownOverlay: View {
    let value: Int

    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            Text("\(value)")
                .font(.system(size: 144, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 18, y: 4)
                .scaleEffect(pulse ? 1.0 : 0.86)
                .opacity(pulse ? 1.0 : 0.6)
                .animation(Brand.Animations.tap, value: pulse)
                .onChange(of: value) { _, _ in
                    pulse.toggle()
                    HapticsManager.playImpact(style: .light)
                }
                .onAppear { pulse = true }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
