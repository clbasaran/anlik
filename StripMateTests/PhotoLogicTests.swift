import XCTest
@testable import StripMate

// MARK: - PhotoUploadDocumentBuilder

final class PhotoUploadDocumentBuilderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func sampleInput(
        receiverIds: [String] = ["receiver_1", "receiver_2"],
        voiceUrl: String? = nil,
        videoUrl: String? = nil,
        videoDuration: Double? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        cityName: String? = nil,
        isSecret: Bool = false,
        dailyPromptId: String? = nil
    ) -> PhotoUploadDocumentBuilder.Input {
        PhotoUploadDocumentBuilder.Input(
            stripId: "strip_id_1",
            senderId: "sender_uid",
            senderProfileSnapshot: ["displayName": "Ali", "avatarUrl": "https://x.com/a.jpg"],
            receiverIds: receiverIds,
            imageUrl: "https://x.com/img.jpg",
            voiceUrl: voiceUrl,
            videoUrl: videoUrl,
            videoDuration: videoDuration,
            latitude: latitude,
            longitude: longitude,
            cityName: cityName,
            isSecret: isSecret,
            dailyPromptId: dailyPromptId
        )
    }

    func testBuildIncludesRequiredFields() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(), timestamp: now)
        XCTAssertEqual(doc["id"] as? String, "strip_id_1")
        XCTAssertEqual(doc["senderId"] as? String, "sender_uid")
        XCTAssertEqual(doc["imageUrl"] as? String, "https://x.com/img.jpg")
        XCTAssertEqual(doc["timestamp"] as? Date, now)
        XCTAssertEqual(doc["isSecret"] as? Bool, false)
        XCTAssertEqual(doc["flagged"] as? Bool, false)
    }

    func testBuildSelfEchoAddsSenderToReceivers() {
        // senderId not in receiverIds → it should be appended
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(receiverIds: ["a", "b"]), timestamp: now)
        let receivers = doc["receiverIds"] as? [String] ?? []
        XCTAssertTrue(receivers.contains("sender_uid"))
        XCTAssertEqual(Set(receivers), ["a", "b", "sender_uid"])
    }

    func testBuildDoesNotDuplicateSenderIfAlreadyInReceivers() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(receiverIds: ["a", "sender_uid"]), timestamp: now)
        let receivers = doc["receiverIds"] as? [String] ?? []
        XCTAssertEqual(receivers.filter { $0 == "sender_uid" }.count, 1)
    }

    func testBuildOmitsVoiceUrlWhenNil() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(voiceUrl: nil), timestamp: now)
        XCTAssertNil(doc["voiceUrl"])
    }

    func testBuildOmitsVoiceUrlWhenEmpty() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(voiceUrl: ""), timestamp: now)
        XCTAssertNil(doc["voiceUrl"])
    }

    func testBuildIncludesVoiceUrlWhenPresent() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(voiceUrl: "https://x.com/v.m4a"), timestamp: now)
        XCTAssertEqual(doc["voiceUrl"] as? String, "https://x.com/v.m4a")
    }

    func testBuildIncludesVideoUrlAndDuration() {
        let doc = PhotoUploadDocumentBuilder.build(
            sampleInput(videoUrl: "https://x.com/v.mp4", videoDuration: 4.2),
            timestamp: now
        )
        XCTAssertEqual(doc["videoUrl"] as? String, "https://x.com/v.mp4")
        XCTAssertEqual(doc["videoDuration"] as? Double, 4.2)
    }

    func testBuildOmitsDurationWhenNil() {
        let doc = PhotoUploadDocumentBuilder.build(
            sampleInput(videoUrl: "https://x.com/v.mp4", videoDuration: nil),
            timestamp: now
        )
        XCTAssertNotNil(doc["videoUrl"])
        XCTAssertNil(doc["videoDuration"])
    }

    func testBuildOmitsLocationWhenZeroZero() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(latitude: 0, longitude: 0), timestamp: now)
        XCTAssertNil(doc["latitude"])
        XCTAssertNil(doc["longitude"])
    }

    func testBuildIncludesLocationWhenValid() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(latitude: 41.0, longitude: 29.0), timestamp: now)
        XCTAssertEqual(doc["latitude"] as? Double, 41.0)
        XCTAssertEqual(doc["longitude"] as? Double, 29.0)
    }

    func testBuildOmitsCityWhenEmpty() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(cityName: ""), timestamp: now)
        XCTAssertNil(doc["cityName"])
    }

    func testBuildIncludesCityWhenPresent() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(cityName: "Istanbul"), timestamp: now)
        XCTAssertEqual(doc["cityName"] as? String, "Istanbul")
    }

    func testBuildSecretSeedsUnlockedByWithSender() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(isSecret: true), timestamp: now)
        XCTAssertEqual(doc["isSecret"] as? Bool, true)
        let unlocked = doc["unlockedBy"] as? [String] ?? []
        XCTAssertEqual(unlocked, ["sender_uid"])
    }

    func testBuildNonSecretOmitsUnlockedBy() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(isSecret: false), timestamp: now)
        XCTAssertNil(doc["unlockedBy"])
    }

    func testBuildIncludesProfileSnapshot() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(), timestamp: now)
        let snapshot = doc["senderProfileSnapshot"] as? [String: Any]
        XCTAssertEqual(snapshot?["displayName"] as? String, "Ali")
    }

    func testBuildIncludesDailyPromptIdWhenSet() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(dailyPromptId: "prompt_123"), timestamp: now)
        XCTAssertEqual(doc["dailyPromptId"] as? String, "prompt_123")
    }

    func testBuildOmitsDailyPromptIdWhenEmpty() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(dailyPromptId: ""), timestamp: now)
        XCTAssertNil(doc["dailyPromptId"])
    }

    func testBuildReactionsStartEmpty() {
        let doc = PhotoUploadDocumentBuilder.build(sampleInput(), timestamp: now)
        let reactions = doc["reactions"] as? [String: [String]] ?? ["x": ["y"]]
        XCTAssertTrue(reactions.isEmpty)
    }
}

