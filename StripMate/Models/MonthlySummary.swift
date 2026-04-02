import Foundation

public struct MonthlySummary: Identifiable, Hashable {
    public let id: String           // "2026-03"
    public let month: Int
    public let year: Int
    public let totalPhotos: Int
    public let totalSent: Int
    public let totalReceived: Int
    public let uniqueCities: [String]
    public let uniqueFriendsCount: Int
    public let topFriendId: String?
    public let topFriendDisplayName: String?
    public let topFriendPhotoCount: Int
    public let averagePhotosPerDay: Double
    public let mostActiveWeekNumber: Int?
    public let mostActiveWeekCount: Int
    public let streakHighlight: Int       // ay içindeki en yüksek seri
    public let weeklyBreakdown: [Int]     // haftalık fotoğraf sayıları (sparkline için)
    public let thumbnailUrl: String?

    public var monthName: String {
        guard month >= 1, month <= 12 else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.standaloneMonthSymbols[month - 1].capitalized
    }

    public init(
        month: Int, year: Int, totalPhotos: Int, totalSent: Int, totalReceived: Int,
        uniqueCities: [String], uniqueFriendsCount: Int,
        topFriendId: String?, topFriendDisplayName: String?, topFriendPhotoCount: Int,
        averagePhotosPerDay: Double, mostActiveWeekNumber: Int?, mostActiveWeekCount: Int,
        streakHighlight: Int, weeklyBreakdown: [Int], thumbnailUrl: String?
    ) {
        self.id = "\(year)-\(String(format: "%02d", month))"
        self.month = month
        self.year = year
        self.totalPhotos = totalPhotos
        self.totalSent = totalSent
        self.totalReceived = totalReceived
        self.uniqueCities = uniqueCities
        self.uniqueFriendsCount = uniqueFriendsCount
        self.topFriendId = topFriendId
        self.topFriendDisplayName = topFriendDisplayName
        self.topFriendPhotoCount = topFriendPhotoCount
        self.averagePhotosPerDay = averagePhotosPerDay
        self.mostActiveWeekNumber = mostActiveWeekNumber
        self.mostActiveWeekCount = mostActiveWeekCount
        self.streakHighlight = streakHighlight
        self.weeklyBreakdown = weeklyBreakdown
        self.thumbnailUrl = thumbnailUrl
    }
}
