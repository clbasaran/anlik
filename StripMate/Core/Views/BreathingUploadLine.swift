import SwiftUI

/// Minimal breathing gradient line shown at the top of the screen during photo upload.
/// Softly pulses opacity to indicate background activity without being intrusive.
struct BreathingUploadLine: View {
    @State private var breathing = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.5), .clear],
                    startPoint: breathing ? .leading : .trailing,
                    endPoint: breathing ? .trailing : .leading
                )
            )
            .frame(height: 2)
            .opacity(breathing ? 0.8 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
    }
}
