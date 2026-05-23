import Foundation
import FirebaseFirestore

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

    /// True if this is a system-generated welcome strip seeded by Cloud Function
    /// for new users. Identified by the `system://` URL scheme. UI should render
    /// these with a special placeholder + caption instead of trying to load.
    public var isSystemWelcomeStrip: Bool { imageUrl.hasPrefix("system://") }

    /// Factory: create from a Firestore document data dictionary.
    /// Returns nil if required fields (id, senderId, receiverIds, imageUrl) are missing.
    public static func from(_ data: [String: Any]) -> PhotoMetadata? {
        guard let id = data["id"] as? String,
              let senderId = data["senderId"] as? String,
              let receiverIds = data["receiverIds"] as? [String],
              let imageUrl = data["imageUrl"] as? String else { return nil }
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        return PhotoMetadata(
            id: id,
            senderId: senderId,
            receiverIds: receiverIds,
            imageUrl: imageUrl,
            timestamp: timestamp,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            cityName: data["cityName"] as? String,
            thumbnailUrl: data["thumbnailUrl"] as? String,
            smallThumbnailUrl: data["smallThumbnailUrl"] as? String,
            flagged: data["flagged"] as? Bool ?? false,
            flagReason: data["flagReason"] as? String,
            voiceUrl: data["voiceUrl"] as? String,
            isSecret: data["isSecret"] as? Bool ?? false,
            unlockedBy: data["unlockedBy"] as? [String],
            seenBy: data["seenBy"] as? [String],
            videoUrl: data["videoUrl"] as? String,
            videoDuration: data["videoDuration"] as? Double
        )
    }

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
