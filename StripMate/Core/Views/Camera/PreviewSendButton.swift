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
                    .font(.system(size: 15, weight: .heavy))
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
