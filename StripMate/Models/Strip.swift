import Foundation
import SwiftData

@Model
public final class Strip {
    @Attribute(.unique) public var id: String
    public var senderId: String
    private var receiverIdsString: String = ""
    public var imageUrl: String
    public var timestamp: Date
    public var latitude: Double?
    public var longitude: Double?
    public var cityName: String?
    public var thumbnailUrl: String?
    public var smallThumbnailUrl: String?
    public var flagged: Bool
    public var flagReason: String?
    public var voiceUrl: String?
    public var isSecret: Bool = false
    private var unlockedByString: String = ""
    private var seenByString: String = ""

    public var unlockedBy: [String] {
        get { unlockedByString.isEmpty ? [] : unlockedByString.split(separator: ",").map(String.init) }
        set { unlockedByString = newValue.joined(separator: ",") }
    }

    public var seenBy: [String] {
        get { seenByString.isEmpty ? [] : seenByString.split(separator: ",").map(String.init) }
        set { seenByString = newValue.joined(separator: ",") }
    }

    /// Bu strip gizli mi ve henüz userId tarafından açılmamış mı?
    public func isLockedFor(_ userId: String) -> Bool {
        guard isSecret, senderId != userId else { return false }
        return !unlockedBy.contains(userId)
    }

    public var receiverIds: [String] {
        get {
            receiverIdsString.split(separator: ",").map(String.init)
        }
        set {
            receiverIdsString = newValue.joined(separator: ",")
        }
    }
    
    // Convert to older struct when needed for non-SwiftData components
    public var asMetadata: PhotoMetadata {
        PhotoMetadata(
            id: id,
            senderId: senderId,
            receiverIds: receiverIds,
            imageUrl: imageUrl,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            cityName: cityName,
            thumbnailUrl: thumbnailUrl,
            smallThumbnailUrl: smallThumbnailUrl,
            flagged: flagged,
            flagReason: flagReason,
            voiceUrl: voiceUrl,
            isSecret: isSecret,
            unlockedBy: unlockedBy,
            seenBy: seenBy
        )
    }
    
    public init(id: String = UUID().uuidString, senderId: String, receiverIds: [String] = [], imageUrl: String, timestamp: Date = Date(), latitude: Double? = nil, longitude: Double? = nil, cityName: String? = nil, thumbnailUrl: String? = nil, smallThumbnailUrl: String? = nil, flagged: Bool = false, flagReason: String? = nil, voiceUrl: String? = nil, isSecret: Bool = false, unlockedBy: [String] = [], seenBy: [String] = []) {
        self.id = id
        self.senderId = senderId
        self.imageUrl = imageUrl
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
        self.thumbnailUrl = thumbnailUrl
        self.smallThumbnailUrl = smallThumbnailUrl
        self.flagged = flagged
        self.flagReason = flagReason
        self.voiceUrl = voiceUrl
        self.isSecret = isSecret
        self.receiverIds = receiverIds
        self.unlockedBy = unlockedBy
        self.seenBy = seenBy
    }
}
