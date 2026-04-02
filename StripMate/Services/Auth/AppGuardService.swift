import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Centralized guard service for ban/suspend checks, maintenance mode, and word filtering.
/// Reads from Firestore on demand with local caching to minimize reads.
public actor AppGuardService {
    public static let shared = AppGuardService()

    private var db: Firestore { Firestore.firestore() }

    // MARK: - Ban/Suspend State

    public enum UserStatus: Sendable {
        case active
        case banned(reason: String)
        case suspended(until: Date, reason: String)
    }

    private var cachedStatus: UserStatus?
    private var statusFetchedAt: Date?
    private let statusTTL: TimeInterval = 60 // re-check every 60s

    /// Checks if the current user is banned or suspended.
    /// Returns `.active` if everything is fine.
    public func checkUserStatus(forceRefresh: Bool = false) async -> UserStatus {
        if !forceRefresh,
           let cached = cachedStatus,
           let fetchedAt = statusFetchedAt,
           Date().timeIntervalSince(fetchedAt) < statusTTL {
            return cached
        }

        guard let uid = Auth.auth().currentUser?.uid else { return .active }

        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let data = doc.data() ?? [:]

            let isBanned = data["isBanned"] as? Bool ?? false
            if isBanned {
                let reason = data["banReason"] as? String ?? ""
                let status = UserStatus.banned(reason: reason)
                cachedStatus = status
                statusFetchedAt = Date()
                return status
            }

            let isSuspended = data["isSuspended"] as? Bool ?? false
            if isSuspended, let until = (data["suspendedUntil"] as? Timestamp)?.dateValue() {
                if until > Date() {
                    let reason = data["banReason"] as? String ?? ""
                    let status = UserStatus.suspended(until: until, reason: reason)
                    cachedStatus = status
                    statusFetchedAt = Date()
                    return status
                }
                // Suspension expired — clear it silently
                try? await db.collection("users").document(uid).updateData([
                    "isSuspended": false,
                    "suspendedUntil": FieldValue.delete(),
                    "banReason": FieldValue.delete(),
                    "bannedBy": FieldValue.delete(),
                    "bannedAt": FieldValue.delete()
                ])
            }

            cachedStatus = .active
            statusFetchedAt = Date()
            return .active
        } catch {
            return cachedStatus ?? .active
        }
    }

    /// Clears cached status (call on logout)
    public func clearCache() {
        cachedStatus = nil
        statusFetchedAt = nil
        maintenanceCache = nil
        maintenanceFetchedAt = nil
        wordFilterCache = nil
        wordFilterFetchedAt = nil
    }

    // MARK: - Maintenance Mode

    public struct MaintenanceInfo: Sendable {
        public let isActive: Bool
        public let message: String
    }

    private var maintenanceCache: MaintenanceInfo?
    private var maintenanceFetchedAt: Date?
    private let maintenanceTTL: TimeInterval = 120 // re-check every 2 min

    /// Checks if the app is in maintenance mode.
    public func checkMaintenance(forceRefresh: Bool = false) async -> MaintenanceInfo {
        if !forceRefresh,
           let cached = maintenanceCache,
           let fetchedAt = maintenanceFetchedAt,
           Date().timeIntervalSince(fetchedAt) < maintenanceTTL {
            return cached
        }

        do {
            let doc = try await db.collection("app_config").document("settings").getDocument()
            let data = doc.data() ?? [:]
            let isActive = data["maintenanceMode"] as? Bool ?? false
            let message = data["maintenanceMessage"] as? String ?? "Uygulama bakımda. Lütfen daha sonra tekrar deneyin."
            let info = MaintenanceInfo(isActive: isActive, message: message)
            maintenanceCache = info
            maintenanceFetchedAt = Date()
            return info
        } catch {
            return maintenanceCache ?? MaintenanceInfo(isActive: false, message: "")
        }
    }

    // MARK: - Word Filter

    private var wordFilterCache: Set<String>?
    private var wordFilterFetchedAt: Date?
    private let wordFilterTTL: TimeInterval = 300 // re-check every 5 min

    /// Fetches the banned word list from Firestore (cached).
    public func fetchBannedWords(forceRefresh: Bool = false) async -> Set<String> {
        if !forceRefresh,
           let cached = wordFilterCache,
           let fetchedAt = wordFilterFetchedAt,
           Date().timeIntervalSince(fetchedAt) < wordFilterTTL {
            return cached
        }

        do {
            let snap = try await db.collection("admin_word_filters").getDocuments()
            let words = Set(snap.documents.compactMap { $0.data()["word"] as? String })
            wordFilterCache = words
            wordFilterFetchedAt = Date()
            return words
        } catch {
            return wordFilterCache ?? []
        }
    }

    /// Checks if a text contains any banned words. Returns the first match or nil.
    /// Uses word boundary regex to avoid false positives (e.g., "ass" matching "class").
    public func containsBannedWord(_ text: String) async -> String? {
        let banned = await fetchBannedWords()
        for word in banned {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return word
            }
        }
        return nil
    }
}
