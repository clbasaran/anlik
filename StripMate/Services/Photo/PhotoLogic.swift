import Foundation

/// Pure-function helpers used by PhotoService. Extracted so they can be
/// exhaustively unit-tested without booting Firebase.
///
/// Naming convention: each enum here owns one specific transform / decision.

// MARK: - Document builder

/// Builds the Firestore document data dictionary for a `strips/{stripId}` write.
/// Pure — no I/O, no time-dependent fields (timestamp comes from caller).
public enum PhotoUploadDocumentBuilder {
    public struct Input: Sendable {
        public let stripId: String
        public let senderId: String
        public let senderProfileSnapshot: [String: Any]
        public let receiverIds: [String]
        public let imageUrl: String
        public let voiceUrl: String?
        public let videoUrl: String?
        public let videoDuration: Double?
        public let latitude: Double?
        public let longitude: Double?
        public let cityName: String?
        public let isSecret: Bool
        public let dailyPromptId: String?

        public init(
            stripId: String,
            senderId: String,
            senderProfileSnapshot: [String: Any] = [:],
            receiverIds: [String],
            imageUrl: String,
            voiceUrl: String? = nil,
            videoUrl: String? = nil,
            videoDuration: Double? = nil,
            latitude: Double? = nil,
            longitude: Double? = nil,
            cityName: String? = nil,
            isSecret: Bool = false,
            dailyPromptId: String? = nil
        ) {
            self.stripId = stripId
            self.senderId = senderId
            self.senderProfileSnapshot = senderProfileSnapshot
            self.receiverIds = receiverIds
            self.imageUrl = imageUrl
            self.voiceUrl = voiceUrl
            self.videoUrl = videoUrl
            self.videoDuration = videoDuration
            self.latitude = latitude
            self.longitude = longitude
            self.cityName = cityName
            self.isSecret = isSecret
            self.dailyPromptId = dailyPromptId
        }
    }

    /// Build the Firestore document body. Caller is expected to also set a
    /// server timestamp via FieldValue.serverTimestamp() — which is added
    /// outside this pure function in production. For tests, callers pass a
    /// fixed Date so output is deterministic.
    public static func build(_ input: Input, timestamp: Date) -> [String: Any] {
        // Always include the sender in receiverIds (self-echo pattern) so the
        // sender's own history shows the strip too.
        var finalReceivers = input.receiverIds
        if !finalReceivers.contains(input.senderId) {
            finalReceivers.append(input.senderId)
        }

        var doc: [String: Any] = [
            "id": input.stripId,
            "senderId": input.senderId,
            "receiverIds": finalReceivers,
            "imageUrl": input.imageUrl,
            "timestamp": timestamp,
            "isSecret": input.isSecret,
            "flagged": false,
            "reactions": [String: [String]]()
        ]

        if let voice = input.voiceUrl, !voice.isEmpty {
            doc["voiceUrl"] = voice
        }
        if let video = input.videoUrl, !video.isEmpty {
            doc["videoUrl"] = video
            if let dur = input.videoDuration {
                doc["videoDuration"] = dur
            }
        }
        if let lat = input.latitude, let lon = input.longitude, !(lat == 0 && lon == 0) {
            doc["latitude"] = lat
            doc["longitude"] = lon
        }
        if let city = input.cityName, !city.isEmpty {
            doc["cityName"] = city
        }
        if let pid = input.dailyPromptId, !pid.isEmpty {
            doc["dailyPromptId"] = pid
        }
        if input.isSecret {
            // Sender always sees their own secret strip — pre-seed the unlock list
            doc["unlockedBy"] = [input.senderId]
        }
        if !input.senderProfileSnapshot.isEmpty {
            doc["senderProfileSnapshot"] = input.senderProfileSnapshot
        }
        return doc
    }
}

// MARK: - Send pre-flight validation

