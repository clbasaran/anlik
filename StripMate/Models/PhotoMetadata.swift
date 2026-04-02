import Foundation

public struct PhotoMetadata: Identifiable, Codable, Sendable {
    public let id: String
    public let senderId: String
    public let receiverIds: [String]
    public let imageUrl: String
    public let timestamp: Date
    public let latitude: Double?
    public let longitude: Double?
    public let cityName: String?
    public let thumbnailUrl: String?
    public let smallThumbnailUrl: String?
    public var reactions: [String: [String]]?  // emoji → [userId]
    public let flagged: Bool
    public let flagReason: String?
    public let voiceUrl: String?
    public let isSecret: Bool
    public var unlockedBy: [String]?
    public var seenBy: [String]?
    public let videoUrl: String?
    public let videoDuration: Double?

    public var isVideo: Bool { videoUrl != nil }

    public nonisolated init(id: String = UUID().uuidString, senderId: String, receiverIds: [String] = [], imageUrl: String, timestamp: Date = Date(), latitude: Double? = nil, longitude: Double? = nil, cityName: String? = nil, thumbnailUrl: String? = nil, smallThumbnailUrl: String? = nil, reactions: [String: [String]]? = nil, flagged: Bool = false, flagReason: String? = nil, voiceUrl: String? = nil, isSecret: Bool = false, unlockedBy: [String]? = nil, seenBy: [String]? = nil, videoUrl: String? = nil, videoDuration: Double? = nil) {
        self.id = id
        self.senderId = senderId
        self.receiverIds = receiverIds
        self.imageUrl = imageUrl
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
        self.thumbnailUrl = thumbnailUrl
        self.smallThumbnailUrl = smallThumbnailUrl
        self.reactions = reactions
        self.flagged = flagged
        self.flagReason = flagReason
        self.voiceUrl = voiceUrl
        self.isSecret = isSecret
        self.unlockedBy = unlockedBy
        self.seenBy = seenBy
        self.videoUrl = videoUrl
        self.videoDuration = videoDuration
    }
}
