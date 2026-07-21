import SwiftUI

/// First-launch coach mark for the collage editor. Tells the user the three
/// non-obvious gestures: tap thumb, drag on photo, pinch on photo.
/// Dismissed by tap or auto-fade after a few seconds. Persists dismissal in
/// AppStorage so it never reappears.
struct CollageHintOverlay: View {
    @Binding var isVisible: Bool

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            VStack(spacing: 10) {
                row(icon: "hand.tap", text: String(localized: "küçük foto: seç ve düzenle"))
                row(icon: "hand.draw", text: String(localized: "foto üstünde sürükle: çerçevele"))
                row(icon: "arrow.up.left.and.arrow.down.right", text: String(localized: "iki parmak: yakınlaştır"))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .padding(.horizontal, 28)
            Text(String(localized: "anladım"))
                .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Brand.Animations.fadeOutStandard) { isVisible = false }
        }
        .transition(.opacity)
    }

    private func row(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 24)
            Text(text)
                .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }
}
