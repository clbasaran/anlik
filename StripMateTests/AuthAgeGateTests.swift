import XCTest
@testable import StripMate

@MainActor
final class AuthAgeGateTests: XCTestCase {
    func testSignupRejectsUsersYoungerThan16() async {
        let viewModel = AuthViewModel()
        viewModel.isSignUp = true
        viewModel.email = "test@example.com"
        viewModel.password = "123456"
        viewModel.displayName = "Test"
        viewModel.username = "testuser"
        viewModel.dateOfBirth = Calendar.current.date(byAdding: .year, value: -15, to: Date())!

        await viewModel.authenticate()

        // Compare against the localized string so the assertion holds in every
        // test-runner locale (the message is now translated to en/es-ES too).
        XCTAssertEqual(
            viewModel.errorMessage,
            String(localized: "kayıt için en az \(AppLimits.minimumRegistrationAge) yaşında olmalısın.")
        )
    }
}
