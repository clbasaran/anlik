import Foundation

public struct SupportMessage: Identifiable, Codable, Sendable {
    public let id: String
    public let senderId: String
    public let text: String
    public let timestamp: Date
    public let isAdmin: Bool
    public var readAt: Date?
}
