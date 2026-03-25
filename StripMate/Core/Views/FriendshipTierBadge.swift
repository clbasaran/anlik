import SwiftUI

/// Reusable badge displaying the user's friendship tier.
/// - Compact mode (default): small capsule with icon + tier name, suitable for list cards.
/// - Full mode (`showProgress = true`): icon + name + progress bar + remaining score text.
public struct FriendshipTierBadge: View {
    let tier: Streak.FriendshipTier
    let score: Int
    let progress: Double
    var showProgress: Bool = false

    public var body: some View {
        if showProgress {
            fullBadge
        } else {
            compactBadge
        }
    }

    // MARK: - Compact

    private var compactBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: tier.tierIcon)
                .font(.system(size: 11, weight: .semibold))
            Text(tier.tierName)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Full

    private var fullBadge: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon + tier name
            HStack(spacing: 6) {
                Image(systemName: tier.tierIcon)
                    .font(.system(size: 14, weight: .semibold))
                Text(tier.tierName)
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: geo.size.width * min(max(progress, 0), 1), height: 6)
                }
            }
            .frame(height: 6)

            // Remaining score text
            if tier != .kadim || progress < 1.0 {
                let remaining = max(nextThreshold - score, 0)
                Text("\(remaining) puan kaldi")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            } else {
                Text("en yuksek seviye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Helpers

    private var nextThreshold: Int {
        switch tier {
        case .tanidik:  return 50
        case .muhabbet: return 150
        case .yakin:    return 350
        case .sirdas:   return 700
        case .kadim:    return 1000
        }
    }
}

// MARK: - Preview

#Preview("Compact") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 12) {
            FriendshipTierBadge(tier: .tanidik, score: 20, progress: 0.4)
            FriendshipTierBadge(tier: .muhabbet, score: 80, progress: 0.3)
            FriendshipTierBadge(tier: .yakin, score: 200, progress: 0.25)
            FriendshipTierBadge(tier: .sirdas, score: 500, progress: 0.43)
            FriendshipTierBadge(tier: .kadim, score: 900, progress: 0.67)
        }
    }
}

#Preview("Full") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            FriendshipTierBadge(tier: .yakin, score: 200, progress: 0.25, showProgress: true)
            FriendshipTierBadge(tier: .kadim, score: 1000, progress: 1.0, showProgress: true)
        }
        .padding()
    }
}