// MARK: - PhotoSendValidator

final class PhotoSendValidatorTests: XCTestCase {
    func testRejectsUnauthenticated() {
        let result = PhotoSendValidator.validate(
            senderId: nil, receiverIds: ["a"], acceptedFriendIds: ["a"]
        )
        XCTAssertEqual(result, .unauthenticated)
    }

    func testRejectsEmptyReceivers() {
        let result = PhotoSendValidator.validate(
            senderId: "me", receiverIds: [], acceptedFriendIds: []
        )
        XCTAssertEqual(result, .noReceivers)
    }

    func testRejectsTooManyReceivers() {
        let receivers = (0..<51).map { "u\($0)" }
        let result = PhotoSendValidator.validate(
            senderId: "me",
            receiverIds: receivers,
            acceptedFriendIds: Set(receivers)
        )
        XCTAssertEqual(result, .tooManyReceivers)
    }

    func testAllowsExactlyMaxReceivers() {
        let receivers = (0..<50).map { "u\($0)" }
        let result = PhotoSendValidator.validate(
            senderId: "me",
            receiverIds: receivers,
            acceptedFriendIds: Set(receivers)
        )
        XCTAssertEqual(result, .ok)
    }

    func testRejectsNonFriendReceivers() {
        let result = PhotoSendValidator.validate(
            senderId: "me",
            receiverIds: ["friend1", "stranger"],
            acceptedFriendIds: ["friend1"]
        )
        if case .nonFriendReceivers(let bad) = result {
            XCTAssertEqual(bad, ["stranger"])
        } else {
            XCTFail("Expected nonFriendReceivers, got \(result)")
        }
    }

