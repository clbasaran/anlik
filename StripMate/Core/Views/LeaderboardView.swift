import SwiftUI

/// Friends leaderboard — streaks and photos ranking
struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var selectedTab: LeaderboardTab = .streaks
    @Environment(\.dismiss) private var dismiss
    
    enum LeaderboardTab: String, CaseIterable {
        case streaks = "en uzun seri"
        case exchanges = "en çok paylaşım"
    }
    
    struct LeaderboardEntry: Identifiable {
        let id: String  // friendId
        let name: String
        let avatarUrl: String?
        let streakCount: Int
        let exchangeCount: Int
        let tier: Streak.FriendshipTier
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(String(localized: "Kapat"))
                    Spacer()
                    Text("sıralama")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                // Tab picker
                HStack(spacing: 0) {
                    ForEach(LeaderboardTab.allCases, id: \.rawValue) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedTab = tab
                            }
                            HapticsManager.playSelection()
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.35))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedTab == tab ? Color.white.opacity(0.08) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                            leaderboardRow(entry: entry, rank: index + 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Spacer()
                } else if entries.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "trophy",
                        title: "henüz veri yok",
                        subtitle: "arkadaşlarınla fotoğraf paylaş ve\nsıralamada yerinizi alın."
                    )
                    Spacer()
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private var sortedEntries: [LeaderboardEntry] {
        switch selectedTab {
        case .streaks:
            return entries.sorted { $0.streakCount > $1.streakCount }
        case .exchanges:
            return entries.sorted { $0.exchangeCount > $1.exchangeCount }
        }
    }
    
    private func leaderboardRow(entry: LeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: 14) {
            // Rank
            Text("\(rank)")
                .font(.system(size: rank <= 3 ? 20 : 16, weight: .heavy))
                .foregroundStyle(rank <= 3 ? .white : .white.opacity(0.4))
                .frame(width: 32)
            
            // Medal for top 3
            if rank == 1 {
                Text("🥇").font(.system(size: 20))
            } else if rank == 2 {
                Text("🥈").font(.system(size: 20))
            } else if rank == 3 {
                Text("🥉").font(.system(size: 20))
            }
            
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
            
            // Name + Tier
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: entry.tier.tierIcon)
                        .font(.system(size: 10, weight: .medium))
                    Text(entry.tier.tierName)
                }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
            
            Spacer()
            
            // Value
            VStack(alignment: .trailing, spacing: 2) {
                Text(selectedTab == .streaks ? "\(entry.streakCount)" : "\(entry.exchangeCount)")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                
                Text(selectedTab == .streaks ? "gün" : "an")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(rank <= 3 ? Color.white.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(rank <= 3 ? Color.white.opacity(0.06) : Color.clear, lineWidth: 0.5)
        )
    }
    
    private func initialsCircle(name: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let streaks = await StreakService.shared.allStreaksByScore()
        var result: [LeaderboardEntry] = []

        for (friendId, streak) in streaks {
            guard let profile = try? await DependencyContainer.shared.userRepository.fetchProfile(for: friendId) else {
                continue
            }
            // Respect privacy_hide_leaderboard setting
            if profile.notificationPreferences?["privacy_hide_leaderboard"] as? Bool == true {
                continue
            }
            result.append(LeaderboardEntry(
                id: friendId,
                name: profile.displayName ?? profile.username ?? "bilinmeyen",
                avatarUrl: profile.avatarUrl,
                streakCount: streak.currentStreak,
                exchangeCount: streak.totalExchanges,
                tier: streak.tier
            ))
        }
        
        entries = result
    }
}
