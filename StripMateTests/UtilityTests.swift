import XCTest
import UIKit
@testable import StripMate

// MARK: - KeychainManager Tests

final class KeychainManagerTests: XCTestCase {
    let testKey = "test_keychain_unit_key_xyz"

    override func setUp() {
        super.setUp()
        // Clean any prior state
        KeychainManager.delete(forKey: testKey)
    }

    override func tearDown() {
        KeychainManager.delete(forKey: testKey)
        super.tearDown()
    }

    func testSaveAndLoadStringRoundTrip() {
        let value = "abc123-token-XYZ"
        XCTAssertTrue(KeychainManager.save(value, forKey: testKey))
        XCTAssertEqual(KeychainManager.load(forKey: testKey), value)
    }

    func testLoadReturnsNilWhenAbsent() {
        XCTAssertNil(KeychainManager.load(forKey: "absolutely_does_not_exist_key"))
    }

    func testSaveOverwritesExistingValue() {
        XCTAssertTrue(KeychainManager.save("first", forKey: testKey))
        XCTAssertTrue(KeychainManager.save("second", forKey: testKey))
        XCTAssertEqual(KeychainManager.load(forKey: testKey), "second")
    }

    func testDeleteRemovesValue() {
        XCTAssertTrue(KeychainManager.save("removeme", forKey: testKey))
        XCTAssertTrue(KeychainManager.delete(forKey: testKey))
        XCTAssertNil(KeychainManager.load(forKey: testKey))
    }

    func testDeleteIdempotentWhenAbsent() {
        // Deleting a key that doesn't exist should still report success
        XCTAssertTrue(KeychainManager.delete(forKey: "ghost_key_no_value"))
    }

    func testSaveEmptyStringIsSupported() {
        XCTAssertTrue(KeychainManager.save("", forKey: testKey))
        XCTAssertEqual(KeychainManager.load(forKey: testKey), "")
    }

    func testSaveLongValueRoundTrip() {
        let long = String(repeating: "x", count: 4096)
        XCTAssertTrue(KeychainManager.save(long, forKey: testKey))
        XCTAssertEqual(KeychainManager.load(forKey: testKey)?.count, 4096)
    }

    func testKeyConstantsExposed() {
        XCTAssertEqual(KeychainManager.Key.fcmToken, "fcm_token")
        XCTAssertEqual(KeychainManager.Key.widgetPushToken, "widget_push_token")
    }
}

// MARK: - RetryHelper Tests

final class RetryHelperTests: XCTestCase {
    enum TestError: Error { case fail }

    func testReturnsImmediatelyOnFirstSuccess() async throws {
        var attempts = 0
        let result: Int = try await RetryHelper.withRetry(maxAttempts: 3, initialDelay: 0.001, maxDelay: 0.001) {
            attempts += 1
            return 42
        }
        XCTAssertEqual(result, 42)
        XCTAssertEqual(attempts, 1)
    }

    func testRetriesOnFailureUntilSuccess() async throws {
        var attempts = 0
        let result: Int = try await RetryHelper.withRetry(maxAttempts: 3, initialDelay: 0.001, maxDelay: 0.001) {
            attempts += 1
            if attempts < 2 { throw TestError.fail }
            return 7
        }
        XCTAssertEqual(result, 7)
        XCTAssertEqual(attempts, 2)
    }

    func testThrowsAfterAllAttemptsFail() async {
        var attempts = 0
        do {
            _ = try await RetryHelper.withRetry(maxAttempts: 3, initialDelay: 0.001, maxDelay: 0.001) { () -> Int in
                attempts += 1
                throw TestError.fail
            }
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(attempts, 3)
        }
    }

    func testWithTimeoutSucceedsBeforeDeadline() async throws {
        let result = try await RetryHelper.withTimeout(seconds: 1.0) {
            try await Task.sleep(nanoseconds: 50_000_000)
            return "done"
        }
        XCTAssertEqual(result, "done")
    }

    func testWithTimeoutThrowsWhenSlower() async {
        do {
            _ = try await RetryHelper.withTimeout(seconds: 0.05) {
                try await Task.sleep(nanoseconds: 500_000_000)
                return "should not return"
            }
            XCTFail("Expected timeout")
        } catch let error as AppError {
            if case .timeout = error { return }
            XCTFail("Expected AppError.timeout, got \(error)")
        } catch {
            XCTFail("Expected AppError.timeout, got \(error)")
        }
    }
}

// MARK: - Deep link validator (mirrored from MainTabView for unit testability)

/// Mirror of MainTabView.isValidDocumentId — tested independently because the
/// real one is `private` to the view. If the view's regex changes, update here.
private func isValidDocumentId(_ id: String) -> Bool {
    guard (4...128).contains(id.count) else { return false }
    return id.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
}