    func testAllowsSelfEvenIfNotInAcceptedFriends() {
        // Sender can include themselves in receiverIds without being in
        // their own friend list.
        let result = PhotoSendValidator.validate(
            senderId: "me",
            receiverIds: ["friend1", "me"],
            acceptedFriendIds: ["friend1"]
        )
        XCTAssertEqual(result, .ok)
    }

    func testValidSendPasses() {
        let result = PhotoSendValidator.validate(
            senderId: "me",
            receiverIds: ["a", "b", "c"],
            acceptedFriendIds: ["a", "b", "c"]
        )
        XCTAssertEqual(result, .ok)
    }
}

// MARK: - PhotoStoragePaths

final class PhotoStoragePathsTests: XCTestCase {
    func testImagePath() {
        XCTAssertEqual(
            PhotoStoragePaths.image(stripId: "S1", senderId: "U1"),
            "strips/U1_S1.jpg"
        )
    }

    func testThumbnailPath() {
        XCTAssertEqual(
            PhotoStoragePaths.thumbnail(stripId: "S1", senderId: "U1", size: 800),
            "strips/thumbs/U1_S1_800x800.jpg"
        )
    }

    func testThumbnailDifferentSize() {
        XCTAssertEqual(
            PhotoStoragePaths.thumbnail(stripId: "S1", senderId: "U1", size: 200),
            "strips/thumbs/U1_S1_200x200.jpg"
        )
    }

    func testVideoPath() {
        XCTAssertEqual(
            PhotoStoragePaths.video(stripId: "S1"),
            "strips/videos/S1.mp4"
        )
    }

    func testVoicePath() {
        XCTAssertEqual(
            PhotoStoragePaths.voice(stripId: "S1", senderId: "U1"),
            "voices/U1_S1.m4a"
        )
    }

    func testAvatarPath() {
        XCTAssertEqual(
            PhotoStoragePaths.avatar(userId: "U1"),
            "avatars/U1.jpg"
        )
    }

    func testChatPhotoPath() {
        XCTAssertEqual(
            PhotoStoragePaths.chatPhoto(messageId: "M1", senderId: "U1"),
            "chat_photos/U1_M1.jpg"
        )
    }

    func testDmPhotoPath() {
        XCTAssertEqual(
            PhotoStoragePaths.dmPhoto(messageId: "M1", senderId: "U1"),
            "dm_photos/U1_M1.jpg"
        )
    }

    func testStorageRulesPrefixCompliance() {
        // Storage rules require {senderId}_{rest} prefix on chat/dm/voice paths.
        // Sanity-check that.
        let userId = "abcDEF123"
        XCTAssertTrue(PhotoStoragePaths.image(stripId: "x", senderId: userId).contains("\(userId)_"))
        XCTAssertTrue(PhotoStoragePaths.voice(stripId: "x", senderId: userId).contains("\(userId)_"))
        XCTAssertTrue(PhotoStoragePaths.chatPhoto(messageId: "x", senderId: userId).contains("\(userId)_"))
        XCTAssertTrue(PhotoStoragePaths.dmPhoto(messageId: "x", senderId: userId).contains("\(userId)_"))
    }
}

// MARK: - ReactionLogic

final class ReactionLogicTests: XCTestCase {
    func testToggleAddsNewEmoji() {
        let next = ReactionLogic.toggle(reactions: [:], userId: "u1", emoji: "❤️")
        XCTAssertEqual(next["❤️"], ["u1"])
    }

    func testToggleRemovesSameEmoji() {
        let next = ReactionLogic.toggle(reactions: ["❤️": ["u1"]], userId: "u1", emoji: "❤️")
        XCTAssertNil(next["❤️"])
    }

    func testToggleSwitchesEmoji() {
        let initial: [String: [String]] = ["❤️": ["u1"]]
        let next = ReactionLogic.toggle(reactions: initial, userId: "u1", emoji: "🔥")
        XCTAssertNil(next["❤️"])
        XCTAssertEqual(next["🔥"], ["u1"])
    }

