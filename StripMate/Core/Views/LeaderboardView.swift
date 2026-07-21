import SwiftUI

/// "bağlarım" — a non-comparative overview of every friendship bond.
///
/// This screen deliberately is NOT a leaderboard: ranking your closest friends
/// against each other contradicts the app's own voice ("gösteriş için değil").
/// Each bond stands on its own card — flame, tier, record — ordered by which
/// friendship breathed most recently, with no ranks, medals, or podiums.
struct LeaderboardView: View {
    @State private var entries: [BondEntry] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    struct BondEntry: Identifiable {
        let id: String  // friendId
        let name: String
        let avatarUrl: String?
        let streakCount: Int
        let longestStreak: Int
        let exchangeCount: Int
        let tier: Streak.FriendshipTier
        let lastExchangeDate: Date?
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                SheetHeader(title: "bağlarım") { dismiss() }

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Spacer()
                } else if entries.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "flame",
                        title: String(localized: "henüz bir bağ yok"),
                        subtitle: String(localized: "arkadaşlarınla an paylaştıkça bağların burada birikir.")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(entries) { entry in
                                bondRow(entry: entry)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }

    private func bondRow(entry: BondEntry) -> some View {
        HStack(spacing: 14) {
            // Avatar
            if let avatarUrl = entry.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } placeholder: {
                    initialsCircle(name: entry.name)
                }
            } else {
                initialsCircle(name: entry.name)
            }

            // Name + tier
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(Brand.scaledFont(size: 15, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: entry.tier.tierIcon)
                        .font(Brand.scaledFont(size: 10, weight: .medium, relativeTo: .caption))
                    Text(entry.tier.tierName)
                        .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                }
                .foregroundStyle(.white.opacity(0.35))
            }

            Spacer()

            // The bond itself: flame + current streak, record underneath.
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                        .foregroundStyle(entry.streakCount > 0 ? .white : .white.opacity(0.25))
                    Text(String(localized: "\(entry.streakCount) gün"))
                        .font(Brand.scaledFont(size: 15, weight: .heavy, relativeTo: .body))
                        .foregroundStyle(.white)
                }

                if entry.longestStreak > entry.streakCount {
                    Text(String(localized: "rekor: \(entry.longestStreak)"))
                        .font(Brand.scaledFont(size: 10, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.3))
                } else {
                    Text(String(localized: "\(entry.exchangeCount) an"))
                        .font(Brand.scaledFont(size: 10, weight: .medium, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .brandCard()
        .accessibilityElement(children: .combine)
    }

    private func initialsCircle(name: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
                    .foregroundStyle(.white)
            )
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let streaks = await StreakService.shared.allStreaksByScore()
        var result: [BondEntry] = []

        for (friendId, streak) in streaks {
            guard let profile = try? await DependencyContainer.shared.userRepository.fetchProfile(for: friendId) else {
                continue
            }
            // The hide toggle predates this non-comparative view; keep
            // honoring it — least surprise for users who opted out.
            if profile.notificationPreferences?["privacy_hide_leaderboard"] as? Bool == true {
                continue
            }
            result.append(BondEntry(
                id: friendId,
                name: profile.displayName ?? profile.username ?? String(localized: "bilinmeyen"),
                avatarUrl: profile.avatarUrl,
                streakCount: streak.currentStreak,
                longestStreak: streak.longestStreak,
                exchangeCount: streak.totalExchanges,
                tier: streak.tier,
                lastExchangeDate: streak.lastExchangeDate
            ))
        }

        // Most recently alive bond first — recency, not ranking.
        entries = result.sorted {
            ($0.lastExchangeDate ?? .distantPast) > ($1.lastExchangeDate ?? .distantPast)
        }
    }
}
