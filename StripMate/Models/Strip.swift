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
            voiceUrl: voiceUrl
        )
    }
    
    public init(id: String = UUID().uuidString, senderId: String, receiverIds: [String] = [], imageUrl: String, timestamp: Date = Date(), latitude: Double? = nil, longitude: Double? = nil, cityName: String? = nil, thumbnailUrl: String? = nil, smallThumbnailUrl: String? = nil, flagged: Bool = false, flagReason: String? = nil, voiceUrl: String? = nil) {
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
        self.receiverIds = receiverIds
    }
}
