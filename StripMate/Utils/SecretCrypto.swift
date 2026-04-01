import Foundation
import CryptoKit

/// AES-GCM encryption for secret strip images.
/// Key derivation: SHA256(senderUID + receiverUID + stripId) → symmetric key
public enum SecretCrypto {

    /// Derives a deterministic symmetric key from the strip context.
    /// Both sender and receiver can independently derive the same key.
    public static func deriveKey(senderId: String, receiverId: String, stripId: String) -> SymmetricKey {
        let seed = "\(senderId)_\(receiverId)_\(stripId)_anlik_secret"
        let hash = SHA256.hash(data: Data(seed.utf8))
        return SymmetricKey(data: hash)
    }

    /// Encrypts data using AES-GCM.
    public static func encrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    /// Decrypts AES-GCM encrypted data.
    public static func decrypt(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    enum CryptoError: Error {
        case encryptionFailed
        case decryptionFailed
    }
}
