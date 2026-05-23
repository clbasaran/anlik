import Foundation
import UIKit

/// Translates notification payloads into either a deep-link URL (for taps) or
/// an outgoing message send (for inline replies). Lives apart from
/// `AppDelegate` so the routing rules are testable in isolation and so the
/// delegate stays focused on UNUserNotificationCenter plumbing.
public enum NotificationRouter {

    // MARK: - Inline reply

    /// Sends a message in response to an inline reply from the lock screen.
    /// Returns `false` and logs the reason when the payload is malformed; the
    /// caller is expected to honour the original completionHandler regardless.
    @discardableResult
    public static func handleInlineReply(text: String, userInfo: [AnyHashable: Any]) async -> Bool {
        let type = userInfo["type"] as? String ?? ""

        do {
            switch type {
            case "new_strip", "new_strip_chat", "new_comment":
                let stripId = userInfo["stripId"] as? String ?? ""
                let senderId = userInfo["senderId"] as? String ?? ""
                guard isValidId(stripId), isValidId(senderId) else {
                    AppLogger.push.error("inline reply rejected: invalid ids type=\(type, privacy: .public)")
                    return false
                }
                try await PhotoService.shared.sendStripChatMessage(
                    text: text,
                    stripId: stripId,
                    chatPartnerId: senderId
                )
                return true

            case "direct_message":
                let senderId = userInfo["senderId"] as? String ?? ""
                guard isValidId(senderId) else {
                    AppLogger.push.error("inline reply rejected: invalid sender id")
                    return false
                }
                try await ChatService.shared.sendDirectMessage(
                    to: senderId,
                    text: text
                )
                return true

            default:
                return false
            }
        } catch {
            AppLogger.push.error("inline reply send failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Deep link

    /// Converts a notification payload into a `stripmate://` URL for the
    /// relevant screen, or nil if the payload doesn't map to one.
    public static func deepLink(for userInfo: [AnyHashable: Any]) -> URL? {
        let type = userInfo["type"] as? String ?? ""

        switch type {
        case "new_strip", "new_comment":
            if let stripId = userInfo["stripId"] as? String, !stripId.isEmpty {
                return URL(string: "stripmate://chat/\(stripId)")
            }
        case "new_strip_chat":
            if let stripId = userInfo["stripId"] as? String, !stripId.isEmpty {
                let receiverId = userInfo["receiverId"] as? String ?? ""
                return URL(string: "stripmate://chat/\(stripId)/\(receiverId)")
            }
        case "direct_message":
            if let threadId = userInfo["threadId"] as? String, !threadId.isEmpty {
                return URL(string: "stripmate://dm/\(threadId)")
            }
        case "friend_request":
            return URL(string: "stripmate://inbox")
        case "weekly_summary":
            let week = userInfo["weekNumber"] as? String ?? ""
            let yr = userInfo["year"] as? String ?? ""
            if !week.isEmpty, !yr.isEmpty {
                return URL(string: "stripmate://recap/\(yr)/\(week)")
            } else {
                return URL(string: "stripmate://history")
            }
        default:
            return nil
        }
        return nil
    }

    // MARK: - Validation

    /// Firestore document ids are alphanumeric with optional underscores or
    /// hyphens, comfortably under 128 characters. A push payload should never
    /// be able to direct an authenticated action through anything else — this
    /// is the same allowlist applied to inline reply ids.
    static func isValidId(_ id: String) -> Bool {
        !id.isEmpty
            && id.count <= 128
            && id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }
}
