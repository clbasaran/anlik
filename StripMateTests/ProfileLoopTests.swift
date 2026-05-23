import XCTest
@testable import StripMate

// MARK: - ProfileLoop model

final class ProfileLoopModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testInitialization() {
        let loop = ProfileLoop(
            id: "slot_0", slot: 0,
            videoUrl: "https://x.com/v.mp4",
            thumbnailUrl: "https://x.com/t.jpg",
            duration: 3.2,
            isBoomerang: true,
            createdAt: now
        )
        XCTAssertEqual(loop.id, "slot_0")
        XCTAssertEqual(loop.slot, 0)
        XCTAssertTrue(loop.isBoomerang)
        XCTAssertEqual(loop.duration, 3.2)
    }

    func testIdForSlot() {
        XCTAssertEqual(ProfileLoop.id(forSlot: 0), "slot_0")
        XCTAssertEqual(ProfileLoop.id(forSlot: 1), "slot_1")
        XCTAssertEqual(ProfileLoop.id(forSlot: 2), "slot_2")
    }

    func testRoundTripDictionary() {
        let original = ProfileLoop(
            id: "slot_1", slot: 1,
            videoUrl: "https://x.com/v.mp4",
            thumbnailUrl: "https://x.com/t.jpg",
            duration: 2.5,
            isBoomerang: false,
            createdAt: now
        )
        let dict = original.asDictionary
        let parsed = ProfileLoop.from(dict)
        XCTAssertEqual(parsed?.id, original.id)
        XCTAssertEqual(parsed?.slot, original.slot)
        XCTAssertEqual(parsed?.videoUrl, original.videoUrl)
        XCTAssertEqual(parsed?.thumbnailUrl, original.thumbnailUrl)
        XCTAssertEqual(parsed?.duration, original.duration)
        XCTAssertEqual(parsed?.isBoomerang, original.isBoomerang)
    }

    func testFromMissingRequiredFieldReturnsNil() {
        XCTAssertNil(ProfileLoop.from(["id": "x"]))
        XCTAssertNil(ProfileLoop.from(["id": "x", "slot": 0]))
        XCTAssertNil(ProfileLoop.from(["id": "x", "slot": 0, "videoUrl": "u"]))
        // No duration → nil
        XCTAssertNil(ProfileLoop.from(["id": "x", "slot": 0, "videoUrl": "u", "thumbnailUrl": "t"]))
    }

    func testFromTimestampVariants() {
        let asDouble: [String: Any] = [
            "id": "x", "slot": 0, "videoUrl": "u",
            "duration": 1.0, "createdAt": Double(1_700_000_000)
        ]
        XCTAssertNotNil(ProfileLoop.from(asDouble)?.createdAt)

        let asDate: [String: Any] = [
            "id": "x", "slot": 0, "videoUrl": "u",
            "duration": 1.0, "createdAt": Date()
        ]
        XCTAssertNotNil(ProfileLoop.from(asDate)?.createdAt)
    }

    func testThumbnailOptional() {
        let dict: [String: Any] = [
            "id": "x", "slot": 0, "videoUrl": "u", "duration": 2.0
        ]
        let loop = ProfileLoop.from(dict)
        XCTAssertNotNil(loop)
        XCTAssertNil(loop?.thumbnailUrl)
    }
}

// MARK: - ProfileLoopService pure helpers

final class ProfileLoopServicePureTests: XCTestCase {
    private func loop(_ slot: Int) -> ProfileLoop {
        ProfileLoop(id: ProfileLoop.id(forSlot: slot), slot: slot,
                    videoUrl: "u", duration: 2.0)
    }

