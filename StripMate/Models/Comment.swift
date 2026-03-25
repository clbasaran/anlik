import Foundation

// MARK: - Sticker Attachment (GIPHY animated sticker on a message)

public struct StickerAttachment: Codable, Sendable, Equatable {
    public let url: String      // GIPHY GIF URL (transparent background)
    public let mediaId: String  // GIPHY media ID

    public init(url: String, mediaId: String) {
        self.url = url
        self.mediaId = mediaId
    }
}

// MARK: - Comment

public struct Comment: Codable, Sendable, Identifiable {
    public let id: String
    public let photoId: String
    public let senderId: String
    public let text: String
    public let timestamp: Date
    public let replyToId: String?
    public let replyToText: String?
    public let replyToSenderId: String?
    public var reactions: [String: String]?           // userId → emoji
    public let voiceUrl: String?
    public var stickers: [String: StickerAttachment]? // userId → sticker
    public let photoReplyUrl: String?                  // photo reply (selfie reaction)

    public init(id: String = UUID().uuidString, photoId: String, senderId: String, text: String, timestamp: Date = Date(), replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil, reactions: [String: String]? = nil, voiceUrl: String? = nil, stickers: [String: StickerAttachment]? = nil, photoReplyUrl: String? = nil) {
        self.id = id
        self.photoId = photoId
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.replyToId = replyToId
        self.replyToText = replyToText
        self.replyToSenderId = replyToSenderId
        self.reactions = reactions
        self.voiceUrl = voiceUrl
        self.stickers = stickers
        self.photoReplyUrl = photoReplyUrl
    }
}
