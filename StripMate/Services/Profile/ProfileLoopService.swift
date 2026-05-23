import Foundation

/// Service for managing the user's profile loops (3 short videos shown on
/// their profile). Uses StorageClient + FirestoreClient via DI so it's
/// fully mockable in tests.
public actor ProfileLoopService {
    public static let shared = ProfileLoopService(
        storage: FirebaseStorageClient.shared,
        firestore: FirebaseFirestoreClient.shared
    )

    public static let maxSlots = 3
    public static let maxFileSize = 8 * 1024 * 1024 // 8 MB

    private let storage: StorageClient
    private let firestore: FirestoreClient

    public init(storage: StorageClient, firestore: FirestoreClient) {
        self.storage = storage
        self.firestore = firestore
    }

    public enum Error: Swift.Error, LocalizedError {
        case slotOutOfRange
        case fileTooLarge(bytes: Int)
        case unauthenticated

        public var errorDescription: String? {
            switch self {
            case .slotOutOfRange: return "Geçersiz profil slotu (0-2 olmalı)."
            case .fileTooLarge(let b): return "Video çok büyük (\(b / 1024 / 1024) MB > 8 MB)."
            case .unauthenticated: return "Önce giriş yap."
            }
        }
    }

    /// Upload a video + optional thumbnail to the given slot, then update the
    /// user's profileLoops array in Firestore. Replaces any existing loop in
    /// that slot.
    @discardableResult
    public func uploadLoop(
        userId: String,
        slot: Int,
        videoData: Data,
        thumbnailData: Data?,
        duration: Double,
        isBoomerang: Bool
    ) async throws -> ProfileLoop {
        try Self.validateSlot(slot)
        try Self.validateSize(videoData.count)

        let videoPath = "profile_loops/\(userId)_\(slot).mp4"
        let videoUrl = try await storage.uploadData(videoData, to: videoPath, contentType: "video/mp4")

        var thumbnailUrl: String?
        if let thumbnailData {
            try Self.validateSize(thumbnailData.count, max: 1 * 1024 * 1024)
            let thumbPath = "profile_loops/thumbs/\(userId)_\(slot).jpg"
            thumbnailUrl = try await storage.uploadData(thumbnailData, to: thumbPath, contentType: "image/jpeg")
        }

        let loop = ProfileLoop(
            id: ProfileLoop.id(forSlot: slot),
            slot: slot,
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl,
            duration: duration,
            isBoomerang: isBoomerang,
            createdAt: Date()
        )

        try await updateUserProfileLoops(userId: userId, replacing: slot, with: loop)
        return loop
    }

    /// Delete the loop at the given slot — removes Storage objects and updates Firestore.
    public func deleteLoop(userId: String, slot: Int) async throws {
        try Self.validateSlot(slot)
        // Best-effort storage cleanup
        try? await storage.deleteObject(at: "profile_loops/\(userId)_\(slot).mp4")
        try? await storage.deleteObject(at: "profile_loops/thumbs/\(userId)_\(slot).jpg")
        try await updateUserProfileLoops(userId: userId, replacing: slot, with: nil)
    }

    /// Read the user's current profile loops from Firestore.
    public func fetchLoops(userId: String) async throws -> [ProfileLoop] {
        guard let data = try await firestore.getDocument(path: "users/\(userId)") else {
            return []
        }
        return Self.extractLoops(from: data)
    }

    // MARK: - Private

    /// Read existing loops, replace the slot (or remove if newLoop is nil), write back.
    /// This is the inner write step — extracted so it's identical between
    /// upload and delete paths.
    private func updateUserProfileLoops(userId: String, replacing slot: Int, with newLoop: ProfileLoop?) async throws {
        let existing = (try? await fetchLoops(userId: userId)) ?? []
        let updated = Self.replace(loops: existing, slot: slot, with: newLoop)
        let serialized = updated.map { $0.asDictionary }
        try await firestore.updateDocument(
            path: "users/\(userId)",
            data: ["profileLoops": serialized]
        )
    }

    // MARK: - Pure helpers (testable without I/O)

    /// Replace (or remove) the loop at the given slot in an existing array.
    /// Returns the new sorted array.
    public static func replace(
        loops: [ProfileLoop],
        slot: Int,
        with newLoop: ProfileLoop?
    ) -> [ProfileLoop] {
        var result = loops.filter { $0.slot != slot }
        if let newLoop {
            result.append(newLoop)
        }
        return result.sorted { $0.slot < $1.slot }
    }

    /// Extract loops from a Firestore user document data dictionary.
    public static func extractLoops(from data: [String: Any]) -> [ProfileLoop] {
        guard let raw = data["profileLoops"] as? [[String: Any]] else { return [] }
        return raw.compactMap { ProfileLoop.from($0) }.sorted { $0.slot < $1.slot }
    }

    /// Find the next free slot (0, 1, or 2). Returns nil if all slots are occupied.
    public static func nextFreeSlot(in loops: [ProfileLoop]) -> Int? {
        let occupied = Set(loops.map(\.slot))
        for i in 0..<maxSlots {
            if !occupied.contains(i) { return i }
        }
        return nil
    }

    public static func validateSlot(_ slot: Int) throws {
        guard slot >= 0 && slot < maxSlots else {
            throw Error.slotOutOfRange
        }
    }

    public static func validateSize(_ bytes: Int, max: Int = maxFileSize) throws {
        guard bytes <= max else {
            throw Error.fileTooLarge(bytes: bytes)
        }
    }
}
