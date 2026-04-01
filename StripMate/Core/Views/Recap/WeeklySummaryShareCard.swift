import SwiftUI

/// Haftalik ozet paylasim karti — Instagram Stories icin 1080x1920 boyutunda
/// markalı gorsel uretir.
struct WeeklySummaryShareCard: View {
    let summary: RollcallSummary

    // MARK: - Date Formatting

    private var weekRangeText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "tr_TR")
        fmt.dateFormat = "d"
        let startDay = fmt.string(from: summary.startDate)
        fmt.dateFormat = "d MMMM yyyy"
        let endFull = fmt.string(from: summary.endDate)
        return "\(startDay)-\(endFull)"
    }

    // MARK: - Trend Helpers

    private var trendArrow: String {
        switch summary.trend {
        case .up: return "\u{2191}"    // ↑
        case .down: return "\u{2193}"  // ↓
        case .same: return "="
        case .firstWeek: return "*"
        }
    }

    private var trendPercentageText: String {
        switch summary.trend {
        case .up(let pct): return "\(trendArrow) geçen haftadan %\(pct) fazla"
        case .down(let pct): return "\(trendArrow) geçen haftadan %\(pct) az"
        case .same: return "= aynı tempoda devam"
        case .firstWeek: return "ilk haftan kutlu olsun!"
        }
    }

    private var trendColor: Color {
        switch summary.trend {
        case .up: return Color.white.opacity(0.8)
        case .down: return Color.white.opacity(0.4)
        default: return Color.white.opacity(0.6)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Arka plan: pure monochrome — Brand uyumlu
            Brand.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 140)

                // Ust: "anlik." logo
                Text(Brand.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Brand.textPrimary)

                Spacer()
                    .frame(height: 8)

                // Hafta araligi
                Text(weekRangeText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Brand.textPrimary.opacity(0.4))

                Spacer()
                    .frame(height: 100)

                // Buyuk istatistik: fotograf sayisi
                Text("\(summary.photosCount)")
                    .font(.system(size: 110, weight: .bold, design: .rounded))
                    .foregroundColor(Brand.textPrimary)

                Text("an birlikte yaşandı")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Brand.textPrimary.opacity(0.5))

                Spacer()
                    .frame(height: 70)

                // Top friend bolumu
                if let friendName = summary.topFriendDisplayName {
                    topFriendSection(name: friendName)
                }

                Spacer()
                    .frame(height: 36)

                // Seri badge
                if summary.longestActiveStreak > 0 {
                    streakBadge
                }

                Spacer()
                    .frame(height: 28)

                // Trend gostergesi
                trendIndicator

                Spacer()

                // Alt watermark
                watermark

                Spacer()
                    .frame(height: 90)
            }
            .padding(.horizontal, 60)
        }
        .frame(width: 1080, height: 1920)
    }

    // MARK: - Sub-views

    private func topFriendSection(name: String) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 64, height: 64)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Brand.textPrimary)

                Text("ile en çok an paylaştın")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Brand.textPrimary.opacity(0.5))

                if summary.topFriendPhotoCount > 0 {
                    Text("\(summary.topFriendPhotoCount) kare birlikte")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Brand.textPrimary.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private var streakBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22))
                .foregroundColor(Brand.textPrimary)

            Text("\(summary.longestActiveStreak) gün seri")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Brand.textPrimary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06), in: Capsule())
    }

    private var trendIndicator: some View {
        Text(trendPercentageText)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(trendColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(trendColor.opacity(0.12), in: Capsule())
    }

    private var watermark: some View {
        Text(Brand.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(Brand.textPrimary.opacity(0.2))
    }
}
