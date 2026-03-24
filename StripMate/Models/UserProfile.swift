import Foundation

public struct UserProfile: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let inviteCode: String
    public let email: String?
    public let displayName: String?
    public let username: String?
    public let dateOfBirth: Date?
    public let avatarUrl: String?
    public let bio: String?
    public let statusEmoji: String?
    /// Mirrors Firestore notificationPreferences map — keyed by setting name.
    public let notificationPreferences: [String: Bool]?
    
    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public nonisolated static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        lhs.id == rhs.id
    }
    
    public nonisolated init(id: String, inviteCode: String, email: String? = nil, displayName: String? = nil, username: String? = nil, dateOfBirth: Date? = nil, avatarUrl: String? = nil, bio: String? = nil, statusEmoji: String? = nil, notificationPreferences: [String: Bool]? = nil) {
        self.id = id
        self.inviteCode = inviteCode
        self.email = email
        self.displayName = displayName
        self.username = username
        self.dateOfBirth = dateOfBirth
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.statusEmoji = statusEmoji
        self.notificationPreferences = notificationPreferences
    }
    
    /// Returns true if the profile is missing required fields (username or displayName).
    /// Apple Sign-In users may have incomplete profiles on first login.
    public nonisolated var needsProfileCompletion: Bool {
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let user = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty || user.isEmpty || name == "Apple User"
    }
}
