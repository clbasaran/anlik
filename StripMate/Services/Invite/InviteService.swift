import Foundation
import FirebaseAuth
import UIKit

/// Handles invite-link redemption from three sources:
/// - Universal Link (https://anlik.web.app/i/<CODE>) → opens app directly with code
/// - Custom URL scheme (stripmate://invite?code=<CODE>) → legacy/in-app share
/// - Clipboard payload "anlik:invite=<CODE>" → deferred deep link (set by the
///   landing page when the app wasn't installed yet)
///
/// On successful redemption, calls the `acceptInvite` Cloud Function which
/// atomically creates a bilateral accepted friendship between the caller and
/// the inviter. Posts a `.inviteAccepted` notification with the inviter's
/// profile preview so the UI can show a welcome toast.
@MainActor
final class InviteService {

    static let shared = InviteService()

    /// Notification posted when an invite has been redeemed successfully.
    /// userInfo: ["displayName": String, "userId": String, "alreadyFriends": Bool]
    static let inviteAcceptedNotification = Notification.Name("InviteService.inviteAccepted")

    /// Tracks redeemed codes for the lifetime of the process so we don't
    /// double-call acceptInvite if the same payload arrives multiple ways
    /// (e.g. universal link AND clipboard).
    private var processedCodes: Set<String> = []

    private let callableURL = "https://europe-west1-stripmate-app.cloudfunctions.net/acceptInvite"

    /// Extract an invite code from a URL — handles both Universal Link and custom scheme.
    /// Returns the uppercased code if the URL is a recognized invite link.
    nonisolated static func extractCode(from url: URL) -> String? {
        // Universal Link: https://anlik.web.app/i/<CODE>
        if url.host == "anlik.web.app" || url.host == "stripmate-app.web.app" {
            let parts = url.path.split(separator: "/").map(String.init)
            if parts.count >= 2, parts[0] == "i" {
                return parts[1].uppercased()
            }
        }
        // Custom scheme: stripmate://invite?code=<CODE> or anlik://invite?code=<CODE>
        if url.scheme == "stripmate" || url.scheme == "anlik" {
            if url.host == "invite" || url.path.contains("invite") {
                if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let code = comps.queryItems?.first(where: { $0.name == "code" })?.value {
                    return code.uppercased()
                }
            }
        }
        return nil
    }

    /// Inspect the system clipboard for a deferred invite payload set by the web
    /// landing page. Returns the code and clears the clipboard entry on success.
    func extractCodeFromClipboard() -> String? {
        let pasteboard = UIPasteboard.general
        // Only read when the pasteboard contains a string (avoids prompting for
        // images, URLs, etc.). Fast path: look for the exact prefix.
        guard pasteboard.hasStrings, let raw = pasteboard.string else { return nil }
        let prefix = "anlik:invite="
        guard raw.hasPrefix(prefix) else { return nil }
        let code = String(raw.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !code.isEmpty, code.count >= 4, code.count <= 16 else { return nil }
        // Clear so the same code doesn't trigger again on next foreground.
        pasteboard.string = ""
        return code
    }

    /// Public entry point. Resolves the invite link to a code (returns true if
    /// it WAS an invite, regardless of accept outcome) and asynchronously
    /// redeems it. Safe to call multiple times — duplicate codes are deduped.
    @discardableResult
    func handleIncoming(url: URL) -> Bool {
        guard let code = Self.extractCode(from: url) else { return false }
        Task { await redeem(code: code) }
        return true
    }

    /// Check the clipboard once and redeem if a deferred invite payload is present.
    func checkClipboardForDeferredInvite() {
        guard let code = extractCodeFromClipboard() else { return }
        Task { await redeem(code: code) }
    }

    /// Call the acceptInvite Cloud Function for a given code. No-op on duplicate.
    func redeem(code: String) async {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty, !processedCodes.contains(normalized) else { return }
        processedCodes.insert(normalized)

        // Auth required — if user isn't signed in yet, defer until they sign in.
        // Caller (StripMateApp) handles the not-authenticated case by re-checking
        // after auth completes.
        guard Auth.auth().currentUser != nil else {
            // Persist the code so we can retry after sign-in.
            UserDefaults.standard.set(normalized, forKey: "pendingInviteCode")
            return
        }

        do {
            let result = try await callAcceptInvite(code: normalized)
            UserDefaults.standard.removeObject(forKey: "pendingInviteCode")

            // Mark friend gate as passed since the user now has at least one friend.
            UserDefaults.standard.set(true, forKey: "hasPassedFriendGate")

            if let inviter = result["inviter"] as? [String: Any] {
                let displayName = inviter["displayName"] as? String ?? ""
                let userId = inviter["userId"] as? String ?? ""
                let alreadyFriends = result["alreadyFriends"] as? Bool ?? false
                NotificationCenter.default.post(
                    name: Self.inviteAcceptedNotification,
                    object: nil,
                    userInfo: [
                        "displayName": displayName,
                        "userId": userId,
                        "alreadyFriends": alreadyFriends
                    ]
                )
                NotificationCenter.default.post(name: .friendListChanged, object: nil)

                // Show a welcome banner so the redeem feels intentional, not magic.
                let title = alreadyFriends
                    ? String(localized: "zaten arkadaşsınız")
                    : String(localized: "arkadaş eklendi")
                let body = displayName.isEmpty
                    ? String(localized: "anlık.'a hoş geldin")
                    : "\(displayName) ile arkadaş oldun"
                NotificationCenter.default.post(
                    name: .showInAppBanner,
                    object: nil,
                    userInfo: [
                        "title": title,
                        "body": body,
                        "icon": "person.crop.circle.badge.plus"
                    ]
                )
            }
        } catch {
            // Allow retry next time — common case is "not-found" for stale codes
            // or "already friends" which will return ok anyway. Removing from
            // processedCodes lets the user try again via a fresh link.
            processedCodes.remove(normalized)
            #if DEBUG
            print("DEBUG: acceptInvite failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Call once after auth completes — picks up any code stashed by the launch
    /// flow before the user was signed in.
    func redeemPendingIfAny() async {
        if let code = UserDefaults.standard.string(forKey: "pendingInviteCode") {
            await redeem(code: code)
        }
    }

    // MARK: - Callable

    private func callAcceptInvite(code: String) async throws -> [String: Any] {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "InviteService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Giriş gerekli"])
        }
        let token = try await user.getIDToken()
        guard let url = URL(string: callableURL) else {
            throw NSError(domain: "InviteService", code: 0)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["data": ["inviteCode": code]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "InviteService", code: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any] else {
            throw NSError(domain: "InviteService", code: 0)
        }
        return result
    }
}
