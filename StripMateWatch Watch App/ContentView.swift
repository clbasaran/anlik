import SwiftUI

/// Root view — simple hub for the watch app. No NavigationStack to avoid nested navigation crashes.
struct ContentView: View {
    @EnvironmentObject var store: WatchDataStore
    @State private var currentPage: WatchPage = .home
    
    enum WatchPage {
        case home, streaks, photo, prompt
    }
    
    var body: some View {
        switch currentPage {
        case .home:
            homeList
        case .streaks:
            StreakDashboardView(onBack: { currentPage = .home })
                .environmentObject(store)
        case .photo:
            LatestPhotoView(onBack: { currentPage = .home })
                .environmentObject(store)
        case .prompt:
            DailyPromptCardView(onBack: { currentPage = .home })
                .environmentObject(store)
        }
    }
    
    // MARK: - Home List
    
    private var homeList: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                Text("anlık.")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 2)
                
                // Connection status
                HStack(spacing: 4) {
                    Circle()
                        .fill(store.lastSyncDate != nil ? .green : .red)
                        .frame(width: 6, height: 6)
                    if let lastSync = store.lastSyncDate {
                        Text("sync: ")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        + Text(lastSync, style: .relative)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("bağlantı bekleniyor")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
                
                // Streaks
                Button { currentPage = .streaks } label: {
                    HStack(spacing: 10) {
                        Text("🔥")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Seriler")
                                .font(.system(size: 14, weight: .semibold))
                            if store.totalActiveStreakCount > 0 {
                                Text("\(store.totalActiveStreakCount) aktif")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                // Latest Photo
                Button { currentPage = .photo } label: {
                    HStack(spacing: 10) {
                        Text("📸")
                            .font(.title3)
                        Text("Son Fotoğraf")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                // Daily Prompt
                Button { currentPage = .prompt } label: {
                    HStack(spacing: 10) {
                        Text(store.dailyPrompt?.emoji ?? "📝")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Günün Görevi")
                                .font(.system(size: 14, weight: .semibold))
                            if let prompt = store.dailyPrompt {
                                Text(prompt.promptText)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                // Expiring streaks warning
                if !store.expiringStreaks.isEmpty {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Text("⏳")
                                .font(.caption2)
                            Text("\(store.expiringStreaks.count) seri bitiyor!")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchDataStore.shared)
}
