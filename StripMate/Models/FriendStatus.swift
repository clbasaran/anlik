import Foundation

public struct FriendStatus: Identifiable, Codable, Sendable {
    public var id: String { userId }
    public let userId: String
    public let isPending: Bool
    public let timestamp: Date
    public let requesterId: String? // Who initiated the request
    public var profile: UserProfile?
    /// Sender-side flag — surfaced at the top of recipient pickers for fast access
    /// in the long-tail of friends lists. Stored at users/{uid}/friendships/{friendId}.isFavorite.
    public var isFavorite: Bool = false

    public init(
        userId: String,
        isPending: Bool,
        timestamp: Date,
        requesterId: String? = nil,
        profile: UserProfile? = nil,
        isFavorite: Bool = false
    ) {
        self.userId = userId
        self.isPending = isPending
        self.timestamp = timestamp
        self.requesterId = requesterId
        self.profile = profile
        self.isFavorite = isFavorite
    }
}
