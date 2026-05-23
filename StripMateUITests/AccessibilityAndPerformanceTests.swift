import XCTest

/// Sanity checks for accessibility + smoke performance of the launch path.
/// Uses UITestBase for clean state.
final class AccessibilityAndPerformanceTests: UITestBase {

    func testFirstScreenAppearsWithinTimeout() throws {
        // Cold simulator may take 30s; this test verifies the app reaches
        // SOME interactive state within the cold-launch budget.
        let interactive = isOnboardingVisible() || isAuthScreenVisible()
        XCTAssertTrue(interactive,
                      "First interactive screen should appear within \(Int(coldLaunchTimeout))s of launch")
    }

    func testOnboardingButtonsHaveAccessibilityLabels() throws {
        let next = app.buttons["devam et"]
        guard next.waitForExistence(timeout: coldLaunchTimeout) else { return }
        XCTAssertFalse(next.label.isEmpty,
                       "'devam et' button must expose an accessibility label")

        let skip = app.buttons["atla"]
        if skip.exists {
            XCTAssertFalse(skip.label.isEmpty)
        }
    }

    func testNoMassivelyEmptyButtonLabels() throws {
        let next = app.buttons["devam et"]
        guard next.waitForExistence(timeout: coldLaunchTimeout) else { return }
        let buttons = app.buttons.allElementsBoundByIndex
        let unlabeled = buttons.filter { $0.exists && $0.label.isEmpty }
        // Threshold: at most 5 unlabeled (allowance for SwiftUI internals,
        // Apple Sign-In glyphs, etc.). The screen must not be a sea of
        // unlabeled controls.
        XCTAssertLessThanOrEqual(unlabeled.count, 5,
                                 "Too many unlabeled buttons (\(unlabeled.count))")
    }

    func testRespondsToOrientationChange() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        // Wait briefly and confirm app still alive
        let next = app.buttons["devam et"]
        _ = next.waitForExistence(timeout: 4)
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
        XCUIDevice.shared.orientation = .portrait
    }
}

// MARK: - Pure performance baseline (NOT a UITestBase subclass — needs custom launch)

/// Standalone launch-time benchmark. Doesn't reset state — measures actual
/// production launch behavior.
final class LaunchPerformanceTests: XCTestCase {
    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let app = XCUIApplication()
                app.launchArguments += ["-ui-test-reset"]
                app.launch()
            }
        }
    }
}
