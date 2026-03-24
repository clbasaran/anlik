import SwiftUI
import WatchKit

/// Main streak dashboard — shows all active streaks with friendship tier info.
struct StreakDashboardView: View {
    @EnvironmentObject var store: WatchDataStore
    @State private var selectedStreak: WatchStreak?
    var onBack: (() -> Void)?
    
    var body: some View {
        if let streak = selectedStreak {
            streakDetail(streak)
        } else if store.streaks.isEmpty {
            emptyState
        } else {
            streakList
        }
    }
    
    // MARK: - Streak List
    
    private var streakList: some View {
        ScrollView {
            VStack(spacing: 4) {
                // Back button
                backButton
                
                // Expiring warning
                ForEach(store.expiringStreaks) { streak in
                    Button { selectedStreak = streak } label: {
                        HStack(spacing: 8) {
                            Text("⏳")
                                .font(.body)
                            Text(streak.friendName.isEmpty ? "Arkadaş" : streak.friendName)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(streak.currentStreak)🔥")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                
                // Active streaks
                let nonExpiring = store.activeStreaks.filter { !$0.isExpiringSoon }
                ForEach(nonExpiring) { streak in
                    Button { selectedStreak = streak } label: {
                        StreakRowView(streak: streak)
                    }
                    .buttonStyle(.plain)
                }
                
                // Inactive
                let inactive = store.streaks.filter { $0.currentStreak == 0 }
                if !inactive.isEmpty {
                    Text("Diğer")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    ForEach(inactive) { streak in
                        Button { selectedStreak = streak } label: {
                            StreakRowView(streak: streak)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Seriler")
    }
    
    // MARK: - Detail
    
    private func streakDetail(_ streak: WatchStreak) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                // Back to list
                HStack {
                    Button {
                        selectedStreak = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Seriler")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.bottom, 2)
                
                Text(streak.tierEmoji)
                    .font(.system(size: 40))
                
                Text(streak.friendName.isEmpty ? "Arkadaş" : streak.friendName)
                    .font(.system(size: 15, weight: .bold))
                
                Text(streak.tierDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                // Progress bar
                ProgressView(value: streak.tierProgress)
                    .tint(.white.opacity(0.6))
                    .padding(.horizontal, 8)
                
                HStack {
                    Text("\(streak.friendshipScore)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                    Spacer()
                    Text("\(streak.nextTierThreshold)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                
                // Stats
                HStack(spacing: 14) {
                    VStack(spacing: 2) {
                        Text("🔥").font(.caption2)
                        Text("\(streak.currentStreak)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Seri").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("⚡").font(.caption2)
                        Text("\(streak.longestStreak)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("En Uzun").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("📸").font(.caption2)
                        Text("\(streak.totalExchanges)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Toplam").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
                
                if streak.isExpiringSoon {
                    Text("⏳ Bugün fotoğraf paylaş!")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.top, 4)
                    
                    Button {
                        PhoneSessionManager.shared.openCameraOnPhone()
                    } label: {
                        Label("Kamerayı Aç", systemImage: "camera.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            backButton
            
            Text("🔥")
                .font(.title2)
            
            Text("Seri verisi bekleniyor...")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Button {
                PhoneSessionManager.shared.requestSync()
                WKInterfaceDevice.current().play(.click)
            } label: {
                Label("Yenile", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
    }
    
    // MARK: - Back Button
    
    private var backButton: some View {
        HStack {
            Button {
                if selectedStreak != nil {
                    selectedStreak = nil
                } else {
                    onBack?()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text(selectedStreak != nil ? "Seriler" : "Ana Sayfa")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Streak Row

struct StreakRowView: View {
    let streak: WatchStreak
    
    var body: some View {
        HStack(spacing: 8) {
            Text(streak.tierEmoji)
                .font(.body)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(streak.friendName.isEmpty ? "Arkadaş" : streak.friendName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                
                Text(streak.tierDisplayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if streak.currentStreak > 0 {
                Text("\(streak.currentStreak)🔥")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StreakDashboardView(onBack: {})
        .environmentObject(WatchDataStore.shared)
}
