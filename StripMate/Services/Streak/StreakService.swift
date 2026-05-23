import Foundation
import FirebaseFirestore

/// Manages streak data between the current user and their friends.
/// Listens to Firestore `streaks` collection and provides real-time streak info.
public actor StreakService {
    public static let shared = StreakService()
    private let db = Firestore.firestore()
    
    /// Cached streaks keyed by friendId (not streakId)
    private var streakCache: [String: Streak] = [:]
    private var listener: ListenerRegistration?
    private var currentListeningUserId: String?
    
    /// Callback fired whenever streak cache is updated from Firestore snapshot
    private var onStreakUpdate: (() -> Void)?
    
    /// Continuations waiting for the first snapshot
    private var firstSnapshotContinuations: [CheckedContinuation<Void, Never>] = []
    private var hasReceivedFirstSnapshot = false
    
    private init() {}
    
    // MARK: - Real-time Listener
    
    /// Register a callback to be notified when streaks are updated from Firestore
    public func setOnUpdate(_ callback: @escaping () -> Void) {
        self.onStreakUpdate = callback
    }
    
    /// Start listening to all streaks for the current user
    public func startListening(for userId: String) {
        // Don't restart if already listening for the same user
        if currentListeningUserId == userId, listener != nil {
            return
        }
        
        stopListening()
        currentListeningUserId = userId
        hasReceivedFirstSnapshot = false
        
        let query = db.collection("streaks")
            .whereField("userIds", arrayContains: userId)
        
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                AppLogger.service.error("streak listener error: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let self, let documents = snapshot?.documents else { return }
            Task { await self.handleSnapshot(documents, currentUserId: userId) }
        }
    }
    
    /// Stop listening and clean up all state (call on logout)
    public func stopListening() {
        listener?.remove()
        listener = nil
        currentListeningUserId = nil
        streakCache.removeAll()
        onStreakUpdate = nil
        hasReceivedFirstSnapshot = false
        let continuations = firstSnapshotContinuations
        firstSnapshotContinuations.removeAll()
        for c in continuations { c.resume() }
    }
    
    /// Wait for the first Firestore snapshot to arrive. Returns immediately if already received.
    public func waitForFirstSnapshot() async {
        if hasReceivedFirstSnapshot { return }
        await withCheckedContinuation { continuation in
            firstSnapshotContinuations.append(continuation)
        }
    }
    
    private func handleSnapshot(_ documents: [QueryDocumentSnapshot], currentUserId: String) {
        // Guard against stale callbacks arriving after stopListening()
        guard currentListeningUserId == currentUserId else { return }

        var newCache: [String: Streak] = [:]
        for doc in documents {
            if let streak = parseStreak(from: doc) {
                let friendId = streak.userIds.first(where: { $0 != currentUserId }) ?? ""
                if !friendId.isEmpty {
                    newCache[friendId] = streak
                }
            }
        }
        self.streakCache = newCache
        
        // Notify waiting continuations (first snapshot)
        if !hasReceivedFirstSnapshot {
            hasReceivedFirstSnapshot = true
            let continuations = firstSnapshotContinuations
            firstSnapshotContinuations.removeAll()
            for continuation in continuations {
                continuation.resume()
            }
        }
        
        // Notify callback listeners
        onStreakUpdate?()
        
        // Push streak updates to Apple Watch
        let watchStreaks: [WatchStreak] = streakCache.map { (friendId, streak) in
            WatchStreak(
                id: streak.id,
                friendId: friendId,
                friendName: "",
                friendAvatarUrl: nil,
                currentStreak: streak.currentStreak,
                longestStreak: streak.longestStreak,
                totalExchanges: streak.totalExchanges,
                lastExchangeDate: streak.lastExchangeDate,
                lastSenderId: streak.lastSenderId,
                friendshipScore: streak.friendshipScore
            )
        }
        WatchSessionManager.shared.sendStreakUpdate(watchStreaks)
    }
    
    // MARK: - Queries
    
    /// Get the streak with a specific friend
    public func streak(with friendId: String) -> Streak? {
        streakCache[friendId]
    }
    
    /// Get all active streaks (currentStreak > 0)
    public func activeStreaks() -> [Streak] {
        streakCache.values.filter { $0.currentStreak > 0 }.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    /// Get all streaks sorted by friendship score
    public func allStreaksByScore() -> [(friendId: String, streak: Streak)] {
        streakCache.map { ($0.key, $0.value) }
            .sorted { $0.streak.friendshipScore > $1.streak.friendshipScore }
    }
    
    // NOTE: Streak updates are handled exclusively by the `onNewStrip` Cloud Function
    // (server-side) to prevent double-writes and score manipulation.
    // See functions/index.js → onNewStrip for the authoritative streak logic.
    
    // MARK: - Parsing
    
    private nonisolated func parseStreak(from doc: QueryDocumentSnapshot) -> Streak? {
        let data = doc.data()
        guard let id = data["id"] as? String,
              let userIds = data["userIds"] as? [String] else { return nil }

        let lastDate = (data["lastExchangeDate"] as? Timestamp)?.dateValue() ?? Date()
        let frozenUntil = (data["frozenUntil"] as? Timestamp)?.dateValue()

        return Streak(
            id: id,
            userIds: userIds,
            currentStreak: data["currentStreak"] as? Int ?? 0,
            longestStreak: data["longestStreak"] as? Int ?? 0,
            totalExchanges: data["totalExchanges"] as? Int ?? 0,
            lastExchangeDate: lastDate,
            lastSenderId: data["lastSenderId"] as? String ?? "",
            friendshipScore: data["friendshipScore"] as? Int ?? 0,
            freezeUsedThisWeek: data["freezeUsedThisWeek"] as? Bool ?? false,
            frozenUntil: frozenUntil
        )
    }

    /// Apply a manual freeze to a streak — extends `frozenUntil` 48h forward
    /// and marks `freezeUsedThisWeek=true` so the user can't double-freeze
    /// in the same week. Only allowed when canFreezeNow is true.
    public func freezeStreak(streakId: String) async throws {
        let until = Date().addingTimeInterval(48 * 3600)
        try await Firestore.firestore().collection("streaks").document(streakId)
            .setData([
                "freezeUsedThisWeek": true,
                "frozenUntil": Timestamp(date: until)
            ], merge: true)
    }
}