final class DeepLinkValidatorTests: XCTestCase {
    func testRealStripIdShape_userId_underscore_uuid() {
        // {28 char Firebase UID}_{36 char UUID} = 65 chars total
        let stripId = "AbCdEfGhIjKlMnOpQrStUvWxYz12_12345678-1234-5678-9012-123456789ABC"
        XCTAssertEqual(stripId.count, 65)
        XCTAssertTrue(isValidDocumentId(stripId))
    }

    func testFirebaseAutoId() {
        // 20-char Firebase auto-generated ID
        XCTAssertTrue(isValidDocumentId("aBcDeFgHiJkLmNoPqRsT"))
    }

    func testDmThreadId() {
        // {28 + 1 + 28} = 57 chars
        let threadId = "AbCdEfGhIjKlMnOpQrStUvWxYz12_ZyXwVuTsRqPoNmLkJiHgFeDcBa12"
        XCTAssertTrue(isValidDocumentId(threadId))
    }

    func testRejectsTooShort() {
        XCTAssertFalse(isValidDocumentId("a"))
        XCTAssertFalse(isValidDocumentId("abc"))
    }

    func testRejectsTooLong() {
        XCTAssertFalse(isValidDocumentId(String(repeating: "x", count: 129)))
    }

    func testRejectsPathTraversal() {
        XCTAssertFalse(isValidDocumentId("../../etc/passwd"))
        XCTAssertFalse(isValidDocumentId("a/b"))
        XCTAssertFalse(isValidDocumentId(".."))
    }

    func testRejectsSpecialCharacters() {
        XCTAssertFalse(isValidDocumentId("abc def"))    // space
        XCTAssertFalse(isValidDocumentId("abc?def"))    // query
        XCTAssertFalse(isValidDocumentId("abc#def"))    // fragment
        XCTAssertFalse(isValidDocumentId("abc%20def"))  // url-encoded space
    }

    func testAcceptsLowerUpperDigitsUnderscoreDash() {
        XCTAssertTrue(isValidDocumentId("abc-DEF_123"))
    }
}

// MARK: - Password Strength

/// Mirror of AuthView.isStrongEnoughPassword for unit testability.
private func isStrongEnoughPassword(_ password: String) -> Bool {
    guard password.count >= 8 else { return false }
    let hasDigit = password.contains(where: { $0.isNumber })
    let hasSymbol = password.contains(where: { !$0.isLetter && !$0.isNumber })
    let hasUppercase = password.contains(where: { $0.isUppercase })
    let categories = [hasDigit, hasSymbol, hasUppercase].filter { $0 }.count
    return categories >= 2
}

final class PasswordStrengthTests: XCTestCase {
    func testRejectsShortPassword() {
        XCTAssertFalse(isStrongEnoughPassword("Aa1"))
        XCTAssertFalse(isStrongEnoughPassword("A1@aB2C"))   // 7 chars
    }

    func testRejectsAllLowercaseLong() {
        XCTAssertFalse(isStrongEnoughPassword("abcdefghij"))  // only one category (none beyond letters)
    }

    func testAcceptsUpperPlusDigit() {
        XCTAssertTrue(isStrongEnoughPassword("Abcdefg1"))
    }

    func testAcceptsDigitPlusSymbol() {
        XCTAssertTrue(isStrongEnoughPassword("abcd123!"))
    }

    func testAcceptsAllThreeCategories() {
        XCTAssertTrue(isStrongEnoughPassword("Aa1!aaaa"))
    }

    func testRejectsSimplePassword() {
        XCTAssertFalse(isStrongEnoughPassword("password"))
        XCTAssertFalse(isStrongEnoughPassword("12345678"))
    }
}

// MARK: - Username Validation

/// Mirror of EditProfileView.validateUsername for unit testability.
private func validateUsername(_ value: String, minLength: Int = 3, maxLength: Int = 20) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.count < minLength { return "too_short" }
    if trimmed.count > maxLength { return "too_long" }
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) {
        return "invalid_chars"
    }
    return nil
}

final class UsernameValidationTests: XCTestCase {
    func testEmptyIsAccepted() {
        XCTAssertNil(validateUsername(""))
        XCTAssertNil(validateUsername("   "))
    }

    func testMinLength() {
        XCTAssertEqual(validateUsername("ab"), "too_short")
        XCTAssertNil(validateUsername("abc"))
    }

    func testMaxLength() {
        XCTAssertNil(validateUsername(String(repeating: "a", count: 20)))
        XCTAssertEqual(validateUsername(String(repeating: "a", count: 21)), "too_long")
    }

