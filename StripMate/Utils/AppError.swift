import Foundation

/// Centralized app-wide error types with user-facing messages.
public enum AppError: Error, LocalizedError {
    // Auth
    case loginFailed(Error)
    case signUpFailed(Error)
    case appleSignInFailed(Error)
    case unauthenticated
    
    // Network
    case networkUnavailable
    case serverError(Error)
    case timeout
    
    // Social
    case userNotFound
    case friendRequestFailed
    case friendAcceptFailed
    case friendRemoveFailed
    case invalidInviteCode
    
    // Photo
    case capturePhotoFailed
    case photoUploadFailed(Error)
    case compressionFailed
    case clearHistoryFailed
    
    // Messaging
    case sendMessageFailed
    case sendCommentFailed
    
    // Data
    case cacheFailed
    case syncFailed
    
    // Generic
    case unknown(Error)
    case custom(String)
    
    public var errorDescription: String? {
        switch self {
        case .loginFailed(let error):
            return String(localized: "Giriş başarısız: \(error.localizedDescription)")
        case .signUpFailed(let error):
            return String(localized: "Kayıt başarısız: \(error.localizedDescription)")
        case .appleSignInFailed(let error):
            return String(localized: "Apple ile giriş başarısız: \(error.localizedDescription)")
        case .unauthenticated:
            return String(localized: "Giriş yapmış olmalısınız.")
        case .networkUnavailable:
            return String(localized: "İnternet bağlantısı yok. Ağ bağlantınızı kontrol edin.")
        case .serverError:
            return String(localized: "Bir şeyler yanlış gitti. Lütfen daha sonra tekrar deneyin.")
        case .timeout:
            return String(localized: "İstek zaman aşımına uğradı. Lütfen tekrar deneyin.")
        case .userNotFound:
            return String(localized: "Kullanıcı bulunamadı.")
        case .friendRequestFailed:
            return String(localized: "Arkadaşlık isteği gönderilemedi.")
        case .friendAcceptFailed:
            return String(localized: "Arkadaşlık isteği kabul edilemedi.")
        case .friendRemoveFailed:
            return String(localized: "Arkadaş kaldırılamadı.")
        case .invalidInviteCode:
            return String(localized: "Bu davet kodu mevcut değil.")
        case .capturePhotoFailed:
            return String(localized: "Fotoğraf çekilemedi.")
        case .photoUploadFailed:
            return String(localized: "Fotoğraf gönderilemedi. Lütfen tekrar deneyin.")
        case .compressionFailed:
            return String(localized: "Görsel işlenemedi.")
        case .clearHistoryFailed:
            return String(localized: "Geçmiş temizlenemedi.")
        case .sendMessageFailed:
            return String(localized: "Mesaj gönderilemedi.")
        case .sendCommentFailed:
            return String(localized: "Yorum gönderilemedi.")
        case .cacheFailed:
            return String(localized: "Veri yerel olarak kaydedilemedi.")
        case .syncFailed:
            return String(localized: "Veri senkronize edilemedi.")
        case .unknown(let error):
            return error.localizedDescription
        case .custom(let message):
            return message
        }
    }
    
    /// User-friendly short title for alert displays
    public var alertTitle: String {
        switch self {
        case .loginFailed, .signUpFailed, .appleSignInFailed, .unauthenticated:
            return String(localized: "Kimlik Doğrulama Hatası")
        case .networkUnavailable, .serverError, .timeout:
            return String(localized: "Bağlantı Hatası")
        case .userNotFound, .friendRequestFailed, .friendAcceptFailed, .friendRemoveFailed, .invalidInviteCode:
            return String(localized: "Sosyal Hata")
        case .capturePhotoFailed, .photoUploadFailed, .compressionFailed, .clearHistoryFailed:
            return String(localized: "Fotoğraf Hatası")
        case .sendMessageFailed, .sendCommentFailed:
            return String(localized: "Mesaj Hatası")
        case .cacheFailed, .syncFailed:
            return String(localized: "Veri Hatası")
        case .unknown:
            return String(localized: "Hata")
        case .custom:
            return String(localized: "Hata")
        }
    }
}
