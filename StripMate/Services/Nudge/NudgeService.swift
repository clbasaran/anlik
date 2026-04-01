import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Service for sending nudges (dürtme) to friends.
/// Max 3 nudges per day per friend pair.
actor NudgeService {
    static let shared = NudgeService()
    private let db = Firestore.firestore()

    /// Send a nudge to a friend. Creates a document under the receiver's nudges subcollection.
    func sendNudge(to friendId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirebaseError.unauthenticated
        }

        let nudgeRef = db.collection("users").document(friendId).collection("nudges").document()
        try await nudgeRef.setData([
            "id": nudgeRef.documentID,
            "senderId": uid,
            "receiverId": friendId,
            "timestamp": FieldValue.serverTimestamp()
        ])
    }

    /// Returns how many nudges remain today for the current user toward a specific friend (max 3).
    func nudgesRemainingToday(for friendId: String) async -> Int {
        guard let uid = Auth.auth().currentUser?.uid else { return 0 }

        let startOfDay = Calendar.current.startOfDay(for: Date())

        do {
            let snapshot = try await db.collection("users")
                .document(friendId)
                .collection("nudges")
                .whereField("senderId", isEqualTo: uid)
                .whereField("timestamp", isGreaterThan: Timestamp(date: startOfDay))
                .getDocuments()
            return max(0, 3 - snapshot.count)
        } catch {
            #if DEBUG
            print("DEBUG: nudgesRemainingToday query failed: \(error.localizedDescription)")
            #endif
            return 3 // Default to allowing nudges when query fails
        }
    }
}
