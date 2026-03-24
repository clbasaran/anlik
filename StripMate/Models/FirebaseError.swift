import Foundation

public enum FirebaseError: Error, LocalizedError {
    case unauthenticated
    case pairingFailed
    case userNotFound
    case invalidInviteCode
    case invalidCodeFormat
    case compressionFailed
    
    public var errorDescription: String? {
        switch self {
        case .unauthenticated: return "You must be signed in."
        case .pairingFailed: return "Could not pair with this user."
        case .userNotFound: return "User not found."
        case .invalidInviteCode: return "This invite code does not exist."
        case .invalidCodeFormat: return "Please enter a valid 6-character code."
        case .compressionFailed: return "Image processing failed."
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
            return "This account uses Apple Sign In. Please tap 'Continue with Apple' to log in."
        case .emailUsedByOtherAccount:
            return "This email is already linked to another account."
        }
    }
}
