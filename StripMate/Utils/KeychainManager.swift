import Foundation
import Security

/// Lightweight Keychain wrapper for storing sensitive tokens (FCM, APNs, widget push).
/// Use this instead of UserDefaults for anything that could be used to impersonate
/// the user or intercept their notifications.
public enum KeychainManager {
    public enum KeychainError: Error {
        case unhandled(status: OSStatus)
    }

    private static let service = "com.celalbasaran.stripmate.tokens"

    /// Stores a string value for the given key, overwriting any existing entry.
    @discardableResult
    public static func save(_ value: String, forKey key: String, accessGroup: String? = nil) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        // Remove any existing entry first
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Reads the string value for the given key, or nil if absent.
    public static func load(forKey key: String, accessGroup: String? = nil) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Removes the value for the given key. Returns true on success or not-found.
    @discardableResult
    public static func delete(forKey key: String, accessGroup: String? = nil) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Known keys
    public enum Key {
        public static let fcmToken = "fcm_token"
        public static let widgetPushToken = "widget_push_token"
    }
}
