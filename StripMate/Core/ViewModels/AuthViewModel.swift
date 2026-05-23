import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import UIKit

@MainActor
@Observable
public final class AuthViewModel {
    public var email = ""
    public var password = ""
    public var displayName = ""
    public var username = ""
    public var dateOfBirth = AppLimits.recommendedDefaultBirthDate
    public var isSignUp = false
    public var isLoading = false
    public var showSuccessMessage = false
    public var errorMessage: String? = nil
    public var currentNonce: String?
    
    private let deps = DependencyContainer.shared
    
    public init() {}
    
    public func authenticate() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "Lütfen tüm alanları doldur")
            return
        }
        if isSignUp {
            guard !displayName.isEmpty, !username.isEmpty else {
                errorMessage = String(localized: "Görünen ad ve kullanıcı adı gerekli")
                return
            }
            if dateOfBirth > Date() {
                errorMessage = String(localized: "Geçerli bir doğum tarihi seç.")
                return
            }
            if !AppLimits.meetsMinimumRegistrationAge(dateOfBirth) {
                errorMessage = String(localized: "kayıt için en az \(AppLimits.minimumRegistrationAge) yaşında olmalısın.")
                return
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if isSignUp {
                HapticsManager.playImpact(style: .medium)
                _ = try await deps.userRepository.signUp(email: trimmedEmail, password: password, displayName: displayName, username: username, dateOfBirth: dateOfBirth)
                AnalyticsService.shared.log(.signUp)
                
                await MainActor.run {
                    self.showSuccessMessage = true
                }
                HapticsManager.playNotification(type: .success)
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            } else {
                HapticsManager.playImpact(style: .medium)
                _ = try await deps.userRepository.login(email: trimmedEmail, password: password)
                AnalyticsService.shared.log(.login)
                HapticsManager.playNotification(type: .success)
            }
            
            await MainActor.run {
                NotificationCenter.default.post(name: .userDidLogin, object: nil)
            }
        } catch {
            await MainActor.run {
                errorMessage = Self.friendlyErrorMessage(for: error)
            }
            HapticsManager.playNotification(type: .error)
        }
        isLoading = false
    }

    public func completeEmailSignUp(avatarImage: UIImage?) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = String(localized: "Lütfen tüm alanları doldur")
            return
        }
        guard !trimmedName.isEmpty, !trimmedUsername.isEmpty else {
            errorMessage = String(localized: "Görünen ad ve kullanıcı adı gerekli")
            return
        }
        if dateOfBirth > Date() {
            errorMessage = String(localized: "Geçerli bir doğum tarihi seç.")
            return
        }
        if !AppLimits.meetsMinimumRegistrationAge(dateOfBirth) {
            errorMessage = String(localized: "kayıt için en az \(AppLimits.minimumRegistrationAge) yaşında olmalısın.")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            HapticsManager.playImpact(style: .medium)
            _ = try await deps.userRepository.signUp(
                email: trimmedEmail,
                password: password,
                displayName: trimmedName,
                username: trimmedUsername,
                dateOfBirth: dateOfBirth
            )

            if let avatarImage {
                do {
                    _ = try await deps.userRepository.uploadAvatar(avatarImage)
                } catch {
                    #if DEBUG
                    print("DEBUG: Avatar upload after signup failed: \(error.localizedDescription)")
                    #endif
                }
            }

            AnalyticsService.shared.log(.signUp)
            showSuccessMessage = true
            HapticsManager.playNotification(type: .success)
            try? await Task.sleep(nanoseconds: 700_000_000)
            NotificationCenter.default.post(name: .userDidLogin, object: nil)
        } catch {
            if Auth.auth().currentUser != nil {
                #if DEBUG
                print("DEBUG: Signup recovered after post-create auth error: \(error.localizedDescription)")
                #endif
                do {
                    if let uid = Auth.auth().currentUser?.uid {
                        _ = try? await AuthService.shared.fetchProfile(for: uid, forceRefresh: true)
                    }
                    if let avatarImage {
                        _ = try? await deps.userRepository.uploadAvatar(avatarImage)
                    }
                }
                showSuccessMessage = true
                HapticsManager.playNotification(type: .success)
                try? await Task.sleep(nanoseconds: 500_000_000)
                NotificationCenter.default.post(name: .userDidLogin, object: nil)
                isLoading = false
                return
            }
            errorMessage = Self.friendlyErrorMessage(for: error)
            HapticsManager.playNotification(type: .error)
        }

        isLoading = false
    }
    
    // MARK: - Apple Sign In Helpers
    
    public func startAppleSignIn() -> String {
        do {
            let nonce = try randomNonceString()
            currentNonce = nonce
            return nonce
        } catch {
            errorMessage = String(localized: "Güvenlik kodu oluşturulamadı. Lütfen tekrar deneyin.")
            return ""
        }
    }
    
    public func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let auth):
            if let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    errorMessage = String(localized: "Oturum süresi doldu. Lütfen tekrar deneyin.")
                    return
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    errorMessage = String(localized: "Kimlik bilgisi alınamadı.")
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    errorMessage = String(localized: "Token verisi işlenemedi.")
                    return
                }
                
                let fullName = appleIDCredential.fullName
                let nameStr = [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")
                
                // Clear nonce immediately to prevent stale reuse
                currentNonce = nil
                
                isLoading = true
                errorMessage = nil
                do {
                    HapticsManager.playImpact(style: .medium)
                    _ = try await deps.userRepository.signInWithApple(idToken: idTokenString, nonce: nonce, fullName: nameStr.isEmpty ? nil : nameStr)
                    AnalyticsService.shared.log(.appleSignIn)
                    HapticsManager.playNotification(type: .success)
                    
                    await MainActor.run {
                        NotificationCenter.default.post(name: .userDidLogin, object: nil)
                    }
                } catch {
                    errorMessage = Self.friendlyErrorMessage(for: error)
                    HapticsManager.playNotification(type: .error)
                }
                isLoading = false
            }
        case .failure(let error):
            // Don't show error for user cancellation
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - User-Friendly Error Messages
    
    private static func friendlyErrorMessage(for error: Error) -> String {
        // Check our custom auth errors first
        if let authError = error as? AuthError {
            return authError.localizedDescription
        }
        
        let nsError = error as NSError
        
        // Firebase Auth error codes
        if nsError.domain == AuthErrorDomain {
            switch AuthErrorCode(rawValue: nsError.code) {
            case .invalidCredential, .wrongPassword:
                return String(localized: "E-posta veya şifre hatalı. Apple ile kayıt olduysanız lütfen 'Apple ile Devam Et' seçeneğini kullanın.")
            case .userNotFound:
                return String(localized: "Bu e-posta ile hesap bulunamadı. Kayıt olun veya 'Apple ile Devam Et' seçeneğini kullanın.")
            case .emailAlreadyInUse:
                return String(localized: "Bu e-posta zaten kayıtlı. Giriş yapmayı veya 'Apple ile Devam Et' seçeneğini deneyin.")
            case .invalidEmail:
                return String(localized: "Lütfen geçerli bir e-posta adresi girin.")
            case .weakPassword:
                return String(localized: "Şifre çok zayıf. En az 6 karakter kullanın.")
            case .networkError:
                return String(localized: "İnternet bağlantısı yok. Ağ bağlantınızı kontrol edip tekrar deneyin.")
            case .tooManyRequests:
                return String(localized: "Çok fazla başarısız deneme. Lütfen biraz bekleyip tekrar deneyin.")
            case .userDisabled:
                return String(localized: "Bu hesap devre dışı bırakılmış. Lütfen destekle iletişime geçin.")
            case .accountExistsWithDifferentCredential:
                return String(localized: "Bu e-posta ile farklı bir giriş yöntemiyle hesap mevcut. 'Apple ile Devam Et' seçeneğini deneyin.")
            case .keychainError:
                return String(localized: "hesabın hazır görünüyor. olmazsa uygulamayı kapatıp tekrar aç.")
            default:
                break
            }
        }
        
        return error.localizedDescription
    }
    
    private enum NonceError: Error {
        case secRandomFailed(OSStatus)
    }

    private func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            throw NonceError.secRandomFailed(errorCode)
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in charset[Int(byte) % charset.count] }
        return String(nonce)
    }

    public func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
