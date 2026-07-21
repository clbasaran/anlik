import SwiftUI

/// Daily prompt banner shown in camera view. Lives on the camera HUD just
/// above the mode picker; visible until dismissed for the day or the day's
/// first strip is sent — at which point it flips in place to its
/// "gönderildi" state instead of vanishing.
struct DailyPromptBannerView: View {
    let prompt: DailyPrompt?
    let isCompleted: Bool
    var onDismiss: (() -> Void)? = nil

    /// The Cloud Function may store a real emoji character in `emoji`, but
    /// the app is SF-Symbols-only — anything that isn't a valid symbol name
    /// falls back to the prompt category's icon (gunluk-dongu-8).
    private var symbolName: String {
        guard let prompt else { return "camera.fill" }
        if UIImage(systemName: prompt.emoji) != nil { return prompt.emoji }
        return prompt.category.icon
    }

    var body: some View {
        if let prompt = prompt {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(Brand.scaledFont(size: 18, relativeTo: .title3))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "günün görevi"))
                        .font(Brand.scaledFont(size: 10, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(prompt.promptText)
                        .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)

                Spacer()

                if isCompleted {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(Brand.scaledFont(size: 10, weight: .bold, relativeTo: .caption))
                        Text(String(localized: "gönderildi"))
                            .font(Brand.scaledFont(size: 11, weight: .semibold, relativeTo: .caption))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .accessibilityElement(children: .combine)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                } else if let onDismiss {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(String(localized: "günün görevini kapat"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // Dark blur backing (matching the camera HUD's capsule language)
            // keeps the banner legible over bright scenes — the original
            // 6% white fill disappeared against the live viewfinder.
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            .padding(.horizontal, 16)
        }
    }
}

/// Vertical exposure slider for camera
struct ExposureControlView: View {
    @Binding var exposureBias: Float
    let range: ClosedRange<Float>
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(Brand.scaledFont(size: 14, weight: .bold, relativeTo: .footnote))
                .foregroundColor(.white)

            // Vertical slider via rotated horizontal Slider
            Slider(value: $exposureBias, in: range, step: 0.1)
                .tint(.white)
                .frame(width: 120)
                .rotationEffect(.degrees(-90))
                .frame(width: 30, height: 120)

            Button {
                HapticsManager.playImpact(style: .light)
                onReset()
            } label: {
                Text("0")
                    .font(Brand.scaledFont(size: 12, weight: .heavy, relativeTo: .caption))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(exposureBias == 0 ? Color.white.opacity(0.15) : Color.white.opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }
}
