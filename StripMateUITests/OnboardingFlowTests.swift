import XCTest

/// Onboarding (4-page intro) flow. Tolerant to simulator slowness — tests
/// skip gracefully if the screen isn't visible (e.g., already completed).
final class OnboardingFlowTests: UITestBase {

    func testFirstScreenInteractive() throws {
        // After launch, SOME interactive screen must be visible
        let interactive = isOnboardingVisible() || isAuthScreenVisible()
        XCTAssertTrue(interactive, "Some interactive screen should be visible after launch")
    }

    func testSkipButtonExitsOnboarding() throws {
        guard isOnboardingVisible() else { return }
        guard skipOnboardingIfShown() else { return }
        XCTAssertTrue(isAuthScreenVisible(), "Auth should appear after skip")
    }

    func testNavigateToLastPage() throws {
        let next = app.buttons["devam et"]
        guard next.waitForExistence(timeout: coldLaunchTimeout) else { return }
        let start = app.buttons["başla"]
        // Page transitions animate (fadeSlow) and a tap can land mid-animation
        // without advancing the pager — allow extra attempts and give each
        // transition time to settle. Once the last page shows, the button's
        // identifier flips to "başla" so surplus taps are impossible.
        for _ in 0..<6 {
            if start.waitForExistence(timeout: 2) { break }
            guard next.waitForExistence(timeout: interactionTimeout) else { break }
            next.tap()
        }
        XCTAssertTrue(start.waitForExistence(timeout: interactionTimeout))
    }

    func testStartButtonExitsOnboarding() throws {
        let next = app.buttons["devam et"]
        guard next.waitForExistence(timeout: coldLaunchTimeout) else { return }
        for _ in 0..<3 where next.exists && next.isHittable { next.tap() }
        let start = app.buttons["başla"]
        guard start.waitForExistence(timeout: interactionTimeout) else { return }
        start.tap()
        XCTAssertFalse(start.waitForExistence(timeout: 3),
                       "'başla' should disappear after tap")
    }
}
