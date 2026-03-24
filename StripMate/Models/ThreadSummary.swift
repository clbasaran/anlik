import Foundation

public struct ThreadSummary: Sendable {
    public let partnerId: String
    public let lastMessage: String
    public let lastMessageSenderId: String
    public let lastMessageTimestamp: Date
    public let unreadCount: Int
}