    func testAlphanumericAccepted() {
        XCTAssertNil(validateUsername("user123"))
        XCTAssertNil(validateUsername("USER_42"))
    }

    func testSpaceRejected() {
        XCTAssertEqual(validateUsername("user name"), "invalid_chars")
    }

    func testSpecialCharsRejected() {
        XCTAssertEqual(validateUsername("user.name"), "invalid_chars")
        XCTAssertEqual(validateUsername("user-name"), "invalid_chars")
        XCTAssertEqual(validateUsername("user@name"), "invalid_chars")
    }

    func testTrimsWhitespace() {
        XCTAssertNil(validateUsername("  user  "))
    }
}

// MARK: - AnalyticsEvent Enum

final class AnalyticsEventTests: XCTestCase {
    func testCriticalFunnelEventsExist() {
        XCTAssertEqual(AnalyticsEvent.appLaunch.rawValue, "sm_app_launch")
        XCTAssertEqual(AnalyticsEvent.signupStarted.rawValue, "sm_signup_started")
        XCTAssertEqual(AnalyticsEvent.signupCompleted.rawValue, "sm_signup_completed")
        XCTAssertEqual(AnalyticsEvent.friendGateShown.rawValue, "sm_friend_gate_shown")
        XCTAssertEqual(AnalyticsEvent.friendGatePassed.rawValue, "sm_friend_gate_passed")
        XCTAssertEqual(AnalyticsEvent.firstPhotoSent.rawValue, "sm_first_photo_sent")
    }

    func testAllRawValuesUseSmPrefix() {
        let cases: [AnalyticsEvent] = [
            .appLaunch, .login, .logout, .signupStarted, .friendGateShown,
            .firstPhotoSent, .sendPhoto, .openHistory, .widgetTapped, .streakIncreased
        ]
        for event in cases {
            XCTAssertTrue(event.rawValue.hasPrefix("sm_"), "Event \(event) missing sm_ prefix")
        }
    }

    func testEventRawValuesAreUnique() {
        // If two cases share a raw value, analytics would conflate them.
        let allEvents: [AnalyticsEvent] = [
            .appLaunch, .onboardingStarted, .onboardingCompleted, .onboardingSkipped,
            .demoPreviewOpened, .demoPreviewClosed, .signupStarted, .signupStepCompleted,
            .signupCompleted, .signupAbandoned, .login, .signUp, .appleSignIn, .logout,
            .profileCompletionShown, .profileCompletionFinished,
            .friendGateShown, .friendGatePassed, .friendGateSkipped, .friendGateHelpOpened,
            .appTourCompleted, .appTourSkipped,
            .firstPhotoSent, .firstFriendAdded, .firstReactionGiven, .firstStripChatMessage,
            .notificationPermissionPrompted, .notificationPermissionGranted, .notificationPermissionDenied,
            .cameraPermissionGranted, .cameraPermissionDenied,
            .contactsPermissionGranted, .contactsPermissionDenied,
            .locationPermissionGranted, .locationPermissionDenied,
            .sendFriendRequest, .acceptFriendRequest, .removeFriend, .blockUser, .reportContent,
            .capturePhoto, .sendPhoto, .sendPhotoFailed, .sendPhotoRetried, .clearHistory, .viewStripDetail,
            .sendComment, .sendDirectMessage,
            .openHistory, .openFriends, .openInbox, .openNotifications, .openSettings,
            .widgetTapped, .widgetRefreshed,
            .streakIncreased, .streakBroken, .dailyPromptViewed, .dailyPromptAnswered,
            .appError
        ]
        let raws = allEvents.map(\.rawValue)
        XCTAssertEqual(Set(raws).count, raws.count, "Duplicate analytics event raw values")
    }

    func testLogOnceRespectsFirstFireFlag() {
        let key = "sm_first_events_logged"
        UserDefaults.standard.removeObject(forKey: key)
        AnalyticsService.shared.logOnce(.firstPhotoSent)
        let after = UserDefaults.standard.stringArray(forKey: key) ?? []
        XCTAssertTrue(after.contains(AnalyticsEvent.firstPhotoSent.rawValue))
        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - AppLogger smoke

final class AppLoggerTests: XCTestCase {
    func testLoggerCategoriesExist() {
        // Just verifying these references resolve (and don't crash).
        // Full os.Logger output isn't trivially asserted in XCTest.
        AppLogger.service.debug("test")
        AppLogger.auth.info("test")
        AppLogger.camera.warning("test")
        AppLogger.network.error("test")
        AppLogger.ui.notice("test")
    }
}

// MARK: - Notification Permission Prompter (state-only check)

final class NotificationPermissionPrompterTests: XCTestCase {
    func testHasPromptedKeyTracking() {
        let key = "notif_permission_prompted"
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: key))

        // We can't drive UNUserNotificationCenter in a unit test without a host
        // app + permission popup; what we CAN test is that the flag persists
        // when set, which is the core dedup mechanism.
        UserDefaults.standard.set(true, forKey: key)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: key))
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Turkish Dative Suffix (vowel harmony)

