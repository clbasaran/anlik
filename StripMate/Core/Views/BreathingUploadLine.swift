import SwiftUI

/// Top-edge upload indicator: a determinate white fill driven by the same
/// milestones as the Dynamic Island (UploadProgressState), with the original
/// breathing shimmer layered on top so the line still feels alive between
/// milestone jumps. Falls back to pure breathing when no progress is known.
struct BreathingUploadLine: View {
    @State private var breathing = false
    private var progressState = UploadProgressState.shared

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Determinate fill — animates between milestone values.
                if let progress = progressState.progress {
                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: geo.size.width * progress)
                        .animation(Brand.Animations.smooth, value: progress)
                }

                // Breathing shimmer across the full width — ambient life
                // between the milestone jumps.
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.5), .clear],
                            startPoint: breathing ? .leading : .trailing,
                            endPoint: breathing ? .trailing : .leading
                        )
                    )
                    .opacity(breathing ? 0.8 : 0.2)
            }
        }
        .frame(height: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
    }
}
