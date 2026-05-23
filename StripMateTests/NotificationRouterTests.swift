import Testing
import Foundation
@testable import StripMate

/// Routing rules are pure functions over the push payload — exactly what we
/// want covered with fast unit tests. A regression here breaks deep links and
/// inline replies for every push the user receives, which is hard to catch
/// from UI tests because it requires real APNs delivery.
@Suite("NotificationRouter")
struct NotificationRouterTests {

    // MARK: - Deep link routing

    @Test("strip notification deep links to chat")
    func newStripDeepLink() {
        let url = NotificationRouter.deepLink(for: ["type": "new_strip", "stripId": "abc123"])
        #expect(url?.absoluteString == "stripmate://chat/abc123")
    }

    @Test("comment notification deep links to chat")
    func newCommentDeepLink() {
        let url = NotificationRouter.deepLink(for: ["type": "new_comment", "stripId": "xyz789"])
        #expect(url?.absoluteString == "stripmate://chat/xyz789")
    }

    @Test("strip chat deep links include receiverId")
    func newStripChatDeepLink() {
        let url = NotificationRouter.deepLink(for: [
            "type": "new_strip_chat",
            "stripId": "s1",
            "receiverId": "u2"
        ])
        #expect(url?.absoluteString == "stripmate://chat/s1/u2")
    }

    @Test("direct message deep links to dm thread")
    func directMessageDeepLink() {
        let url = NotificationRouter.deepLink(for: [
            "type": "direct_message",
            "threadId": "t_xyz"
        ])
        #expect(url?.absoluteString == "stripmate://dm/t_xyz")
    }

    @Test("friend request deep links to inbox")
    func friendRequestDeepLink() {
        let url = NotificationRouter.deepLink(for: ["type": "friend_request"])
        #expect(url?.absoluteString == "stripmate://inbox")
    }

    @Test("weekly summary deep links to recap")
    func weeklySummaryDeepLink() {
        let url = NotificationRouter.deepLink(for: [
            "type": "weekly_summary",
            "weekNumber": "12",
            "year": "2026"
        ])
        #expect(url?.absoluteString == "stripmate://recap/2026/12")
    }

    @Test("weekly summary without dates falls back to history")
    func weeklySummaryFallback() {
        let url = NotificationRouter.deepLink(for: ["type": "weekly_summary"])
        #expect(url?.absoluteString == "stripmate://history")
    }

    @Test("unknown payload type yields no link")
    func unknownTypeIsNil() {
        let url = NotificationRouter.deepLink(for: ["type": "made_up_event"])
        #expect(url == nil)
    }

    @Test("missing stripId yields no link")
    func missingStripIdIsNil() {
        let url = NotificationRouter.deepLink(for: ["type": "new_strip"])
        #expect(url == nil)
    }

    @Test("empty stripId yields no link")
    func emptyStripIdIsNil() {
        let url = NotificationRouter.deepLink(for: ["type": "new_strip", "stripId": ""])
        #expect(url == nil)
    }

    // MARK: - ID validation

    @Test("valid alphanumeric id passes")
    func validIdPasses() {
        #expect(NotificationRouter.isValidId("abc123XYZ"))
    }

    @Test("id with hyphens and underscores passes")
    func validIdWithSeparators() {
        #expect(NotificationRouter.isValidId("user_id-12_3"))
    }

    @Test("empty id fails")
    func emptyIdFails() {
        #expect(!NotificationRouter.isValidId(""))
    }

    @Test("id over 128 chars fails")
    func tooLongIdFails() {
        let long = String(repeating: "a", count: 129)
        #expect(!NotificationRouter.isValidId(long))
    }

    @Test("id with path traversal fails")
    func pathTraversalIdFails() {
        #expect(!NotificationRouter.isValidId("../../etc/passwd"))
    }

    @Test("id with special chars fails")
    func specialCharsIdFails() {
        #expect(!NotificationRouter.isValidId("abc@def"))
        #expect(!NotificationRouter.isValidId("abc def"))
        #expect(!NotificationRouter.isValidId("abc/def"))
        #expect(!NotificationRouter.isValidId("abc.def"))
    }

    @Test("id at exactly 128 chars passes")
    func boundaryLengthPasses() {
        let edge = String(repeating: "x", count: 128)
        #expect(NotificationRouter.isValidId(edge))
    }
}
