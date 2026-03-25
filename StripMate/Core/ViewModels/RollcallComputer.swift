import Foundation
import FirebaseAuth

/// Haftalık ve aylık özet hesaplama motoru.
/// Mevcut localStrips verisinden zengin içgörüler üretir.
@MainActor
public enum RollcallComputer {

    // MARK: - Ana Hesaplama

    /// localStrips dizisinden zengin haftalık özetler hesaplar.
    public static func computeWeeklySummaries(
        from strips: [Strip],
        friendNameCache: [String: String] = [:]
    ) -> [RollcallSummary] {
        let calendar = Calendar.current
        let currentUserId = Auth.auth().currentUser?.uid ?? ""

        // 1. ISO haftaya göre grupla
        let grouped = Dictionary(grouping: strips) { strip in
            calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: strip.timestamp)
        }

        // 2. Önce tüm hafta gruplarını temel verilerle oluştur (trend hesaplaması için)
        var weeklyData: [(components: DateComponents, strips: [Strip], weekNumber: Int, year: Int, start: Date, end: Date)] = []

        for (components, weekStrips) in grouped {
            let sortedStrips = weekStrips.sorted { $0.timestamp > $1.timestamp }
            let weekNumber = components.weekOfYear ?? 0
            let year = components.yearForWeekOfYear ?? 0
            let referenceDate = sortedStrips.first?.timestamp ?? Date()
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
            let start = weekInterval?.start ?? (calendar.date(from: components) ?? Date())
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start

            weeklyData.append((components, weekStrips, weekNumber, year, start, end))
        }

        // Tarihe göre sırala (en yeni ilk)
        weeklyData.sort { $0.start > $1.start }

        // 3. Her hafta için zengin özet oluştur
        var summaries: [RollcallSummary] = []

        for (index, week) in weeklyData.enumerated() {
            let weekStrips = week.strips
            let sortedByTime = weekStrips.sorted { $0.timestamp < $1.timestamp }

            // Sent / Received ayrımı
            let sentStrips = weekStrips.filter { $0.senderId == currentUserId }
            let receivedStrips = weekStrips.filter { $0.senderId != currentUserId }

            // Benzersiz şehirler
            let cities = Array(Set(weekStrips.compactMap { $0.cityName })).sorted()

            // Arkadaş frekansı
            let (topFriendId, topFriendCount, friendsCount) = computeTopFriend(
                strips: weekStrips,
                currentUserId: currentUserId
            )
            let topFriendName = topFriendId.flatMap { friendNameCache[$0] }

            // En aktif gün
            let (activeDay, activeDayCount) = computeMostActiveDay(strips: weekStrips)
            let activeDayName = activeDay.map { RollcallSummary.weekdayName(for: $0) }

            // Zaman dağılımı
            let timeDist = computeTimeDistribution(strips: weekStrips)

            // Trend hesapla (önceki hafta ile karşılaştır)
            let previousWeekCount: Int? = (index + 1 < weeklyData.count) ? weeklyData[index + 1].strips.count : nil
            let trend = computeTrend(current: weekStrips.count, previous: previousWeekCount)

            // Öne çıkan fotoğraflar
            let highlight = sortedByTime.first?.imageUrl ?? sortedByTime.last?.imageUrl
            let firstTimestamp = sortedByTime.first?.timestamp
            let lastTimestamp = sortedByTime.last?.timestamp

            let summary = RollcallSummary(
                weekNumber: week.weekNumber,
                year: week.year,
                startDate: week.start,
                endDate: week.end,
                photosCount: weekStrips.count,
                sentCount: sentStrips.count,
                receivedCount: receivedStrips.count,
                thumbnailUrl: sortedByTime.last(where: { !$0.isSecret })?.imageUrl ?? sortedByTime.last?.imageUrl,
                uniqueCities: cities,
                friendsInteractedCount: friendsCount,
                topFriendId: topFriendId,
                topFriendDisplayName: topFriendName,
                topFriendPhotoCount: topFriendCount,
                mostActiveDay: activeDay,
                mostActiveDayName: activeDayName,
                mostActiveDayCount: activeDayCount,
                timeDistribution: timeDist,
                streakMilestones: [], // Streak milestones ayrı hesaplanabilir
                longestActiveStreak: 0,
                previousWeekPhotosCount: previousWeekCount,
                trend: trend,
                highlightPhotoUrl: highlight,
                firstPhotoTimestamp: firstTimestamp,
                lastPhotoTimestamp: lastTimestamp
            )

            summaries.append(summary)
        }

