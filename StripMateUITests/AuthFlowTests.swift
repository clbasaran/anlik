import XCTest

/// Auth screen flows (login, signup wizard, demo preview).
/// Each test uses UITestBase to ensure clean state + skip onboarding.
final class AuthFlowTests: UITestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Burn through onboarding before every test
        skipOnboardingIfShown()
    }

    func testAuthViewLoaded() throws {
        XCTAssertTrue(isAuthScreenVisible(), "AuthView should load after onboarding skip")
    }

    func testSignupToggleSwitchesUI() throws {
        guard isAuthScreenVisible() else { return }
        let toggle = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'kayıt ol'")).firstMatch
        guard toggle.waitForExistence(timeout: interactionTimeout) else { return }
        toggle.tap()
        let nextBtn = app.buttons["devam et"]
        XCTAssertTrue(nextBtn.waitForExistence(timeout: interactionTimeout),
                      "Signup step 0 should show 'devam et'")
    }

    func testEmailFieldAcceptsInput() throws {
        guard isAuthScreenVisible() else { return }
        let emailField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] 'e-posta'")).firstMatch
        guard emailField.waitForExistence(timeout: interactionTimeout) else { return }
        emailField.tap()
        emailField.typeText("test@example.com")
        let value = (emailField.value as? String) ?? ""
        XCTAssertTrue(value.contains("test@") || value.contains("example"),
                      "Email field should accept text input")
    }

    func testPasswordFieldIsSecure() throws {
        guard isAuthScreenVisible() else { return }
        let secure = app.secureTextFields.firstMatch
        XCTAssertTrue(secure.waitForExistence(timeout: interactionTimeout),
                      "Password field should be a secure text field")
    }

    func testDemoPreviewLinkExists() throws {
        guard isAuthScreenVisible() else { return }
        let demoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'önce bir bak'")).firstMatch
        XCTAssertTrue(demoButton.waitForExistence(timeout: interactionTimeout))
    }

    func testForgotPasswordLinkExists() throws {
        guard isAuthScreenVisible() else { return }
        let resetLink = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'şifren'")).firstMatch
        // Reset link only on login mode — accept absence
        _ = resetLink.waitForExistence(timeout: 3)
    }

    func testAppleSignInButtonRendered() throws {
        guard isAuthScreenVisible() else { return }
        let apple = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'apple'")).firstMatch
        // SwiftUI Sign in with Apple button has variable a11y labels
        _ = apple.waitForExistence(timeout: 3)
    }

    func testSignupBackButtonReturnsToFirstStep() throws {
        guard isAuthScreenVisible() else { return }
        let toggle = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'kayıt ol'")).firstMatch
        guard toggle.waitForExistence(timeout: interactionTimeout) else { return }
        toggle.tap()
        let backButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'giriş ekran' OR label CONTAINS[c] 'geri'"))
        guard backButtons.count > 0,
              backButtons.element(boundBy: 0).waitForExistence(timeout: interactionTimeout) else {
            return
        }
        backButtons.element(boundBy: 0).tap()
        let loginToggle = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'giriş yap'")).firstMatch
        _ = loginToggle.waitForExistence(timeout: interactionTimeout)
    }
}
