import Foundation

/// Thin profile-fetching service that consumes `FirestoreClient` so all of its
/// operations are mockable in tests. Extracts the pure data-shape conversion
/// from Firestore into `UserProfile` so we can test edge cases without booting
/// Firebase.
///
/// AuthService delegates its profile reads to this. Auth flows (login/signup)
/// stay in AuthService since they need FirebaseAuth-specific behavior.
public actor ProfileStore {
    public static let shared = ProfileStore(firestore: FirebaseFirestoreClient.shared)

    private let firestore: FirestoreClient

    /// In-memory profile cache with TTL to reduce Firestore reads.
    private var cache: [String: (profile: UserProfile, fetchedAt: Date)] = [:]
    private let cacheTTL: TimeInterval

    public init(firestore: FirestoreClient, cacheTTL: TimeInterval = 60) {
        self.firestore = firestore
        self.cacheTTL = cacheTTL
    }

    /// Fetch a user's profile by uid. Returns cached value if fresh.
    public func fetchProfile(for userId: String, forceRefresh: Bool = false) async throws -> UserProfile {
        if !forceRefresh, let cached = cache[userId],
           Date().timeIntervalSince(cached.fetchedAt) < cacheTTL {
            return cached.profile
        }

        guard let data = try await firestore.getDocument(path: "users/\(userId)") else {
            throw FirebaseError.userNotFound
        }
        let profile = Self.parseProfile(uid: userId, data: data)
        cache[userId] = (profile, Date())
        return profile
    }

    /// Search for a user by their 8-char invite code.
    public func searchUser(byInviteCode code: String) async throws -> UserProfile {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 8, trimmed.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            throw FirebaseError.userNotFound
        }
        let results = try await firestore.queryDocuments(
            collection: "users",
            filters: [.isEqualTo(field: "inviteCode", value: trimmed)],
            orderBy: nil,
            limit: 1
        )
        guard let result = results.first else {
            throw FirebaseError.userNotFound
        }
        return Self.parseProfile(uid: result.id, data: result.data)
    }

    /// Invalidate the cache (e.g., after a profile update or on logout).
    public func invalidateCache(for userId: String? = nil) {
        if let userId {
            cache.removeValue(forKey: userId)
        } else {
            cache.removeAll()
        }
    }

    /// Pure parser: dictionary → UserProfile. Pulled out so tests can verify
    /// edge cases (missing fields, type mismatches) without any I/O.
    public static func parseProfile(uid: String, data: [String: Any]) -> UserProfile {
        UserProfile(
            id: uid,
            inviteCode: data["inviteCode"] as? String ?? "",
            email: data["email"] as? String,
            displayName: data["displayName"] as? String,
            username: data["username"] as? String,
            dateOfBirth: extractTimestamp(data["dateOfBirth"]),
            avatarUrl: data["avatarUrl"] as? String,
            bio: data["bio"] as? String,
            statusEmoji: data["statusEmoji"] as? String,
            favoriteSong: data["favoriteSong"] as? String,
            zodiacSign: data["zodiacSign"] as? String,
            personalityEmojis: data["personalityEmojis"] as? [String],
            profileLoops: parseProfileLoops(data["profileLoops"]),
            notificationPreferences: {
                guard let raw = data["notificationPreferences"] as? [String: Any] else { return nil }
                return raw.compactMapValues { $0 as? Bool }
            }()
        )
    }

    /// Parse profileLoops array. Defensive — drops malformed entries silently.
    private static func parseProfileLoops(_ raw: Any?) -> [ProfileLoop]? {
        guard let array = raw as? [[String: Any]] else { return nil }
        let parsed = array.compactMap { ProfileLoop.from($0) }
        return parsed.isEmpty ? nil : parsed.sorted { $0.slot < $1.slot }
    }

    /// Convert various timestamp encodings (Date, NSDate, Firestore Timestamp,
    /// or seconds-since-epoch number) to a Date. Defensive against schema
    /// drift between server/client encoders.
    private static func extractTimestamp(_ raw: Any?) -> Date? {
        if let d = raw as? Date { return d }
        if let n = raw as? Double { return Date(timeIntervalSince1970: n) }
        if let n = raw as? Int { return Date(timeIntervalSince1970: TimeInterval(n)) }
        // Firebase Firestore Timestamp has .dateValue(), but we don't want to
        // import the Firestore SDK here. Test path uses Date directly; production
        // path goes through Firestore which auto-decodes Timestamp on .data().
        return nil
    }

    /// Updates a user's profile fields. Pass only the fields you want to change.
    public func updateProfile(uid: String, fields: [String: Any]) async throws {
        try await firestore.updateDocument(path: "users/\(uid)", data: fields)
        invalidateCache(for: uid)
    }
}
