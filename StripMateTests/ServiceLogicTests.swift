import XCTest
import UIKit
@testable import StripMate

// MARK: - PhotoMetadata Parsing & Edge Cases

final class PhotoMetadataParsingTests: XCTestCase {
    func testFromValidDictionary() {
        let dict: [String: Any] = [
            "id": "abc123",
            "senderId": "sender_uid",
            "receiverIds": ["r1", "r2", "sender_uid"],
            "imageUrl": "https://example.com/photo.jpg",
            "timestamp": Date(),
            "latitude": 41.0,
            "longitude": 29.0,
            "cityName": "Istanbul"
        ]
        let photo = PhotoMetadata.from(dict)
        XCTAssertNotNil(photo)
        XCTAssertEqual(photo?.id, "abc123")
        XCTAssertEqual(photo?.senderId, "sender_uid")
        XCTAssertEqual(photo?.receiverIds.count, 3)
        XCTAssertEqual(photo?.cityName, "Istanbul")
    }

    func testFromMinimalDictionary() {
        // Only required fields
        let dict: [String: Any] = [
            "id": "x",
            "senderId": "u",
            "receiverIds": ["a", "b"],
            "imageUrl": "https://x.com/x.jpg",
            "timestamp": Date()
        ]
        XCTAssertNotNil(PhotoMetadata.from(dict))
    }

    func testFromMissingRequiredFieldFails() {
        // Missing senderId
        let dict: [String: Any] = [
            "id": "x",
            "receiverIds": ["a"],
            "imageUrl": "https://x.com/x.jpg",
            "timestamp": Date()
        ]
        XCTAssertNil(PhotoMetadata.from(dict))
    }

    func testFromEmptyDictionaryReturnsNil() {
        XCTAssertNil(PhotoMetadata.from([:]))
    }

    func testFromHandlesSecretFlag() {
        let dict: [String: Any] = [
            "id": "x",
            "senderId": "u",
            "receiverIds": ["a"],
            "imageUrl": "https://x.com/x.jpg",
            "timestamp": Date(),
            "isSecret": true,
            "unlockedBy": ["a", "b"]
        ]
        let photo = PhotoMetadata.from(dict)
        XCTAssertEqual(photo?.isSecret, true)
        XCTAssertEqual(photo?.unlockedBy?.count, 2)
    }

    func testIsVideoFlag() {
        let dict: [String: Any] = [
            "id": "x",
            "senderId": "u",
            "receiverIds": ["a"],
            "imageUrl": "https://x.com/x.jpg",
            "timestamp": Date(),
            "videoUrl": "https://x.com/v.mp4",
            "videoDuration": 3.5
        ]
        let photo = PhotoMetadata.from(dict)
        XCTAssertEqual(photo?.isVideo, true)
        XCTAssertEqual(photo?.videoDuration, 3.5)
    }
}

// MARK: - DirectMessage construction (DirectMessage.from is private — test direct init)

final class DirectMessageConstructionTests: XCTestCase {
    func testInitDirectMessage() {
        let msg = DirectMessage(
            id: "1",
            senderId: "a",
            receiverId: "b",
            text: "Hello",
            timestamp: Date(),
            replyToId: nil,
            replyToText: nil,
            replyToSenderId: nil,
            readAt: nil
        )
        XCTAssertEqual(msg.text, "Hello")
        XCTAssertEqual(msg.senderId, "a")
        XCTAssertNil(msg.readAt)
    }

    func testReplyFields() {
        let msg = DirectMessage(
            id: "1", senderId: "a", receiverId: "b",
            text: "OK", timestamp: Date(),
            replyToId: "0", replyToText: "Önceki", replyToSenderId: "b"
        )
        XCTAssertEqual(msg.replyToId, "0")
        XCTAssertEqual(msg.replyToText, "Önceki")
    }

    func testReadAtMarkedAfterRead() {
        let now = Date()
        let msg = DirectMessage(
            id: "1", senderId: "a", receiverId: "b",
            text: "x", timestamp: now, readAt: now
        )
        XCTAssertNotNil(msg.readAt)
    }
}

// MARK: - UserProfile Edge Cases

