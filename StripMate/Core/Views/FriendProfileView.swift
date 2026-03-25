import SwiftUI
import SwiftData
import FirebaseAuth

/// Friend profile page — shared photos gallery, streak stats, mutual actions
struct FriendProfileView: View {
    let friend: FriendStatus
    @Query(sort: \Strip.timestamp, order: .reverse) private var allStrips: [Strip]
    @State private var streak: Streak?
    @State private var freshProfile: UserProfile?
    @State private var showRemoveAlert = false
    @State private var isRemoving = false
    @Environment(\.dismiss) private var dismiss
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private var sharedStrips: [Strip] {
        let friendId = friend.userId
        let myId = currentUserId
        return allStrips.filter { strip in
            // Only show photos directly between me and this friend:
            // 1. I sent it AND this friend is a receiver
            // 2. This friend sent it AND I am a receiver
            let iSentToFriend = strip.senderId == myId && strip.receiverIds.contains(friendId)
            let friendSentToMe = strip.senderId == friendId && strip.receiverIds.contains(myId)
            return iSentToFriend || friendSentToMe
        }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    // Header with back button
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // Avatar + Name
                    VStack(spacing: 12) {
                        if let avatarUrl = (freshProfile ?? friend.profile)?.avatarUrl, let url = URL(string: avatarUrl) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                            } placeholder: {
                                avatarPlaceholder
                            }
                        } else {
                            avatarPlaceholder
                        }
                        
                        Text((freshProfile ?? friend.profile)?.displayName ?? (freshProfile ?? friend.profile)?.username ?? String(localized: "bilinmeyen"))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        
                        if let username = (freshProfile ?? friend.profile)?.username {
                            Text("@\(username)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        
                        if let bio = (freshProfile ?? friend.profile)?.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .padding(.horizontal, 32)
                                .padding(.top, 4)
                        }
                    }
                    
                    // Streak Stats
                    if let streak {
                        HStack(spacing: 20) {
                            statPill(value: "\(streak.currentStreak)", label: String(localized: "günlük seri"), icon: "sparkle")
                            statPill(value: "\(streak.longestStreak)", label: String(localized: "en uzun seri"), icon: "trophy.fill")
                            statPill(value: "\(streak.totalExchanges)", label: String(localized: "toplam an"), icon: "camera.fill")
                        }
                        .padding(.horizontal, 20)
                        
                        // Tier badge
                        HStack(spacing: 6) {
                            Image(systemName: streak.tier.tierIcon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            Text(streak.tier.tierName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    
                    // Shared photos gallery
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(String(localized: "birlikte paylaşılan anlar"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.45))
                                .textCase(.uppercase)
                                .tracking(1)
                            Spacer()
                            if !sharedStrips.isEmpty {
                                NavigationLink {
                                    SharedMomentsView(friendName: friend.profile?.displayName ?? "", strips: sharedStrips)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(String(localized: "tümünü gör"))
                                            .font(.system(size: 12, weight: .semibold))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if sharedStrips.isEmpty {
                            EmptyStateView(
                                icon: "photo.on.rectangle",
                                title: String(localized: "henüz paylaşılan an yok"),
                                subtitle: String(localized: "bir fotoğraf gönder ve burada görünsün.")
                            )
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 2),
                                GridItem(.flexible(), spacing: 2),
                                GridItem(.flexible(), spacing: 2)
                            ], spacing: 2) {
                                ForEach(sharedStrips.prefix(30), id: \.id) { strip in
                                    let locked = strip.isLockedFor(currentUserId)
                                    ZStack {
                                        CachedAsyncImage(url: URL(string: strip.smallThumbnailUrl ?? strip.thumbnailUrl ?? strip.imageUrl)) { image in
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                                .aspectRatio(1, contentMode: .fill)
                                                .clipped()
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.04))
                                                .aspectRatio(1, contentMode: .fill)
                                        }
                                        .blur(radius: locked ? 16 : 0)

                                        if locked {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 20)
                        }
                    }
                    // Arkadaşlıktan çıkar
                    Button {
                        showRemoveAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.minus")
                                .font(.system(size: 14, weight: .semibold))
                            Text(String(localized: "arkadaşlıktan çıkar"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.15), lineWidth: 0.5))
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
        }
        .navigationBarHidden(true)
        .alert(String(localized: "arkadaşlıktan çıkar"), isPresented: $showRemoveAlert) {
            Button(String(localized: "vazgeç"), role: .cancel) {}
            Button(String(localized: "çıkar"), role: .destructive) {
                Task {
                    isRemoving = true
                    try? await FriendshipService.shared.removeFriend(friend.userId)
                    isRemoving = false
                    dismiss()
                }
            }
        } message: {
            let name = (freshProfile ?? friend.profile)?.displayName ?? String(localized: "bu kişi")
            Text(String(localized: "\(name) arkadaş listenden çıkarılacak. bu işlem geri alınamaz."))
        }
        .task {
            async let streakTask = StreakService.shared.streak(with: friend.userId)
            async let profileTask = AuthService.shared.fetchProfile(for: friend.userId, forceRefresh: true)
            streak = await streakTask
            freshProfile = try? await profileTask
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 96, height: 96)
            .overlay(
                Text(String(((freshProfile ?? friend.profile)?.displayName ?? "?").prefix(1)))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
    
    private func statPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}
