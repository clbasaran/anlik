import Foundation
import FirebaseFirestore

/// Handles direct messaging between users.
public actor ChatService {
    public static let shared = ChatService()
    
    private var db: Firestore { Firestore.firestore() }
    
    private init() {}
    
    private func getThreadId(user1: String, user2: String) -> String {
        return user1 < user2 ? "\(user1)_\(user2)" : "\(user2)_\(user1)"
    }
    
    public func sendDirectMessage(to receiverId: String, text: String, replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil) async throws {
        guard let profile = await AuthService.shared.currentUserProfile else { throw FirebaseError.unauthenticated }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Word filter check
        if let bannedWord = await AppGuardService.shared.containsBannedWord(text) {
            throw AppError.custom(String(localized: "Mesajınız yasaklı kelime içeriyor: \(bannedWord)"))
        }
        
        let threadId = getThreadId(user1: profile.id, user2: receiverId)
        let messageId = UUID().uuidString
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
        
        try await db.collection("direct_messages").document(threadId)
            .collection("messages").document(messageId)
            .updateData([
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
            print("DEBUG: ⚠️ Failed to set typing status: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Mark all unread messages from partner as read.
    /// NOTE: Privacy check is intentionally on the DISPLAY side (ReadReceiptView),
    /// not here. The receiver ALWAYS writes readAt — otherwise the sender
    /// can never know the message was read.
    public func markMessagesAsRead(partnerId: String) async {
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
            print("[ChatService] ✅ Marked \(unreadDocs.count) messages as read")
            #endif
        } catch {
            #if DEBUG
            print("[ChatService] ❌ markAsRead error: \(error.localizedDescription)")
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
            print("DEBUG: ⚠️ Failed to add reaction: \(error.localizedDescription)")
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
            #if DEBUG
            print("DEBUG: ⚠️ Failed to remove reaction: \(error.localizedDescription)")
            #endif
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
                
                let threadId = await self.getThreadId(user1: profile.id, user2: partnerId)
                // Limit to 50 most recent messages for performance
                let query = Firestore.firestore()
                    .collection("direct_messages").document(threadId).collection("messages")
                    .order(by: "timestamp", descending: false)
                    .limit(toLast: 50)
                
                let listener = query.addSnapshotListener { snapshot, error in
                    if let error = error {
                        #if DEBUG
                        print("DEBUG: Chat listener error: \(error.localizedDescription)")
                        #endif
                        return
                    }
                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }
                    let messages = documents.compactMap { ChatService.parseMessage(from: $0.data()) }
                    continuation.yield(messages)
                }
                
                continuation.onTermination = { @Sendable _ in
                    listener.remove()
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
            print("DEBUG: ⚠️ Failed to load more messages: \(error.localizedDescription)")
            #endif
            return []
        }
    }
    
    // MARK: - Private Helpers
    
    /// Fetch summary data for a single DM thread (last message + unread count).
    public func fetchThreadSummary(partnerId: String) async -> ThreadSummary? {
        guard let profile = await AuthService.shared.currentUserProfile else { return nil }
        let threadId = getThreadId(user1: profile.id, user2: partnerId)

        do {
            // Tek sorguyla son 30 mesaji cek — hem son mesaj hem unread sayisi buradan
            let recentSnapshot = try await db.collection("direct_messages").document(threadId)
                .collection("messages")
                .order(by: "timestamp", descending: true)
                .limit(to: 30)
                .getDocuments()

            guard let lastDoc = recentSnapshot.documents.first else { return nil }
            let lastData = lastDoc.data()
            let lastText = lastData["text"] as? String ?? ""
            let lastSenderId = lastData["senderId"] as? String ?? ""
            let lastTimestamp = (lastData["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            let isDeleted = lastData["isDeleted"] as? Bool ?? false

            // Son 30 mesaj icinden okunmamislari say
            let unreadCount = recentSnapshot.documents.filter { doc in
                let data = doc.data()
                let fromPartner = (data["senderId"] as? String) == partnerId
                let isForMe = (data["receiverId"] as? String) == profile.id
                let isUnread = data["readAt"] == nil || data["readAt"] is NSNull
                return fromPartner && isForMe && isUnread
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
            print("DEBUG: ⚠️ Failed to fetch thread summary for \(partnerId): \(error.localizedDescription)")
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
