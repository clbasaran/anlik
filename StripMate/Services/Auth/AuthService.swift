import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseStorage
import UIKit

/// Handles authentication, profile management, and FCM token updates.
public actor AuthService {
    public static let shared = AuthService()

    var auth: Auth { Auth.auth() }
    var db: Firestore { Firestore.firestore() }

    public var currentUserProfile: UserProfile?
    public var fcmToken: String?

    /// Syncs invite code to App Group for QR Code Widget
    func syncInviteCodeToWidget(_ profile: UserProfile?) {
        let defaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
        if let code = profile?.inviteCode, !code.isEmpty {
            defaults?.set(code, forKey: "user_invite_code")
            defaults?.set(profile?.displayName, forKey: "user_display_name")
            defaults?.set(profile?.username, forKey: "user_username")
        } else {
            defaults?.removeObject(forKey: "user_invite_code")
            defaults?.removeObject(forKey: "user_display_name")
            defaults?.removeObject(forKey: "user_username")
        }
    }

    /// In-memory profile cache with TTL to reduce Firestore reads
    var profileCache: [String: (profile: UserProfile, fetchedAt: Date)] = [:]
    let profileCacheTTL: TimeInterval = 300 // 5 minutes

    /// Rate limiting state for invite code searches (brute-force protection)
    var searchAttempts: [Date] = []
    let maxSearchAttemptsPerMinute = 5

    /// Returns the list of blocked user IDs (cached for 5 minutes)
    var cachedBlockedIds: Set<String>?
    var blockedCacheTime: Date?

    // MARK: - Unique Invite Code Generation

    /// Generates a unique 8-char invite code, verifying uniqueness against Firestore.
    /// Retries up to `maxAttempts` times if a collision is detected.
    func generateUniqueInviteCode(maxAttempts: Int = 5) async throws -> String {
        for _ in 0..<maxAttempts {
            let candidate = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
            let snapshot = try await db.collection("users")
                .whereField("inviteCode", isEqualTo: candidate)
                .limit(to: 1)
                .getDocuments()
            if snapshot.documents.isEmpty {
                return candidate
            }
        }
        // Extremely unlikely fallback — use full UUID prefix for maximum entropy
        return String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)).uppercased()
    }

    // MARK: - Username Validation

    /// Checks if the given username is already taken by another user.
    /// Queries the `usernames` collection first, falls back to `users` collection.
    func validateUsernameUniqueness(_ username: String, for uid: String) async throws {
        let lowercased = username.lowercased()

        // Check usernames collection (authoritative source)
        let usernameDoc = try await db.collection("usernames").document(lowercased).getDocument()
        if usernameDoc.exists, let ownerId = usernameDoc.data()?["uid"] as? String, ownerId != uid {
            throw FirebaseError.usernameTaken
        }

        // Fallback: also check users collection in case usernames collection is not fully synced
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: lowercased)
            .limit(to: 1)
            .getDocuments()

        if let doc = snapshot.documents.first, doc.documentID != uid {
            throw FirebaseError.usernameTaken
        }
    }

    private init() {}

    // MARK: - Auth

    public func login(email: String, password: String) async throws -> UserProfile {
        #if DEBUG
        print("DEBUG: Attempting email/password login for: \(email)")
        #endif
        let result = try await auth.signIn(withEmail: email, password: password)
        #if DEBUG
 print("DEBUG: Email login success — UID: \(result.user.uid)")
        #endif
        #if DEBUG
        print("DEBUG: Providers: \(result.user.providerData.map { $0.providerID })")
        #endif

        do {
            let token = try await Messaging.messaging().token()
            self.fcmToken = token
            do {
                try await db.collection("users").document(result.user.uid).collection("private").document("tokens").setData(["fcmToken": token], merge: true)
            } catch {
                #if DEBUG
 print("DEBUG: Failed to save FCM token on login: \(error.localizedDescription)")
                #endif
            }
        } catch {
            #if DEBUG
 print("DEBUG: Failed to get FCM token on login: \(error.localizedDescription)")
            #endif
        }

        return try await RetryHelper.withRetry(maxAttempts: 2) {
            try await self.fetchProfile(for: result.user.uid)
        }
    }

    public func signUp(email: String, password: String, displayName: String, username: String, dateOfBirth: Date) async throws -> UserProfile {
        let result = try await auth.createUser(withEmail: email, password: password)
        let userId = result.user.uid

        // Validate username uniqueness before writing to Firestore; delete auth user on failure to avoid orphans
        do {
            try await validateUsernameUniqueness(username, for: userId)
        } catch {
            try? await result.user.delete()
            throw error
        }

        let newCode = try await generateUniqueInviteCode()
        let newProfile = UserProfile(
            id: userId,
            inviteCode: newCode,
            email: email,
            displayName: displayName,
            username: username,
            dateOfBirth: dateOfBirth,
            avatarUrl: nil
        )

        let initialData: [String: Any] = [
            "id": newProfile.id,
            "inviteCode": newProfile.inviteCode,
            "email": email,
            "displayName": displayName,
            "username": username,
            "dateOfBirth": Timestamp(date: dateOfBirth),
            "consent": [
                "acceptedAt": FieldValue.serverTimestamp(),
                "version": LegalDocument.currentVersion,
                "acceptedDocuments": LegalDocument.allCases.map { $0.rawValue },
                "method": "email_signup"
            ] as [String: Any]
        ]

        do {
            let token = try await Messaging.messaging().token()
            self.fcmToken = token
        } catch {
            #if DEBUG
 print("DEBUG: Failed to get FCM token on signup: \(error.localizedDescription)")
            #endif
        }

        try await db.collection("users").document(userId).setData(initialData)

        // Reserve username in the usernames collection
        try await db.collection("usernames").document(username.lowercased()).setData(["uid": userId])

        if let token = self.fcmToken {
            do {
                try await db.collection("users").document(userId).collection("private").document("tokens").setData(["fcmToken": token])
            } catch {
                #if DEBUG
 print("DEBUG: Failed to save FCM token on signup: \(error.localizedDescription)")
                #endif
            }
        }

        self.currentUserProfile = newProfile
        syncInviteCodeToWidget(newProfile)
        return newProfile
    }

    // MARK: - Logout

    public nonisolated func logout() throws {
        try Auth.auth().signOut()
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
        SwiftDataSyncService.shared.clearAllStrips()
        // Clear actor-isolated state asynchronously
        Task {
            await self.clearSessionState()
        }
    }

    /// Clears in-memory session state. Called on logout and account deletion.
    func clearSessionState() {
        self.currentUserProfile = nil
        syncInviteCodeToWidget(nil)
        self.profileCache.removeAll()
        self.fcmToken = nil
        // Stop streak listener
        Task { await StreakService.shared.stopListening() }
        // Reset pagination cursor so next login starts fresh
        Task { await PhotoService.shared.resetPagination() }
    }
}
