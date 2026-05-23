import XCTest
@testable import StripMate

// MARK: - parseProfile (pure function tests)

final class ParseProfileTests: XCTestCase {
    func testParsesAllFields() {
        let dob = Date(timeIntervalSince1970: 1_000_000_000)
        let data: [String: Any] = [
            "inviteCode": "ABCD1234",
            "email": "x@y.com",
            "displayName": "Ali",
            "username": "ali",
            "dateOfBirth": dob,
            "avatarUrl": "https://x.com/a.jpg",
            "bio": "hi",
            "statusEmoji": "🔥",
            "favoriteSong": "S",
            "zodiacSign": "leo",
            "personalityEmojis": ["🎉", "🌙"]
        ]
        let p = ProfileStore.parseProfile(uid: "uid_a", data: data)
        XCTAssertEqual(p.id, "uid_a")
        XCTAssertEqual(p.inviteCode, "ABCD1234")
        XCTAssertEqual(p.email, "x@y.com")
        XCTAssertEqual(p.displayName, "Ali")
        XCTAssertEqual(p.username, "ali")
        XCTAssertEqual(p.dateOfBirth, dob)
        XCTAssertEqual(p.avatarUrl, "https://x.com/a.jpg")
        XCTAssertEqual(p.bio, "hi")
        XCTAssertEqual(p.statusEmoji, "🔥")
        XCTAssertEqual(p.favoriteSong, "S")
        XCTAssertEqual(p.zodiacSign, "leo")
        XCTAssertEqual(p.personalityEmojis?.count, 2)
    }

    func testEmptyDictionaryDefaults() {
        let p = ProfileStore.parseProfile(uid: "uid", data: [:])
        XCTAssertEqual(p.id, "uid")
        XCTAssertEqual(p.inviteCode, "")
        XCTAssertNil(p.email)
        XCTAssertNil(p.displayName)
        XCTAssertNil(p.username)
        XCTAssertNil(p.dateOfBirth)
        XCTAssertNil(p.avatarUrl)
        XCTAssertNil(p.bio)
    }

    func testTimestampAsDouble() {
        let secs: Double = 1_700_000_000
        let p = ProfileStore.parseProfile(uid: "u", data: ["dateOfBirth": secs])
        XCTAssertEqual(p.dateOfBirth, Date(timeIntervalSince1970: secs))
    }

    func testTimestampAsInt() {
        let secs: Int = 1_700_000_000
        let p = ProfileStore.parseProfile(uid: "u", data: ["dateOfBirth": secs])
        XCTAssertEqual(p.dateOfBirth, Date(timeIntervalSince1970: TimeInterval(secs)))
    }

    func testNotificationPrefsExtractBoolsOnly() {
        let raw: [String: Any] = [
            "push": true,
            "quiet_hours_enabled": false,
            "quiet_hours_start": 22, // Int — should be filtered out
            "quiet_hours_end": "07"  // String — should be filtered out
        ]
        let p = ProfileStore.parseProfile(uid: "u", data: ["notificationPreferences": raw])
        XCTAssertEqual(p.notificationPreferences?["push"], true)
        XCTAssertEqual(p.notificationPreferences?["quiet_hours_enabled"], false)
        XCTAssertNil(p.notificationPreferences?["quiet_hours_start"])
        XCTAssertNil(p.notificationPreferences?["quiet_hours_end"])
    }

    func testWrongTypeFieldsIgnored() {
        let data: [String: Any] = [
            "inviteCode": 12345, // Int — should be ignored, default ""
            "email": Date()      // Date — should be ignored, nil
        ]
        let p = ProfileStore.parseProfile(uid: "u", data: data)
        XCTAssertEqual(p.inviteCode, "")
        XCTAssertNil(p.email)
    }
}

// MARK: - ProfileStore (with MockFirestoreClient)

final class ProfileStoreFetchTests: XCTestCase {
    private var firestore: MockFirestoreClient!
    private var store: ProfileStore!

    override func setUp() {
        super.setUp()
        firestore = MockFirestoreClient()
        store = ProfileStore(firestore: firestore, cacheTTL: 60)
    }

