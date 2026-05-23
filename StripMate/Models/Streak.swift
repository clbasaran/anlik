import Foundation

/// Represents the streak (consecutive daily exchange) between two users.
/// Stored in Firestore at: `streaks/{streakId}` where streakId = sorted "uid1_uid2"
public struct Streak: Identifiable, Codable, Sendable {
    /// Composite id: sorted "uid1_uid2"
    public let id: String
    /// The two user IDs participating in this streak
    public let userIds: [String]
    /// Current consecutive-day count
    public var currentStreak: Int
    /// All-time longest streak between these two users
    public var longestStreak: Int
    /// Total strips exchanged (both directions combined)
    public var totalExchanges: Int
    /// Last date a strip was exchanged (used to check continuity)
    public var lastExchangeDate: Date
    /// The userId who sent the last strip (to show "your turn" indicator)
    public var lastSenderId: String
    /// Friendship score: weighted combination of streak, frequency, recency
    public var friendshipScore: Int
    /// Whether either side has used their weekly freeze on the current cycle.
    /// Resets every Monday (server-side via weeklyFreezeReset cron).
    public var freezeUsedThisWeek: Bool = false
    /// Optional timestamp until which the streak is "frozen" — backend treats
    /// these days as a continuation rather than a break. Cleared when both
    /// users exchange again.
    public var frozenUntil: Date? = nil

    /// Whether the streak is about to expire (no exchange today yet, streak > 0)
    public var isExpiringSoon: Bool {
        guard currentStreak > 0 else { return false }
        // A frozen streak is in safe-mode — don't surface the expiring badge.
        if let frozenUntil, frozenUntil > Date() { return false }
        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: lastExchangeDate)
        let today = calendar.startOfDay(for: Date())
        let daysSince = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return daysSince >= 1 // Haven't exchanged today
    }

    /// True when a freeze is currently active (frozenUntil is in the future).
    public var isFrozen: Bool {
        guard let frozenUntil else { return false }
        return frozenUntil > Date()
    }

    /// True when the user can still freeze this week and the streak is at risk.
    public var canFreezeNow: Bool {
        currentStreak > 0
            && !freezeUsedThisWeek
            && !isFrozen
            && isExpiringSoon
    }

    /// Helper to build the composite streak id from two user ids
    public static func streakId(for uid1: String, and uid2: String) -> String {
        [uid1, uid2].sorted().joined(separator: "_")
    }

    public init(
        id: String,
        userIds: [String],
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        totalExchanges: Int = 0,
        lastExchangeDate: Date = Date(),
        lastSenderId: String = "",
        friendshipScore: Int = 0,
        freezeUsedThisWeek: Bool = false,
        frozenUntil: Date? = nil
    ) {
        self.id = id
        self.userIds = userIds
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalExchanges = totalExchanges
        self.lastExchangeDate = lastExchangeDate
        self.lastSenderId = lastSenderId
        self.friendshipScore = friendshipScore
        self.freezeUsedThisWeek = freezeUsedThisWeek
        self.frozenUntil = frozenUntil
    }
}

// MARK: - Friendship Score Tiers

public extension Streak {
    /// Tier based on friendship score
    enum FriendshipTier: String, Sendable {
        case tanidik = "Tanıdık"
        case muhabbet = "Muhabbet"
        case yakin = "Yakın"
        case sirdas = "Sırdaş"
        case kadim = "Kadim"

        /// Türkçe seviye adı
        public var tierName: String { rawValue }

        /// Monokrom SF Symbol ikon adı
        public var tierIcon: String {
            switch self {
            case .tanidik:  return "circle.dotted"
            case .muhabbet: return "cup.and.saucer.fill"
            case .yakin:    return "link"
            case .sirdas:   return "key.fill"
            case .kadim:    return "infinity"
            }
        }
    }

    var tier: FriendshipTier {
        switch friendshipScore {
        case 0..<50:   return .tanidik
        case 50..<150: return .muhabbet
        case 150..<350: return .yakin
        case 350..<700: return .sirdas
        default:        return .kadim
        }
    }

    /// Next tier threshold (for progress bar)
    var nextTierThreshold: Int {
        switch tier {
        case .tanidik:  return 50
        case .muhabbet: return 150
        case .yakin:    return 350
        case .sirdas:   return 700
        case .kadim:    return 1000
        }
    }

    /// Progress towards the next tier (0.0 - 1.0)
    var tierProgress: Double {
        let current = Double(friendshipScore)
        let thresholds: [(Int, Int)] = [(0, 50), (50, 150), (150, 350), (350, 700), (700, 1000)]
        for (low, high) in thresholds {
            if friendshipScore < high {
                return (current - Double(low)) / Double(high - low)
            }
        }
        return 1.0
    }
}
