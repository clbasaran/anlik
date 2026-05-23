import XCTest
@testable import StripMate

// MARK: - StripQueryStore (FirestoreClient-backed)

final class StripQueryStoreTests: XCTestCase {
    private var firestore: MockFirestoreClient!
    private var store: StripQueryStore!

    override func setUp() {
        super.setUp()
        firestore = MockFirestoreClient()
        store = StripQueryStore(firestore: firestore)
    }

    func testFetchStripReturnsParsed() async throws {
        firestore.documents["strips/s1"] = [
            "id": "s1",
            "senderId": "u1",
            "receiverIds": ["a", "b"],
            "imageUrl": "https://x.com/i.jpg",
            "timestamp": Date()
        ]
        let p = try await store.fetchStrip(byId: "s1")
        XCTAssertNotNil(p)
        XCTAssertEqual(p?.id, "s1")
        XCTAssertEqual(p?.senderId, "u1")
    }

    func testFetchStripMissingReturnsNil() async throws {
        let p = try await store.fetchStrip(byId: "no_such")
        XCTAssertNil(p)
    }

    func testFetchInitialHistoryReturnsForUser() async throws {
        let now = Date()
        firestore.documents["strips/s1"] = [
            "id": "s1", "senderId": "u_other", "receiverIds": ["me"],
            "imageUrl": "https://x.com/1.jpg", "timestamp": now.addingTimeInterval(-100)
        ]
        firestore.documents["strips/s2"] = [
            "id": "s2", "senderId": "u_other", "receiverIds": ["me"],
            "imageUrl": "https://x.com/2.jpg", "timestamp": now
        ]
        firestore.documents["strips/s3_other_user"] = [
            "id": "s3", "senderId": "u_other", "receiverIds": ["someone_else"],
            "imageUrl": "https://x.com/3.jpg", "timestamp": now
        ]
        let strips = try await store.fetchInitialHistory(for: "me", limit: 10)
        XCTAssertEqual(strips.count, 2)
        // Most recent first (descending timestamp)
        XCTAssertEqual(strips[0].id, "s2")
        XCTAssertEqual(strips[1].id, "s1")
    }

    func testFetchInitialHistoryRespectsLimit() async throws {
        for i in 0..<10 {
            firestore.documents["strips/s\(i)"] = [
                "id": "s\(i)", "senderId": "u", "receiverIds": ["me"],
                "imageUrl": "https://x.com/\(i).jpg",
                "timestamp": Date().addingTimeInterval(-Double(i))
            ]
        }
        let strips = try await store.fetchInitialHistory(for: "me", limit: 3)
        XCTAssertEqual(strips.count, 3)
    }

    func testResetCursorClearsLastTimestamp() async {
        // No public way to inspect cursor — just verify it doesn't crash
        await store.resetCursor()
    }
}

// MARK: - Pure filter helpers

final class StripFilterHelperTests: XCTestCase {
    private func strip(_ id: String, sender: String, flagged: Bool = false) -> PhotoMetadata {
        PhotoMetadata(
            id: id,
            senderId: sender,
            receiverIds: ["me", sender],
            imageUrl: "https://x",
            timestamp: Date(),
            flagged: flagged
        )
    }

    func testFilterRemovesBlockedSenders() {
        let strips = [
            strip("a", sender: "good"),
            strip("b", sender: "blocked"),
            strip("c", sender: "good2")
        ]
        let visible = StripQueryStore.filterVisible(photos: strips, blockedIds: ["blocked"])
        XCTAssertEqual(visible.map(\.id), ["a", "c"])
    }

    func testFilterRemovesFlagged() {
        let strips = [
            strip("a", sender: "u", flagged: false),
            strip("b", sender: "u", flagged: true)
        ]
        let visible = StripQueryStore.filterVisible(photos: strips, blockedIds: [])
        XCTAssertEqual(visible.map(\.id), ["a"])
    }

    func testFilterPreservesEmptyBlockSet() {
        let strips = [strip("a", sender: "u")]
        let visible = StripQueryStore.filterVisible(photos: strips, blockedIds: [])
        XCTAssertEqual(visible.count, 1)
    }

