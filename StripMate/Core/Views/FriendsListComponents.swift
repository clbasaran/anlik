import SwiftUI
import FirebaseAuth

// MARK: - Search Result Card

struct FriendSearchResultCard: View {
    let profile: UserProfile
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 44, height: 44)
                .overlay(Text(String(profile.displayName?.prefix(1) ?? "?")).font(.system(size: 17, weight: .bold)).foregroundColor(.white))

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName ?? String(localized: "Kullanıcı"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(profile.inviteCode)
                    .font(.system(size: 12, design: .monospaced).weight(.medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Button {
                HapticsManager.playImpact(style: .medium)
                onAdd()
            } label: {
                Text(String(localized: "ekle"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}

// MARK: - Pending Request Row

struct FriendPendingRequestRow: View {
    let request: FriendStatus
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let urlStr = request.profile?.avatarUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } placeholder: {
                    FriendAvatarPlaceholder(initial: String((request.profile?.displayName ?? "U").prefix(1)))
                }
            } else {
                FriendAvatarPlaceholder(initial: String((request.profile?.displayName ?? "U").prefix(1)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.profile?.displayName ?? String(localized: "isimsiz"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(String(localized: "arkadaş olmak istiyor"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    HapticsManager.playNotification(type: .success)
                    onAccept()
                } label: {
                    Text(String(localized: "kabul et"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    HapticsManager.playImpact(style: .light)
                    onReject()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }
}

// MARK: - Conversation Row

struct FriendConversationRow: View {
    let conversation: ConversationItem
    let currentUserId: String?

    var body: some View {
        let hasUnread = (conversation.summary?.unreadCount ?? 0) > 0

        HStack(spacing: 14) {
            if let urlStr = conversation.avatarUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } placeholder: {
                    FriendAvatarPlaceholder(initial: conversation.avatarInitial, size: 48)
                }
            } else {
                FriendAvatarPlaceholder(initial: conversation.avatarInitial, size: 48)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conversation.displayName)
                        .font(.system(size: 16, weight: hasUnread ? .bold : .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    if let summary = conversation.summary {
                        Text(friendTimeAgo(summary.lastMessageTimestamp))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(hasUnread ? .white : .white.opacity(0.3))
                    }
                }

                HStack {
                    if let summary = conversation.summary {
                        let isMe = summary.lastMessageSenderId == (currentUserId ?? "")
                        Text(isMe ? String(localized: "sen: \(summary.lastMessage)") : summary.lastMessage)
                            .font(.system(size: 13, weight: hasUnread ? .semibold : .regular))
                            .foregroundColor(hasUnread ? .white.opacity(0.7) : .white.opacity(0.35))
                            .lineLimit(1)
                    } else {
                        Text(String(localized: "sohbete başla"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Spacer()

                    if hasUnread, let unreadCount = conversation.summary?.unreadCount {
                        Text("\(unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(hasUnread ? Color.white.opacity(0.07) : Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

// MARK: - Friend Card Components

struct FriendCardView: View {
    let friend: Friend
    let streak: Streak?
    let onTapProfile: () -> Void
    let onAccept: () -> Void
    let onReject: () -> Void
    let onDM: (() -> Void)?
    let dmDestination: UserProfile?

    var body: some View {
        VStack(spacing: 0) {
            FriendCardHeaderView(
                friend: friend,
                onTapProfile: onTapProfile,
                onAcceptFriend: { userId in onAccept() },
                onRejectFriend: { userId in onReject() }
            )
            FriendCardStreakView(friend: friend, streak: streak)
            FriendCardTierProgressView(friend: friend, streak: streak)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 20)
    }
}

struct FriendCardHeaderView: View {
    let friend: Friend
    let onTapProfile: () -> Void
    var onAcceptFriend: ((String) async -> Void)?
    var onRejectFriend: ((String) async -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let avatarUrl = friend.profile?.avatarUrl,
               let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } placeholder: {
                    FriendAvatarPlaceholder(for: friend)
                }
            } else {
                FriendAvatarPlaceholder(for: friend)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(friend.profile?.displayName ?? friend.profile?.username ?? String(localized: "isimsiz"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if friend.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Color.yellow.opacity(0.9))
                            .font(.system(size: 11, weight: .bold))
                    }
                }

                if friend.isPending {
                    let isIncoming = friend.requesterId != nil && friend.requesterId != FirebaseAuth.Auth.auth().currentUser?.uid
                    Text(isIncoming ? String(localized: "sana istek gönderdi") : String(localized: "istek gönderildi"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !friend.isPending {
                    onTapProfile()
                }
            }

            Spacer(minLength: 4)

            if friend.isPending {
                FriendCardPendingActions(friend: friend, onAccept: onAcceptFriend, onReject: onRejectFriend)
            } else {
                FriendCardActiveActions(friend: friend)
            }
        }
    }
}

struct FriendCardPendingActions: View {
    let friend: Friend
    var onAccept: ((String) async -> Void)?
    var onReject: ((String) async -> Void)?

    var body: some View {
        let isIncoming = friend.requesterId != nil && friend.requesterId != FirebaseAuth.Auth.auth().currentUser?.uid
        if isIncoming {
            HStack(spacing: 8) {
                Button {
                    Task { await onAccept?(friend.userId) }
                } label: {
                    Text(String(localized: "kabul et"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(String(localized: "Arkadaşlık isteğini kabul et"))

                Button {
                    Task { await onReject?(friend.userId) }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "isteği reddet"))
            }
        } else {
            Button {
                HapticsManager.playImpact(style: .light)
                Task { await onReject?(friend.userId) }
            } label: {
                Text(String(localized: "iptal"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

struct FriendCardActiveActions: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 8) {
            if let profileContext = friend.profile {
                let metadataProfile = UserProfile(
                    id: profileContext.id,
                    inviteCode: profileContext.inviteCode,
                    email: profileContext.email,
                    displayName: profileContext.displayName,
                    username: profileContext.username,
                    dateOfBirth: profileContext.dateOfBirth,
                    avatarUrl: profileContext.avatarUrl,
                    bio: profileContext.bio
                )
                NavigationLink {
                    DirectMessageView(partner: metadataProfile)
                } label: {
                    Image(systemName: "bubble.right.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "mesaj gönder"))
            }
        }
    }
}

struct FriendCardStreakView: View {
    let friend: Friend
    let streak: Streak?

    @State private var sparkleAnimating = false

    var body: some View {
        if !friend.isPending, let streak = streak {
            HStack(spacing: 16) {
                if streak.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            // Subtle "alive" pulse on the streak indicator —
                            // gives a small daily-return cue without being
                            // showy. Reduce-motion users get a static icon.
                            .scaleEffect(sparkleAnimating ? 1.18 : 0.92)
                            .opacity(sparkleAnimating ? 1.0 : 0.7)
                            .animation(
                                UIAccessibility.isReduceMotionEnabled
                                    ? .default
                                    : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                                value: sparkleAnimating
                            )
                            .onAppear {
                                if !UIAccessibility.isReduceMotionEnabled {
                                    sparkleAnimating = true
                                }
                            }
                        Text("\(streak.currentStreak)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: streak.tier.tierIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.gray)
                    Text(streak.tier.tierName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.gray)
                }

                if let currentId = FirebaseAuth.Auth.auth().currentUser?.uid,
                   streak.lastSenderId != currentId,
                   streak.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .medium))
                        Text(String(localized: "senin sıran"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }

                if streak.isFrozen {
                    HStack(spacing: 4) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 10, weight: .medium))
                        Text(String(localized: "donduruldu"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                } else if streak.canFreezeNow {
                    Button {
                        Task {
                            do {
                                try await StreakService.shared.freezeStreak(streakId: streak.id)
                                HapticsManager.playNotification(type: .success)
                                // Force-refresh the streak listener cache so the
                                // UI flips from "bağı dondur" → "donduruldu"
                                // even before the snapshot listener fires.
                                if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
                                    await StreakService.shared.startListening(for: uid)
                                }
                            } catch {
                                HapticsManager.playNotification(type: .error)
                                AppLogger.ui.error("freezeStreak failed: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 10, weight: .medium))
                            Text(String(localized: "bağı dondur"))
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.16))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else if streak.isExpiringSoon {
                    StreakExpiringClock()
                }

                Spacer()
            }
            .padding(.top, 10)
            .padding(.leading, 56)
        }
    }
}

struct FriendCardTierProgressView: View {
    let friend: Friend
    let streak: Streak?

    var body: some View {
        if !friend.isPending, let streak = streak, streak.friendshipScore > 0 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 2)
                    Capsule()
                        .fill(LinearGradient(colors: friendTierGradient(for: streak.tier), startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * streak.tierProgress, height: 2)
                        .animation(.easeInOut(duration: 0.6), value: streak.tierProgress)
                }
            }
            .frame(height: 2)
            .padding(.top, 12)
        }
    }
}

// MARK: - Stat Pill

struct FriendStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
        }
    }
}

// MARK: - Avatar Placeholder

struct FriendAvatarPlaceholder: View {
    let initial: String
    let size: CGFloat

    init(initial: String, size: CGFloat = 44) {
        self.initial = initial
        self.size = size
    }

    init(for friend: Friend) {
        self.initial = String((friend.profile?.displayName ?? friend.profile?.username ?? "?").prefix(1))
        self.size = 44
    }

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Skeleton Conversation Row

struct SkeletonConversationRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 180, height: 12)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .shimmer()
    }
}

// MARK: - Report User Sheet

struct ReportUserSheet: View {
    let userName: String
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let reasons = [
        String(localized: "Uygunsuz İçerik"),
        String(localized: "Taciz veya Zorbalık"),
        String(localized: "Spam veya Sahte Hesap"),
        String(localized: "Diğer")
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(String(localized: "kullanıcıyı şikâyet et"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)

                Text(String(localized: "bu kullanıcıyı neden şikâyet ediyorsun?"))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))

                VStack(spacing: 12) {
                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            onReport(reason)
                        } label: {
                            Text(reason)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text(String(localized: "iptal"))
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 32)
        }
    }
}

// MARK: - Helpers

func friendTierGradient(for tier: Streak.FriendshipTier) -> [Color] {
    switch tier {
    case .tanidik:  return [.white.opacity(0.2), .white.opacity(0.3)]
    case .muhabbet: return [.white.opacity(0.3), .white.opacity(0.4)]
    case .yakin:    return [.white.opacity(0.4), .white.opacity(0.6)]
    case .sirdas:   return [.white.opacity(0.6), .white.opacity(0.8)]
    case .kadim:    return [.white.opacity(0.8), .white]
    }
}

func friendTimeAgo(_ date: Date) -> String {
    TurkishDateFormatter.timeAgo(from: date)
}

/// Faster-pulsing clock icon used when a streak is about to expire. Stays in
/// the monochrome palette — urgency comes from the pulse cadence, not color.
struct StreakExpiringClock: View {
    @State private var pulsing = false

    var body: some View {
        Image(systemName: "clock.badge.exclamationmark")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .scaleEffect(pulsing ? 1.18 : 0.92)
            .opacity(pulsing ? 1.0 : 0.45)
            .animation(
                UIAccessibility.isReduceMotionEnabled
                    ? .default
                    : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                value: pulsing
            )
            .onAppear {
                if !UIAccessibility.isReduceMotionEnabled {
                    pulsing = true
                }
            }
    }
}
