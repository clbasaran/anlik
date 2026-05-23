import SwiftUI

/// Top bar of MainCameraView: profile button on the left, friends-count pill
/// in the centre, balance spacer on the right. Pulled out of MainCameraView
/// so the body of that 700-line file reads as a layout instead of mixing
/// camera plumbing with header chrome.
struct CameraTopBar: View {
    let profile: UserProfile?
    let friendsCount: Int
    var onProfileTap: () -> Void

    var body: some View {
        HStack {
            // Top Left: Profile
            Button {
                HapticsManager.playImpact(style: .light)
                onProfileTap()
            } label: {
                avatarOrInitial
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(String(localized: "Profil ve Ayarlar"))
            .accessibilityHint(String(localized: "Ayarları açıp profilini görmek için çift dokun"))

            Spacer()

            // Top Middle: Friends Pill
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(String(localized: "\(friendsCount) arkadaş"))
                    .font(.system(.subheadline, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            .accessibilityLabel(String(localized: "\(friendsCount) arkadaş bağlı"))

            Spacer()

            // Empty spacer for balance (inbox moved to friends tab)
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var avatarOrInitial: some View {
        if let urlString = profile?.avatarUrl,
           let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
            } placeholder: {
                initialCircle
            }
        } else {
            initialCircle
        }
    }

    private var initialCircle: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(profile?.displayName?.prefix(1) ?? "?"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.white)
            )
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}

#Preview("With avatar") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            CameraTopBar(
                profile: UserProfile(
                    id: "1",
                    inviteCode: "AB",
                    email: nil,
                    displayName: "Celal",
                    username: nil,
                    dateOfBirth: nil,
                    avatarUrl: nil
                ),
                friendsCount: 7,
                onProfileTap: {}
            )
            Spacer()
        }
    }
}
