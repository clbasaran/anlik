import XCTest

/// Common base for all UI tests. Centralises:
/// - Reset state via `-ui-test-reset` launch arg
/// - Forced terminate-before-launch so tests don't inherit a previous state
/// - Cold-launch wait for foreground state
/// - Generous timeout helpers tolerant to simulator slowness
class UITestBase: XCTestCase {
    var app: XCUIApplication!

    /// Cold launch on simulator can take 15-25s. Anything past 40s is broken.
    let coldLaunchTimeout: TimeInterval = 40
    /// Any state transition (button appears after tap) should land within 8s.
    let interactionTimeout: TimeInterval = 8

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-ui-test-reset"]
        // Terminate any leftover instance so reset flag actually takes effect.
        app.terminate()
        app.launch()
        // Wait until app is actually foregrounded — prevents flaky "button not
        // found" errors when assertions run against a still-launching process.
        _ = app.wait(for: .runningForeground, timeout: coldLaunchTimeout)
    }

    override func tearDownWithError() throws {
        // Capture screenshot on failure for easier debugging
        if testRun?.hasSucceeded == false, let app {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.lifetime = .keepAlways
            attachment.name = "Failure-\(name)"
            add(attachment)
        }
        app?.terminate()
    }

    // MARK: - State checks

    /// Returns true if the app is currently showing the onboarding screen.
    func isOnboardingVisible() -> Bool {
        app.buttons["devam et"].waitForExistence(timeout: 3)
            || app.buttons["başla"].exists
    }

    /// Returns true if the app is currently showing the auth screen.
    func isAuthScreenVisible() -> Bool {
        let signupToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'kayıt'")).firstMatch
        let loginButton = app.buttons["giriş yap"]
        let demoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'önce bir bak'")).firstMatch
        return signupToggle.waitForExistence(timeout: 3)
            || loginButton.exists
            || demoButton.exists
    }

    /// Skip onboarding if visible. Returns true if we successfully reached the
    /// next screen (auth) — false if onboarding wasn't shown to begin with.
    @discardableResult
    func skipOnboardingIfShown() -> Bool {
        let skip = app.buttons["atla"]
        if skip.waitForExistence(timeout: coldLaunchTimeout) {
            skip.tap()
            return true
        }
        return false
    }

    /// Skip onboarding (if shown) AND wait for auth screen.
    /// Returns true if auth screen appeared, false otherwise.
    @discardableResult
    func reachAuthScreen() -> Bool {
        skipOnboardingIfShown()
        return isAuthScreenVisible()
    }
}
