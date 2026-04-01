import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Handles in-app notification CRUD (Firestore notifications collection).
public actor AppNotificationService {
    public static let shared = AppNotificationService()
    
    private var auth: Auth { Auth.auth() }
    private var db: Firestore { Firestore.firestore() }
    
    private init() {}
    
    public nonisolated func listenToNotifications() -> AsyncStream<[AppNotification]> {
        AsyncStream { continuation in
            guard let uid = Auth.auth().currentUser?.uid else {
                continuation.yield([])
                return
            }
            
            let query = Firestore.firestore().collection("notifications")
                .whereField("userId", isEqualTo: uid)
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
            
            let listener = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("DEBUG: Notification listener error: \(error.localizedDescription)")
                    #endif
                    return
                }
                guard let documents = snapshot?.documents else {
                    continuation.yield([])
                    return
                }
                
                let notifications = documents.compactMap { doc -> AppNotification? in
                    let data = doc.data()
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
                continuation.yield(notifications)
            }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    public func markNotificationAsRead(id: String) async {
        do {
            try await db.collection("notifications").document(id).updateData(["isRead": true])
        } catch {
            print("[AppNotificationService] \(error)")
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
            print("[AppNotificationService] \(error)")
        }
    }
}
