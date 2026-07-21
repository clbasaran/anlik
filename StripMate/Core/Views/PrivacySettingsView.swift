import SwiftUI

// MARK: - Privacy Settings View

struct PrivacySettingsView: View {
    @State private var blockedUsers: [(id: String, name: String?)] = []
    @State private var isLoadingBlocked = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Privacy Promise
                privacyPromiseCard

                // Privacy Toggles
                privacySection(title: "görünürlük") {
                    privacyToggle(
                        key: "privacy_hide_online",
                        label: "çevrimiçi durumunu gizle",
                        icon: "eye.slash.fill",
                        description: "diğerleri seni çevrimiçi göremez"
                    )
                    divider
                    privacyToggle(
                        key: "privacy_hide_read_receipts",
                        label: "okundu bilgisini gizle",
                        icon: "checkmark.message.fill",
                        description: "mesajları okuduğun bilgisi gönderilmez"
                    )
                    divider
                    privacyToggle(
                        key: "privacy_hide_leaderboard",
                        label: "liderlik tablosundan gizlen",
                        icon: "trophy.fill",
                        description: "sıralamada görünmezsin"
                    )
                }

                // Location
                privacySection(title: "doğum günü") {
                    privacyToggle(
                        key: "privacy_birthday_visible",
                        label: "doğum günümü arkadaşlarımla paylaş",
                        icon: "gift.fill",
                        description: "doğum günün geldiğinde arkadaşların bilgilendirilir",
                        defaultValue: true
                    )
                }

                privacySection(title: "konum") {
                    privacyToggle(
                        key: "privacy_share_location",
                        label: "konum paylaşımı",
                        icon: "location.fill",
                        description: "fotoğraflara konum bilgisi eklenir",
                        defaultValue: true
                    )
                    divider
                    privacyToggle(
                        key: "privacy_show_distance",
                        label: "mesafe göster",
                        icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                        description: "widget'ta arkadaşınla arandaki mesafe"
                    )
                }

                // Blocked Users
                privacySection(title: "engellenen kullanıcılar") {
                    if isLoadingBlocked {
                        HStack {
                            Spacer()
                            ProgressView().tint(.white.opacity(0.3))
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    } else if blockedUsers.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(Brand.scaledFont(size: 14, relativeTo: .footnote))
                                .foregroundColor(.white.opacity(0.2))
                            Text("engellenen kullanıcı yok")
                                .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
                                .foregroundColor(.white.opacity(0.25))
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(blockedUsers, id: \.id) { user in
                            blockedUserRow(userId: user.id, name: user.name)
                            if user.id != blockedUsers.last?.id {
                                divider
                            }
                        }
                    }
                }

                // Info
                Text("gizlilik ayarların yalnızca bu hesap için geçerlidir. engellenen kullanıcılar seni arkadaş olarak ekleyemez ve sana mesaj gönderemez.")
                    .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundColor(.white.opacity(0.2))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("gizlilik")
                    .font(Brand.scaledFont(size: 17, weight: .bold, relativeTo: .body))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadBlockedUsers()
        }
    }

    // MARK: - Components

    /// The app's privacy promise, stated plainly at the top of the privacy
    /// screen. Factual and quiet — these are commitments, not marketing.
    private var privacyPromiseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "gizlilik sözümüz."))
                .font(Brand.scaledFont(size: 15, weight: .bold, relativeTo: .body))
                .foregroundStyle(.white)

            promiseRow(icon: "rectangle.slash", text: String(localized: "reklam yok."))
            promiseRow(icon: "cpu", text: String(localized: "fotoğrafların yapay zeka eğitiminde kullanılmaz."))
            promiseRow(icon: "eye.slash", text: String(localized: "herkese açık akış yok."))
            promiseRow(icon: "person.2", text: String(localized: "anların sadece seçtiğin kişilere gider."))

            Text(String(localized: "kvkk uyumlu."))
                .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .brandCard()
        .accessibilityElement(children: .combine)
    }

    private func promiseRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 20)
            Text(text)
                .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // Titles/labels are `LocalizedStringResource` (not `String`) so the Turkish
    // literals at the call sites land in the string catalog and localize.
    private func privacySection(title: LocalizedStringResource, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.35))
                .textCase(.uppercase)
                .tracking(1)
                .padding(.horizontal, 4)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private func privacyToggle(key: String, label: LocalizedStringResource, icon: String, description: LocalizedStringResource, defaultValue: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Brand.scaledFont(size: 15, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.8))

                Text(description)
                    .font(Brand.scaledFont(size: 12, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.25))
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: key)
                    Task {
                        try? await AuthService.shared.updateNotificationPreference(key: key, enabled: newValue)
                    }
                }
            ))
            .tint(.white.opacity(0.5))
            .labelsHidden()
        }
        .padding(.vertical, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

    private func blockedUserRow(userId: String, name: String?) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(name?.prefix(1) ?? "?"))
                        .font(Brand.scaledFont(size: 14, weight: .bold, relativeTo: .footnote))
                        .foregroundColor(.white.opacity(0.4))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name ?? userId)
                    .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                    .foregroundColor(.white.opacity(0.7))

                Text(userId.prefix(8) + "...")
                    .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundColor(.white.opacity(0.2))
            }

            Spacer()

            Button {
                Task {
                    // Unblock from Firestore
                    try? await DependencyContainer.shared.userRepository.unblockUser(userId)
                    blockedUsers.removeAll { $0.id == userId }
                    HapticsManager.playNotification(type: .success)
                }
            } label: {
                Text("engeli kaldır")
                    .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func loadBlockedUsers() async {
        isLoadingBlocked = true
        do {
            let ids = try await DependencyContainer.shared.userRepository.fetchBlockedUserIds()
            var users: [(id: String, name: String?)] = []
            for id in ids {
                let profile = try? await DependencyContainer.shared.userRepository.fetchProfile(for: id)
                users.append((id: id, name: profile?.displayName))
            }
            blockedUsers = users
        } catch {
            blockedUsers = []
        }
        isLoadingBlocked = false
    }
}
