import SwiftUI
import FirebaseAuth

// MARK: - Rollcall Card (İyileştirilmiş)
struct RollcallCard: View {
    let summary: RollcallSummary
    var isNewest: Bool = false

    private var insightText: String {
        if let friendName = summary.topFriendDisplayName {
            return "@\(friendName) ile"
        } else if case .up = summary.trend {
            return "↑ daha aktif"
        } else {
            return "\(summary.photosCount) an"
        }
    }

    private var trendIcon: String {
        if !summary.streakMilestones.isEmpty { return "flame.fill" }
        return summary.trend.icon
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image
            if let thumb = summary.thumbnailUrl, let url = URL(string: thumb) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 170, height: 240)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.1))
                }
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }

            // Üst gradient (badge okunabilirliği)
            VStack {
                LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 60)
                Spacer()
            }

            // Alt gradient (yazı okunabilirliği)
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)

            // İçerik
            VStack(alignment: .leading, spacing: 4) {
                // Üst bar: trend ikonu + fotoğraf sayısı
                HStack {
                    Image(systemName: trendIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    HStack(spacing: 4) {
                        if case .up = summary.trend {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                        }
                        Text("\(summary.photosCount)")
                            .font(.system(.caption, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }

                Spacer()

                // Hafta başlığı
                Text("Hafta \(summary.weekNumber)")
                    .font(.system(.headline, weight: .bold))
                    .foregroundColor(.white)

                // Tarih
                Text(summary.startDate.formatted(.dateTime.day().month()))
                    .font(.system(.caption2, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                // İçgörü preview
                Text(insightText)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(16)
        }
        .frame(width: 170, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Monthly Recap Card (Geniş format)
struct MonthlyRecapCard: View {
    let summary: MonthlySummary

    private var insightText: String {
        if let friendName = summary.topFriendDisplayName {
            return "@\(friendName) ile en çok"
        } else if summary.uniqueCities.count > 1 {
            return "\(summary.uniqueCities.count) şehir"
        } else {
            return "günde ort. \(String(format: "%.1f", summary.averagePhotosPerDay)) an"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image
            if let thumb = summary.thumbnailUrl, let url = URL(string: thumb) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 340, height: 200)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.1))
                }
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }

            // Üst gradient
            VStack {
                LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 60)
                Spacer()
            }

            // Alt gradient
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)

            // İçerik
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    // Ay başlığı
                    Text(summary.monthName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("\(summary.year)")
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    // İçgörü
                    Text(insightText)
                        .font(.system(.caption2, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                // Sparkline
                if summary.weeklyBreakdown.count >= 2 {
                    sparkline
                }

                // Fotoğraf sayısı badge
                HStack(spacing: 4) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(summary.totalPhotos)")
                        .font(.system(.caption, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(16)
        }
        .frame(width: 340, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var sparkline: some View {
        let data = summary.weeklyBreakdown
        let maxVal = max(data.max() ?? 1, 1)
        let barHeight: CGFloat = 32

        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(data.enumerated()), id: \.offset) { _, count in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(count == maxVal ? 0.8 : 0.35))
                    .frame(width: 6, height: max(CGFloat(count) / CGFloat(maxVal) * barHeight, 3))
            }
        }
    }
}

// MARK: - Stat Box (Korundu)
struct StatBox: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.white)
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
