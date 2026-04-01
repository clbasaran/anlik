import SwiftUI

/// Display user's unlocked achievements in a badge grid
struct AchievementView: View {
    let unlockedIds: Set<String>
    @Environment(\.dismiss) private var dismiss
    
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
                    Text(String(localized: "rozetler"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
                
                // Progress
                let total = Achievement.all.count
                let unlocked = unlockedIds.count
                HStack(spacing: 8) {
                    Text("\(unlocked)/\(total)")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(String(localized: "rozet kazanıldı"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom, 20)
                
                // Categories
                ScrollView {
                    VStack(spacing: 28) {
                        ForEach(Achievement.Category.allCases, id: \.rawValue) { category in
                            categorySection(for: category)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
        }
    }
    
    @ViewBuilder
    private func categorySection(for category: Achievement.Category) -> some View {
        let achievements = Achievement.all.filter { $0.category == category }
        
        VStack(alignment: .leading, spacing: 14) {
            Text(category.rawValue)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
                .tracking(1)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(achievements) { achievement in
                    badgeCard(for: achievement)
                }
            }
        }
    }
    
    private func badgeCard(for achievement: Achievement) -> some View {
        let isUnlocked = unlockedIds.contains(achievement.id)
        
        return VStack(spacing: 8) {
            Image(systemName: achievement.emoji)
                .font(.system(size: 28))
                .foregroundStyle(isUnlocked ? .white : .white.opacity(0.2))
            
            Text(achievement.title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isUnlocked ? .white : .white.opacity(0.2))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isUnlocked ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isUnlocked ? Color.white.opacity(0.1) : Color.clear, lineWidth: 0.5)
        )
    }
}
