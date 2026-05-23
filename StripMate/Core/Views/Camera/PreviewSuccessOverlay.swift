import SwiftUI

/// "Gönderildi!" success overlay shown over the photo preview after a
/// successful send. Owns no state; the parent flips `isVisible` and the
/// view animates the paperplane lift-off.
struct PreviewSuccessOverlay: View {
    let isVisible: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.white.opacity(0.15), radius: 30, y: 10)
                    .scaleEffect(isVisible ? 1.2 : 0.01)
                    .rotationEffect(.degrees(isVisible ? 0 : -45))
                    .opacity(isVisible ? 1 : 0)

                Text(String(localized: "gönderildi!"))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isVisible ? 1 : 0.5)
                    .opacity(isVisible ? 1 : 0)
            }
        }
        .accessibilityHidden(!isVisible)
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
