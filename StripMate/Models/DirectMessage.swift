import Foundation

public struct DirectMessage: Codable, Sendable, Identifiable {
    public let id: String
    public let senderId: String
    public let receiverId: String
    public let text: String
    public let timestamp: Date
    public let replyToId: String?
    public let replyToText: String?
    public let replyToSenderId: String?
    public let reactions: [String: String]?  // userId -> emoji
    public let readAt: Date?
    public let isDeleted: Bool?
    
    public init(id: String = UUID().uuidString, senderId: String, receiverId: String, text: String, timestamp: Date = Date(), replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil, reactions: [String: String]? = nil, readAt: Date? = nil, isDeleted: Bool? = nil) {
        self.id = id
        self.senderId = senderId
        self.receiverId = receiverId
        self.text = text
        self.timestamp = timestamp
        self.replyToId = replyToId
        self.replyToText = replyToText
        self.replyToSenderId = replyToSenderId
        self.reactions = reactions
        self.readAt = readAt
        self.isDeleted = isDeleted
    }
}
