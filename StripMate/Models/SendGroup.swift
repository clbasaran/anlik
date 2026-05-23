import Foundation

/// A user-created list of friends that can be selected as a single recipient
/// in the send sheet. Lives at users/{uid}/send_groups/{groupId}.
public struct SendGroup: Identifiable, Codable, Sendable {
    public let id: String
    public var name: String
    public var memberIds: [String]
    public let createdAt: Date

    public init(id: String = UUID().uuidString, name: String, memberIds: [String], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.memberIds = memberIds
        self.createdAt = createdAt
    }
}
