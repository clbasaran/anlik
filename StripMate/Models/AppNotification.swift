import Foundation

public enum NotificationType: String, Codable, Sendable {
    case photoReceived = "photo_received"
    case commentReceived = "comment_received"
    case friendAdded = "friend_added"
    case directMessage = "direct_message"
    case stripChat = "strip_chat"
    case weeklySummary = "weekly_summary"
    case supportReply = "support_reply"
    case streakWarning = "streak_warning"
    case achievementUnlocked = "achievement_unlocked"
    case nudge = "nudge"
}

public struct AppNotification: Identifiable, Codable, Sendable {
    public let id: String
    public let userId: String // Recipient
    public let senderId: String
    public let senderName: String
    public let type: NotificationType
    public let relatedId: String? // stripId or other reference
    public let thumbnailUrl: String?
    public let timestamp: Date
    public var isRead: Bool
    
    public init(id: String, userId: String, senderId: String, senderName: String, type: NotificationType, relatedId: String? = nil, thumbnailUrl: String? = nil, timestamp: Date = Date(), isRead: Bool = false) {
        self.id = id
        self.userId = userId
        self.senderId = senderId
        self.senderName = senderName
        self.type = type
        self.relatedId = relatedId
        self.thumbnailUrl = thumbnailUrl
        self.timestamp = timestamp
        self.isRead = isRead
    }
}