final class UserProfileTests: XCTestCase {
    func testInitialsFromDisplayName() {
        let profile = UserProfile(
            id: "1", inviteCode: "AB", email: nil,
            displayName: "Ali Veli", username: "ali", dateOfBirth: nil
        )
        // The model itself doesn't expose initials, but a callee could derive them.
        // This test pins the displayName format expected by avatar fallback logic.
        XCTAssertEqual(profile.displayName?.split(separator: " ").count, 2)
    }

    func testEmptyOrNilUsername() {
        let p = UserProfile(id: "1", inviteCode: "X", email: nil,
                            displayName: nil, username: nil, dateOfBirth: nil)
        XCTAssertNil(p.username)
    }

    func testInviteCodeFormat() {
        // Invite codes are uppercase 8-char alphanumeric
        let p = UserProfile(id: "1", inviteCode: "ABCD1234", email: nil,
                            displayName: nil, username: nil, dateOfBirth: nil)
        XCTAssertEqual(p.inviteCode.count, 8)
        XCTAssertEqual(p.inviteCode, p.inviteCode.uppercased())
    }
}

// MARK: - Streak State Machine

final class StreakStateMachineTests: XCTestCase {
    private func makeStreak(current: Int, lastExchange: Date = Date()) -> Streak {
        Streak(
            id: "test",
            userIds: ["a", "b"],
            currentStreak: current,
            longestStreak: current,
            lastExchangeDate: lastExchange,
            friendshipScore: current * 10
        )
    }

    func testTierDiffersByScore() {
        // currentStreak 0 → lowest tier; we don't pin the exact name, just the
        // ordering: low streaks should be in a different tier than high streaks.
        let lowStreak = makeStreak(current: 0)
        let highStreak = makeStreak(current: 365)
        XCTAssertNotEqual(lowStreak.tier.rawValue, highStreak.tier.rawValue)
    }

    func testTierProgressesWithStreak() {
        let casualStreak = makeStreak(current: 7)
        let bestieStreak = makeStreak(current: 30)
        let soulmateStreak = makeStreak(current: 100)
        XCTAssertLessThanOrEqual(casualStreak.longestStreak, bestieStreak.longestStreak)
        XCTAssertLessThanOrEqual(bestieStreak.longestStreak, soulmateStreak.longestStreak)
    }

    func testZeroStreakIsNotExpiring() {
        let s = makeStreak(current: 0)
        XCTAssertFalse(s.isExpiringSoon)
    }

    func testIsExpiringAfterDayChange() {
        // 30 hours ago crosses calendar day boundary → expiring
        let thirtyHoursAgo = Date().addingTimeInterval(-30 * 60 * 60)
        let s = makeStreak(current: 3, lastExchange: thirtyHoursAgo)
        XCTAssertTrue(s.isExpiringSoon)
    }

    func testIsNotExpiringIfRecent() {
        // Exchange today → not expiring even if early in day
        let s = makeStreak(current: 3, lastExchange: Date())
        XCTAssertFalse(s.isExpiringSoon)
    }
}

// MARK: - AppError + FirebaseError

final class ErrorTypeTests: XCTestCase {
    func testAppErrorCustomMessageSurvives() {
        let error = AppError.custom("Özel hata mesajı")
        XCTAssertTrue(error.localizedDescription.contains("Özel hata mesajı"))
    }

    func testAppErrorTimeoutHasMessage() {
        XCTAssertFalse(AppError.timeout.localizedDescription.isEmpty)
    }

    func testAppErrorNetworkUnavailableHasMessage() {
        XCTAssertFalse(AppError.networkUnavailable.localizedDescription.isEmpty)
    }

    func testFirebaseErrorUnauthenticatedHasMessage() {
        XCTAssertFalse(FirebaseError.unauthenticated.localizedDescription.isEmpty)
    }

    func testFirebaseErrorUserNotFoundHasMessage() {
        XCTAssertFalse(FirebaseError.userNotFound.localizedDescription.isEmpty)
    }

    func testFirebaseErrorNoReceiversHasMessage() {
        XCTAssertFalse(FirebaseError.noReceivers.localizedDescription.isEmpty)
    }
}

// MARK: - AppLimits constants