    func testTogglePreservesOtherUsersReactions() {
        let initial: [String: [String]] = ["❤️": ["u1", "u2"]]
        let next = ReactionLogic.toggle(reactions: initial, userId: "u1", emoji: "🔥")
        XCTAssertEqual(next["❤️"], ["u2"])
        XCTAssertEqual(next["🔥"], ["u1"])
    }

    func testToggleAddsToExistingEmojiBucket() {
        let initial: [String: [String]] = ["❤️": ["existing"]]
        let next = ReactionLogic.toggle(reactions: initial, userId: "newcomer", emoji: "❤️")
        XCTAssertEqual(Set(next["❤️"] ?? []), ["existing", "newcomer"])
    }

    func testToggleRepeatedlyOnSameEmojiNoOp() {
        var state: [String: [String]] = [:]
        // Toggle on
        state = ReactionLogic.toggle(reactions: state, userId: "u", emoji: "🎉")
        XCTAssertEqual(state["🎉"], ["u"])
        // Toggle off
        state = ReactionLogic.toggle(reactions: state, userId: "u", emoji: "🎉")
        XCTAssertNil(state["🎉"])
        // Toggle on again
        state = ReactionLogic.toggle(reactions: state, userId: "u", emoji: "🎉")
        XCTAssertEqual(state["🎉"], ["u"])
    }

    func testUserHasReactedTrue() {
        XCTAssertTrue(ReactionLogic.userHasReacted(["❤️": ["u1"]], userId: "u1"))
    }

    func testUserHasReactedFalse() {
        XCTAssertFalse(ReactionLogic.userHasReacted(["❤️": ["u2"]], userId: "u1"))
    }

    func testCurrentEmojiReturnsExisting() {
        XCTAssertEqual(ReactionLogic.currentEmoji(["🔥": ["u1"]], userId: "u1"), "🔥")
    }

    func testCurrentEmojiNilWhenNoneSet() {
        XCTAssertNil(ReactionLogic.currentEmoji([:], userId: "u1"))
    }
}

// MARK: - SecretStripLogic

final class SecretStripLogicTests: XCTestCase {
    private func strip(senderId: String, isSecret: Bool, unlockedBy: [String]?) -> PhotoMetadata {
        PhotoMetadata(
            id: "x", senderId: senderId, receiverIds: ["a", "b"],
            imageUrl: "https://x.com/x.jpg", timestamp: Date(),
            latitude: nil, longitude: nil, cityName: nil,
            voiceUrl: nil, isSecret: isSecret, unlockedBy: unlockedBy
        )
    }

    func testNonSecretAlwaysVisible() {
        let p = strip(senderId: "alice", isSecret: false, unlockedBy: nil)
        XCTAssertFalse(SecretStripLogic.isLockedFor(viewer: "bob", strip: p))
    }

    func testSecretLockedToOutsider() {
        let p = strip(senderId: "alice", isSecret: true, unlockedBy: [])
        XCTAssertTrue(SecretStripLogic.isLockedFor(viewer: "bob", strip: p))
    }

    func testSecretUnlockedAfterAdded() {
        let p = strip(senderId: "alice", isSecret: true, unlockedBy: ["bob"])
        XCTAssertFalse(SecretStripLogic.isLockedFor(viewer: "bob", strip: p))
    }

    func testSecretAlwaysVisibleToOwnSender() {
        let p = strip(senderId: "alice", isSecret: true, unlockedBy: [])
        XCTAssertFalse(SecretStripLogic.isLockedFor(viewer: "alice", strip: p))
    }

    func testNilUnlockedByTreatedAsEmpty() {
        let p = strip(senderId: "alice", isSecret: true, unlockedBy: nil)
        XCTAssertTrue(SecretStripLogic.isLockedFor(viewer: "bob", strip: p))
    }
}
