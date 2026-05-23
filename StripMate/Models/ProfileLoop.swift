import Foundation

/// A short Boomerang-style video shown on a user's profile.
/// Each user has up to 3 slots. The slot index is the position in the
/// `UserProfile.profileLoops` array.
public struct ProfileLoop: Identifiable, Codable, Sendable, Equatable, Hashable {
    /// Stable id. We use slot index encoded as "slot_N" so updates target the
    /// same identity rather than appending. Display order is array order.
    public let id: String

    /// Slot index 0...2.
    public let slot: Int

    /// Storage download URL for the video file.
    public let videoUrl: String

    /// Optional poster/thumbnail URL — first frame as JPEG for fast preview.
    public let thumbnailUrl: String?

    /// Duration in seconds (typically 2-3 seconds).
    public let duration: Double

    /// Whether this loop was created via Boomerang (forward + reverse).
    public let isBoomerang: Bool

    /// Server timestamp when the loop was created.
    public let createdAt: Date

    public init(
        id: String,
        slot: Int,
        videoUrl: String,
        thumbnailUrl: String? = nil,
        duration: Double,
        isBoomerang: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.slot = slot
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
        self.isBoomerang = isBoomerang
        self.createdAt = createdAt
    }

    /// Build the canonical id for a slot — used so updates replace the same identity.
    public static func id(forSlot slot: Int) -> String {
        "slot_\(slot)"
    }
}

// MARK: - Dictionary parsing (Firestore round-trip)

public extension ProfileLoop {
    /// Build from a Firestore-style dictionary. Returns nil if required fields missing.
    static func from(_ data: [String: Any]) -> ProfileLoop? {
        guard let id = data["id"] as? String,
              let slot = data["slot"] as? Int,
              let videoUrl = data["videoUrl"] as? String,
              let duration = data["duration"] as? Double else { return nil }
        let thumbnailUrl = data["thumbnailUrl"] as? String
        let isBoomerang = data["isBoomerang"] as? Bool ?? false
        let createdAt: Date = {
            if let d = data["createdAt"] as? Date { return d }
            if let n = data["createdAt"] as? Double { return Date(timeIntervalSince1970: n) }
            return Date()
        }()
        return ProfileLoop(
            id: id, slot: slot, videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl, duration: duration,
            isBoomerang: isBoomerang, createdAt: createdAt
        )
    }

    /// Serialize to Firestore-style dictionary.
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "slot": slot,
            "videoUrl": videoUrl,
            "duration": duration,
            "isBoomerang": isBoomerang,
            "createdAt": createdAt
        ]
        if let thumbnailUrl { dict["thumbnailUrl"] = thumbnailUrl }
        return dict
    }
}