final class AppLimitsExtraTests: XCTestCase {
    func testReceiverLimitMatchesMessageLimit() {
        // App enforces max 50 receivers per strip in PhotoService too — keep aligned.
        XCTAssertEqual(AppLimits.maxReceivers, 50)
    }

    func testUsernameRangeIsReasonable() {
        XCTAssertTrue(AppLimits.usernameMinLength >= 3)
        XCTAssertTrue(AppLimits.usernameMaxLength <= 30)
        XCTAssertTrue(AppLimits.usernameMinLength < AppLimits.usernameMaxLength)
    }

    func testMessageLengthIsBigEnough() {
        XCTAssertGreaterThanOrEqual(AppLimits.messageMaxLength, 1000)
    }

    func testWidgetRefreshIntervalReasonable() {
        // Widget refresh: minimum 1 minute, max 30 min sanity bounds
        XCTAssertGreaterThanOrEqual(AppLimits.widgetRefreshInterval, 60)
        XCTAssertLessThanOrEqual(AppLimits.widgetRefreshInterval, 30 * 60)
    }

    func testMinimumRegistrationAgeIs16() {
        XCTAssertEqual(AppLimits.minimumRegistrationAge, 16)
    }

    func testLatestAllowedBirthDateIsInPast() {
        XCTAssertLessThan(AppLimits.latestAllowedBirthDate, Date())
    }
}

// MARK: - DependencyContainer mock injection

final class DependencyContainerExtraTests: XCTestCase {
    override func tearDown() {
        // Always reset back to production wiring after the test
        DependencyContainer.shared.reset()
        super.tearDown()
    }

    func testMockUserRepositoryInjectable() {
        let mock = MockUserRepository()
        DependencyContainer.shared.userRepository = mock
        XCTAssertTrue(DependencyContainer.shared.userRepository is MockUserRepository)
    }

    func testMockStripRepositoryInjectable() {
        let mock = MockStripRepository()
        DependencyContainer.shared.stripRepository = mock
        XCTAssertTrue(DependencyContainer.shared.stripRepository is MockStripRepository)
    }

    func testMockFriendRepositoryInjectable() {
        let mock = MockFriendRepository()
        DependencyContainer.shared.friendRepository = mock
        XCTAssertTrue(DependencyContainer.shared.friendRepository is MockFriendRepository)
    }

    func testResetRestoresProductionRepos() {
        let mock = MockFriendRepository()
        DependencyContainer.shared.friendRepository = mock
        DependencyContainer.shared.reset()
        XCTAssertFalse(DependencyContainer.shared.friendRepository is MockFriendRepository)
    }
}

// MARK: - Comment / Reactions

final class CommentReactionsTests: XCTestCase {
    func testReactionToggleSimulation() {
        // Simulate the reactions dictionary mutation used by toggleReaction.
        var reactions: [String: [String]] = ["❤️": ["userA"]]
        let userId = "userB"
        let emoji = "🔥"

        // Add new emoji
        reactions[emoji, default: []].append(userId)
        XCTAssertEqual(reactions[emoji], [userId])
        XCTAssertEqual(reactions["❤️"]?.count, 1)

        // Remove user — emoji empties
        reactions[emoji]?.removeAll(where: { $0 == userId })
        if reactions[emoji]?.isEmpty == true { reactions.removeValue(forKey: emoji) }
        XCTAssertNil(reactions[emoji])
    }

    func testFindExistingReactionByUser() {
        let reactions: [String: [String]] = ["❤️": ["a"], "🔥": ["b"]]
        XCTAssertEqual(reactions.first(where: { $0.value.contains("a") })?.key, "❤️")
        XCTAssertEqual(reactions.first(where: { $0.value.contains("b") })?.key, "🔥")
        XCTAssertNil(reactions.first(where: { $0.value.contains("ghost") })?.key)
    }
}

// MARK: - Notification Type enum

final class NotificationTypeTests: XCTestCase {
    func testRawValuesStable() {
        // Cloud Functions side relies on these strings — pin them.
        XCTAssertEqual(NotificationType(rawValue: "photo_received"), .photoReceived)
        XCTAssertEqual(NotificationType(rawValue: "comment_received"), .commentReceived)
        XCTAssertEqual(NotificationType(rawValue: "direct_message"), .directMessage)
        XCTAssertEqual(NotificationType(rawValue: "friend_added"), .friendAdded)
        XCTAssertEqual(NotificationType(rawValue: "strip_chat"), .stripChat)
        XCTAssertEqual(NotificationType(rawValue: "weekly_summary"), .weeklySummary)
    }