    func testReplaceAddsNewLoop() {
        let result = ProfileLoopService.replace(loops: [], slot: 0, with: loop(0))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].slot, 0)
    }

    func testReplaceReplacesExistingSlot() {
        let initial = [loop(0), loop(1)]
        let new = ProfileLoop(id: "slot_0", slot: 0, videoUrl: "new", duration: 3.0)
        let result = ProfileLoopService.replace(loops: initial, slot: 0, with: new)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.first(where: { $0.slot == 0 })?.videoUrl, "new")
    }

    func testReplaceRemovesWhenNil() {
        let initial = [loop(0), loop(1), loop(2)]
        let result = ProfileLoopService.replace(loops: initial, slot: 1, with: nil)
        XCTAssertEqual(result.count, 2)
        XCTAssertFalse(result.contains(where: { $0.slot == 1 }))
    }

    func testReplaceSortsBySlot() {
        let initial = [loop(2), loop(0)]
        let result = ProfileLoopService.replace(loops: initial, slot: 1, with: loop(1))
        XCTAssertEqual(result.map(\.slot), [0, 1, 2])
    }

    func testNextFreeSlotEmpty() {
        XCTAssertEqual(ProfileLoopService.nextFreeSlot(in: []), 0)
    }

    func testNextFreeSlotPartial() {
        XCTAssertEqual(ProfileLoopService.nextFreeSlot(in: [loop(0)]), 1)
        XCTAssertEqual(ProfileLoopService.nextFreeSlot(in: [loop(0), loop(2)]), 1)
    }

    func testNextFreeSlotFull() {
        let full = [loop(0), loop(1), loop(2)]
        XCTAssertNil(ProfileLoopService.nextFreeSlot(in: full))
    }

    func testValidateSlotRejectsOutOfRange() {
        XCTAssertThrowsError(try ProfileLoopService.validateSlot(-1))
        XCTAssertThrowsError(try ProfileLoopService.validateSlot(3))
        XCTAssertThrowsError(try ProfileLoopService.validateSlot(99))
    }

    func testValidateSlotAcceptsInRange() {
        XCTAssertNoThrow(try ProfileLoopService.validateSlot(0))
        XCTAssertNoThrow(try ProfileLoopService.validateSlot(1))
        XCTAssertNoThrow(try ProfileLoopService.validateSlot(2))
    }

    func testValidateSizeAcceptsUnderLimit() {
        XCTAssertNoThrow(try ProfileLoopService.validateSize(1024))
        XCTAssertNoThrow(try ProfileLoopService.validateSize(8 * 1024 * 1024))
    }

    func testValidateSizeRejectsOverLimit() {
        XCTAssertThrowsError(try ProfileLoopService.validateSize(8 * 1024 * 1024 + 1))
    }

    func testExtractLoopsEmpty() {
        XCTAssertEqual(ProfileLoopService.extractLoops(from: [:]).count, 0)
        XCTAssertEqual(ProfileLoopService.extractLoops(from: ["profileLoops": []]).count, 0)
    }

    func testExtractLoopsSorted() {
        let data: [String: Any] = [
            "profileLoops": [
                ["id": "slot_2", "slot": 2, "videoUrl": "u2", "duration": 3.0],
                ["id": "slot_0", "slot": 0, "videoUrl": "u0", "duration": 2.0]
            ]
        ]
        let loops = ProfileLoopService.extractLoops(from: data)
        XCTAssertEqual(loops.map(\.slot), [0, 2])
    }

    func testExtractLoopsSkipsMalformed() {
        let data: [String: Any] = [
            "profileLoops": [
                ["id": "slot_0", "slot": 0, "videoUrl": "u", "duration": 2.0],  // valid
                ["id": "x"],  // malformed
                ["slot": 1, "videoUrl": "u", "duration": 2.0]  // missing id
            ]
        ]
        let loops = ProfileLoopService.extractLoops(from: data)
        XCTAssertEqual(loops.count, 1)
    }
}

// MARK: - ProfileLoopService with mocks

final class ProfileLoopServiceUploadTests: XCTestCase {
    private var firestore: MockFirestoreClient!
    private var storage: MockProfileLoopStorage!
    private var service: ProfileLoopService!

    override func setUp() {
        super.setUp()
        firestore = MockFirestoreClient()
        storage = MockProfileLoopStorage()
        service = ProfileLoopService(storage: storage, firestore: firestore)
    }

