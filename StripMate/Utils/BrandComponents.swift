import SwiftUI

// MARK: - anlık. Design-System Components
//
// Canonical reusable surfaces and controls for the monochrome OLED-black
// identity. Prefer these over hand-rolled copies so surface opacities,
// radii and hit targets stay consistent across the app.

// MARK: - Surface Modifiers

extension View {

    /// Canonical elevated-card surface: 4% white fill inside a continuous
    /// 16pt rounded rectangle with a 0.5pt 6% white hairline stroke.
    func brandCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Brand.Radius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
    }

    /// Raised chip / input surface: 8% white fill inside a capsule, no stroke.
    func brandChip() -> some View {
        self
            .background(Color.white.opacity(0.08), in: Capsule())
    }

    /// Canonical eyebrow / section-header treatment: 12pt bold uppercase,
    /// 35% white, 1pt tracking.
    func sectionHeader() -> some View {
        self
            .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
            .foregroundStyle(Color.white.opacity(0.35))
            .textCase(.uppercase)
            .tracking(1)
    }
}

// MARK: - Circle Icon Button

/// The app's one close/icon circle button — replaces 22 hand-rolled copies.
/// A 36pt (default) circular 8% white surface with a centered SF Symbol,
/// wrapped in a 44pt hit target with press-scale feedback.
struct CircleIconButton: View {
    var icon: String
    var size: CGFloat = 36
    var iconSize: CGFloat = 14
    var accessibilityLabel: LocalizedStringResource
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(Brand.scaledFont(size: iconSize, weight: .bold, relativeTo: .footnote))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

// MARK: - Sheet Header

/// Canonical sheet header: circular close button on the left, centered bold
/// title, and a clear 44pt spacer on the right to keep the title balanced.
struct SheetHeader: View {
    var title: LocalizedStringResource
    var onClose: () -> Void

    var body: some View {
        HStack {
            CircleIconButton(icon: "xmark", accessibilityLabel: "kapat", action: onClose)
            Spacer()
            Text(title)
                .font(Brand.scaledFont(size: 17, weight: .bold, relativeTo: .body))
                .foregroundStyle(.white)
            Spacer()
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
