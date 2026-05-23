import Foundation

/// Read-only strip queries that go through `FirestoreClient`. Pure logic for
/// pagination cursors lives in this file too. Mockable in tests.
public actor StripQueryStore {
    public static let shared = StripQueryStore(firestore: FirebaseFirestoreClient.shared)

    private let firestore: FirestoreClient

    /// Last timestamp from the most recent loadMore page — used to drive
    /// cursor-based pagination without exposing Firestore types.
    private var lastSeenTimestamp: Date?

    public init(firestore: FirestoreClient) {
        self.firestore = firestore
    }

    /// Fetch a single strip by id, or nil if it doesn't exist.
    public func fetchStrip(byId stripId: String) async throws -> PhotoMetadata? {
        guard let data = try await firestore.getDocument(path: "strips/\(stripId)") else {
            return nil
        }
        return PhotoMetadata.from(data)
    }

    /// Fetch the most recent N strips visible to a user (the user is in receiverIds).
    /// Used as the initial load for History.
    public func fetchInitialHistory(for userId: String, limit: Int = 50) async throws -> [PhotoMetadata] {
        let results = try await firestore.queryDocuments(
            collection: "strips",
            filters: [.arrayContains(field: "receiverIds", value: userId)],
            orderBy: QueryOrder(field: "timestamp", descending: true),
            limit: limit
        )
        let photos = results.compactMap { PhotoMetadata.from($0.data) }
        lastSeenTimestamp = photos.last?.timestamp
        return photos
    }

    /// Reset the pagination cursor (call on logout / refresh).
    public func resetCursor() {
        lastSeenTimestamp = nil
    }

    /// Filter out strips from blocked senders and flagged content.
    /// Pure helper — testable.
    public static func filterVisible(
        photos: [PhotoMetadata],
        blockedIds: Set<String>
    ) -> [PhotoMetadata] {
        photos.filter { photo in
            if blockedIds.contains(photo.senderId) { return false }
            if photo.flagged == true { return false }
            return true
        }
    }

    /// Pick the photo most relevant to show on the home widget — prefers
    /// `pinnedFriendId` if set, otherwise the most recent strip from a user
    /// other than the viewer.
    /// Pure helper — testable.
    public static func widgetTargetPhoto(
        from photos: [PhotoMetadata],
        viewerId: String,
        pinnedFriendId: String?
    ) -> PhotoMetadata? {
        if let pid = pinnedFriendId, !pid.isEmpty {
            if let pinned = photos.first(where: { $0.senderId == pid }) {
                return pinned
            }
        }
        return photos.first(where: { $0.senderId != viewerId })
    }
}
