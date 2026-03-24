import Foundation

public struct FriendStatus: Identifiable, Codable, Sendable {
    public var id: String { userId }
    public let userId: String
    public let isPending: Bool
    public let timestamp: Date
    public let requesterId: String? // Who initiated the request
    public var profile: UserProfile?
}
