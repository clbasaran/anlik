import Foundation

public enum FirebaseError: Error, LocalizedError {
    case unauthenticated
    case pairingFailed
    case userNotFound
    case invalidInviteCode
    case invalidCodeFormat
    case compressionFailed
    case usernameTaken
    case noReceivers

    public var errorDescription: String? {
        switch self {
        case .unauthenticated: return "Oturum açmanız gerekiyor."
        case .pairingFailed: return "Eşleştirme başarısız oldu."
        case .userNotFound: return "Kullanıcı bulunamadı."
        case .invalidInviteCode: return "Geçersiz davet kodu."
        case .invalidCodeFormat: return "Kod formatı geçersiz."
        case .compressionFailed: return "Fotoğraf sıkıştırma başarısız oldu."
        case .usernameTaken: return String(localized: "Bu kullanıcı adı zaten kullanılıyor.")
        case .noReceivers: return String(localized: "Lütfen en az bir alıcı seçin.")
        }
    }
}

/// Auth-specific errors for account linking and provider conflicts
public enum AuthError: Error, LocalizedError {
    case accountLinkedToApple
    case emailUsedByOtherAccount

    public var errorDescription: String? {
        switch self {
        case .accountLinkedToApple:
            return "Bu hesap Apple ile bağlantılı. Lütfen Apple ile giriş yapın."
        case .emailUsedByOtherAccount:
            return "Bu e-posta başka bir hesap tarafından kullanılıyor."
        }
    }
}
