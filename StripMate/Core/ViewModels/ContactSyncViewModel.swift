import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@Observable
final class ContactSyncViewModel {

    let service = ContactSyncService()

    // Friend request sending
    private(set) var sentRequestIds: Set<String> = []
    private(set) var sendingRequestFor: String? = nil

    var isSyncing: Bool {
        if case .loading = service.state { return true }
        if case .requestingPermission = service.state { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let msg) = service.state { return msg }
        return nil
    }

    func startSync() {
        Task { await service.requestAndSync() }
    }

    func sendFriendRequest(to userId: String) async {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        sendingRequestFor = userId
        defer { sendingRequestFor = nil }

        do {
            let db = Firestore.firestore()
            // Write friend request (same pattern as existing app)
            try await db.collection("friend_requests").addDocument(data: [
                "senderId": currentUid,
                "receiverId": userId,
                "status": "pending",
                "createdAt": FieldValue.serverTimestamp()
            ])
            sentRequestIds.insert(userId)
        } catch {
            // Silently fail — UI can show retry
        }
    }

    func sendSMSInvite(to contact: ContactSyncService.UnmatchedContact) {
        let appLink = "https://apps.apple.com/us/app/anl%C4%B1k/id6759793761"
        let message = "anlik.'i dene! \(appLink)"
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let number = contact.phoneNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "sms:\(number)&body=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
