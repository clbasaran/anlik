import XCTest
@testable import StripMate

final class LegalDocumentLocalizationTests: XCTestCase {
    func testPrivacyPolicyReturnsSpanishCopy() {
        XCTAssertEqual(LegalDocument.privacyPolicy.title(for: "es-ES"), "Politica de privacidad")
        XCTAssertTrue(LegalDocument.privacyPolicy.content(for: "es-ES").contains("POLITICA DE PRIVACIDAD"))
        XCTAssertTrue(LegalDocument.privacyPolicy.content(for: "es-ES").contains("16 anos"))
    }

    func testTermsOfServiceReturnsSpanishCopy() {
        XCTAssertEqual(LegalDocument.termsOfService.title(for: "es-ES"), "Condiciones de uso")
        XCTAssertTrue(LegalDocument.termsOfService.content(for: "es-ES").contains("CONDICIONES DE USO"))
        XCTAssertTrue(LegalDocument.termsOfService.content(for: "es-ES").contains("16 anos"))
    }
}
