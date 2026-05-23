import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Handles in-app notification CRUD (Firestore notifications collection).
public actor AppNotificationService {
    public static let shared = AppNotificationService()
    
    private var auth: Auth { Auth.auth() }
    private var db: Firestore { Firestore.firestore() }

    /// Active Firestore listeners, keyed for dedup (one per stream key) +
    /// drained on logout. Keys are like "notifications:<uid>".
    private var activeListeners: [String: ListenerRegistration] = [:]

    func registerListener(_ reg: ListenerRegistration, key: String) {
        activeListeners[key]?.remove()
        activeListeners[key] = reg
    }

    func unregisterListener(key: String) {
        activeListeners[key]?.remove()
        activeListeners[key] = nil
    }

    public func stopAllListeners() {
        activeListeners.values.forEach { $0.remove() }
        activeListeners.removeAll()
    }

    private init() {}
    
    public nonisolated func listenToNotifications() -> AsyncStream<[AppNotification]> {
        AsyncStream { continuation in
            guard let uid = Auth.auth().currentUser?.uid else {
                continuation.yield([])
                return
            }

            // Hot inbox window — most recent 100 notifications stream live.
            // Older notifications are fetched on-demand via loadOlderNotifications
            // and merged into the consumer's list.
            let query = Firestore.firestore().collection("notifications")
                .whereField("userId", isEqualTo: uid)
                .order(by: "timestamp", descending: true)
                .limit(to: 100)

            let listener = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    AppLogger.service.error("notification listener error: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let documents = snapshot?.documents else {
                    continuation.yield([])
                    return
                }

                let notifications = documents.compactMap { Self.parse($0.data()) }
                continuation.yield(notifications)
            }

            let listenerKey = "notifications:\(uid)"
            Task { await AppNotificationService.shared.registerListener(listener, key: listenerKey) }

            continuation.onTermination = { _ in
                listener.remove()
                Task { await AppNotificationService.shared.unregisterListener(key: listenerKey) }
            }
        }
    }

    /// Cursor-based pagination for older notifications. Pass the timestamp of
    /// the oldest notification currently rendered; we return up to `pageSize`
    /// older entries. Returns an empty array when there are no more.
    public func loadOlderNotifications(before timestamp: Date, pageSize: Int = 50) async -> [AppNotification] {
        guard let uid = auth.currentUser?.uid else { return [] }
        do {
            let snapshot = try await db.collection("notifications")
                .whereField("userId", isEqualTo: uid)
                .order(by: "timestamp", descending: true)
                .whereField("timestamp", isLessThan: Timestamp(date: timestamp))
                .limit(to: pageSize)
                .getDocuments()
            return snapshot.documents.compactMap { Self.parse($0.data()) }
        } catch {
            AppLogger.service.error("loadOlderNotifications failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Single point of truth for parsing the Firestore document into our
    /// struct — the listener and the paginator must produce identical
    /// AppNotification values, otherwise the merged list flickers as the
    /// shapes diverge.
    private static func parse(_ data: [String: Any]) -> AppNotification? {
        guard let id = data["id"] as? String,
              let userId = data["userId"] as? String,
              let senderId = data["senderId"] as? String,
              let senderName = data["senderName"] as? String,
              let typeString = data["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else { return nil }

        return AppNotification(
            id: id,
            userId: userId,
            senderId: senderId,
            senderName: senderName,
            type: type,
            relatedId: data["relatedId"] as? String,
            thumbnailUrl: data["thumbnailUrl"] as? String,
            timestamp: timestamp,
            isRead: data["isRead"] as? Bool ?? false
        )
    }

    public func markNotificationAsRead(id: String) async {
        do {
            try await db.collection("notifications").document(id).updateData(["isRead": true])
        } catch {
            AppLogger.service.error("markAsRead failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    public func sendInAppNotification(to userId: String, type: NotificationType, relatedId: String?, thumbnailUrl: String?) async {
        guard let profile = await AuthService.shared.currentUserProfile else { return }
        guard userId != profile.id else { return }
        
        let id = UUID().uuidString
        let data: [String: Any] = [
            "id": id,
            "userId": userId,
            "senderId": profile.id,
            "senderName": profile.displayName ?? profile.username ?? String(localized: "Birisi"),
            "type": type.rawValue,
            "relatedId": relatedId as Any,
            "thumbnailUrl": thumbnailUrl as Any,
            "timestamp": FieldValue.serverTimestamp(),
            "isRead": false
        ]
        
        do {
            try await db.collection("notifications").document(id).setData(data)
        } catch {
            AppLogger.service.error("[AppNotificationService] \(String(describing: error), privacy: .public)")
        }
    }
}