/// Result of validating a photo send before any Storage / Firestore work.
public enum SendValidationResult: Equatable, Sendable {
    case ok
    case noReceivers
    case tooManyReceivers
    case nonFriendReceivers([String])  // userIds that are not accepted friends
    case unauthenticated
}

public enum PhotoSendValidator {
    public static func validate(
        senderId: String?,
        receiverIds: [String],
        acceptedFriendIds: Set<String>,
        maxReceivers: Int = 50
    ) -> SendValidationResult {
        guard let _ = senderId else { return .unauthenticated }
        guard !receiverIds.isEmpty else { return .noReceivers }
        guard receiverIds.count <= maxReceivers else { return .tooManyReceivers }
        // Filter out sender (self-echo allowed) and check the rest are friends
        let nonFriend = receiverIds.filter { rid in
            rid != senderId && !acceptedFriendIds.contains(rid)
        }
        if !nonFriend.isEmpty {
            return .nonFriendReceivers(nonFriend)
        }
        return .ok
    }
}

// MARK: - Storage path generators

public enum PhotoStoragePaths {
    public static func image(stripId: String, senderId: String) -> String {
        "strips/\(senderId)_\(stripId).jpg"
    }

    public static func thumbnail(stripId: String, senderId: String, size: Int) -> String {
        "strips/thumbs/\(senderId)_\(stripId)_\(size)x\(size).jpg"
    }

    public static func video(stripId: String) -> String {
        "strips/videos/\(stripId).mp4"
    }

    public static func voice(stripId: String, senderId: String) -> String {
        "voices/\(senderId)_\(stripId).m4a"
    }

    public static func avatar(userId: String) -> String {
        "avatars/\(userId).jpg"
    }

    public static func chatPhoto(messageId: String, senderId: String) -> String {
        "chat_photos/\(senderId)_\(messageId).jpg"
    }

    public static func dmPhoto(messageId: String, senderId: String) -> String {
        "dm_photos/\(senderId)_\(messageId).jpg"
    }
}

// MARK: - Reaction toggle logic

/// Pure logic for toggling an emoji reaction on a strip. The Firestore call
/// uses a transaction; the *decision* of what to write is computed here.
public enum ReactionLogic {
    /// Apply a toggle: if user already reacted with this emoji, remove it;
    /// if user reacted with a different emoji, switch to the new one;
    /// if user hadn't reacted, add the new emoji.
    public static func toggle(
        reactions: [String: [String]],
        userId: String,
        emoji: String
    ) -> [String: [String]] {
        var next = reactions

        // Find any existing emoji this user reacted with
        let existingEmoji = next.first(where: { $0.value.contains(userId) })?.key

        if let existing = existingEmoji {
            // Remove user from old emoji
            next[existing]?.removeAll(where: { $0 == userId })
            if next[existing]?.isEmpty == true {
                next.removeValue(forKey: existing)
            }
            // If toggling the same emoji, we're done (user de-reacted)
            if existing == emoji {
                return next
            }
        }

        // Add user to new emoji
        next[emoji, default: []].append(userId)
        return next
    }

    /// Returns true if the user has any reaction set on this strip.
    public static func userHasReacted(_ reactions: [String: [String]], userId: String) -> Bool {
        reactions.values.contains(where: { $0.contains(userId) })
    }

    /// Returns the user's current emoji, if any.
    public static func currentEmoji(_ reactions: [String: [String]], userId: String) -> String? {
        reactions.first(where: { $0.value.contains(userId) })?.key
    }
}

// MARK: - Secret-strip locking decision

public enum SecretStripLogic {
    /// True if the viewer should see the locked placeholder (unencrypted preview
    /// blocked) rather than the actual image.
    public static func isLockedFor(
        viewer viewerId: String,
        strip: PhotoMetadata
    ) -> Bool {
        guard strip.isSecret == true else { return false }
        if strip.senderId == viewerId { return false }                  // sender always sees own
        let unlockedBy = Set(strip.unlockedBy ?? [])
        return !unlockedBy.contains(viewerId)
    }
}
