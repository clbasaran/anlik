import Foundation
import SwiftData

@Model
public final class Friend {
    @Attribute(.unique) public var userId: String
    public var isPending: Bool
    public var timestamp: Date
    public var requesterId: String? // Who initiated the request
    /// Sender-side flag — surfaced at the top of friend lists for fast access.
    public var isFavorite: Bool = false
    @Relationship public var profile: User? // Link to the local User record

    public init(userId: String, isPending: Bool, timestamp: Date, requesterId: String? = nil, profile: User? = nil, isFavorite: Bool = false) {
        self.userId = userId
        self.isPending = isPending
        self.timestamp = timestamp
        self.requesterId = requesterId
        self.profile = profile
        self.isFavorite = isFavorite
    }
}
