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

    /// Deduplicates concurrent fetchProfile calls for the same userId — if a fetch
    /// is already in flight, subsequent callers reuse the same task instead of
    /// triggering redundant Firestore reads.
    private var inFlightProfileFetches: [String: Task<UserProfile, Error>] = [:]
    /// 60s keeps ban/suspend actions reactive across devices while still cutting
    /// Firestore reads for rapid consecutive fetches (e.g. list + detail views).
    let profileCacheTTL: TimeInterval = 60 // 1 minute

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
        AppLogger.auth.debug("login attempt email=\(email, privacy: .private)")
        CrashReporter.shared.breadcrumb(.auth, "login attempt")
        let result = try await auth.signIn(withEmail: email, password: password)
        let providers = result.user.providerData.map { $0.providerID }.joined(separator: ",")
        AppLogger.auth.debug("login success uid=\(result.user.uid, privacy: .private) providers=\(providers, privacy: .public)")

        // Kick FCM registration off in parallel so it doesn't block the path
        // back to the UI. Profile fetch is what gates the home screen — FCM
        // can finish on its own time. If it fails, we log; the next foreground
        // pass will refresh the token via FirebaseMessaging delegate.
        let uid = result.user.uid
        Task { [weak self] in
            guard let self else { return }
            do {
                let token = try await Messaging.messaging().token()
                await self.setFcmToken(token)
                try await RetryHelper.withRetry(maxAttempts: 3, initialDelay: 1.0, maxDelay: 4.0) {
                    try await self.storeFCMToken(token, for: uid)
                }
            } catch {
                AppLogger.auth.error("FCM token persist failed (login): \(error.localizedDescription, privacy: .public)")
            }
        }

        return try await RetryHelper.withRetry(maxAttempts: 2) {
            try await self.fetchProfile(for: uid)
        }
    }

    /// Actor-isolated setter so the parallel FCM Task can update the cached
    /// token without violating actor isolation.
    private func setFcmToken(_ token: String) {
        self.fcmToken = token
    }

    public func signUp(email: String, password: String, displayName: String, username: String, dateOfBirth: Date) async throws -> UserProfile {
        CrashReporter.shared.breadcrumb(.auth, "signUp attempt")
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

        // Denormalize birth month/day so the automation engine can match on
        // them with a single index lookup instead of parsing dateOfBirth on
        // every cron tick. createdAt powers account-age based automations
        // (e.g. "ilk hafta" rules) that the engine reads directly off the user doc.
        let calendar = Calendar(identifier: .gregorian)
        let birthComponents = calendar.dateComponents([.month, .day], from: dateOfBirth)

        let initialData: [String: Any] = [
            "id": newProfile.id,
            "inviteCode": newProfile.inviteCode,
            "email": email,
            "displayName": displayName,
            "username": username,
            "dateOfBirth": Timestamp(date: dateOfBirth),
            "birthMonth": birthComponents.month ?? 0,
            "birthDay": birthComponents.day ?? 0,
            "createdAt": FieldValue.serverTimestamp(),
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
            AppLogger.auth.error("FCM token fetch failed (signup): \(error.localizedDescription, privacy: .public)")
        }

        try await db.collection("users").document(userId).setData(initialData)

        do {
            try await db.collection("usernames").document(username.lowercased()).setData(["uid": userId])
        } catch {
            AppLogger.auth.error("username mirror write failed (signup): \(error.localizedDescription, privacy: .public)")
        }

        if let token = self.fcmToken {
            do {
                try await RetryHelper.withRetry(maxAttempts: 3, initialDelay: 1.0, maxDelay: 4.0) {
                    try await self.storeFCMToken(token, for: userId)
                }
            } catch {
                AppLogger.auth.error("FCM token persist failed (signup): \(error.localizedDescription, privacy: .public)")
            }
        }

        self.currentUserProfile = newProfile
        syncInviteCodeToWidget(newProfile)
        // Cold-start welcome strips are seeded server-side by the
        // `seedWelcomeStrips` Cloud Function (triggered on user doc create).
        // Client-side seeding doesn't work because Firestore rules require
        // `senderId == request.auth.uid` for strip writes.
        return newProfile
    }

    // MARK: - Logout

    /// Logout: clears all actor-isolated state BEFORE Firebase signOut to prevent
    /// race conditions where readers observe stale currentUserProfile between
    /// signOut and async state clearing.
    public func logout() async throws {
        // 1. Clear all actor-isolated state first (we're on the actor here)
        self.clearSessionState()
        // 2. Clear local SwiftData cache
        SwiftDataSyncService.shared.clearAllStrips()
        // 3. Only then sign out Firebase
        try Auth.auth().signOut()
        // 4. Notify observers after everything is clean
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }

    /// Clears in-memory session state. Called on logout and account deletion.
    func clearSessionState() {
        CrashReporter.shared.breadcrumb(.auth, "clearSessionState")
        CrashReporter.shared.clearUserId()
        self.currentUserProfile = nil
        syncInviteCodeToWidget(nil)
        self.profileCache.removeAll()
        self.fcmToken = nil
        self.cachedBlockedIds = nil
        self.blockedCacheTime = nil
        // Drop the persisted blocked set too — it belongs to the previous user;
        // the next signed-in account will rebuild its own on first fetch.
        Self.clearPersistedBlockedSet()
        // Remove sensitive tokens from Keychain on logout
        KeychainManager.delete(forKey: KeychainManager.Key.fcmToken)
        KeychainManager.delete(forKey: KeychainManager.Key.widgetPushToken)
        // Stop all per-service listeners. Each is tracked separately because
        // the services run as actors with their own listener state — a missed
        // entry here means a Firestore listener keeps firing after logout
        // (memory + read-quota waste, plus stale data flickering on re-login).
        Task { await StreakService.shared.stopListening() }
        Task { await AchievementService.shared.stopListening() }
        Task { await PhotoService.shared.stopAllListeners() }
        Task { await ChatService.shared.stopAllListeners() }
        Task { await AppNotificationService.shared.stopAllListeners() }
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
                try await RetryHelper.withRetry(maxAttempts: 3, initialDelay: 1.0, maxDelay: 4.0) {
                    try await self.storeFCMToken(token, for: uid)
                    // Also store on user doc as fallback for Cloud Functions
                    try await self.db.collection("users").document(uid)
                        .updateData(["fcmToken": token])
                }
            } catch {
                AppLogger.auth.error("FCM token persist failed (refresh): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Persists the in-memory cached FCM token to Firestore after login.
    public func persistCachedFCMToken() async {
        guard let token = self.fcmToken, let uid = auth.currentUser?.uid else { return }
        do {
            try await RetryHelper.withRetry(maxAttempts: 3, initialDelay: 1.0, maxDelay: 4.0) {
                try await self.storeFCMToken(token, for: uid)
                try await self.db.collection("users").document(uid)
                    .updateData(["fcmToken": token])
            }
        } catch {
            AppLogger.auth.error("FCM token persist failed (cached): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Syncs the widget push token (APNs device token) to Firestore for server-side widget pushes.
    public func syncWidgetPushToken() async {
        guard let uid = auth.currentUser?.uid else { return }
        // Prefer Keychain (sensitive storage) and fall back to App Group UserDefaults
        // for back-compat with older installs that haven't migrated yet.
        let keychainToken = KeychainManager.load(forKey: KeychainManager.Key.widgetPushToken)
        let sharedDefaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
        let udToken = sharedDefaults?.string(forKey: "widgetPushToken")
        guard let tokenHex = (keychainToken ?? udToken), !tokenHex.isEmpty else { return }
        do {
            try await db.collection("users").document(uid)
                .collection("private").document("tokens")
                .setData([
                    "widgetPushToken": tokenHex,
                    "widgetPlatform": "ios",
                    "widgetUpdatedAt": FieldValue.serverTimestamp()
                ], merge: true)
        } catch {
            AppLogger.push.error("widget push token sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Notification Preferences

    /// Valid notification preference keys — allowlist to prevent injection via dot-path traversal.
    private static let validNotificationKeys: Set<String> = [
        "push_enabled", "quiet_hours_enabled", "quiet_hours_start", "quiet_hours_end",
        "notif_strips", "notif_comments", "notif_strip_chat", "notif_dms",
        "notif_support", "notif_friends", "notif_nudge", "notif_streaks",
        "notif_prompts", "notif_weekly"
    ]

    /// Updates a single notification preference key in Firestore.
    public func updateNotificationPreference(key: String, enabled: Bool) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        guard Self.validNotificationKeys.contains(key) else {
            AppLogger.auth.error("rejected invalid notification key=\(key, privacy: .public)")
            return
        }
        try await db.collection("users").document(uid).updateData([
            "notificationPreferences.\(key)": enabled
        ])
    }

    private func storeFCMToken(_ token: String, for uid: String) async throws {
        // Mirror into Keychain (sensitive storage) so token is protected at rest
        // even if Firestore write succeeds but other code needs to re-read it locally.
        KeychainManager.save(token, forKey: KeychainManager.Key.fcmToken)
        try await db.collection("users").document(uid)
            .collection("private").document("tokens")
            .setData([
                "fcmToken": token,
                "platform": "ios",
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
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

        // Dedup: if another caller already started a fetch for this uid, reuse it
        if let existing = inFlightProfileFetches[userId] {
            return try await existing.value
        }

        let task = Task<UserProfile, Error> { [db] in
            let doc = try await db.collection("users").document(userId).getDocument()
            guard let data = doc.data() else { throw FirebaseError.userNotFound }

            return UserProfile(
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
                notificationPreferences: {
                    // Firestore map contains mixed types (Bool for toggles, Int for quiet hours).
                    // Extract only Bool entries for the [String: Bool] model.
                    guard let raw = data["notificationPreferences"] as? [String: Any] else { return nil }
                    return raw.compactMapValues { $0 as? Bool }
                }()
            )
        }
        inFlightProfileFetches[userId] = task

        defer { inFlightProfileFetches[userId] = nil }

        let profile = try await task.value
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

        let calendar = Calendar(identifier: .gregorian)
        let birthComponents = calendar.dateComponents([.month, .day], from: dateOfBirth)
        let updates: [String: Any] = [
            "displayName": displayName,
            "username": username,
            "dateOfBirth": Timestamp(date: dateOfBirth),
            "birthMonth": birthComponents.month ?? 0,
            "birthDay": birthComponents.day ?? 0
        ]
        try await db.collection("users").document(uid).updateData(updates)

        do {
            try await db.collection("usernames").document(username.lowercased()).setData(["uid": uid])
        } catch {
            AppLogger.auth.error("username mirror write failed (profile completion): \(error.localizedDescription, privacy: .public)")
        }

        // Refresh cached profile
        _ = try await fetchProfile(for: uid, forceRefresh: true)
        // Welcome strips are seeded server-side via `seedWelcomeStrips` Cloud Function.
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
        if let dateOfBirth {
            updates["dateOfBirth"] = Timestamp(date: dateOfBirth)
            // Keep denormalized birth month/day in sync for the automation engine.
            let calendar = Calendar(identifier: .gregorian)
            let birthComponents = calendar.dateComponents([.month, .day], from: dateOfBirth)
            updates["birthMonth"] = birthComponents.month ?? 0
            updates["birthDay"] = birthComponents.day ?? 0
        }
        if let favoriteSong { updates["favoriteSong"] = favoriteSong }
        if let zodiacSign { updates["zodiacSign"] = zodiacSign }
        if let personalityEmojis { updates["personalityEmojis"] = personalityEmojis }

        try await db.collection("users").document(uid).updateData(updates)

        // Refresh cached profile
        _ = try await fetchProfile(for: uid, forceRefresh: true)
    }

    // MARK: - Apple Sign-In

    public func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> UserProfile {
        CrashReporter.shared.breadcrumb(.auth, "signInWithApple")
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
                try await RetryHelper.withRetry(maxAttempts: 3, initialDelay: 1.0, maxDelay: 4.0) {
                    try await self.storeFCMToken(token, for: uid)
                }
            } catch {
                AppLogger.auth.error("FCM token persist failed (Apple existing): \(error.localizedDescription, privacy: .public)")
            }
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

        // Apple sign-in doesn't collect dateOfBirth at signup — birthMonth/Day
        // get filled in later when the user completes their profile. createdAt
        // is set unconditionally so account-age rules apply from day zero.
        let initialData: [String: Any] = [
            "id": uid,
            "inviteCode": newCode,
            "email": result.user.email ?? "",
            "displayName": displayName,
            "createdAt": FieldValue.serverTimestamp(),
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
            try await RetryHelper.withRetry(maxAttempts: 3, initialDelay: 1.0, maxDelay: 4.0) {
                try await self.storeFCMToken(token, for: uid)
            }
        } catch {
            AppLogger.auth.error("FCM token persist failed (Apple new): \(error.localizedDescription, privacy: .public)")
        }

        self.currentUserProfile = profile
        syncInviteCodeToWidget(profile)
        return profile
    }

    // MARK: - Avatar

    public func uploadAvatar(_ image: UIImage) async throws -> String {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        // Resize before encoding so a 12 MP camera shot doesn't get uploaded as
        // a 6 MB avatar (the bucket sat at multi-MB blobs before this). 512px
        // is plenty for the largest avatar surface (profile header at 2x/3x).
        let resized = image.resizedToMax(dimension: AppLimits.avatarSize)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { throw FirebaseError.compressionFailed }

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
        CrashReporter.shared.breadcrumb(.auth, "deleteAccount")
        guard let user = auth.currentUser else { throw FirebaseError.unauthenticated }
        let uid = user.uid
        let username = currentUserProfile?.username?.lowercased()

        // Delete Auth account first — this is the irreversible step.
        // If it fails, Firestore data is intact and the user can retry.
        try await user.delete()

        // Best-effort Firestore cleanup (Cloud Functions handle cascading)
        if let username {
            try? await db.collection("usernames").document(username).delete()
        }
        try? await db.collection("users").document(uid).delete()

        UserDefaults.standard.set(true, forKey: "show_deleted_account_farewell")
        clearSessionState()
    }

    // MARK: - Block / Unblock

    public func blockUser(_ userId: String) async throws {
        CrashReporter.shared.breadcrumb(.auth, "blockUser")
        defer {
            // Block removes the user from friend lists; broadcast so Camera
            // and other surfaces drop their cached friend lists.
            NotificationCenter.default.post(name: .friendListChanged, object: nil)
        }
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        try await db.collection("users").document(uid)
            .collection("blocked").document(userId)
            .setData(["blockedAt": FieldValue.serverTimestamp()])
        // Remove from friends if exists
        try? await db.collection("users").document(uid)
            .collection("friendships").document(userId).delete()
        try? await db.collection("users").document(userId)
            .collection("friendships").document(uid).delete()
        // Eagerly add to the persisted blocked set so feeds/chats filter the
        // user out even if a refresh fetch fails right after the block.
        Self.mutatePersistedBlockedSet { $0.insert(userId) }
        // Invalidate the in-memory cache so the next fetch rebuilds from Firestore.
        // Partial mutation (insert) races with concurrent refreshes and can desync.
        cachedBlockedIds = nil
        blockedCacheTime = nil
    }

    public func unblockUser(_ userId: String) async throws {
        CrashReporter.shared.breadcrumb(.auth, "unblockUser")
        defer {
            NotificationCenter.default.post(name: .friendListChanged, object: nil)
        }
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        try await db.collection("users").document(uid)
            .collection("blocked").document(userId).delete()
        Self.mutatePersistedBlockedSet { $0.remove(userId) }
        // See note in blockUser — clear whole cache to avoid races.
        cachedBlockedIds = nil
        blockedCacheTime = nil
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
        // Persist so a cold start with an offline network can still filter
        // blocked users (defense-in-depth — see bestKnownBlockedUserIds).
        Self.persistBlockedSet(ids)
        return ids
    }

    /// Returns the best known blocked user set without throwing. Use this in
    /// realtime listeners on the failure path of fetchBlockedUserIds — falling
    /// back to an empty set would let a freshly blocked user reappear in the
    /// feed during a brief network outage.
    public func bestKnownBlockedUserIds() -> Set<String> {
        if let cached = cachedBlockedIds { return cached }
        return Self.loadPersistedBlockedSet()
    }

    // MARK: - Persisted blocked-set helpers

    private static let persistedBlockedKey = "blocked_user_ids"

    private static func loadPersistedBlockedSet() -> Set<String> {
        guard let array = UserDefaults(suiteName: AppConstants.appGroupID)?
            .stringArray(forKey: persistedBlockedKey) else { return [] }
        return Set(array)
    }

    private static func persistBlockedSet(_ ids: Set<String>) {
        UserDefaults(suiteName: AppConstants.appGroupID)?
            .set(Array(ids), forKey: persistedBlockedKey)
    }

    private static func mutatePersistedBlockedSet(_ transform: (inout Set<String>) -> Void) {
        var current = loadPersistedBlockedSet()
        transform(&current)
        persistBlockedSet(current)
    }

    private static func clearPersistedBlockedSet() {
        UserDefaults(suiteName: AppConstants.appGroupID)?
            .removeObject(forKey: persistedBlockedKey)
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
