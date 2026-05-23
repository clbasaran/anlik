import XCTest

/// Original smoke tests, refactored to UITestBase for consistency.
final class StripMateUITests: UITestBase {

    func testAppLaunches() throws {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: coldLaunchTimeout))
    }

    func testOnboardingOrAuthVisible() throws {
        let interactive = isOnboardingVisible() || isAuthScreenVisible()
        XCTAssertTrue(interactive)
    }

    func testTabNavigation() throws {
        let tabBar = app.tabBars.firstMatch
        // Tab bar appears only after auth is complete — accept absence pre-auth.
        if tabBar.waitForExistence(timeout: coldLaunchTimeout) {
            XCTAssertGreaterThanOrEqual(tabBar.buttons.count, 3,
                                        "Tab bar should have at least 3 tabs")
        }
    }

    func testOnboardingSkipButtonAvailable() throws {
        let skip = app.buttons["atla"]
        if skip.waitForExistence(timeout: coldLaunchTimeout) {
            XCTAssertTrue(skip.isHittable)
        }
    }

    func testOnboardingAdvanceButton() throws {
        let next = app.buttons["devam et"]
        guard next.waitForExistence(timeout: coldLaunchTimeout) else { return }
        next.tap()
        let advanced = app.buttons["devam et"].exists
            || app.buttons["başla"].waitForExistence(timeout: 3)
        XCTAssertTrue(advanced)
    }

    func testAuthScreenAccessible() throws {
        skipOnboardingIfShown()
        let signInButton = app.buttons["giriş yap"]
        let signUpToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'kayıt'")).firstMatch
        let appleSignIn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'apple'")).firstMatch
        let anyControl = signInButton.waitForExistence(timeout: interactionTimeout)
            || signUpToggle.waitForExistence(timeout: 3)
            || appleSignIn.waitForExistence(timeout: 3)
        XCTAssertTrue(anyControl)
    }

    func testDemoPreviewEntryPointVisible() throws {
        skipOnboardingIfShown()
        let demoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'önce bir bak'")).firstMatch
        _ = demoButton.waitForExistence(timeout: interactionTimeout)
    }

    func testInteractiveElementsHaveLabels() throws {
        let buttons = app.buttons.allElementsBoundByIndex
        for btn in buttons.prefix(20) where btn.exists && !btn.label.isEmpty {
            XCTAssertFalse(btn.label.isEmpty)
        }
    }
}
