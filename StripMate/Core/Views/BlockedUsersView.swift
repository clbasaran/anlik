import SwiftUI

/// Engellenen kullanıcıları listeleyen ve engel kaldırma imkanı sunan ekran.
struct BlockedUsersView: View {
    @State private var blockedUsers: [(id: String, profile: UserProfile?)] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var unblockingId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if blockedUsers.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(String(localized: "engellenen kullanıcılar"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadBlockedUsers()
        }
    }

    // MARK: - Boş Durum

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.2))

            Text(String(localized: "engellenen kullanıcı yok"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Liste

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(blockedUsers, id: \.id) { entry in
                    blockedUserRow(entry)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private func blockedUserRow(_ entry: (id: String, profile: UserProfile?)) -> some View {
        HStack(spacing: 14) {
            // Avatar
            if let url = entry.profile?.avatarUrl, let imageUrl = URL(string: url) {
                CachedAsyncImage(url: imageUrl) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } placeholder: {
                    avatarPlaceholder(for: entry.profile)
                }
            } else {
                avatarPlaceholder(for: entry.profile)
            }

            // İsim
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.profile?.displayName ?? String(localized: "kullanıcı"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                if let username = entry.profile?.username {
                    Text("@\(username)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            Spacer()

            // Engeli Kaldır Butonu
            Button {
                Task {
                    await unblockUser(entry.id)
                }
            } label: {
                if unblockingId == entry.id {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 24, height: 24)
                } else {
                    Text(String(localized: "engeli kaldır"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .disabled(unblockingId != nil)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
        }
    }

    private func avatarPlaceholder(for profile: UserProfile?) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(profile?.displayName?.prefix(1) ?? "?"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            )
    }

    // MARK: - Veri İşlemleri

    private func loadBlockedUsers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let blockedIds = try await AuthService.shared.fetchBlockedUserIds()
            var results: [(id: String, profile: UserProfile?)] = []

            for id in blockedIds {
                let profile = try? await DependencyContainer.shared.userRepository.fetchProfile(for: id)
                results.append((id: id, profile: profile))
            }

            blockedUsers = results.sorted { ($0.profile?.displayName ?? "") < ($1.profile?.displayName ?? "") }
        } catch {
            errorMessage = "engellenen kullanıcılar yüklenemedi"
            #if DEBUG
            print("DEBUG: BlockedUsersView yükleme hatası: \(error.localizedDescription)")
            #endif
        }
    }

    private func unblockUser(_ userId: String) async {
        unblockingId = userId
        defer { unblockingId = nil }

        do {
            try await AuthService.shared.unblockUser(userId)
            await AuthService.shared.invalidateBlockedCache()
            blockedUsers.removeAll { $0.id == userId }
            HapticsManager.playNotification(type: .success)
        } catch {
            HapticsManager.playNotification(type: .error)
            #if DEBUG
            print("DEBUG: BlockedUsersView engel kaldirma hatasi: \(error.localizedDescription)")
            #endif
        }
    }
}
