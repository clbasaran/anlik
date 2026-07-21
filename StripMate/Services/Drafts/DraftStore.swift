import Foundation
import UIKit

/// Persists a single in-flight upload across app restarts so a network blip
/// or process kill doesn't lose the user's photo. The CameraViewModel writes
/// its `pendingRetry` state through here on every mutation; on next cold
/// launch the same state is rehydrated and the user sees a "taslak hazır"
/// banner with a tap-to-retry affordance.
///
/// Two slots exist today: `shared` (the retry draft) and `firstMoment` (the
/// capture parked while the user waits for their first accepted friend).
/// Before the split a failed send could silently overwrite the queued first
/// moment — the slots now live in separate directories.
public final class DraftStore: @unchecked Sendable {
    public static let shared = DraftStore()
    /// Dedicated slot for the awaiting-first-friend capture (yeni-kullanici-1).
    public static let firstMoment = DraftStore(slot: "first_moment")

    public struct Snapshot: Codable, Sendable {
        public var receivers: [String]
        public var comment: String?
        public var latitude: Double?
        public var longitude: Double?
        public var cityName: String?
        public var isSecret: Bool
        public var hasVoice: Bool
        public var videoDuration: Double?
        public var videoIncludesSound: Bool
        public var savedAt: Date
        /// Media filenames inside the drafts directory; nil if no such media.
        public var imageFile: String?
        public var videoFile: String?
        public var voiceFile: String?
        /// Set when the draft is a queued "first moment" — captured before
        /// any friend was accepted (yeni-kullanici-1). Surfaces as the
        /// camera's waiting chip instead of the retry banner. Optional so
        /// drafts saved by older builds keep decoding.
        public var awaitingFirstFriend: Bool?
    }

    private let fileManager = FileManager.default
    /// Subdirectory under drafts/ for this slot; nil = the legacy root slot.
    private let slot: String?
    private lazy var directory: URL = {
        // Prefer app group container so widget extension can be aware too;
        // fall back to Documents if the group container isn't available.
        let base = fileManager.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        var dir = base.appendingPathComponent("drafts", isDirectory: true)
        if let slot {
            dir = dir.appendingPathComponent(slot, isDirectory: true)
        }
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    private var metadataURL: URL { directory.appendingPathComponent("active.json") }

    public init() {
        self.slot = nil
    }

    public init(slot: String) {
        self.slot = slot
    }

    /// Writes a fresh snapshot, replacing any prior draft. Media files are
    /// copied into the drafts directory so they survive even if the original
    /// /tmp paths get cleared by the OS.
    public func save(
        receivers: [String],
        comment: String?,
        latitude: Double?,
        longitude: Double?,
        cityName: String?,
        isSecret: Bool,
        videoDuration: Double?,
        videoIncludesSound: Bool,
        image: UIImage? = nil,
        videoURL: URL? = nil,
        voiceData: Data? = nil,
        awaitingFirstFriend: Bool = false
    ) {
        // Wipe prior media — we keep at most one draft.
        clearMedia()

        var snapshot = Snapshot(
            receivers: receivers,
            comment: comment,
            latitude: latitude,
            longitude: longitude,
            cityName: cityName,
            isSecret: isSecret,
            hasVoice: voiceData != nil,
            videoDuration: videoDuration,
            videoIncludesSound: videoIncludesSound,
            savedAt: Date(),
            imageFile: nil,
            videoFile: nil,
            voiceFile: nil,
            awaitingFirstFriend: awaitingFirstFriend ? true : nil
        )

        if let image, let jpeg = image.jpegData(compressionQuality: 0.85) {
            let file = "image.jpg"
            try? jpeg.write(to: directory.appendingPathComponent(file), options: .atomic)
            snapshot.imageFile = file
        }
        if let videoURL {
            let file = "video.mp4"
            let dest = directory.appendingPathComponent(file)
            try? fileManager.removeItem(at: dest)
            try? fileManager.copyItem(at: videoURL, to: dest)
            snapshot.videoFile = file
        }
        if let voiceData {
            let file = "voice.m4a"
            try? voiceData.write(to: directory.appendingPathComponent(file), options: .atomic)
            snapshot.voiceFile = file
        }

        do {
            let json = try JSONEncoder().encode(snapshot)
            try json.write(to: metadataURL, options: .atomic)
        } catch {
            // Persistence is best-effort — failure leaves the in-memory retry
            // state intact, just no cross-launch durability.
        }
    }

    /// Returns the persisted snapshot if present and the media files still
    /// exist. Returns nil when the slot is empty.
    public func restore() -> (snapshot: Snapshot, image: UIImage?, videoURL: URL?, voiceData: Data?)? {
        guard fileManager.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return nil
        }
        let image: UIImage? = snapshot.imageFile.flatMap { name in
            let url = directory.appendingPathComponent(name)
            return UIImage(contentsOfFile: url.path)
        }
        let videoURL: URL? = snapshot.videoFile.flatMap { name in
            let url = directory.appendingPathComponent(name)
            return fileManager.fileExists(atPath: url.path) ? url : nil
        }
        let voiceData: Data? = snapshot.voiceFile.flatMap { name in
            let url = directory.appendingPathComponent(name)
            return try? Data(contentsOf: url)
        }
        return (snapshot, image, videoURL, voiceData)
    }

    /// Removes the persisted draft and any associated media. Idempotent.
    public func clear() {
        clearMedia()
        try? fileManager.removeItem(at: metadataURL)
    }

    /// True when a draft is currently persisted on disk.
    public var hasDraft: Bool {
        fileManager.fileExists(atPath: metadataURL.path)
    }

    private func clearMedia() {
        for name in ["image.jpg", "video.mp4", "voice.m4a"] {
            try? fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}
