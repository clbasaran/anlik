import XCTest
@testable import StripMate

final class AppLimitsTests: XCTestCase {
    func testFriendLimitsAreReasonable() {
        XCTAssertGreaterThan(AppLimits.maxFriends, 0)
        XCTAssertLessThanOrEqual(AppLimits.maxFriends, 200)
    }

    func testContentLimitsAreReasonable() {
        XCTAssertGreaterThan(AppLimits.messageMaxLength, 0)
        XCTAssertGreaterThan(AppLimits.commentMaxLength, 0)
        XCTAssertGreaterThan(AppLimits.bioMaxLength, 0)
    }

    func testImageQualityIsInRange() {
        XCTAssertGreaterThan(AppLimits.jpegQuality, 0)
        XCTAssertLessThanOrEqual(AppLimits.jpegQuality, 1.0)
    }

    func testPaginationSizes() {
        XCTAssertGreaterThan(AppLimits.pageSize, 0)
        XCTAssertGreaterThanOrEqual(AppLimits.initialLoadSize, AppLimits.pageSize)
    }

    func testSpainMinimumRegistrationAgeIs16() {
        XCTAssertEqual(AppLimits.minimumRegistrationAge, 16)
    }
}
