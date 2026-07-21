import SwiftUI

/// Slim banner shown at the top of the camera when a previous send failed
/// (or was interrupted by an app kill). Surfaces the persisted draft with a
/// single tap-to-retry action and an opt-out cancel.
struct DraftRetryBanner: View {
    let onRetry: () -> Void
    let onCancel: () -> Void

    /// Discard is destructive — the draft holds the only copy of the unsent
    /// moment — so the X asks before wiping (guven-5). No accidental-tap
    /// data loss on a 24pt target.
    @State private var showDiscardConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full")
                .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "taslak hazır"))
                    .font(Brand.scaledFont(size: 13, weight: .bold, relativeTo: .footnote))
                    .foregroundStyle(.white)
                Text(String(localized: "gönderilemeyen bir an seni bekliyor"))
                    .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Spacer()
            Button {
                onRetry()
            } label: {
                Text(String(localized: "tekrar dene"))
                    .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Button {
                showDiscardConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "taslağı sil"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        .confirmationDialog(
            String(localized: "taslağı sil?"),
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "taslağı sil"), role: .destructive) {
                onCancel()
            }
            Button(String(localized: "vazgeç"), role: .cancel) {}
        } message: {
            Text(String(localized: "gönderilmeyen an kalıcı olarak silinir."))
        }
    }
}
