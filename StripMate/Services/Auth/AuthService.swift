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
        self.cachedBlockedIds = nil
        self.blockedCacheTime = nil
        // Stop streak listener
        Task { await StreakService.shared.stopListening() }
        // Reset pagination cursor so next login starts fresh
        Task { await PhotoService.shared.resetPagination() }
    }

    // MARK: - FCM Token Management

    /// Updates the FCM token in Firestore. Called by AppDelegate on token refresh.
    public func updateFCMToken(_ token: String) {
        self.fcmToken = token
        guard let uid = auth.currentUser?.uid else { return }
        Task {
            do {
                try await db.collection("users").document(uid)
                    .collection("private").document("tokens")
                    .setData(["fcmToken": token], merge: true)
                // Also store on user doc as fallback for Cloud Functions
                try await db.collection("users").document(uid)
                    .updateData(["fcmToken": token])
            } catch {
                #if DEBUG
                print("DEBUG: Failed to persist FCM token: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Persists the in-memory cached FCM token to Firestore after login.
    public func persistCachedFCMToken() async {
        guard let token = self.fcmToken, let uid = auth.currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("private").document("tokens")
                .setData(["fcmToken": token], merge: true)
            try await db.collection("users").document(uid)
                .updateData(["fcmToken": token])
        } catch {
            #if DEBUG
            print("DEBUG: Failed to persist cached FCM token: \(error.localizedDescription)")
            #endif
        }
    }

    /// Syncs the widget push token (APNs device token) to Firestore for server-side widget pushes.
    public func syncWidgetPushToken() async {
        guard let uid = auth.currentUser?.uid else { return }
        let sharedDefaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
        guard let tokenHex = sharedDefaults?.string(forKey: "widgetPushToken"), !tokenHex.isEmpty else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("private").document("tokens")
                .setData(["widgetPushToken": tokenHex], merge: true)
        } catch {
            #if DEBUG
            print("DEBUG: Failed to sync widget push token: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Notification Preferences

    /// Updates a single notification preference key in Firestore.
    public func updateNotificationPreference(key: String, enabled: Bool) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        try await db.collection("users").document(uid).updateData([
            "notificationPreferences.\(key)": enabled
        ])
    }

    /// Syncs quiet hours start/end to Firestore for Cloud Functions.
    public func syncQuietHours(start: Int, end: Int) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        try await db.collection("users").document(uid).updateData([
            "notificationPreferences.quiet_hours_start": start,
            "notificationPreferences.quiet_hours_end": end
        ])
    }

    // MARK: - Profile

    /// Whether the current user needs to complete their profile.
    public var needsProfileCompletion: Bool {
        currentUserProfile?.needsProfileCompletion ?? false
    }

    /// Fetches a user profile from Firestore with in-memory caching.
    public func fetchProfile(for userId: String, forceRefresh: Bool = false) async throws -> UserProfile {
        // Check cache first
        if !forceRefresh, let cached = profileCache[userId],
           Date().timeIntervalSince(cached.fetchedAt) < profileCacheTTL {
            return cached.profile
        }

        let doc = try await db.collection("users").document(userId).getDocument()
        guard let data = doc.data() else { throw FirebaseError.userNotFound }

        let profile = UserProfile(
            id: userId,
            inviteCode: data["inviteCode"] as? String ?? "",
            email: data["email"] as? String,
            displayName: data["displayName"] as? String,
            username: data["username"] as? String,
            dateOfBirth: (data["dateOfBirth"] as? Timestamp)?.dateValue(),
            avatarUrl: data["avatarUrl"] as? String,
            bio: data["bio"] as? String,
            statusEmoji: data["statusEmoji"] as? String,
            favoriteSong: data["favoriteSong"] as? String,
            zodiacSign: data["zodiacSign"] as? String,
            personalityEmojis: data["personalityEmojis"] as? [String],
            notificationPreferences: data["notificationPreferences"] as? [String: Bool]
        )

        profileCache[userId] = (profile: profile, fetchedAt: Date())

        // Update current user profile if it's us
        if userId == auth.currentUser?.uid {
            self.currentUserProfile = profile
            syncInviteCodeToWidget(profile)
        }

        return profile
    }

    /// Completes profile for new users (Apple Sign-In or signup flow).
    public func completeProfile(displayName: String, username: String, dateOfBirth: Date) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }

        try await validateUsernameUniqueness(username, for: uid)

        let updates: [String: Any] = [
            "displayName": displayName,
            "username": username,
            "dateOfBirth": Timestamp(date: dateOfBirth)
        ]
        try await db.collection("users").document(uid).updateData(updates)

        // Reserve username
        try await db.collection("usernames").document(username.lowercased()).setData(["uid": uid])

        // Refresh cached profile
        _ = try await fetchProfile(for: uid, forceRefresh: true)
    }

    /// Updates existing profile fields.
    public func updateProfile(displayName: String, username: String?, bio: String?, dateOfBirth: Date?, favoriteSong: String?, zodiacSign: String?, personalityEmojis: [String]?) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }

        // Validate username if changed
        if let newUsername = username {
            let current = currentUserProfile?.username?.lowercased()
            if current != newUsername.lowercased() {
                try await validateUsernameUniqueness(newUsername, for: uid)
                // Reserve new username, delete old
                try await db.collection("usernames").document(newUsername.lowercased()).setData(["uid": uid])
                if let old = current {
                    try? await db.collection("usernames").document(old).delete()
                }
            }
        }

        var updates: [String: Any] = ["displayName": displayName]
        if let username { updates["username"] = username }
        if let bio { updates["bio"] = bio }
        if let dateOfBirth { updates["dateOfBirth"] = Timestamp(date: dateOfBirth) }
        if let favoriteSong { updates["favoriteSong"] = favoriteSong }
        if let zodiacSign { updates["zodiacSign"] = zodiacSign }
        if let personalityEmojis { updates["personalityEmojis"] = personalityEmojis }

        try await db.collection("users").document(uid).updateData(updates)

        // Refresh cached profile
        _ = try await fetchProfile(for: uid, forceRefresh: true)
    }

    // MARK: - Apple Sign-In

    public func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> UserProfile {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        let result = try await auth.signIn(with: credential)
        let uid = result.user.uid

        // Check if user doc exists
        let doc = try await db.collection("users").document(uid).getDocument()
        if doc.exists {
            // Existing user — fetch profile
            do {
                let token = try await Messaging.messaging().token()
                self.fcmToken = token
                try? await db.collection("users").document(uid)
                    .collection("private").document("tokens")
                    .setData(["fcmToken": token], merge: true)
            } catch {}
            return try await fetchProfile(for: uid, forceRefresh: true)
        }

        // New user — create minimal profile
        let newCode = try await generateUniqueInviteCode()
        let displayName = fullName ?? result.user.displayName ?? "Apple User"
        let profile = UserProfile(
            id: uid,
            inviteCode: newCode,
            email: result.user.email,
            displayName: displayName,
            username: nil,
            dateOfBirth: nil,
            avatarUrl: nil
        )

        let initialData: [String: Any] = [
            "id": uid,
            "inviteCode": newCode,
            "email": result.user.email ?? "",
            "displayName": displayName,
            "consent": [
                "acceptedAt": FieldValue.serverTimestamp(),
                "version": LegalDocument.currentVersion,
                "acceptedDocuments": LegalDocument.allCases.map { $0.rawValue },
                "method": "apple_signin"
            ] as [String: Any]
        ]
        try await db.collection("users").document(uid).setData(initialData)

        // Save FCM token
        do {
            let token = try await Messaging.messaging().token()
            self.fcmToken = token
            try? await db.collection("users").document(uid)
                .collection("private").document("tokens")
                .setData(["fcmToken": token])
        } catch {}

        self.currentUserProfile = profile
        syncInviteCodeToWidget(profile)
        return profile
    }

    // MARK: - Avatar

    public func uploadAvatar(_ image: UIImage) async throws -> String {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw FirebaseError.compressionFailed }

        let ref = Storage.storage().reference().child("avatars/\(uid).jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)
        let url = try await ref.downloadURL().absoluteString

        try await db.collection("users").document(uid).updateData(["avatarUrl": url])

        // Update cached profile
        _ = try await fetchProfile(for: uid, forceRefresh: true)
        return url
    }

    // MARK: - Search

    public func searchUser(byCode code: String) async throws -> UserProfile {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count >= 6, trimmed.count <= 10 else { throw FirebaseError.invalidCodeFormat }

        // Rate limiting
        let now = Date()
        searchAttempts.removeAll { now.timeIntervalSince($0) > 60 }
        guard searchAttempts.count < maxSearchAttemptsPerMinute else {
            throw FirebaseError.invalidCodeFormat
        }
        searchAttempts.append(now)

        let snapshot = try await db.collection("users")
            .whereField("inviteCode", isEqualTo: trimmed)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { throw FirebaseError.invalidInviteCode }
        let data = doc.data()

        return UserProfile(
            id: doc.documentID,
            inviteCode: data["inviteCode"] as? String ?? "",
            email: data["email"] as? String,
            displayName: data["displayName"] as? String,
            username: data["username"] as? String,
            dateOfBirth: (data["dateOfBirth"] as? Timestamp)?.dateValue(),
            avatarUrl: data["avatarUrl"] as? String,
            bio: data["bio"] as? String,
            statusEmoji: data["statusEmoji"] as? String
        )
    }

    // MARK: - Password Reset

    public func sendPasswordReset(to email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    // MARK: - Account Deletion

    public func deleteAccount() async throws {
        guard let user = auth.currentUser else { throw FirebaseError.unauthenticated }
        let uid = user.uid

        // Delete username reservation
        if let username = currentUserProfile?.username?.lowercased() {
            try? await db.collection("usernames").document(username).delete()
        }

        // Delete user document (Cloud Functions handle cascading cleanup)
        try? await db.collection("users").document(uid).delete()

        clearSessionState()
        try await user.delete()
    }

    // MARK: - Block / Unblock

    public func blockUser(_ userId: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        try await db.collection("users").document(uid)
            .collection("blocked").document(userId)
            .setData(["blockedAt": FieldValue.serverTimestamp()])
        // Remove from friends if exists
        try? await db.collection("users").document(uid)
            .collection("friendships").document(userId).delete()
        try? await db.collection("users").document(userId)
            .collection("friendships").document(uid).delete()
        // Invalidate cache
        cachedBlockedIds?.insert(userId)
    }

    public func unblockUser(_ userId: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        try await db.collection("users").document(uid)
            .collection("blocked").document(userId).delete()
        cachedBlockedIds?.remove(userId)
    }

    public func invalidateBlockedCache() {
        cachedBlockedIds = nil
        blockedCacheTime = nil
    }

    public func fetchBlockedUserIds() async throws -> Set<String> {
        // Return cached if fresh
        if let cached = cachedBlockedIds, let cacheTime = blockedCacheTime,
           Date().timeIntervalSince(cacheTime) < profileCacheTTL {
            return cached
        }

        guard let uid = auth.currentUser?.uid else { return [] }
        let snapshot = try await db.collection("users").document(uid)
            .collection("blocked").getDocuments()
        let ids = Set(snapshot.documents.map { $0.documentID })
        cachedBlockedIds = ids
        blockedCacheTime = Date()
        return ids
    }

    // MARK: - Report

    public func reportUser(_ userId: String, reason: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        try await db.collection("reports").addDocument(data: [
            "reporterId": uid,
            "reportedUserId": userId,
            "reason": reason,
            "type": "user",
            "timestamp": FieldValue.serverTimestamp()
        ])
    }

    public func reportContent(contentType: String, contentId: String, contentOwnerId: String, reason: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        try await db.collection("reports").addDocument(data: [
            "reporterId": uid,
            "contentType": contentType,
            "contentId": contentId,
            "contentOwnerId": contentOwnerId,
            "reason": reason,
            "timestamp": FieldValue.serverTimestamp()
        ])
    }
}
