import Foundation

/// Pure-logic helpers for the friendship subsystem. All Firestore I/O happens
/// through the injected `FirestoreClient`, making every code path here unit
/// testable without booting Firebase.
///
/// FriendshipService delegates read paths to this; mutating ops (transactions)
/// stay in FriendshipService since they need Firestore-specific transaction APIs.
public actor FriendshipQueries {
    public static let shared = FriendshipQueries(firestore: FirebaseFirestoreClient.shared)

    private let firestore: FirestoreClient

    public init(firestore: FirestoreClient) {
        self.firestore = firestore
    }

    /// Fetch the user's friendship documents from `users/{uid}/friendships`.
    /// Returns lightweight `Entry` records that are independent of Firestore
    /// types so callers can test without imports.
    public func fetchFriendshipEntries(for uid: String) async throws -> [Entry] {
        let results = try await firestore.listSubcollection(parentPath: "users/\(uid)", name: "friendships")
        return results.compactMap { Entry.from(id: $0.id, data: $0.data) }
    }

    /// Fetch a batch of user profiles by uid. Splits >30-id requests into
    /// parallel chunks (Firestore `in` query limit). Returns empty if no IDs.
    public func fetchProfiles(forUserIds ids: [String]) async throws -> [String: UserProfile] {
        guard !ids.isEmpty else { return [:] }
        let chunks = stride(from: 0, to: ids.count, by: 30).map {
            Array(ids[$0..<min($0 + 30, ids.count)])
        }

        var profiles: [String: UserProfile] = [:]
        for chunk in chunks {
            let results = try await firestore.queryDocuments(
                collection: "users",
                filters: [.isIn(field: "__name__", values: chunk)],
                orderBy: nil,
                limit: nil
            )
            for r in results {
                profiles[r.id] = ProfileStore.parseProfile(uid: r.id, data: r.data)
            }
        }
        return profiles
    }

    /// Combine friendship entries with their corresponding profiles.
    /// Pure function — testable without I/O. Friendship without a matching
    /// profile gets an entry with profile=nil (caller can show a placeholder).
    public static func mergeEntriesWithProfiles(
        entries: [Entry],
        profiles: [String: UserProfile]
    ) -> [FriendStatus] {
        entries.map { entry in
            FriendStatus(
                userId: entry.userId,
                isPending: entry.isPending,
                timestamp: entry.timestamp,
                requesterId: entry.requesterId,
                profile: profiles[entry.userId]
            )
        }
    }

    /// Determines whether two users are mutual friends (both accepted).
    /// Pure function for testability.
    public static func isMutualFriend(
        myFriendshipsContainsAcceptedFor otherUid: String,
        in entries: [Entry]
    ) -> Bool {
        entries.contains { $0.userId == otherUid && !$0.isPending }
    }

    public struct Entry: Sendable, Equatable {
        public let userId: String
        public let isPending: Bool
        public let timestamp: Date
        public let requesterId: String?

        public init(userId: String, isPending: Bool, timestamp: Date, requesterId: String?) {
            self.userId = userId
            self.isPending = isPending
            self.timestamp = timestamp
            self.requesterId = requesterId
        }

        /// Parse a Firestore friendship document into an Entry, or nil if malformed.
        public static func from(id: String, data: [String: Any]) -> Entry? {
            guard let userId = data["userId"] as? String,
                  let isPending = data["isPending"] as? Bool else { return nil }
            let timestamp: Date
            if let d = data["timestamp"] as? Date {
                timestamp = d
            } else if let n = data["timestamp"] as? Double {
                timestamp = Date(timeIntervalSince1970: n)
            } else {
                timestamp = Date()
            }
            let requesterId = data["requesterId"] as? String
            return Entry(userId: userId, isPending: isPending, timestamp: timestamp, requesterId: requesterId)
        }
    }
}
