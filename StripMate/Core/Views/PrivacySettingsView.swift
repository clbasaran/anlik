import SwiftUI

// MARK: - Privacy Settings View

struct PrivacySettingsView: View {
    @State private var blockedUsers: [(id: String, name: String?)] = []
    @State private var isLoadingBlocked = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
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
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.2))
                            Text("engellenen kullanıcı yok")
                                .font(.system(size: 14, weight: .medium))
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
                    .font(.system(size: 12, weight: .medium))
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
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadBlockedUsers()
        }
    }
    
    // MARK: - Components
    
    private func privacySection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
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
    
    private func privacyToggle(key: String, label: String, icon: String, description: String, defaultValue: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text(description)
                    .font(.system(size: 12, weight: .regular))
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name ?? userId)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(userId.prefix(8) + "...")
                    .font(.system(size: 11, weight: .medium))
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
                    .font(.system(size: 12, weight: .semibold))
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
