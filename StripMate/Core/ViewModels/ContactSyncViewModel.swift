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

    /// Cached invite code so sendSMSInvite can build a personalized link without
    /// hopping into the AuthService actor on every share tap.
    private(set) var myInviteCode: String = ""

    /// Populates `myInviteCode` from the current user's profile. Call from a Task.
    func loadMyInviteCode() async {
        if let code = await AuthService.shared.currentUserProfile?.inviteCode {
            myInviteCode = code
        }
    }

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
        Task {
            await loadMyInviteCode()
            await service.requestAndSync()
        }
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
        // Use a personalized invite link if we know the user's invite code —
        // recipients who tap it will auto-friend on first launch via
        // InviteService (universal link OR clipboard-deferred fallback).
        let code = myInviteCode
        let link = code.isEmpty ? "https://anlik.web.app" : "https://anlik.web.app/i/\(code)"
        let message = "anlık.'a gel: \(link)"
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let number = contact.phoneNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "sms:\(number)&body=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
