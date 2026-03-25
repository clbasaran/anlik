import Foundation
import FirebaseFirestore
import FirebaseAuth

@Observable
final class SupportChatViewModel {

    // MARK: - Properties

    var messages: [SupportMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Listener

    func listenToMessages() {
        guard let uid = currentUserId else { return }
        isLoading = true

        listener = db
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

        try? await docRef.setData(payload)
    }

    // MARK: - Cleanup

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
