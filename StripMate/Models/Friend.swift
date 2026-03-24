import Foundation
import SwiftData

@Model
public final class Friend {
    @Attribute(.unique) public var userId: String
    public var isPending: Bool
    public var timestamp: Date
    public var requesterId: String? // Who initiated the request
    @Relationship public var profile: User? // Link to the local User record
    
    public init(userId: String, isPending: Bool, timestamp: Date, requesterId: String? = nil, profile: User? = nil) {
        self.userId = userId
        self.isPending = isPending
        self.timestamp = timestamp
        self.requesterId = requesterId
        self.profile = profile
    }
}
