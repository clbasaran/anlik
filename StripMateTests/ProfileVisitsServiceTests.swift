import XCTest
@testable import StripMate

final class ProfileVisitsServiceTests: XCTestCase {

    /// Tracks every write attempt the service made — tests assert on count
    /// + contents to verify gating logic.
    private actor WriteRecorder {
        private(set) var writes: [[String: Any]] = []
        func append(_ data: [String: Any]) -> Bool {
            writes.append(data)
            return true
        }
        var count: Int { writes.count }
        func sourceAt(_ idx: Int) -> String? {
            guard idx < writes.count else { return nil }
            return writes[idx]["source"] as? String
        }
        func visitorAt(_ idx: Int) -> String? {
            guard idx < writes.count else { return nil }
            return writes[idx]["visitorId"] as? String
        }
        func profileAt(_ idx: Int) -> String? {
            guard idx < writes.count else { return nil }
            return writes[idx]["profileId"] as? String
        }
    }

    private func makeService(
        throttleWindow: TimeInterval = 5 * 60,
        blockedIds: Set<String> = [],
        visitorBlockedByProfile: Bool = false,
        recorder: WriteRecorder
    ) -> ProfileVisitsService {
        ProfileVisitsService(
            throttleWindow: throttleWindow,
            blockedIdsProvider: { blockedIds },
            visitorIsBlockedByProfile: { _, _ in visitorBlockedByProfile },
            writeRecord: { data in await recorder.append(data) }
        )
    }

    // MARK: - Self-visit

    func testSelfVisit_isNotWritten() async {
        let recorder = WriteRecorder()
        let service = makeService(recorder: recorder)
        await service.recordVisit(visitorId: "u1", profileId: "u1", source: .feed)
        let count = await recorder.count
        XCTAssertEqual(count, 0, "Visiting your own profile must not be recorded")
    }

    func testEmptyIds_areNotWritten() async {
        let recorder = WriteRecorder()
        let service = makeService(recorder: recorder)
        await service.recordVisit(visitorId: "", profileId: "u2", source: .feed)
        await service.recordVisit(visitorId: "u1", profileId: "", source: .feed)
        let count = await recorder.count
        XCTAssertEqual(count, 0)
    }

    // MARK: - Throttle

    func testFirstVisit_isWritten() async {
        let recorder = WriteRecorder()
        let service = makeService(recorder: recorder)
        await service.recordVisit(visitorId: "u1", profileId: "u2", source: .search)
        let count = await recorder.count
        let source = await recorder.sourceAt(0)
        XCTAssertEqual(count, 1)
        XCTAssertEqual(source, "search")
    }

    func testSamePairWithinWindow_isThrottled() async {
        let recorder = WriteRecorder()
        let service = makeService(throttleWindow: 60 * 60, recorder: recorder) // 1h
        await service.recordVisit(visitorId: "u1", profileId: "u2", source: .feed)
        await service.recordVisit(visitorId: "u1", profileId: "u2", source: .feed)
        await service.recordVisit(visitorId: "u1", profileId: "u2", source: .list)
        let count = await recorder.count
        XCTAssertEqual(count, 1, "Repeat visits within the throttle window must be skipped")
    }

    func testThrottleIsPerPair() async {
        let recorder = WriteRecorder()
        let service = makeService(recorder: recorder)
        await service.recordVisit(visitorId: "u1", profileId: "u2", source: .feed)
        await service.recordVisit(visitorId: "u1", profileId: "u3", source: .feed)
        await service.recordVisit(visitorId: "u4", profileId: "u2", source: .feed)
        let count = await recorder.count
        XCTAssertEqual(count, 3, "Throttle scope must be (visitor, profile) — different pairs are independent")
    }

    func testZeroWindow_doesNotThrottle() async {
        let recorder = WriteRecorder()
        let service = makeService(throttleWindow: 0, recorder: recorder)
        await service.recordVisit(visitorId: "u1", profileId: "u2", source: .feed)
        await service.recordVisit(visitorId: "u1", profileId: "u2", source: .feed)
        let count = await recorder.count
        XCTAssertEqual(count, 2, "With zero throttle window every call writes")
    }

    // MARK: - Block check

    func testProfileBlockedByVisitor_isNotWritten() async {
        let recorder = WriteRecorder()
        let service = makeService(blockedIds: ["u2"], recorder: recorder)
        await service.recordVisit(visitorId: "u1", profileId: "u2", source: .feed)
        let count = await recorder.count
        XCTAssertEqual(count, 0, "If visitor has blocked the profile owner, no visit is recorded")
    }

    func testVisitorBlockedByProfile_isNotWritten() async {
        let recorder = WriteRecorder()
        let service = makeService(visitorBlockedByProfile: true, recorder: recorder)
        await service.recordVisit(visitorId: "u1", profileId: "u2", source: .feed)
        let count = await recorder.count
        XCTAssertEqual(count, 0, "If profile owner has blocked visitor, no visit is recorded")
    }
}