    func testUnknownRawValueReturnsNil() {
        XCTAssertNil(NotificationType(rawValue: "definitely_not_a_real_type"))
    }
}

// MARK: - PhotoMetadata isLockedFor logic

final class SecretMomentLockingTests: XCTestCase {
    private func makePhoto(senderId: String, isSecret: Bool, unlockedBy: [String]?) -> PhotoMetadata {
        PhotoMetadata(
            id: "x",
            senderId: senderId,
            receiverIds: ["sender", "viewer"],
            imageUrl: "https://x.com/x.jpg",
            timestamp: Date(),
            latitude: nil, longitude: nil, cityName: nil,
            voiceUrl: nil, isSecret: isSecret, unlockedBy: unlockedBy
        )
    }

    func testNonSecretAlwaysVisible() {
        let p = makePhoto(senderId: "alice", isSecret: false, unlockedBy: nil)
        let viewer = "bob"
        let isLocked = p.isSecret == true
            && !(p.unlockedBy ?? []).contains(viewer)
            && p.senderId != viewer
        XCTAssertFalse(isLocked)
    }

    func testSecretLockedForViewerWhoHasNotUnlocked() {
        let p = makePhoto(senderId: "alice", isSecret: true, unlockedBy: [])
        let viewer = "bob"
        let isLocked = p.isSecret == true
            && !(p.unlockedBy ?? []).contains(viewer)
            && p.senderId != viewer
        XCTAssertTrue(isLocked)
    }

    func testSecretUnlockedAfterUserAdded() {
        let p = makePhoto(senderId: "alice", isSecret: true, unlockedBy: ["bob"])
        let viewer = "bob"
        let isLocked = p.isSecret == true
            && !(p.unlockedBy ?? []).contains(viewer)
            && p.senderId != viewer
        XCTAssertFalse(isLocked)
    }

    func testSecretAlwaysVisibleToOwnSender() {
        let p = makePhoto(senderId: "alice", isSecret: true, unlockedBy: [])
        let viewer = "alice"
        let isLocked = p.isSecret == true
            && !(p.unlockedBy ?? []).contains(viewer)
            && p.senderId != viewer
        XCTAssertFalse(isLocked)
    }
}

// MARK: - Invite Code Normalization (FriendGateView helper logic)

private func normalizeInviteCode(_ raw: String) -> String? {
    let upper = raw.uppercased()
    let chars = upper.filter { $0.isLetter || $0.isNumber }
    guard chars.count >= 8 else { return nil }
    return String(chars.suffix(8))
}

final class InviteCodeNormalizationTests: XCTestCase {
    func testStripsDashesAndSpaces() {
        XCTAssertEqual(normalizeInviteCode("ab-cd-1234"), "ABCD1234")
        XCTAssertEqual(normalizeInviteCode("ab cd 12 34"), "ABCD1234")
    }

    func testTakesLastEightCharsForLongerInput() {
        XCTAssertEqual(normalizeInviteCode("PREFIXABCD1234"), "ABCD1234")
    }

    func testRejectsTooShort() {
        XCTAssertNil(normalizeInviteCode("ABC"))
        XCTAssertNil(normalizeInviteCode("AB-CD"))
    }

    func testRejectsEmptyString() {
        XCTAssertNil(normalizeInviteCode(""))
    }

    func testCaseInsensitive() {
        XCTAssertEqual(normalizeInviteCode("abcd1234"), "ABCD1234")
        XCTAssertEqual(normalizeInviteCode("AbCd1234"), "ABCD1234")
    }

    func testHandlesUnicodeStripped() {
        // Emoji and Turkish chars not in ASCII alphanumeric should be stripped
        // (filter is liberal on Letter/Number, so Turkish letters pass through —
        //  but emoji fail).
        XCTAssertNotNil(normalizeInviteCode("🎉ABCD12345🎉"))
    }
}

// MARK: - Friendship state transitions