    func testWidgetTargetPrefersPinnedFriend() {
        let strips = [
            strip("a", sender: "other"),
            strip("b", sender: "pinned"),
            strip("c", sender: "another")
        ]
        let target = StripQueryStore.widgetTargetPhoto(
            from: strips, viewerId: "me", pinnedFriendId: "pinned"
        )
        XCTAssertEqual(target?.senderId, "pinned")
    }

    func testWidgetTargetFallsBackToFirstNonViewer() {
        let strips = [
            strip("a", sender: "me"),       // viewer's own — skipped
            strip("b", sender: "friend"),
            strip("c", sender: "another")
        ]
        let target = StripQueryStore.widgetTargetPhoto(
            from: strips, viewerId: "me", pinnedFriendId: nil
        )
        XCTAssertEqual(target?.senderId, "friend")
    }

    func testWidgetTargetIgnoresEmptyPinnedId() {
        let strips = [
            strip("b", sender: "friend"),
            strip("c", sender: "another")
        ]
        let target = StripQueryStore.widgetTargetPhoto(
            from: strips, viewerId: "me", pinnedFriendId: ""
        )
        XCTAssertEqual(target?.senderId, "friend")
    }

    func testWidgetTargetNilWhenAllAreViewerOwn() {
        let strips = [
            strip("a", sender: "me"),
            strip("b", sender: "me")
        ]
        let target = StripQueryStore.widgetTargetPhoto(
            from: strips, viewerId: "me", pinnedFriendId: nil
        )
        XCTAssertNil(target)
    }

    func testWidgetTargetNilWhenNoStrips() {
        let target = StripQueryStore.widgetTargetPhoto(
            from: [], viewerId: "me", pinnedFriendId: nil
        )
        XCTAssertNil(target)
    }
}

// MARK: - MockStorageClient (sanity tests)

private final class MockStorageClient: StorageClient, @unchecked Sendable {
    var uploads: [String: Data] = [:]
    var deletions: [String] = []
    var nextUploadError: Error?
    var nextDeleteError: Error?

    func uploadData(_ data: Data, to path: String, contentType: String?) async throws -> String {
        if let err = nextUploadError { nextUploadError = nil; throw err }
        uploads[path] = data
        return "https://mock-storage.example.com/\(path)"
    }

    func deleteObject(at path: String) async throws {
        if let err = nextDeleteError { nextDeleteError = nil; throw err }
        deletions.append(path)
        uploads.removeValue(forKey: path)
    }

    func downloadURL(for path: String) async throws -> String {
        guard uploads[path] != nil else {
            throw NSError(domain: "Mock", code: 404)
        }
        return "https://mock-storage.example.com/\(path)"
    }
}

final class StorageClientContractTests: XCTestCase {
    func testUploadReturnsURL() async throws {
        let storage = MockStorageClient()
        let url = try await storage.uploadData(Data([0x01]), to: "x/y.jpg", contentType: "image/jpeg")
        XCTAssertTrue(url.contains("x/y.jpg"))
        XCTAssertEqual(storage.uploads["x/y.jpg"]?.count, 1)
    }

    func testUploadPropagatesError() async {
        let storage = MockStorageClient()
        struct Err: Error {}
        storage.nextUploadError = Err()
        do {
            _ = try await storage.uploadData(Data([0]), to: "x", contentType: nil)
            XCTFail("Expected error")
        } catch is Err {
            // ok
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testDeleteRemovesPath() async throws {
        let storage = MockStorageClient()
        _ = try await storage.uploadData(Data([0]), to: "x", contentType: nil)
        try await storage.deleteObject(at: "x")
        XCTAssertEqual(storage.deletions, ["x"])
        XCTAssertNil(storage.uploads["x"])
    }

    func testDownloadURLForMissingThrows() async {
        let storage = MockStorageClient()
        do {
            _ = try await storage.downloadURL(for: "no")
            XCTFail("Expected error")
        } catch {
            // ok
        }
    }
}
