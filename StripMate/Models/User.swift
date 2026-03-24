import Foundation
import SwiftData

@Model
public final class User {
    @Attribute(.unique) public var id: String
    public var inviteCode: String
    public var email: String?
    public var displayName: String?
    public var username: String?
    public var dateOfBirth: Date?
    public var avatarUrl: String?
    public var bio: String?
    public var statusEmoji: String?

    public init(id: String, inviteCode: String, email: String? = nil, displayName: String? = nil, username: String? = nil, dateOfBirth: Date? = nil, avatarUrl: String? = nil, bio: String? = nil, statusEmoji: String? = nil) {
        self.id = id
        self.inviteCode = inviteCode
        self.email = email
        self.displayName = displayName
        self.username = username
        self.dateOfBirth = dateOfBirth
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.statusEmoji = statusEmoji
    }
}
