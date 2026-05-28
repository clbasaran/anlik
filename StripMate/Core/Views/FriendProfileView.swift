import SwiftUI
import SwiftData
import FirebaseAuth

/// Friend profile page — shared photos gallery, streak stats, mutual actions
struct FriendProfileView: View {
    let friend: FriendStatus
    /// Where the user opened this profile from. Forwarded to ProfileVisitsService
    /// so the automation engine can segment visits by funnel.
    var visitSource: ProfileVisitSource = .list
    @Query(sort: \Strip.timestamp, order: .reverse) private var allStrips: [Strip]
    @State private var streak: Streak?
    @State private var freshProfile: UserProfile?
    @State private var showRemoveAlert = false
    @State private var isRemoving = false
    @State private var nudgeRemaining: Int = 3
    @State private var isNudging = false
    @State private var showNudgeSuccess = false
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
        NavigationStack {
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

                    // Profile loops — short Boomerang-style videos
                    if let loops = (freshProfile ?? friend.profile)?.profileLoops, !loops.isEmpty {
                        ProfileLoopGalleryView(loops: loops, editable: false)
                            .padding(.horizontal, 20)
                    }

                    // Profile personalization
                    profilePersonalizationSection

                    // Nudge button
                    nudgeButton

                    // Streak Stats
                    if let streak {
                        HStack(spacing: 20) {
                            statPill(value: "\(streak.currentStreak)", label: String(localized: "günlük bağ"), icon: "sparkle")
                            statPill(value: "\(streak.longestStreak)", label: String(localized: "en uzun bağ"), icon: "trophy.fill")
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

                    // Friendship profile button
                    if let profile = freshProfile ?? friend.profile {
                        NavigationLink {
                            FriendshipProfileView(friendId: friend.userId, friendProfile: profile, visitSource: visitSource)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(String(localized: "arkadaşlık profili"))
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                        }
                    }

                    // Inline friendship stats (preview of friendship profile)
                    if !sharedStrips.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(String(localized: "arkadaşlık istatistikleri"))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .textCase(.uppercase)
                                    .tracking(1)
                                Spacer()
                            }
                            .padding(.horizontal, 20)

                            HStack(spacing: 12) {
                                friendStatCard(
                                    icon: "photo.fill",
                                    value: "\(sharedStrips.count)",
                                    label: String(localized: "toplam an")
                                )
                                friendStatCard(
                                    icon: "arrow.up.right",
                                    value: "\(sharedStrips.filter { $0.senderId == currentUserId }.count)",
                                    label: String(localized: "gönderilen")
                                )
                                friendStatCard(
                                    icon: "arrow.down.left",
                                    value: "\(sharedStrips.filter { $0.senderId != currentUserId }.count)",
                                    label: String(localized: "alınan")
                                )
                            }
                            .padding(.horizontal, 20)

                            // Mini photo grid (6 photos)
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 2),
                                GridItem(.flexible(), spacing: 2),
                                GridItem(.flexible(), spacing: 2)
                            ], spacing: 2) {
                                ForEach(sharedStrips.prefix(6), id: \.id) { strip in
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
        }
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
            async let nudgeTask = NudgeService.shared.nudgesRemainingToday(for: friend.userId)
            streak = await streakTask
            freshProfile = try? await profileTask
            nudgeRemaining = await nudgeTask

            // Fire-and-forget visit log for the automation engine. Self-visits,
            // duplicate visits within 5 min, and blocked pairs are filtered
            // inside the service.
            await ProfileVisitsService.shared.recordVisit(
                visitorId: currentUserId,
                profileId: friend.userId,
                source: visitSource
            )
        }
    }

    private let zodiacDisplayMap: [String: (name: String, icon: String)] = [
        "aries": ("Koc", "arrow.up.right"), "taurus": ("Boga", "circle.fill"), "gemini": ("Ikizler", "person.2"),
        "cancer": ("Yengec", "moon.fill"), "leo": ("Aslan", "sun.max.fill"), "virgo": ("Basak", "leaf.fill"),
        "libra": ("Terazi", "scale.3d"), "scorpio": ("Akrep", "bolt.fill"), "sagittarius": ("Yay", "location.north.fill"),
        "capricorn": ("Oglak", "mountain.2.fill"), "aquarius": ("Kova", "drop.fill"), "pisces": ("Balik", "water.waves")
    ]

    @ViewBuilder
    private var nudgeButton: some View {
        Button {
            guard !isNudging, nudgeRemaining > 0 else { return }
            isNudging = true
            Task {
                do {
                    try await NudgeService.shared.sendNudge(to: friend.userId)
                    nudgeRemaining = max(0, nudgeRemaining - 1)
                    showNudgeSuccess = true
                    HapticsManager.playImpact(style: .medium)
                    // Auto-hide success after 2s
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    showNudgeSuccess = false
                } catch {
                    HapticsManager.playNotification(type: .error)
                }
                isNudging = false
            }
        } label: {
            HStack(spacing: 6) {
                if showNudgeSuccess {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                    Text(String(localized: "dürtüldü!"))
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 14))
                    Text(String(localized: "Dürt"))
                        .font(.system(size: 14, weight: .semibold))
                    if nudgeRemaining < 3 {
                        Text("\(nudgeRemaining)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
            .foregroundStyle(nudgeRemaining > 0 ? .white : .white.opacity(0.3))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(nudgeRemaining > 0 ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        }
        .disabled(nudgeRemaining <= 0 || isNudging)
        .animation(Brand.Animations.fadeQuick, value: showNudgeSuccess)
    }

    @ViewBuilder
    private var profilePersonalizationSection: some View {
        let p = freshProfile ?? friend.profile
        let hasSong = !(p?.favoriteSong ?? "").isEmpty
        let hasZodiac = !(p?.zodiacSign ?? "").isEmpty
        let hasEmojis = !(p?.personalityEmojis ?? []).isEmpty

        if hasSong || hasZodiac || hasEmojis {
            VStack(spacing: 10) {
                if let song = p?.favoriteSong, !song.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(song)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                if let zodiac = p?.zodiacSign, let display = zodiacDisplayMap[zodiac] {
                    HStack(spacing: 6) {
                        Image(systemName: display.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(display.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if let emojis = p?.personalityEmojis, !emojis.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(emojis, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
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

    private func friendStatCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}
