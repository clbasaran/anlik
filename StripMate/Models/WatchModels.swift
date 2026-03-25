import Foundation

// MARK: - Lightweight Codable DTOs for WatchConnectivity transfer
// These mirror the main app's models but without SwiftData / Firebase dependencies.
// Used by both iOS (WatchSessionManager) and watchOS (PhoneSessionManager).

/// Streak data transferred to the watch.
public struct WatchStreak: Codable, Sendable, Identifiable {
    public let id: String
    public let friendId: String
    public let friendName: String
    public let friendAvatarUrl: String?
    public let currentStreak: Int
    public let longestStreak: Int
    public let totalExchanges: Int
    public let lastExchangeDate: Date
    public let lastSenderId: String
    public let friendshipScore: Int
    
    public var tier: String {
        switch friendshipScore {
        case 0..<50: return "newFriend"
        case 50..<150: return "casual"
        case 150..<350: return "closeFriend"
        case 350..<700: return "bestFriend"
        default: return "soulmate"
        }
    }
    
    public var tierEmoji: String {
        switch tier {
        case "newFriend": return "🌱"
        case "casual": return "👋"
        case "closeFriend": return "💜"
        case "bestFriend": return "⭐"
        case "soulmate": return "💎"
        default: return "🌱"
        }
    }
    
    public var tierDisplayName: String {
        switch tier {
        case "newFriend": return "Yeni Arkadaş"
        case "casual": return "Tanıdık"
        case "closeFriend": return "Yakın Arkadaş"
        case "bestFriend": return "En İyi Arkadaş"
        case "soulmate": return "Ruh İkizi"
        default: return "Yeni Arkadaş"
        }
    }
    
    public var isExpiringSoon: Bool {
        guard currentStreak > 0 else { return false }
        let calendar = Calendar.current
        let lastDay = calendar.startOfDay(for: lastExchangeDate)
        let today = calendar.startOfDay(for: Date())
        let daysSince = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        return daysSince >= 1
    }
    
    public var tierProgress: Double {
        let current = Double(friendshipScore)
        let thresholds: [(Int, Int)] = [(0, 50), (50, 150), (150, 400), (400, 750), (750, 1000)]
        for (low, high) in thresholds {
            if friendshipScore < high {
                return (current - Double(low)) / Double(high - low)
            }
        }
        return 1.0
    }
    
    public var nextTierThreshold: Int {
        switch friendshipScore {
        case 0..<50: return 50
        case 50..<150: return 150
        case 150..<400: return 400
        case 400..<750: return 750
        default: return 1000
        }
    }
}

/// Lightweight photo info transferred to the watch (no image data — transferred separately via file).
public struct WatchPhotoInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let senderName: String
    public let senderAvatarUrl: String?
    public let timestamp: Date
    public let cityName: String?
    public let latitude: Double?
    public let longitude: Double?
}

/// Daily prompt data transferred to the watch.
public struct WatchPrompt: Codable, Sendable {
    public let id: String
    public let promptText: String
    public let emoji: String
    public let category: String
    public let isCompletedToday: Bool
}

/// Complete payload pushed from iPhone → Watch.
public struct WatchSyncPayload: Codable, Sendable {
    public let streaks: [WatchStreak]
    public let latestPhotos: [WatchPhotoInfo]
    public let dailyPrompt: WatchPrompt?
    public let currentUserId: String?
    public let syncTimestamp: Date
    /// Base64-encoded JPEG thumbnail of the latest photo (≤100KB).
    public let latestPhotoData: Data?
    
    public init(
        streaks: [WatchStreak] = [],
        latestPhotos: [WatchPhotoInfo] = [],
        dailyPrompt: WatchPrompt? = nil,
        currentUserId: String? = nil,
        latestPhotoData: Data? = nil
    ) {
        self.streaks = streaks
        self.latestPhotos = latestPhotos
        self.dailyPrompt = dailyPrompt
        self.currentUserId = currentUserId
        self.latestPhotoData = latestPhotoData
        self.syncTimestamp = Date()
    }
}

// MARK: - WatchConnectivity Message Keys

/// Keys used in WCSession messages and userInfo dictionaries.
public enum WatchMessageKey {
    public static let syncPayload = "syncPayload"
    public static let photoFile = "photoFile"
    public static let action = "action"
    public static let openCamera = "openCamera"
    public static let requestSync = "requestSync"
    public static let photoId = "photoId"
}