    func testFetchProfileReturnsParsedProfile() async throws {
        firestore.documents["users/uid_a"] = [
            "inviteCode": "INVCODE1",
            "displayName": "Ahmet",
            "username": "ahmet"
        ]
        let p = try await store.fetchProfile(for: "uid_a")
        XCTAssertEqual(p.id, "uid_a")
        XCTAssertEqual(p.inviteCode, "INVCODE1")
        XCTAssertEqual(p.displayName, "Ahmet")
    }

    func testFetchProfileMissingThrowsUserNotFound() async {
        do {
            _ = try await store.fetchProfile(for: "nope")
            XCTFail("Expected userNotFound")
        } catch let error as FirebaseError {
            if case .userNotFound = error { return }
            XCTFail("Expected .userNotFound, got \(error)")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testFetchProfilePropagatesNetworkError() async {
        struct NetErr: Error {}
        firestore.documents["users/uid_a"] = ["inviteCode": "X"]
        firestore.nextGetError = NetErr()
        do {
            _ = try await store.fetchProfile(for: "uid_a")
            XCTFail("Expected error")
        } catch is NetErr {
            // ok
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testFetchProfileUsesCache() async throws {
        firestore.documents["users/uid_a"] = ["inviteCode": "X1"]
        _ = try await store.fetchProfile(for: "uid_a")
        let firstCallCount = firestore.getDocumentCalls
        // Second call should hit cache, no new Firestore read
        _ = try await store.fetchProfile(for: "uid_a")
        XCTAssertEqual(firestore.getDocumentCalls, firstCallCount)
    }

    func testFetchProfileForceRefreshBypassesCache() async throws {
        firestore.documents["users/uid_a"] = ["inviteCode": "X1"]
        _ = try await store.fetchProfile(for: "uid_a")
        let firstCallCount = firestore.getDocumentCalls
        _ = try await store.fetchProfile(for: "uid_a", forceRefresh: true)
        XCTAssertEqual(firestore.getDocumentCalls, firstCallCount + 1)
    }

    func testInvalidateCacheForcesRefresh() async throws {
        firestore.documents["users/uid_a"] = ["inviteCode": "X1"]
        _ = try await store.fetchProfile(for: "uid_a")
        await store.invalidateCache(for: "uid_a")
        _ = try await store.fetchProfile(for: "uid_a")
        XCTAssertEqual(firestore.getDocumentCalls, 2)
    }

    func testInvalidateCacheClearsAllWhenNilUid() async throws {
        firestore.documents["users/uid_a"] = ["inviteCode": "A"]
        firestore.documents["users/uid_b"] = ["inviteCode": "B"]
        _ = try await store.fetchProfile(for: "uid_a")
        _ = try await store.fetchProfile(for: "uid_b")
        await store.invalidateCache()
        _ = try await store.fetchProfile(for: "uid_a")
        _ = try await store.fetchProfile(for: "uid_b")
        XCTAssertEqual(firestore.getDocumentCalls, 4)
    }

    func testCacheExpiresAfterTTL() async throws {
        let shortTTLStore = ProfileStore(firestore: firestore, cacheTTL: 0.05)
        firestore.documents["users/uid_a"] = ["inviteCode": "X1"]
        _ = try await shortTTLStore.fetchProfile(for: "uid_a")
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s — past TTL
        _ = try await shortTTLStore.fetchProfile(for: "uid_a")
        XCTAssertEqual(firestore.getDocumentCalls, 2)
    }
}

// MARK: - searchUser by invite code

final class ProfileStoreSearchTests: XCTestCase {
    private var firestore: MockFirestoreClient!
    private var store: ProfileStore!

    override func setUp() {
        super.setUp()
        firestore = MockFirestoreClient()
        store = ProfileStore(firestore: firestore, cacheTTL: 60)
    }

    func testSearchByValidCodeFindsUser() async throws {
        firestore.documents["users/uid_match"] = [
            "inviteCode": "MATCH123",
            "displayName": "Matched"
        ]
        firestore.documents["users/uid_other"] = [
            "inviteCode": "OTHER999",
            "displayName": "Other"
        ]
        let p = try await store.searchUser(byInviteCode: "MATCH123")
        XCTAssertEqual(p.id, "uid_match")
        XCTAssertEqual(p.displayName, "Matched")
    }

    func testSearchUppercasesInput() async throws {
        firestore.documents["users/uid"] = ["inviteCode": "MIXED123"]
        let p = try await store.searchUser(byInviteCode: "mixed123")
        XCTAssertEqual(p.id, "uid")
    }

    func testSearchTrimsWhitespace() async throws {
        firestore.documents["users/uid"] = ["inviteCode": "ABC12345"]
        let p = try await store.searchUser(byInviteCode: "  abc12345  ")
        XCTAssertEqual(p.id, "uid")
    }

    func testSearchTooShortRejectsBeforeQuery() async {
        do {
            _ = try await store.searchUser(byInviteCode: "ABC")
            XCTFail("Expected userNotFound")
        } catch let error as FirebaseError {
            if case .userNotFound = error { return }
            XCTFail("Expected userNotFound, got \(error)")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
        // Most importantly — no Firestore call was issued
        XCTAssertEqual(firestore.queryDocumentsCalls, 0)
    }

    func testSearchInvalidCharsRejectsBeforeQuery() async {
        do {
            _ = try await store.searchUser(byInviteCode: "ABC!@#$%")
            XCTFail("Expected userNotFound")
        } catch is FirebaseError {
            // ok
        } catch {
            XCTFail("Wrong error: \(error)")
        }
        XCTAssertEqual(firestore.queryDocumentsCalls, 0)
    }

    func testSearchNotFoundThrows() async {
        firestore.documents["users/u1"] = ["inviteCode": "OTHER123"]
        do {
            _ = try await store.searchUser(byInviteCode: "MISSING1")
            XCTFail("Expected userNotFound")
        } catch let error as FirebaseError {
            if case .userNotFound = error { return }
            XCTFail("Expected userNotFound, got \(error)")
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testSearchPropagatesQueryError() async {
        struct NetErr: Error {}
        firestore.nextQueryError = NetErr()
        do {
            _ = try await store.searchUser(byInviteCode: "ABCD1234")
            XCTFail("Expected error")
        } catch is NetErr {
            // ok
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - updateProfile

final class ProfileStoreUpdateTests: XCTestCase {
    private var firestore: MockFirestoreClient!
    private var store: ProfileStore!

    override func setUp() {
        super.setUp()
        firestore = MockFirestoreClient()
        store = ProfileStore(firestore: firestore, cacheTTL: 60)
    }

    func testUpdateMergesFields() async throws {
        firestore.documents["users/uid"] = ["inviteCode": "X", "displayName": "Old"]
        try await store.updateProfile(uid: "uid", fields: ["displayName": "New"])
        XCTAssertEqual(firestore.documents["users/uid"]?["displayName"] as? String, "New")
        XCTAssertEqual(firestore.documents["users/uid"]?["inviteCode"] as? String, "X")
    }

    func testUpdateInvalidatesCache() async throws {
        firestore.documents["users/uid"] = ["inviteCode": "X", "displayName": "Old"]
        _ = try await store.fetchProfile(for: "uid")
        try await store.updateProfile(uid: "uid", fields: ["displayName": "New"])
        firestore.documents["users/uid"]?["displayName"] = "Newer-server-side-truth"
        let after = try await store.fetchProfile(for: "uid")
        XCTAssertEqual(after.displayName, "Newer-server-side-truth")
    }

    func testUpdatePropagatesError() async {
        struct NetErr: Error {}
        firestore.documents["users/uid"] = ["x": "y"]
        firestore.nextUpdateError = NetErr()
        do {
            try await store.updateProfile(uid: "uid", fields: ["x": "z"])
            XCTFail("Expected error")
        } catch is NetErr {
            // ok
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

// MARK: - FriendshipQueries

final class FriendshipQueriesEntryTests: XCTestCase {
    func testEntryFromValidDictionary() {
        let now = Date()
        let entry = FriendshipQueries.Entry.from(id: "doc_1", data: [
            "userId": "u1",
            "isPending": true,
            "timestamp": now,
            "requesterId": "me"
        ])
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.userId, "u1")
        XCTAssertTrue(entry?.isPending ?? false)
        XCTAssertEqual(entry?.requesterId, "me")
    }

    func testEntryRejectsMissingUserId() {
        let entry = FriendshipQueries.Entry.from(id: "x", data: [
            "isPending": true
        ])
        XCTAssertNil(entry)
    }

    func testEntryRejectsMissingIsPending() {
        let entry = FriendshipQueries.Entry.from(id: "x", data: [
            "userId": "u"
        ])
        XCTAssertNil(entry)
    }

    func testEntryAcceptsTimestampAsDouble() {
        let entry = FriendshipQueries.Entry.from(id: "x", data: [
            "userId": "u", "isPending": false,
            "timestamp": Double(1_700_000_000)
        ])
        XCTAssertNotNil(entry)
    }

    func testEntryFallsBackTimestampWhenMissing() {
        let entry = FriendshipQueries.Entry.from(id: "x", data: [
            "userId": "u", "isPending": false
        ])
        XCTAssertNotNil(entry?.timestamp)
    }

    func testMutualFriendDetectedAcceptedOnly() {
        let entries = [
            FriendshipQueries.Entry(userId: "u1", isPending: false, timestamp: Date(), requesterId: nil),
            FriendshipQueries.Entry(userId: "u2", isPending: true, timestamp: Date(), requesterId: "me")
        ]
        XCTAssertTrue(FriendshipQueries.isMutualFriend(myFriendshipsContainsAcceptedFor: "u1", in: entries))
        XCTAssertFalse(FriendshipQueries.isMutualFriend(myFriendshipsContainsAcceptedFor: "u2", in: entries))
        XCTAssertFalse(FriendshipQueries.isMutualFriend(myFriendshipsContainsAcceptedFor: "ghost", in: entries))
    }

    func testMergeEntriesWithProfiles() {
        let entries = [
            FriendshipQueries.Entry(userId: "u1", isPending: false, timestamp: Date(), requesterId: nil),
            FriendshipQueries.Entry(userId: "u2", isPending: false, timestamp: Date(), requesterId: nil)
        ]
        let profileU1 = UserProfile(id: "u1", inviteCode: "X", email: nil,
                                    displayName: "User One", username: "u1",
                                    dateOfBirth: nil)
        let profiles = ["u1": profileU1]
        let merged = FriendshipQueries.mergeEntriesWithProfiles(entries: entries, profiles: profiles)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].profile?.displayName, "User One")
        XCTAssertNil(merged[1].profile, "u2 has no profile in lookup → nil")
    }
}

final class FriendshipQueriesFetchTests: XCTestCase {
    private var firestore: MockFirestoreClient!
    private var queries: FriendshipQueries!

    override func setUp() {
        super.setUp()
        firestore = MockFirestoreClient()
        queries = FriendshipQueries(firestore: firestore)
    }

    func testFetchFriendshipEntriesParsesResults() async throws {
        firestore.documents["users/me/friendships/u1"] = [
            "userId": "u1", "isPending": false, "timestamp": Date()
        ]
        firestore.documents["users/me/friendships/u2"] = [
            "userId": "u2", "isPending": true, "timestamp": Date(), "requesterId": "u2"
        ]
        let entries = try await queries.fetchFriendshipEntries(for: "me")
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.userId == "u1" && !$0.isPending })
        XCTAssertTrue(entries.contains { $0.userId == "u2" && $0.isPending })
    }

    func testFetchFriendshipEntriesEmptyForUserWithNoFriends() async throws {
        let entries = try await queries.fetchFriendshipEntries(for: "lonely_user")
        XCTAssertEqual(entries.count, 0)
    }

    func testFetchFriendshipEntriesSkipsMalformed() async throws {
        firestore.documents["users/me/friendships/good"] = [
            "userId": "u1", "isPending": false
        ]
        firestore.documents["users/me/friendships/bad"] = [
            // missing userId — should be filtered out
            "isPending": true
        ]
        let entries = try await queries.fetchFriendshipEntries(for: "me")
        XCTAssertEqual(entries.count, 1)
    }

    func testFetchProfilesEmptyInput() async throws {
        let result = try await queries.fetchProfiles(forUserIds: [])
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(firestore.queryDocumentsCalls, 0)
    }
}
