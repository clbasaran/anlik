import Foundation
import FirebaseFirestore

/// Handles direct messaging between users.
public actor ChatService {
    public static let shared = ChatService()
    
    private var db: Firestore { Firestore.firestore() }

    /// Active Firestore listeners, keyed so we can deduplicate when the same
    /// logical stream is requested twice (e.g. rapid view re-appear) and
    /// drain everything on logout. Keys are like "dm:<partnerId>".
    private var activeListeners: [String: ListenerRegistration] = [:]

    /// Registers a listener under a key. If a listener already exists for
    /// the key it is removed first — guarantees one live listener per
    /// (channel) at any time.
    func registerListener(_ reg: ListenerRegistration, key: String) {
        activeListeners[key]?.remove()
        activeListeners[key] = reg
    }

    /// Idempotent — safe to call when no listener exists for the key.
    func unregisterListener(key: String) {
        activeListeners[key]?.remove()
        activeListeners[key] = nil
    }

    public func stopAllListeners() {
        activeListeners.values.forEach { $0.remove() }
        activeListeners.removeAll()
    }

    private init() {}
    
    private func getThreadId(user1: String, user2: String) -> String {
        return user1 < user2 ? "\(user1)_\(user2)" : "\(user2)_\(user1)"
    }
    
    public func sendDirectMessage(to receiverId: String, text: String, clientId: String? = nil, replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil) async throws {
        CrashReporter.shared.breadcrumb(.dm, "sendDirectMessage len=\(text.count) reply=\(replyToId != nil)")
        guard let profile = await AuthService.shared.currentUserProfile else { throw FirebaseError.unauthenticated }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Word filter check
        if let bannedWord = await AppGuardService.shared.containsBannedWord(text) {
            throw AppError.custom(String(localized: "Mesajınız yasaklı kelime içeriyor: \(bannedWord)"))
        }

        let threadId = getThreadId(user1: profile.id, user2: receiverId)
        // If the caller already showed the message optimistically with a
        // generated id, reuse that id on the server document so the listener
        // can match server → optimistic and replace cleanly.
        let messageId = clientId ?? UUID().uuidString
        let messageRef = db.collection("direct_messages").document(threadId).collection("messages").document(messageId)

        var documentData: [String: Any] = [
            "id": messageId,
            "senderId": profile.id,
            "receiverId": receiverId,
            "text": text,
            "timestamp": FieldValue.serverTimestamp()
        ]

        if let replyToId = replyToId { documentData["replyToId"] = replyToId }
        if let replyToText = replyToText { documentData["replyToText"] = replyToText }
        if let replyToSenderId = replyToSenderId { documentData["replyToSenderId"] = replyToSenderId }

        try await messageRef.setData(documentData)
    }
    
    /// Soft-delete own message
    public func deleteMessage(messageId: String, partnerId: String) async throws {
        guard let profile = await AuthService.shared.currentUserProfile else { throw FirebaseError.unauthenticated }
        let threadId = getThreadId(user1: profile.id, user2: partnerId)

        let messageRef = db.collection("direct_messages").document(threadId)
            .collection("messages").document(messageId)

        // Verify the current user is the sender before allowing deletion
        let messageDoc = try await messageRef.getDocument()
        guard let messageData = messageDoc.data(),
              let senderId = messageData["senderId"] as? String,
              senderId == profile.id else {
            throw AppError.custom(String(localized: "Sadece kendi mesajlarınızı silebilirsiniz."))
        }

        try await messageRef.updateData([
                "isDeleted": true,
                "text": String(localized: "bu mesaj silindi")
            ])
    }
    
    /// Set typing status in a thread
    public func setTyping(partnerId: String, isTyping: Bool) async {
        guard let profile = await AuthService.shared.currentUserProfile else { return }
        let threadId = getThreadId(user1: profile.id, user2: partnerId)
        let typingRef = db.collection("direct_messages").document(threadId)
        
        do {
            try await typingRef.setData([
                "typing_\(profile.id)": isTyping,
                "typing_\(profile.id)_at": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            #if DEBUG
 print("DEBUG: Failed to set typing status: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Mark all unread messages from partner as read.
    /// Respects the user's "hide read receipts" privacy setting — when enabled,
    /// readAt is NOT written to Firestore to enforce the setting server-side.
    public func markMessagesAsRead(partnerId: String) async {
        // Check privacy setting: if user has hidden read receipts, skip writing readAt.
        // UserDefaults is thread-safe, so no MainActor hop needed.
        let hideReadReceipts = UserDefaults.standard.bool(forKey: "privacy_hide_read_receipts")
        if hideReadReceipts {
            #if DEBUG
            print("[ChatService] Read receipts hidden — skipping readAt write")
            #endif
            return
        }

        guard let profile = await AuthService.shared.currentUserProfile else {
            #if DEBUG
            print("[ChatService] markAsRead failed: no current user")
            #endif
            return
        }
        let threadId = getThreadId(user1: profile.id, user2: partnerId)
        
        do {
            // Single-field query to avoid composite index requirement.
            // Filter receiverId in memory. Limit to recent 100 messages for performance.
            let snapshot = try await db.collection("direct_messages").document(threadId)
                .collection("messages")
                .whereField("senderId", isEqualTo: partnerId)
                .order(by: "timestamp", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            let unreadDocs = snapshot.documents.filter { doc in
                let data = doc.data()
                let isForMe = (data["receiverId"] as? String) == profile.id
                let isUnread = data["readAt"] == nil || data["readAt"] is NSNull
                return isForMe && isUnread
            }
            
            guard !unreadDocs.isEmpty else { return }
            
            let batch = db.batch()
            for doc in unreadDocs {
                batch.updateData(["readAt": FieldValue.serverTimestamp()], forDocument: doc.reference)
            }
            try await batch.commit()
            #if DEBUG
 print("[ChatService] Marked \(unreadDocs.count) messages as read")
            #endif
        } catch {
            #if DEBUG
 print("[ChatService] markAsRead error: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Add emoji reaction to a message
    public func addReaction(threadId: String, messageId: String, emoji: String) async {
        guard let profile = await AuthService.shared.currentUserProfile else { return }
        let ref = db.collection("direct_messages").document(threadId)
            .collection("messages").document(messageId)
        do {
            try await ref.updateData(["reactions.\(profile.id)": emoji])
        } catch {
            #if DEBUG
 print("DEBUG: Failed to add reaction: \(error.localizedDescription)")
            #endif
        }
    }

    /// Remove emoji reaction from a message
    public func removeReaction(threadId: String, messageId: String) async {
        guard let profile = await AuthService.shared.currentUserProfile else { return }
        let ref = db.collection("direct_messages").document(threadId)
            .collection("messages").document(messageId)
        do {
            try await ref.updateData(["reactions.\(profile.id)": FieldValue.delete()])
        } catch {
            AppLogger.service.error("DM reaction remove failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Listen to the most recent 50 messages in a DM thread (real-time).
    public nonisolated func listenToDirectMessages(with partnerId: String) -> AsyncStream<[DirectMessage]> {
        AsyncStream { continuation in
            Task {
                guard let profile = await AuthService.shared.currentUserProfile else {
                    continuation.yield([])
                    return
                }

                // Block check: a DM thread is between exactly two users, so if
                // the partner is in our blocked set we never wire up the Firestore
                // listener at all. Yield empty and finish — the chat surface
                // shouldn't have been navigable in the first place, but this is
                // defense-in-depth in case the UI guard is bypassed.
                let blockedIds = await AuthService.shared.bestKnownBlockedUserIds()
                if blockedIds.contains(partnerId) {
                    continuation.yield([])
                    continuation.finish()
                    return
                }

                let threadId = await self.getThreadId(user1: profile.id, user2: partnerId)
                // Limit to 50 most recent messages for performance
                let query = Firestore.firestore()
                    .collection("direct_messages").document(threadId).collection("messages")
                    .order(by: "timestamp", descending: false)
                    .limit(toLast: 50)

                let listener = query.addSnapshotListener { snapshot, error in
                    if let error = error {
                        AppLogger.service.error("DM listener error: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }
                    let messages = documents.compactMap { ChatService.parseMessage(from: $0.data()) }
                    continuation.yield(messages)
                }

                let listenerKey = "dm:\(partnerId)"
                await ChatService.shared.registerListener(listener, key: listenerKey)

                continuation.onTermination = { @Sendable _ in
                    listener.remove()
                    Task { await ChatService.shared.unregisterListener(key: listenerKey) }
                }
            }
        }
    }
    
    /// Load older messages before a given timestamp (cursor-based pagination).
    public func loadMoreMessages(partnerId: String, before timestamp: Date) async -> [DirectMessage] {
        guard let profile = await AuthService.shared.currentUserProfile else { return [] }
        let threadId = getThreadId(user1: profile.id, user2: partnerId)

        do {
            let snapshot = try await db.collection("direct_messages").document(threadId)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .whereField("timestamp", isLessThan: Timestamp(date: timestamp))
                .limit(to: 30)
                .getDocuments()
            let messages = snapshot.documents.compactMap { ChatService.parseMessage(from: $0.data()) }
            return messages.reversed()
        } catch {
            #if DEBUG
 print("DEBUG: Failed to load more messages: \(error.localizedDescription)")
            #endif
            return []
        }
    }
    
    // MARK: - Private Helpers
    
    /// Fetch summary data for a single DM thread (last message + unread count).
    /// Optimized: fetches only the latest message (1 query) + a separate lightweight unread count query.
    public func fetchThreadSummary(partnerId: String) async -> ThreadSummary? {
        guard let profile = await AuthService.shared.currentUserProfile else { return nil }
        let threadId = getThreadId(user1: profile.id, user2: partnerId)
        let threadRef = db.collection("direct_messages").document(threadId).collection("messages")

        do {
            // Query 1: fetch only the latest message
            let lastSnapshot = try await threadRef
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .getDocuments()

            guard let lastDoc = lastSnapshot.documents.first else { return nil }
            let lastData = lastDoc.data()
            let lastText = lastData["text"] as? String ?? ""
            let lastSenderId = lastData["senderId"] as? String ?? ""
            let lastTimestamp = (lastData["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let isDeleted = lastData["isDeleted"] as? Bool ?? false

            // Query 2: count unread messages from partner (lightweight)
            let unreadSnapshot = try await threadRef
                .whereField("senderId", isEqualTo: partnerId)
                .whereField("receiverId", isEqualTo: profile.id)
                .order(by: "timestamp", descending: true)
                .limit(to: 30)
                .getDocuments()

            let unreadCount = unreadSnapshot.documents.filter { doc in
                let data = doc.data()
                return data["readAt"] == nil || data["readAt"] is NSNull
            }.count

            return ThreadSummary(
                partnerId: partnerId,
                lastMessage: isDeleted ? "bu mesaj silindi" : lastText,
                lastMessageSenderId: lastSenderId,
                lastMessageTimestamp: lastTimestamp,
                unreadCount: unreadCount
            )
        } catch {
            #if DEBUG
 print("DEBUG: Failed to fetch thread summary for \(partnerId): \(error.localizedDescription)")
            #endif
            return nil
        }
    }
    
    private static func parseMessage(from data: [String: Any]) -> DirectMessage? {
        guard let id = data["id"] as? String,
              let senderId = data["senderId"] as? String,
              let receiverId = data["receiverId"] as? String,
              let text = data["text"] as? String else { return nil }
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        let readAt = (data["readAt"] as? Timestamp)?.dateValue()
        let reactions = data["reactions"] as? [String: String]
        let isDeleted = data["isDeleted"] as? Bool
        return DirectMessage(
            id: id, senderId: senderId, receiverId: receiverId, text: text, timestamp: timestamp,
            replyToId: data["replyToId"] as? String,
            replyToText: data["replyToText"] as? String,
            replyToSenderId: data["replyToSenderId"] as? String,
            reactions: reactions,
            readAt: readAt,
            isDeleted: isDeleted
        )
    }
}