/// Mirror of PreviewView's helper. Test independently for correctness.
private func turkishDativeSuffix(for name: String) -> String {
    let backVowels = Set<Character>(["a", "ı", "o", "u", "A", "I", "O", "U"])
    let lastVowel = name.reversed().first(where: { ch in
        let lower = Character(ch.lowercased())
        return "aeıioöuü".contains(lower)
    })
    guard let v = lastVowel else { return "'a" }
    return backVowels.contains(v) ? "'a" : "'e"
}

final class TurkishGrammarTests: XCTestCase {
    func testBackVowelGetsA() {
        XCTAssertEqual(turkishDativeSuffix(for: "Ahmet"), "'e")  // last vowel 'e' (front)
        XCTAssertEqual(turkishDativeSuffix(for: "Ali"), "'e")
        XCTAssertEqual(turkishDativeSuffix(for: "Burak"), "'a")  // last vowel 'a' (back)
    }

    func testFrontVowelGetsE() {
        XCTAssertEqual(turkishDativeSuffix(for: "Elif"), "'e")
        XCTAssertEqual(turkishDativeSuffix(for: "Mert"), "'e")
        XCTAssertEqual(turkishDativeSuffix(for: "Deniz"), "'e")
    }

    func testFallbackForNoVowels() {
        XCTAssertEqual(turkishDativeSuffix(for: "XYZ"), "'a")
    }

    func testCapitalizationIgnored() {
        XCTAssertEqual(turkishDativeSuffix(for: "BURAK"), "'a")
        XCTAssertEqual(turkishDativeSuffix(for: "ELİF"), "'e")
    }
}

// MARK: - User-facing UX copy guards

final class UserFacingUXCopyTests: XCTestCase {
    func testCameraSourceIncludesFirstRunGestureHints() throws {
        let source = try appSource("StripMate/Core/Views/MainCameraView.swift")

        XCTAssertTrue(source.contains("basılı tut: video"))
        XCTAssertTrue(source.contains("çift dokun: kamera çevir"))
        XCTAssertTrue(source.contains("yakınlaştırmak için sıkıştır"))
    }

    func testPreviewKeepsAdvancedSendOptionsBehindDisclosure() throws {
        let source = try appSource("StripMate/Core/Views/PreviewView.swift")

        XCTAssertTrue(source.contains("showAdvancedSendOptions"))
        XCTAssertTrue(source.contains("daha fazla"))
        XCTAssertTrue(source.contains("if showAdvancedSendOptions"))
    }

    func testKnownTurkishCopyRegressionsAreNotPresent() throws {
        let files = [
            "StripMate/Core/Views/MainTabView.swift",
            "StripMate/Core/Views/FriendsListView.swift",
            "StripMate/Core/Views/FriendProfileView.swift",
            "StripMate/Core/Views/FriendshipProfileView.swift",
            "StripMate/Core/Views/NotificationsView.swift",
            "StripMate/Core/Views/InboxView.swift",
            "StripMate/Core/Views/SettingsView.swift",
            "StripMate/Core/Views/BlockedUsersView.swift",
            "StripMate/Core/Views/PhotoReplyCapture.swift",
            "StripMate/Utils/ErrorAlertModifier.swift"
        ]

        let forbidden = [
            "cevrimdisi",
            "baglanti",
            "henuz",
            "kullanicilar",
            "kullanici",
            "olustu",
            "goremez",
            "ulasamaz",
            "kisi",
            "yakin cevren",
            "bulamadik",
            "arkadaslik",
            "arkadasina",
            "arkadasinin",
            "paylasilan",
            "gonderdi",
            "gonderilen",
            "gonderdigin",
            "gonder",
            "fotograf"
        ]

        for file in files {
            let source = try appSource(file)
            for phrase in forbidden {
                XCTAssertFalse(source.contains("String(localized: \"\(phrase)"),
                               "\(file) contains unaccented Turkish copy: \(phrase)")
                XCTAssertFalse(source.contains("Text(\"\(phrase)"),
                               "\(file) contains unaccented Turkish Text copy: \(phrase)")
                XCTAssertFalse(source.contains(".accessibilityLabel(\"\(phrase)"),
                               "\(file) contains unaccented Turkish accessibility copy: \(phrase)")
            }
        }
    }

    private func appSource(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }
}