    func testUploadWritesVideoToStorage() async throws {
        firestore.documents["users/uid"] = ["inviteCode": "X"]
        let videoData = Data(repeating: 0xAB, count: 1024)
        _ = try await service.uploadLoop(
            userId: "uid", slot: 0,
            videoData: videoData, thumbnailData: nil,
            duration: 2.5, isBoomerang: true
        )
        XCTAssertEqual(storage.uploads["profile_loops/uid_0.mp4"], videoData)
    }

    func testUploadWritesThumbnailWhenProvided() async throws {
        firestore.documents["users/uid"] = ["inviteCode": "X"]
        let thumb = Data([0x01, 0x02, 0x03])
        _ = try await service.uploadLoop(
            userId: "uid", slot: 1,
            videoData: Data([0x10]), thumbnailData: thumb,
            duration: 2.0, isBoomerang: false
        )
        XCTAssertEqual(storage.uploads["profile_loops/thumbs/uid_1.jpg"], thumb)
    }

    func testUploadUpdatesUserDoc() async throws {
        firestore.documents["users/uid"] = ["inviteCode": "X"]
        _ = try await service.uploadLoop(
            userId: "uid", slot: 0,
            videoData: Data([0x10]), thumbnailData: nil,
            duration: 2.0, isBoomerang: true
        )
        let userDoc = firestore.documents["users/uid"]
        let loops = userDoc?["profileLoops"] as? [[String: Any]]
        XCTAssertEqual(loops?.count, 1)
        XCTAssertEqual(loops?.first?["slot"] as? Int, 0)
    }

    func testUploadRejectsInvalidSlot() async {
        do {
            _ = try await service.uploadLoop(
                userId: "uid", slot: 5,
                videoData: Data([0x10]), thumbnailData: nil,
                duration: 2.0, isBoomerang: false
            )
            XCTFail("Expected slotOutOfRange")
        } catch is ProfileLoopService.Error {
            // ok
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testUploadRejectsTooLargeFile() async {
        firestore.documents["users/uid"] = ["inviteCode": "X"]
        let big = Data(count: 10 * 1024 * 1024)
        do {
            _ = try await service.uploadLoop(
                userId: "uid", slot: 0,
                videoData: big, thumbnailData: nil,
                duration: 2.0, isBoomerang: false
            )
            XCTFail("Expected fileTooLarge")
        } catch is ProfileLoopService.Error {
            // ok
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    func testDeleteRemovesStorageObjects() async throws {
        firestore.documents["users/uid"] = [
            "inviteCode": "X",
            "profileLoops": [
                ["id": "slot_0", "slot": 0, "videoUrl": "u", "duration": 2.0]
            ]
        ]
        // Pre-populate storage
        _ = try await storage.uploadData(Data([0x10]), to: "profile_loops/uid_0.mp4", contentType: "video/mp4")
        try await service.deleteLoop(userId: "uid", slot: 0)
        XCTAssertNil(storage.uploads["profile_loops/uid_0.mp4"])
    }

    func testFetchLoopsParsesArray() async throws {
        firestore.documents["users/uid"] = [
            "profileLoops": [
                ["id": "slot_0", "slot": 0, "videoUrl": "u0", "duration": 2.0],
                ["id": "slot_1", "slot": 1, "videoUrl": "u1", "duration": 3.0]
            ]
        ]
        let loops = try await service.fetchLoops(userId: "uid")
        XCTAssertEqual(loops.count, 2)
    }

    func testFetchLoopsEmptyForMissingUser() async throws {
        let loops = try await service.fetchLoops(userId: "nope")
        XCTAssertEqual(loops.count, 0)
    }
}

// MARK: - Mock storage for ProfileLoopService tests

private final class MockProfileLoopStorage: StorageClient, @unchecked Sendable {
    var uploads: [String: Data] = [:]
    var deletions: [String] = []

    func uploadData(_ data: Data, to path: String, contentType: String?) async throws -> String {
        uploads[path] = data
        return "https://mock-storage.example.com/\(path)"
    }

    func deleteObject(at path: String) async throws {
        deletions.append(path)
        uploads.removeValue(forKey: path)
    }

    func downloadURL(for path: String) async throws -> String {
        guard uploads[path] != nil else { throw NSError(domain: "Mock", code: 404) }
        return "https://mock-storage.example.com/\(path)"
    }
}
