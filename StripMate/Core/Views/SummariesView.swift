import SwiftUI
import SwiftData

/// Haftalık ve aylık özetlerin toplandığı sayfa — SettingsView'dan erişilir.
struct SummariesView: View {
    @Query(sort: \Strip.timestamp, order: .reverse) private var localStrips: [Strip]
    @Query(filter: #Predicate<Friend> { !$0.isPending }) private var localFriends: [Friend]
    @State private var selectedSummary: RollcallSummary?
    @State private var selectedMonthlySummary: MonthlySummary?
    @State private var friendNameCache: [String: String] = [:]

    private var weeklySummaries: [RollcallSummary] {
        RollcallComputer.computeWeeklySummaries(from: Array(localStrips), friendNameCache: friendNameCache)
    }

    private var monthlySummaries: [MonthlySummary] {
        RollcallComputer.computeMonthlySummaries(from: Array(localStrips), weeklySummaries: weeklySummaries, friendNameCache: friendNameCache)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Haftalık özetler
                if !weeklySummaries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "haftalık"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(weeklySummaries) { summary in
                                    Button {
                                        HapticsManager.playImpact(style: .light)
                                        selectedSummary = summary
                                    } label: {
                                        RollcallCard(summary: summary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // Aylık özetler
                if !monthlySummaries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "aylık"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.45))
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(monthlySummaries) { summary in
                                    monthlyCard(summary)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                // Boş durum
                if weeklySummaries.isEmpty && monthlySummaries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.2))
                        Text(String(localized: "henüz yeterli veri yok"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(String(localized: "fotoğraf paylaştıkça özetlerin burada görünecek."))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.25))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(String(localized: "özetler"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            var cache: [String: String] = [:]
            for friend in localFriends {
                if let name = friend.profile?.displayName ?? friend.profile?.username {
                    cache[friend.userId] = name
                }
            }
            friendNameCache = cache
        }
        .fullScreenCover(item: $selectedSummary) { summary in
            WeeklyRecapStoryView(
                summary: summary,
                strips: localStrips.filter { strip in
                    let cal = Calendar.current
                    let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: strip.timestamp)
                    return comps.weekOfYear == summary.weekNumber && comps.yearForWeekOfYear == summary.year
                }
            )
        }
    }

    // MARK: - Monthly Card

    @ViewBuilder
    private func monthlyCard(_ summary: MonthlySummary) -> some View {
        let monthNames = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
        let name = summary.month >= 1 && summary.month <= 12 ? monthNames[summary.month] : ""

        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text("\(summary.year)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()

            Text(String(localized: "\(summary.totalPhotos) an"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
        .frame(width: 140, height: 160)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.1), Color.white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}
