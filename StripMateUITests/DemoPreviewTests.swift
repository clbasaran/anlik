import XCTest

/// Demo preview flow — pre-auth peek at sample feed.
final class DemoPreviewTests: UITestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        skipOnboardingIfShown()
    }

    private func openDemo() -> Bool {
        guard isAuthScreenVisible() else { return false }
        let demoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'önce bir bak'")).firstMatch
        guard demoButton.waitForExistence(timeout: interactionTimeout) else { return false }
        demoButton.tap()
        return true
    }

    func testDemoPreviewOpensFromAuth() throws {
        guard openDemo() else { return }
        let header = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'örnek akış' OR label CONTAINS[c] 'anlık'")
        ).firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: interactionTimeout))
    }

    func testDemoPreviewHasContinueCTA() throws {
        guard openDemo() else { return }
        let cta = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'giriş yap'")).firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: interactionTimeout))
    }

    func testDemoPreviewCloseReturnsToAuth() throws {
        guard openDemo() else { return }
        let cta = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'giriş yap'")).firstMatch
        guard cta.waitForExistence(timeout: interactionTimeout) else { return }
        cta.tap()
        let toggle = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'kayıt ol'")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: interactionTimeout))
    }

    func testDemoPreviewSwipesThroughSamples() throws {
        guard openDemo() else { return }
        // Sample cards via TabView page indicator
        let firstCard = app.images.firstMatch
        if firstCard.waitForExistence(timeout: interactionTimeout) {
            app.swipeLeft()
            app.swipeLeft()
        }
        let cta = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'giriş yap'")).firstMatch
        XCTAssertTrue(cta.exists)
    }
}
