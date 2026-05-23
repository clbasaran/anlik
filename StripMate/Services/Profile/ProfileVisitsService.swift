import Foundation
import FirebaseFirestore

/// Records lightweight profile visit events into the `profile_visits` collection.
/// The automation engine (admin-side) reads this collection to count unique
/// visitors per profile and trigger "Profil Ziyareti" notifications.
///
/// We never read this data from the client — it's a one-way write feed.
public protocol ProfileVisitsServicing: Sendable {
    func recordVisit(visitorId: String, profileId: String, source: ProfileVisitSource) async
}

public enum ProfileVisitSource: String, Sendable {
    case feed          // strip / history feed entry
    case search        // friend search results
    case deeplink      // universal-link / invite QR / push deep link
    case list          // friends list, leaderboard, suggestion sheets
    case notification  // tap on a notification card

    var raw: String { rawValue }
}

public final class ProfileVisitsService: ProfileVisitsServicing, @unchecked Sendable {
    public static let shared = ProfileVisitsService()

    /// Last write timestamp keyed by `"<visitor>_<profile>"`. Used as an
    /// in-memory throttle so re-opening the same profile within 5 minutes
    /// doesn't burn a Firestore write or pollute the engine's unique-visitor
    /// count.
    private var recentWrites: [String: Date] = [:]
    private let recentWritesLock = NSLock()
    private let throttleWindow: TimeInterval

    /// Resolver for the current set of blocked user ids (visitor → owner of
    /// blocked list). Injected so tests can substitute. Defaults to the live
    /// AuthService cache.
    public var blockedIdsProvider: @Sendable () async -> Set<String>
    /// Reverse-block check — true if the visitor has been blocked BY the
    /// profile owner. Default returns false (we can't read other users'
    /// blocked subcollections client-side); admin / Cloud Functions will
    /// enforce this fully. Tests can flip it.
    public var visitorIsBlockedByProfile: @Sendable (_ visitorId: String, _ profileId: String) async -> Bool

    /// Performs the actual Firestore write. Injected so tests can stub it out
    /// without touching real Firestore. Default writes a doc to `profile_visits`.
    public var writeRecord: @Sendable (_ data: [String: Any]) async -> Bool

    public init(
        throttleWindow: TimeInterval = 5 * 60,
        blockedIdsProvider: @escaping @Sendable () async -> Set<String> = { await AuthService.shared.bestKnownBlockedUserIds() },
        visitorIsBlockedByProfile: @escaping @Sendable (String, String) async -> Bool = { _, _ in false },
        writeRecord: @escaping @Sendable ([String: Any]) async -> Bool = { data in
            do {
                try await Firestore.firestore().collection("profile_visits").addDocument(data: data)
                return true
            } catch {
                return false
            }
        }
    ) {
        self.throttleWindow = throttleWindow
        self.blockedIdsProvider = blockedIdsProvider
        self.visitorIsBlockedByProfile = visitorIsBlockedByProfile
        self.writeRecord = writeRecord
    }

    public func recordVisit(visitorId: String, profileId: String, source: ProfileVisitSource) async {
        // Self-visit is always a no-op — surfacing your own profile shouldn't
        // pollute the visitor list.
        guard visitorId != profileId, !visitorId.isEmpty, !profileId.isEmpty else { return }

        // Skip writes when the visitor has the profile owner blocked OR vice versa.
        let blockedByMe = await blockedIdsProvider()
        if blockedByMe.contains(profileId) { return }
        if await visitorIsBlockedByProfile(visitorId, profileId) { return }

        // 5-minute throttle per (visitor, profile) pair.
        let key = "\(visitorId)_\(profileId)"
        let now = Date()
        recentWritesLock.lock()
        let last = recentWrites[key]
        if let last, now.timeIntervalSince(last) < throttleWindow {
            recentWritesLock.unlock()
            return
        }
        recentWrites[key] = now
        // Opportunistically prune old entries so the dict doesn't grow unbounded.
        if recentWrites.count > 256 {
            let cutoff = now.addingTimeInterval(-throttleWindow)
            recentWrites = recentWrites.filter { $0.value >= cutoff }
        }
        recentWritesLock.unlock()

        let didWrite = await writeRecord([
            "visitorId": visitorId,
            "profileId": profileId,
            "timestamp": FieldValue.serverTimestamp(),
            "source": source.raw
        ])
        if !didWrite {
            // Failure → roll back throttle entry so the next legit visit lands.
            recentWritesLock.lock()
            recentWrites.removeValue(forKey: key)
            recentWritesLock.unlock()
        }
    }
}
