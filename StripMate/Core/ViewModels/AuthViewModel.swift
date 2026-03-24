import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth

@MainActor
@Observable
public final class AuthViewModel {
    public var email = ""
    public var password = ""
    public var displayName = ""
    public var username = ""
    public var dateOfBirth = Date()
    public var isSignUp = false
    public var isLoading = false
    public var showSuccessMessage = false
    public var errorMessage: String? = nil
    public var currentNonce: String?
    
    private let deps = DependencyContainer.shared
    
    public init() {}
    
    public func authenticate() async {
        guard !email.isEmpty, !password.isEmpty else {
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
            let ageComponents = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date())
            if let age = ageComponents.year, age < 13 {
                errorMessage = String(localized: "Kayıt olmak için en az 13 yaşında olmalısın.")
                return
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if isSignUp {
                HapticsManager.playImpact(style: .medium)
                _ = try await deps.userRepository.signUp(email: email, password: password, displayName: displayName, username: username, dateOfBirth: dateOfBirth)
                AnalyticsService.shared.log(.signUp)
                
                await MainActor.run {
                    self.showSuccessMessage = true
                }
                HapticsManager.playNotification(type: .success)
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            } else {
                HapticsManager.playImpact(style: .medium)
                _ = try await deps.userRepository.login(email: email, password: password)
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
    
    // MARK: - Apple Sign In Helpers
    
    public func startAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return nonce
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
            default:
                break
            }
        }
        
        return error.localizedDescription
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
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
