import SwiftUI

/// "Gönder" / "arkadaş ekle" button shown at the bottom of PreviewView. When
/// the user has no friends yet, the same surface flips to an empty-state CTA
/// that routes to the Friends tab — so this button is always usable, never
/// disabled in a confusing way.
///
/// Pulled out of PreviewView so the parent stops carrying alert state and
/// the no-friends fallback for what is conceptually one component.
struct PreviewSendButton: View {
    let availableFriends: [FriendStatus]
    let isUploading: Bool
    let showSuccess: Bool
    var onSendTap: () -> Void
    /// Long-press path that always opens the picker — escape hatch for users
    /// who pre-selected receivers but want to change them on this send.
    /// Optional; falls back to plain `onSendTap` if not wired.
    var onSendLongPress: (() -> Void)? = nil
    var onAddFriend: () -> Void
    var onRetake: () -> Void

    @State private var showNoFriendsAlert = false

    var body: some View {
        Button {
            HapticsManager.playImpact(style: .medium)
            if availableFriends.isEmpty {
                showNoFriendsAlert = true
            } else {
                onSendTap()
            }
        } label: {
            HStack(spacing: 8) {
                Text(availableFriends.isEmpty
                     ? String(localized: "arkadaş ekle")
                     : String(localized: "gönder"))
                    .font(.system(.title3, weight: .heavy))
                Image(systemName: availableFriends.isEmpty ? "person.badge.plus" : "chevron.right")
                    .font(Brand.scaledFont(size: 15, weight: .heavy, relativeTo: .body))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Brand.Spacing.lg - 2)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isUploading || showSuccess)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                guard !availableFriends.isEmpty else { return }
                HapticsManager.playImpact(style: .medium)
                if let onSendLongPress = onSendLongPress {
                    onSendLongPress()
                } else {
                    onSendTap()
                }
            }
        )
        .accessibilityLabel(availableFriends.isEmpty
                            ? String(localized: "Arkadaş Ekle")
                            : String(localized: "Fotoğraf Gönder"))
        .alert(String(localized: "arkadaş ekle"), isPresented: $showNoFriendsAlert) {
            Button(String(localized: "arkadaş ekle")) {
                onAddFriend()
                onRetake()
            }
            Button(String(localized: "iptal"), role: .cancel) {}
        } message: {
            Text(String(localized: "fotoğraf göndermek için en az bir arkadaş eklemelisin."))
        }
    }
}

// MARK: - Send Chips Row

/// Compact chip row rendered directly above `PreviewSendButton`.
///
/// - Recipients chip ("ali, ayşe +1"): shows exactly who will receive the
///   send when the user taps gönder without opening the picker. Tapping it
///   opens the friend picker sheet. This is what makes the one-tap send safe:
///   the selection is visible on the preview instead of hidden in the sheet.
/// - Location chip ("kadıköy · kaldır"): shown when a location will ride
///   along with this send; one tap strips it for this send only.
struct PreviewSendChipsRow: View {
    /// Display names of the currently selected (still-valid) recipients.
    let recipientNames: [String]
    /// Lowercase city label for the location chip; nil hides the chip.
    /// Falls back to "konum" upstream when only coordinates are known.
    let locationLabel: String?
    let isDisabled: Bool
    var onRecipientsTap: () -> Void
    var onRemoveLocation: () -> Void

    /// "ali, ayşe +1" — first two names, then a count for the rest.
    private var recipientsText: String {
        let visible = recipientNames.prefix(2).joined(separator: ", ")
        let remaining = recipientNames.count - min(recipientNames.count, 2)
        return remaining > 0 ? "\(visible) +\(remaining)" : visible
    }

    var body: some View {
        HStack(spacing: 8) {
            if !recipientNames.isEmpty {
                chip(icon: "person.2.fill", text: recipientsText, action: onRecipientsTap)
                    .accessibilityLabel(String(localized: "Alıcılar: \(recipientNames.joined(separator: ", "))"))
                    .accessibilityHint(String(localized: "Alıcıları değiştirmek için dokun."))
            }
            if let locationLabel {
                chip(icon: "location.fill", text: String(localized: "\(locationLabel) · kaldır"), action: onRemoveLocation)
                    .layoutPriority(1)
                    .accessibilityLabel(String(localized: "Konumu kaldır"))
                    .accessibilityHint(String(localized: "Bu an konumsuz gönderilir."))
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(isDisabled)
    }

    private func chip(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticsManager.playSelection()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                Text(text)
                    .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