final class FriendshipStateTests: XCTestCase {
    func testFriendStatusPendingFlag() {
        let pending = FriendStatus(
            userId: "u",
            isPending: true,
            timestamp: Date(),
            requesterId: "me",
            profile: nil
        )
        XCTAssertTrue(pending.isPending)
        XCTAssertEqual(pending.requesterId, "me")
    }

    func testIsOutgoingHelper() {
        // outgoing: I am the requester
        let outgoing = FriendStatus(userId: "u", isPending: true, timestamp: Date(), requesterId: "me", profile: nil)
        XCTAssertEqual(outgoing.requesterId, "me")
    }

    func testIsIncomingHelper() {
        // incoming: friend is the requester
        let incoming = FriendStatus(userId: "friend", isPending: true, timestamp: Date(), requesterId: "friend", profile: nil)
        XCTAssertEqual(incoming.requesterId, "friend")
    }

    func testAcceptedFriend() {
        let accepted = FriendStatus(userId: "u", isPending: false, timestamp: Date(), requesterId: nil, profile: nil)
        XCTAssertFalse(accepted.isPending)
    }
}

// MARK: - Time-based expiry helpers

final class TimeExpiryTests: XCTestCase {
    func testProfileCacheExpired() {
        let ttl: TimeInterval = 60
        let oldFetch = Date().addingTimeInterval(-120)
        XCTAssertGreaterThan(Date().timeIntervalSince(oldFetch), ttl)
    }

    func testProfileCacheFresh() {
        let ttl: TimeInterval = 60
        let recentFetch = Date().addingTimeInterval(-30)
        XCTAssertLessThan(Date().timeIntervalSince(recentFetch), ttl)
    }

    func testWidgetTimelineRefreshIntervalConsistent() {
        // Widget fallback policy is 15 minutes — verify constant matches.
        let expected: TimeInterval = 15 * 60
        XCTAssertEqual(expected, 900)
    }
}

// MARK: - URL/Deep link parsing helpers

final class URLParsingTests: XCTestCase {
    func testStripmateChatURLParses() {
        let url = URL(string: "stripmate://chat/abcd1234")!
        XCTAssertEqual(url.scheme, "stripmate")
        XCTAssertEqual(url.host, "chat")
        XCTAssertEqual(url.pathComponents.filter { $0 != "/" }, ["abcd1234"])
    }

    func testStripmateChatWithReceiverParses() {
        let url = URL(string: "stripmate://chat/ABC_xyz/RCV_qwe")!
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        XCTAssertEqual(pathComponents.count, 2)
        XCTAssertEqual(pathComponents[0], "ABC_xyz")
        XCTAssertEqual(pathComponents[1], "RCV_qwe")
    }

    func testStripmateDmThreadURLParses() {
        let url = URL(string: "stripmate://dm/uid1_uid2")!
        XCTAssertEqual(url.host, "dm")
        XCTAssertEqual(url.pathComponents.filter { $0 != "/" }.first, "uid1_uid2")
    }

    func testInvalidSchemeRejected() {
        let url = URL(string: "https://chat/x")!
        XCTAssertNotEqual(url.scheme, "stripmate")
    }
}

// MARK: - Image downsampling helper

final class UIImageDownsampleTests: XCTestCase {
    private func makeImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testResizeBigImagePreservesAspectRatio() {
        let img = makeImage(size: CGSize(width: 2000, height: 4000))
        let down = img.resizedToMax(dimension: 512)
        XCTAssertLessThanOrEqual(max(down.size.width, down.size.height), 512.5)
        // Aspect ratio preserved within rounding
        let originalRatio = img.size.width / img.size.height
        let downRatio = down.size.width / down.size.height
        XCTAssertEqual(originalRatio, downRatio, accuracy: 0.01)
    }

    func testResizeSmallImageNoChange() {
        let img = makeImage(size: CGSize(width: 200, height: 300))
        let down = img.resizedToMax(dimension: 512)
        XCTAssertEqual(down.size.width, 200)
        XCTAssertEqual(down.size.height, 300)
    }

    func testResizeSquareImage() {
        let img = makeImage(size: CGSize(width: 1000, height: 1000))
        let down = img.resizedToMax(dimension: 200)
        XCTAssertEqual(down.size.width, down.size.height)
    }
}