        return summaries
    }

    // MARK: - Alt Hesaplamalar

    /// En çok etkileşilen arkadaşı bul
    private static func computeTopFriend(
        strips: [Strip],
        currentUserId: String
    ) -> (topFriendId: String?, topFriendCount: Int, uniqueFriendsCount: Int) {
        var friendCounts: [String: Int] = [:]

        for strip in strips {
            if strip.senderId == currentUserId {
                // Benim gönderdiğim → alıcılar arkadaşlarım (kendimi hariç tut)
                for receiverId in strip.receiverIds where receiverId != currentUserId {
                    friendCounts[receiverId, default: 0] += 1
                }
            } else {
                // Bana gönderilen → gönderen arkadaşım (kendimi hariç tut)
                if strip.senderId != currentUserId {
                    friendCounts[strip.senderId, default: 0] += 1
                }
            }
        }

        // Kendimi kesinlikle çıkar
        friendCounts.removeValue(forKey: currentUserId)

        let uniqueFriends = friendCounts.count
        guard let top = friendCounts.max(by: { $0.value < $1.value }) else {
            return (nil, 0, 0)
        }

        return (top.key, top.value, uniqueFriends)
    }

    /// Haftanın en aktif gününü bul
    private static func computeMostActiveDay(strips: [Strip]) -> (weekday: Int?, count: Int) {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: strips) { strip in
            calendar.component(.weekday, from: strip.timestamp)
        }

        guard let top = grouped.max(by: { $0.value.count < $1.value.count }) else {
            return (nil, 0)
        }

        return (top.key, top.value.count)
    }

    /// Zaman dağılımını hesapla
    private static func computeTimeDistribution(strips: [Strip]) -> TimeDistribution {
        let calendar = Calendar.current
        var morning = 0, afternoon = 0, evening = 0, night = 0

        for strip in strips {
            let hour = calendar.component(.hour, from: strip.timestamp)
            switch hour {
            case 6..<12:  morning += 1
            case 12..<17: afternoon += 1
            case 17..<21: evening += 1
            default:       night += 1     // 21-5
            }
        }

        return TimeDistribution(morning: morning, afternoon: afternoon, evening: evening, night: night)
    }

    /// Haftalık trend hesapla
    private static func computeTrend(current: Int, previous: Int?) -> WeekTrend {
        guard let prev = previous else { return .firstWeek }
        guard prev > 0 else {
            return current > 0 ? .up(100) : .same
        }

        let diff = current - prev
        if diff == 0 { return .same }

        let pct = abs(diff * 100 / prev)
        return diff > 0 ? .up(pct) : .down(pct)
    }

    // MARK: - Aylık Özet Hesaplama

    /// localStrips dizisinden aylık özetler hesaplar.
    public static func computeMonthlySummaries(
        from strips: [Strip],
        weeklySummaries: [RollcallSummary] = [],
        friendNameCache: [String: String] = [:]
    ) -> [MonthlySummary] {
        let calendar = Calendar.current
        let currentUserId = Auth.auth().currentUser?.uid ?? ""

        // Aya göre grupla
        let grouped = Dictionary(grouping: strips) { strip in
            calendar.dateComponents([.year, .month], from: strip.timestamp)
        }

        var summaries: [MonthlySummary] = []

        for (components, monthStrips) in grouped {
            let month = components.month ?? 1
            let year = components.year ?? 2026

            // Sadece tamamlanmış ayları göster (mevcut ay hariç)
            let now = Date()
            let currentMonth = calendar.component(.month, from: now)
            let currentYear = calendar.component(.year, from: now)
            if year == currentYear && month == currentMonth { continue }

            let totalPhotos = monthStrips.count
            let sentStrips = monthStrips.filter { $0.senderId == currentUserId }
            let receivedStrips = monthStrips.filter { $0.senderId != currentUserId }

            // Benzersiz şehirler
            let cities = Array(Set(monthStrips.compactMap { $0.cityName })).sorted()

            // Arkadaş etkileşimi
            let (topFriendId, topFriendCount, friendsCount) = computeTopFriend(
                strips: monthStrips,
                currentUserId: currentUserId
            )
            let topFriendName = topFriendId.flatMap { friendNameCache[$0] }

            // Günlük ortalama
            let daysInMonth = calendar.range(of: .day, in: .month,
                for: calendar.date(from: components) ?? Date())?.count ?? 30
            let avgPerDay = Double(totalPhotos) / Double(daysInMonth)

            // O aya ait haftalık özetlerden en aktif haftayı bul
            let monthWeeklies = weeklySummaries.filter { summary in
                let summaryMonth = calendar.component(.month, from: summary.startDate)
                let summaryYear = calendar.component(.year, from: summary.startDate)
                return summaryMonth == month && summaryYear == year
            }
            let mostActiveWeek = monthWeeklies.max(by: { $0.photosCount < $1.photosCount })

            // Haftalık breakdown (sparkline verisi)
            let weeklyBreakdown = monthWeeklies
                .sorted { $0.startDate < $1.startDate }
                .map { $0.photosCount }

            // En yüksek seri (mevcut veri olmadığı için 0)
            let streakHighlight = monthWeeklies.map { $0.longestActiveStreak }.max() ?? 0

            // Thumbnail: ayın son gizli olmayan fotoğrafı
            let sortedByTime = monthStrips.sorted { $0.timestamp > $1.timestamp }
            let thumbnail = sortedByTime.first(where: { !$0.isSecret })?.imageUrl ?? sortedByTime.first?.imageUrl

            let summary = MonthlySummary(
                month: month,
                year: year,
                totalPhotos: totalPhotos,
                totalSent: sentStrips.count,
                totalReceived: receivedStrips.count,
                uniqueCities: cities,
                uniqueFriendsCount: friendsCount,
                topFriendId: topFriendId,
                topFriendDisplayName: topFriendName,
                topFriendPhotoCount: topFriendCount,
                averagePhotosPerDay: avgPerDay,
                mostActiveWeekNumber: mostActiveWeek?.weekNumber,
                mostActiveWeekCount: mostActiveWeek?.photosCount ?? 0,
                streakHighlight: streakHighlight,
                weeklyBreakdown: weeklyBreakdown,
                thumbnailUrl: thumbnail
            )

            summaries.append(summary)
        }

        // En yeni ay önce
        return summaries.sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year > rhs.year }
            return lhs.month > rhs.month
        }
    }
}
