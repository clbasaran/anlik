import Foundation
import SwiftData
import FirebaseAuth

@MainActor
@Observable
final class FriendshipProfileViewModel {
    let friendId: String
    let friendProfile: UserProfile

    var firstPhotoDate: Date?
    var totalPhotos: Int = 0
    var sentPhotos: Int = 0
    var receivedPhotos: Int = 0
    var mostActiveDay: String = "-"
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var monthlyActivity: [(month: String, count: Int)] = []
    var sharedPhotos: [Strip] = []
    var displayedPhotos: [Strip] = []
    var hasMorePhotos: Bool = false
    var isLoadingMore: Bool = false
    var currentUserProfile: UserProfile?
    var streak: Streak?
    var isLoading = true

    private let pageSize: Int = 30
    private let turkishDayNames = ["pazar", "pazartesi", "salı", "çarşamba", "perşembe", "cuma", "cumartesi"]
    private let turkishMonthAbbreviations = ["oca", "şub", "mar", "nis", "may", "haz", "tem", "ağu", "eyl", "eki", "kas", "ara"]

    init(friendId: String, friendProfile: UserProfile) {
        self.friendId = friendId
        self.friendProfile = friendProfile
    }

    func loadData(allStrips: [Strip]) async {
        isLoading = true
        let myId = Auth.auth().currentUser?.uid ?? ""

        // Fetch current user profile
        currentUserProfile = try? await AuthService.shared.fetchProfile(for: myId)

        // Fetch streak data
        streak = await StreakService.shared.streak(with: friendId)
        currentStreak = streak?.currentStreak ?? 0
        longestStreak = streak?.longestStreak ?? 0

        // Filter shared strips
        let shared = allStrips.filter { strip in
            let iSentToFriend = strip.senderId == myId && strip.receiverIds.contains(friendId)
            let friendSentToMe = strip.senderId == friendId && strip.receiverIds.contains(myId)
            return iSentToFriend || friendSentToMe
        }.sorted { $0.timestamp > $1.timestamp }

        sharedPhotos = shared
        totalPhotos = shared.count

        // Sent / received counts
        sentPhotos = shared.filter { $0.senderId == myId }.count
        receivedPhotos = totalPhotos - sentPhotos

        // First photo date
        firstPhotoDate = shared.last?.timestamp

        // Most active day of week
        computeMostActiveDay(from: shared)

        // Monthly activity (last 6 months)
        computeMonthlyActivity(from: shared)

        // Pagination
        loadInitialPhotos()

        isLoading = false
    }

    func loadInitialPhotos() {
        displayedPhotos = Array(sharedPhotos.prefix(pageSize))
        hasMorePhotos = sharedPhotos.count > pageSize
    }

    func loadMorePhotos() {
        guard !isLoadingMore, hasMorePhotos else { return }
        isLoadingMore = true
        let endIndex = min(displayedPhotos.count + pageSize, sharedPhotos.count)
        let next = Array(sharedPhotos[displayedPhotos.count..<endIndex])
        displayedPhotos.append(contentsOf: next)
        hasMorePhotos = displayedPhotos.count < sharedPhotos.count
        isLoadingMore = false
    }

    private func computeMostActiveDay(from strips: [Strip]) {
        guard !strips.isEmpty else {
            mostActiveDay = "-"
            return
        }
        let calendar = Calendar.current
        var dayCounts = [Int: Int]()
        for strip in strips {
            let weekday = calendar.component(.weekday, from: strip.timestamp)
            dayCounts[weekday, default: 0] += 1
        }
        if let maxDay = dayCounts.max(by: { $0.value < $1.value }) {
            // Calendar weekday: 1 = Sunday, 2 = Monday, etc.
            let index = maxDay.key - 1
            if index >= 0 && index < turkishDayNames.count {
                mostActiveDay = turkishDayNames[index]
            }
        }
    }

    private func computeMonthlyActivity(from strips: [Strip]) {
        let calendar = Calendar.current
        let now = Date()

        var result: [(month: String, count: Int)] = []
        for i in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let monthIndex = calendar.component(.month, from: monthDate) - 1
            let year = calendar.component(.year, from: monthDate)
            let monthLabel = turkishMonthAbbreviations[monthIndex]

            let count = strips.filter { strip in
                let stripMonth = calendar.component(.month, from: strip.timestamp)
                let stripYear = calendar.component(.year, from: strip.timestamp)
                return stripMonth == (monthIndex + 1) && stripYear == year
            }.count

            result.append((month: monthLabel, count: count))
        }
        monthlyActivity = result
    }
}
