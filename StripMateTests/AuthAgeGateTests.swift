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

        XCTAssertEqual(
            viewModel.errorMessage,
            "kayıt için en az \(AppLimits.minimumRegistrationAge) yaşında olmalısın."
        )
    }
}
