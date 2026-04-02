import Foundation

// MARK: - Time Distribution
public struct TimeDistribution: Hashable {
    public let morning: Int    // 06:00-11:59
    public let afternoon: Int  // 12:00-16:59
    public let evening: Int    // 17:00-20:59
    public let night: Int      // 21:00-05:59

    public var total: Int { morning + afternoon + evening + night }

    public var dominantPeriod: String {
        guard total > 0 else { return "" }
        let periods: [(String, Int)] = [
            (String(localized: "sabah"), morning),
            (String(localized: "öğleden sonra"), afternoon),
            (String(localized: "akşam"), evening),
            (String(localized: "gece"), night)
        ]
        return periods.max(by: { $0.1 < $1.1 })?.0 ?? ""
    }

    public var dominantIcon: String {
        guard total > 0 else { return "clock" }
        let periods = [
            ("sun.horizon.fill", morning),
            ("sun.max.fill", afternoon),
            ("sunset.fill", evening),
            ("moon.stars.fill", night)
        ]
        return periods.max(by: { $0.1 < $1.1 })?.0 ?? "clock"
    }

    public static let empty = TimeDistribution(morning: 0, afternoon: 0, evening: 0, night: 0)
}

// MARK: - Week Trend
public enum WeekTrend: Hashable {
    case up(Int)       // % artış
    case down(Int)     // % azalış
    case same
    case firstWeek

    public var isPositive: Bool {
        if case .up = self { return true }
        return false
    }

    public var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .same: return "equal"
        case .firstWeek: return "sparkles"
        }
    }

    public var description: String {
        switch self {
        case .up(let pct):
            return String(localized: "geçen haftaya göre %\(pct) daha fazla")
        case .down(let pct):
            return String(localized: "geçen haftaya göre %\(pct) daha az")
        case .same:
            return String(localized: "geçen haftayla aynı tempo")
        case .firstWeek:
            return String(localized: "ilk haftan kutlu olsun!")
        }
    }
}

// MARK: - Streak Milestone
public struct StreakMilestone: Hashable, Identifiable {
    public var id: String { "\(friendId)_\(milestoneValue)" }
    public let friendId: String
    public let friendDisplayName: String
    public let milestoneValue: Int   // 7, 14, 30, 50, 100
    public let currentStreak: Int
}

// MARK: - Rollcall Summary (Weekly)
public struct RollcallSummary: Identifiable, Hashable {
    public let id: String
    public let weekNumber: Int
    public let year: Int
    public let startDate: Date
    public let endDate: Date

    // Temel metrikler
    public let photosCount: Int
    public let sentCount: Int
    public let receivedCount: Int
    public let thumbnailUrl: String?

    // Şehirler
    public let uniqueCities: [String]

    // Arkadaş etkileşimi
    public let friendsInteractedCount: Int
    public let topFriendId: String?
    public let topFriendDisplayName: String?
    public let topFriendPhotoCount: Int

    // Zaman kalıpları
    public let mostActiveDay: Int?          // Calendar weekday (1=Paz, 2=Pzt, ..., 7=Cmt)
    public let mostActiveDayName: String?
    public let mostActiveDayCount: Int
    public let timeDistribution: TimeDistribution

    // Seri içgörüleri
    public let streakMilestones: [StreakMilestone]
    public let longestActiveStreak: Int

    // Önceki hafta karşılaştırması
    public let previousWeekPhotosCount: Int?
    public let trend: WeekTrend

    // Öne çıkan fotoğraf
    public let highlightPhotoUrl: String?
    public let firstPhotoTimestamp: Date?
    public let lastPhotoTimestamp: Date?

    // Toplam sayfa sayısı (boş sayfalar hariç)
    public var storyPageCount: Int {
        var count = 3 // başlık + fotoğraf sayısı + grid (her zaman var)
        if topFriendId != nil { count += 1 }
        if !uniqueCities.isEmpty { count += 1 }
        if photosCount >= 3 { count += 1 } // zaman kalıpları (yeterli veri varsa)
        if longestActiveStreak > 0 || !streakMilestones.isEmpty { count += 1 }
        return count
    }

    public init(
        weekNumber: Int,
        year: Int,
        startDate: Date,
        endDate: Date,
        photosCount: Int,
        sentCount: Int = 0,
        receivedCount: Int = 0,
        thumbnailUrl: String? = nil,
        uniqueCities: [String] = [],
        friendsInteractedCount: Int = 0,
        topFriendId: String? = nil,
        topFriendDisplayName: String? = nil,
        topFriendPhotoCount: Int = 0,
        mostActiveDay: Int? = nil,
        mostActiveDayName: String? = nil,
        mostActiveDayCount: Int = 0,
        timeDistribution: TimeDistribution = .empty,
        streakMilestones: [StreakMilestone] = [],
        longestActiveStreak: Int = 0,
        previousWeekPhotosCount: Int? = nil,
        trend: WeekTrend = .firstWeek,
        highlightPhotoUrl: String? = nil,
        firstPhotoTimestamp: Date? = nil,
        lastPhotoTimestamp: Date? = nil
    ) {
        self.id = "\(year)-W\(weekNumber)"
        self.weekNumber = weekNumber
        self.year = year
        self.startDate = startDate
        self.endDate = endDate
        self.photosCount = photosCount
        self.sentCount = sentCount
        self.receivedCount = receivedCount
        self.thumbnailUrl = thumbnailUrl
        self.uniqueCities = uniqueCities
        self.friendsInteractedCount = friendsInteractedCount
        self.topFriendId = topFriendId
        self.topFriendDisplayName = topFriendDisplayName
        self.topFriendPhotoCount = topFriendPhotoCount
        self.mostActiveDay = mostActiveDay
        self.mostActiveDayName = mostActiveDayName
        self.mostActiveDayCount = mostActiveDayCount
        self.timeDistribution = timeDistribution
        self.streakMilestones = streakMilestones
        self.longestActiveStreak = longestActiveStreak
        self.previousWeekPhotosCount = previousWeekPhotosCount
        self.trend = trend
        self.highlightPhotoUrl = highlightPhotoUrl
        self.firstPhotoTimestamp = firstPhotoTimestamp
        self.lastPhotoTimestamp = lastPhotoTimestamp
    }

    // Eski init ile geriye uyumluluk
    public init(weekNumber: Int, year: Int, photosCount: Int, thumbnailUrl: String?, startDate: Date, endDate: Date) {
        self.init(
            weekNumber: weekNumber,
            year: year,
            startDate: startDate,
            endDate: endDate,
            photosCount: photosCount,
            thumbnailUrl: thumbnailUrl
        )
    }
}

// MARK: - Helper: Weekday Name
extension RollcallSummary {
    public static func weekdayName(for weekday: Int) -> String {
        guard weekday >= 1, weekday <= 7 else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        // Calendar weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        // DateFormatter.weekdaySymbols: index 0=Sunday, 1=Monday, ..., 6=Saturday
        return formatter.weekdaySymbols[weekday - 1].capitalized
    }
}
