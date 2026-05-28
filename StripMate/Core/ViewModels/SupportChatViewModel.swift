import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor @Observable
final class SupportChatViewModel {

    // MARK: - Properties

    var messages: [SupportMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false

    /// Stored in an `IsolatedRef` so the nonisolated `deinit` can remove the
    /// Firestore listener without `nonisolated(unsafe)`.
    private let listener = IsolatedRef<ListenerRegistration?>(nil)
    private let db = Firestore.firestore()

    deinit {
        listener.value?.remove()
    }

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Listener

    func listenToMessages() {
        guard let uid = currentUserId else { return }
        isLoading = true

        listener.value = db
            .collection("support_chats")
            .document(uid)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                guard let documents = snapshot?.documents else { return }
                self.messages = documents.compactMap { doc in
                    let data = doc.data()
                    guard let senderId = data["senderId"] as? String,
                          let text = data["text"] as? String,
                          let ts = data["timestamp"] as? Timestamp,
                          let isAdmin = data["isAdmin"] as? Bool else { return nil }

                    let readAt = (data["readAt"] as? Timestamp)?.dateValue()

                    return SupportMessage(
                        id: doc.documentID,
                        senderId: senderId,
                        text: text,
                        timestamp: ts.dateValue(),
                        isAdmin: isAdmin,
                        readAt: readAt
                    )
                }
            }
    }

    // MARK: - Send

    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let uid = currentUserId else { return }

        let text = trimmed
        inputText = ""

        let docRef = db
            .collection("support_chats")
            .document(uid)
            .collection("messages")
            .document()

        let payload: [String: Any] = [
            "senderId": uid,
            "text": text,
            "timestamp": FieldValue.serverTimestamp(),
            "isAdmin": false
        ]

        // Parent dokümanı oluştur (yoksa) — admin app thread'i bulabilsin
        let parentRef = db.collection("support_chats").document(uid)
        do {
            try await parentRef.setData(["createdAt": FieldValue.serverTimestamp(), "userId": uid], merge: true)
        } catch {
            AppLogger.service.debug("\(error)")
        }

        do {
            try await docRef.setData(payload)
        } catch {
            AppLogger.service.debug("\(error)")
        }
    }

    // MARK: - Cleanup

    func stopListening() {
        listener.value?.remove()
        listener.value = nil
    }
}
