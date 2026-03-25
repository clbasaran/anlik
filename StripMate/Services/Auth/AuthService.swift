import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseStorage
import UIKit

/// Handles authentication, profile management, and FCM token updates.
public actor AuthService {
    public static let shared = AuthService()
    
    private var auth: Auth { Auth.auth() }
    private var db: Firestore { Firestore.firestore() }
    
    public var currentUserProfile: UserProfile?
    public var fcmToken: String?
    
    /// Syncs invite code to App Group for QR Code Widget
    private func syncInviteCodeToWidget(_ profile: UserProfile?) {
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
    private var profileCache: [String: (profile: UserProfile, fetchedAt: Date)] = [:]
    private let profileCacheTTL: TimeInterval = 300 // 5 minutes
    
    // MARK: - Unique Invite Code Generation
    
    /// Generates a unique 8-char invite code, verifying uniqueness against Firestore.
    /// Retries up to `maxAttempts` times if a collision is detected.
    private func generateUniqueInviteCode(maxAttempts: Int = 5) async throws -> String {
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
    
    private init() {}
    
    // MARK: - Auth
    
    public func login(email: String, password: String) async throws -> UserProfile {
        #if DEBUG
        print("DEBUG: Attempting email/password login for: \(email)")
        #endif
        let result = try await auth.signIn(withEmail: email, password: password)
        #if DEBUG
        print("DEBUG: ✅ Email login success — UID: \(result.user.uid)")
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
                print("DEBUG: ⚠️ Failed to save FCM token on login: \(error.localizedDescription)")
                #endif
            }
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ Failed to get FCM token on login: \(error.localizedDescription)")
            #endif
        }

        return try await RetryHelper.withRetry(maxAttempts: 2) {
            try await self.fetchProfile(for: result.user.uid)
        }
    }
    
    public func signUp(email: String, password: String, displayName: String, username: String, dateOfBirth: Date) async throws -> UserProfile {
        let result = try await auth.createUser(withEmail: email, password: password)
        let userId = result.user.uid
        
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
            print("DEBUG: ⚠️ Failed to get FCM token on signup: \(error.localizedDescription)")
            #endif
        }

        try await db.collection("users").document(userId).setData(initialData)

        if let token = self.fcmToken {
            do {
                try await db.collection("users").document(userId).collection("private").document("tokens").setData(["fcmToken": token])
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ Failed to save FCM token on signup: \(error.localizedDescription)")
                #endif
            }
        }

        self.currentUserProfile = newProfile
        syncInviteCodeToWidget(newProfile)
        return newProfile
    }
    
    public func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> UserProfile {
        let credential = OAuthProvider.credential(
            providerID: .apple,
            idToken: idToken,
            rawNonce: nonce
        )
        let result = try await auth.signIn(with: credential)
        let userId = result.user.uid
        let appleEmail = result.user.email
        
        #if DEBUG
        print("DEBUG: ✅ Apple Sign In — UID: \(userId), email: \(appleEmail ?? "nil")")
        #endif
        #if DEBUG
        print("DEBUG: Providers: \(result.user.providerData.map { $0.providerID })")
        #endif
        
        let userDoc = db.collection("users").document(userId)
        let document: DocumentSnapshot?
        do {
            document = try await userDoc.getDocument()
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ Failed to fetch Apple user doc: \(error.localizedDescription)")
            #endif
            document = nil
        }
        
        if let doc = document, doc.exists, let data = doc.data() {
            let dob = (data["dateOfBirth"] as? Timestamp)?.dateValue()
            let existingEmail = data["email"] as? String
            let effectiveEmail = existingEmail ?? appleEmail
            
            let profile = UserProfile(
                id: userId,
                inviteCode: data["inviteCode"] as? String ?? "",
                email: effectiveEmail,
                displayName: data["displayName"] as? String,
                username: data["username"] as? String,
                dateOfBirth: dob,
                avatarUrl: data["avatarUrl"] as? String,
                bio: data["bio"] as? String,
                statusEmoji: data["statusEmoji"] as? String
            )
            self.currentUserProfile = profile
            syncInviteCodeToWidget(profile)
            
            // Always ensure email is saved in Firestore (may be missing from earlier Apple sign-ins)
            // Also replace Apple relay emails with real email if available
            if let email = appleEmail, !email.isEmpty {
                let stored = existingEmail ?? ""
                if stored.isEmpty || (stored.contains("privaterelay.appleid.com") && !email.contains("privaterelay.appleid.com")) {
                    do {
                        try await userDoc.setData(["email": email], merge: true)
                    } catch {
                        #if DEBUG
                        print("DEBUG: ⚠️ Failed to update Apple email: \(error.localizedDescription)")
                        #endif
                    }
                }
            }

            // If Apple provides fullName and displayName is missing/generic, update it
            if let name = fullName, !name.isEmpty {
                let currentName = data["displayName"] as? String ?? ""
                if currentName.isEmpty || currentName == "Apple User" {
                    do {
                        try await userDoc.setData(["displayName": name], merge: true)
                    } catch {
                        #if DEBUG
                        print("DEBUG: ⚠️ Failed to update Apple displayName: \(error.localizedDescription)")
                        #endif
                    }
                    // Update local profile with the new name
                    self.currentUserProfile = UserProfile(
                        id: profile.id,
                        inviteCode: profile.inviteCode,
                        email: effectiveEmail,
                        displayName: name,
                        username: profile.username,
                        dateOfBirth: profile.dateOfBirth,
                        avatarUrl: profile.avatarUrl,
                        bio: profile.bio,
                        statusEmoji: profile.statusEmoji
                    )
                }
            }
            
            do {
                let token = try await Messaging.messaging().token()
                self.fcmToken = token
                do {
                    try await db.collection("users").document(userId).collection("private").document("tokens").setData(["fcmToken": token], merge: true)
                } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ Failed to save FCM token (Apple existing): \(error.localizedDescription)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ Failed to get FCM token (Apple existing): \(error.localizedDescription)")
                #endif
            }

            #if DEBUG
            print("DEBUG: Loaded existing profile: \(profile.displayName ?? "nil"), inviteCode: \(profile.inviteCode)")
            #endif
            return profile
        } else {
            // New Apple Sign In — create user document
            let newCode = try await generateUniqueInviteCode()
            let name = fullName ?? "Apple User"
            let profile = UserProfile(
                id: userId,
                inviteCode: newCode,
                email: appleEmail,
                displayName: name,
                username: nil,
                dateOfBirth: nil,
                avatarUrl: nil
            )
            
            let initialData: [String: Any] = [
                "id": profile.id,
                "inviteCode": profile.inviteCode,
                "email": appleEmail as Any,
                "displayName": name,
                "consent": [
                    "acceptedAt": FieldValue.serverTimestamp(),
                    "version": LegalDocument.currentVersion,
                    "acceptedDocuments": LegalDocument.allCases.map { $0.rawValue },
                    "method": "apple_signin"
                ] as [String: Any]
            ]
            
            do {
                let token = try await Messaging.messaging().token()
                self.fcmToken = token
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ Failed to get FCM token (Apple new): \(error.localizedDescription)")
                #endif
            }

            try await db.collection("users").document(userId).setData(initialData)

            if let token = self.fcmToken {
                do {
                    try await db.collection("users").document(userId).collection("private").document("tokens").setData(["fcmToken": token])
                } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ Failed to save FCM token (Apple new): \(error.localizedDescription)")
                    #endif
                }
            }

            self.currentUserProfile = profile
            syncInviteCodeToWidget(profile)
            await SwiftDataSyncService.shared.syncUserToLocal(profile)
            
            #if DEBUG
            print("DEBUG: Created new Apple user profile: \(name), code: \(newCode)")
            #endif
            return profile
        }
    }
    
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
    private func clearSessionState() {
        self.currentUserProfile = nil
        syncInviteCodeToWidget(nil)
        self.profileCache.removeAll()
        self.fcmToken = nil
        // Stop streak listener
        Task { await StreakService.shared.stopListening() }
    }
    
    // MARK: - Profile
    
    public func fetchProfile(for userId: String, forceRefresh: Bool = false) async throws -> UserProfile {
        // Return cached profile if within TTL (skip for own profile to keep it fresh)
        if !forceRefresh,
           userId != auth.currentUser?.uid,
           let cached = profileCache[userId],
           Date().timeIntervalSince(cached.fetchedAt) < profileCacheTTL {
            return cached.profile
        }

        let userDoc = db.collection("users").document(userId)
        let document = try await userDoc.getDocument(source: forceRefresh ? .server : .default)
        
        guard document.exists, let data = document.data() else {
            throw FirebaseError.userNotFound
        }
        
        let dob = (data["dateOfBirth"] as? Timestamp)?.dateValue()
        
        let profile = UserProfile(
            id: userId,
            inviteCode: data["inviteCode"] as? String ?? "",
            email: data["email"] as? String,
            displayName: data["displayName"] as? String,
            username: data["username"] as? String,
            dateOfBirth: dob,
            avatarUrl: data["avatarUrl"] as? String,
            bio: data["bio"] as? String,
            statusEmoji: data["statusEmoji"] as? String
        )
        
        // Cache the profile
        profileCache[userId] = (profile: profile, fetchedAt: Date())
        
        if userId == auth.currentUser?.uid {
            self.currentUserProfile = profile
            syncInviteCodeToWidget(profile)

            let tokenToSave: String?
            do {
                let t = try await Messaging.messaging().token()
                self.fcmToken = t
                tokenToSave = t
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ Failed to get FCM token in fetchProfile: \(error.localizedDescription)")
                #endif
                tokenToSave = self.fcmToken
            }

            if let token = tokenToSave {
                do {
                    try await userDoc.collection("private").document("tokens").setData(["fcmToken": token], merge: true)
                } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ Failed to save FCM token in fetchProfile: \(error.localizedDescription)")
                    #endif
                }
            }
        }
        
        await SwiftDataSyncService.shared.syncUserToLocal(profile)
        
        return profile
    }
    
    // MARK: - Push Tokens
    
    public func updateFCMToken(_ token: String) {
        self.fcmToken = token
        if let uid = auth.currentUser?.uid {
            Task {
                do {
                    try await db.collection("users").document(uid).collection("private").document("tokens").setData(["fcmToken": token], merge: true)
                    #if DEBUG
                    print("DEBUG: ✅ FCM token saved to Firestore for user \(uid)")
                    #endif
                } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ Failed to save FCM token: \(error.localizedDescription)")
                    #endif
                }
            }
        } else {
            #if DEBUG
            print("DEBUG: ⚠️ FCM token received but no authenticated user yet — cached for later")
            #endif
        }
    }
    
    /// Re-persist the cached FCM token after login (covers race condition where token arrives before auth)
    public func persistCachedFCMToken() async {
        guard let token = fcmToken, let uid = auth.currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).collection("private").document("tokens").setData(["fcmToken": token], merge: true)
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ Failed to persist FCM token: \(error.localizedDescription)")
            #endif
        }
        #if DEBUG
        print("DEBUG: ✅ Persisted cached FCM token for user \(uid)")
        #endif

        // Also sync widget push token if available
        await syncWidgetPushToken()
    }

    /// Upload widget push token from shared UserDefaults to Firestore (for APNs widget updates)
    public func syncWidgetPushToken() async {
        guard let uid = auth.currentUser?.uid else { return }
        let sharedDefaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
        guard let widgetToken = sharedDefaults?.string(forKey: "widget_push_token"), !widgetToken.isEmpty else { return }

        do {
            try await db.collection("users").document(uid).collection("private").document("tokens").setData(["widgetPushToken": widgetToken], merge: true)
        } catch {
            #if DEBUG
            print("DEBUG: Failed to sync widget push token: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Update notification preference in Firestore (for Cloud Functions to check)
    public func updateNotificationPreference(key: String, enabled: Bool) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        try await db.collection("users").document(uid).setData([
            "notificationPreferences": [key: enabled]
        ], merge: true)
    }
    
    /// Sync quiet hours start/end to Firestore for Cloud Functions
    public func syncQuietHours(start: Int, end: Int) async throws {
        guard let uid = auth.currentUser?.uid else { return }
        try await db.collection("users").document(uid).setData([
            "notificationPreferences": [
                "quiet_hours_start": start,
                "quiet_hours_end": end
            ]
        ], merge: true)
    }
    
    // MARK: - Search
    
    /// Rate limiting state for invite code searches (brute-force protection)
    private var searchAttempts: [Date] = []
    private let maxSearchAttemptsPerMinute = 5
    
    public func searchUser(byCode code: String) async throws -> UserProfile {
        // Rate limit: max 5 searches per minute
        let now = Date()
        searchAttempts = searchAttempts.filter { now.timeIntervalSince($0) < 60 }
        guard searchAttempts.count < maxSearchAttemptsPerMinute else {
            throw AppError.custom(String(localized: "Çok fazla arama yapıldı. Lütfen bir dakika bekleyin."))
        }
        searchAttempts.append(now)

        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try invite code first (8 chars, uppercase)
        if trimmed.count == 8 {
            let uppercaseCode = trimmed.uppercased()
            let snapshot = try await db.collection("users")
                .whereField("inviteCode", isEqualTo: uppercaseCode)
                .limit(to: 1)
                .getDocuments()

            if let partnerDoc = snapshot.documents.first {
                return try await fetchProfile(for: partnerDoc.documentID)
            }
        }

        // Try username (case-insensitive)
        let lowercased = trimmed.lowercased()
        let usernameSnapshot = try await db.collection("users")
            .whereField("username", isEqualTo: lowercased)
            .limit(to: 1)
            .getDocuments()

        guard let partnerDoc = usernameSnapshot.documents.first else {
            throw FirebaseError.invalidInviteCode
        }

        return try await fetchProfile(for: partnerDoc.documentID)
    }
    
    // MARK: - Avatar Upload
    
    public func uploadAvatar(_ image: UIImage) async throws -> String {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { throw FirebaseError.compressionFailed }
        
        let storageRef = Storage.storage().reference().child("avatars/\(uid).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        let urlString = downloadURL.absoluteString
        
        // Update Firestore user document
        try await db.collection("users").document(uid).updateData(["avatarUrl": urlString])
        
        // Update local profile
        if let profile = self.currentUserProfile {
            self.currentUserProfile = UserProfile(
                id: profile.id,
                inviteCode: profile.inviteCode,
                email: profile.email,
                displayName: profile.displayName,
                username: profile.username,
                dateOfBirth: profile.dateOfBirth,
                avatarUrl: urlString,
                bio: profile.bio,
                statusEmoji: profile.statusEmoji
            )
        }
        
        return urlString
    }
    
    // MARK: - Update Profile
    
    /// Updates the user's profile fields in Firestore.
    public func updateProfile(displayName: String, username: String?, bio: String?, dateOfBirth: Date?) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        
        // Word filter check on bio
        if let bio, let bannedWord = await AppGuardService.shared.containsBannedWord(bio) {
            throw AppError.custom(String(localized: "Biyografiniz yasaklı kelime içeriyor: \(bannedWord)"))
        }
        
        var updateData: [String: Any] = [
            "displayName": displayName
        ]
        
        if let username = username {
            updateData["username"] = username
        }
        if let bio = bio, !bio.isEmpty {
            updateData["bio"] = bio
        } else {
            updateData["bio"] = FieldValue.delete()
        }
        if let dob = dateOfBirth {
            updateData["dateOfBirth"] = Timestamp(date: dob)
        }
        
        try await db.collection("users").document(uid).updateData(updateData)
        
        // Update local profile
        if let profile = self.currentUserProfile {
            self.currentUserProfile = UserProfile(
                id: profile.id,
                inviteCode: profile.inviteCode,
                email: profile.email,
                displayName: displayName,
                username: username ?? profile.username,
                dateOfBirth: dateOfBirth ?? profile.dateOfBirth,
                avatarUrl: profile.avatarUrl,
                bio: bio ?? profile.bio,
                statusEmoji: profile.statusEmoji
            )
        }
        
        // Invalidate profile cache
        profileCache.removeValue(forKey: uid)
    }
    
    // MARK: - Password Reset
    
    public func sendPasswordReset(to email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    // MARK: - Profile Completion (Apple Sign-In)
    
    /// Returns true if the current user's profile is missing required fields.
    public var needsProfileCompletion: Bool {
        currentUserProfile?.needsProfileCompletion ?? false
    }
    
    /// Completes a partially-filled profile (e.g. Apple Sign-In user missing username/displayName).
    public func completeProfile(displayName: String, username: String, dateOfBirth: Date) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        
        let updateData: [String: Any] = [
            "displayName": displayName,
            "username": username,
            "dateOfBirth": Timestamp(date: dateOfBirth)
        ]
        
        try await db.collection("users").document(uid).setData(updateData, merge: true)
        
        // Refresh local profile
        if let profile = self.currentUserProfile {
            self.currentUserProfile = UserProfile(
                id: profile.id,
                inviteCode: profile.inviteCode,
                email: profile.email,
                displayName: displayName,
                username: username,
                dateOfBirth: dateOfBirth,
                avatarUrl: profile.avatarUrl,
                bio: profile.bio,
                statusEmoji: profile.statusEmoji
            )
        }
        
        // Invalidate profile cache
        profileCache.removeValue(forKey: uid)
    }
    
    // MARK: - Delete Account
    
    /// Permanently deletes the current user's account and all associated data.
    /// Steps: delete Firestore data → delete Storage files → delete Auth account
    public func deleteAccount() async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        
        // 1. Delete user's friendships (both sides)
        let friendDocs = try await db.collection("users").document(uid).collection("friendships").getDocuments()
        for doc in friendDocs.documents {
            let friendId = doc.documentID
            do {
                try await db.collection("users").document(friendId).collection("friendships").document(uid).delete()
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ deleteAccount — failed to remove reverse friendship \(friendId): \(error.localizedDescription)")
                #endif
            }
            do {
                try await doc.reference.delete()
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ deleteAccount — failed to remove friendship doc: \(error.localizedDescription)")
                #endif
            }
        }

        // 2. Delete private subcollection
        let privateDocs = try await db.collection("users").document(uid).collection("private").getDocuments()
        for doc in privateDocs.documents {
            do {
                try await doc.reference.delete()
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ deleteAccount — failed to delete private doc: \(error.localizedDescription)")
                #endif
            }
        }

        // 3. Delete user's notifications
        let notifSnapshot = try await db.collection("notifications").whereField("userId", isEqualTo: uid).getDocuments()
        for doc in notifSnapshot.documents {
            do {
                try await doc.reference.delete()
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ deleteAccount — failed to delete notification: \(error.localizedDescription)")
                #endif
            }
        }

        // 4. Delete user's sent strips and their Storage files (GDPR/KVKK compliance)
        let stripSnapshot = try await db.collection("strips").whereField("senderId", isEqualTo: uid).getDocuments()
        for doc in stripSnapshot.documents {
            let data = doc.data()
            // Delete strip image from Storage
            if let imageUrl = data["imageUrl"] as? String,
               let fileName = URL(string: imageUrl)?.lastPathComponent {
                let imageRef = Storage.storage().reference().child("strips/\(fileName)")
                do { try await imageRef.delete() } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ deleteAccount — failed to delete strip image: \(error.localizedDescription)")
                    #endif
                }
                // Delete thumbnails
                let baseName = (fileName as NSString).deletingPathExtension
                do { try await Storage.storage().reference().child("strips/thumbs/\(baseName)_800x800.jpg").delete() } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ deleteAccount — failed to delete 800 thumb: \(error.localizedDescription)")
                    #endif
                }
                do { try await Storage.storage().reference().child("strips/thumbs/\(baseName)_200x200.jpg").delete() } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ deleteAccount — failed to delete 200 thumb: \(error.localizedDescription)")
                    #endif
                }
            }
            // Delete comments subcollection
            do {
                let comments = try await doc.reference.collection("comments").getDocuments()
                for commentDoc in comments.documents {
                    do { try await commentDoc.reference.delete() } catch {
                        #if DEBUG
                        print("DEBUG: ⚠️ deleteAccount — failed to delete comment: \(error.localizedDescription)")
                        #endif
                    }
                }
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ deleteAccount — failed to fetch comments: \(error.localizedDescription)")
                #endif
            }
            do {
                try await doc.reference.delete()
            } catch {
                #if DEBUG
                print("DEBUG: ⚠️ deleteAccount — failed to delete strip doc: \(error.localizedDescription)")
                #endif
            }
        }

        // 5. Clean up direct message threads
        do {
            let dmThreads = try await db.collection("direct_messages")
                .whereField("participants", arrayContains: uid)
                .getDocuments()
            for dmDoc in dmThreads.documents {
                do {
                    let messagesSnapshot = try await dmDoc.reference.collection("messages").getDocuments()
                    let batch = db.batch()
                    for msg in messagesSnapshot.documents {
                        batch.deleteDocument(msg.reference)
                    }
                    try await batch.commit()
                } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ deleteAccount — failed to delete DM messages: \(error.localizedDescription)")
                    #endif
                }
                do { try await dmDoc.reference.delete() } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ deleteAccount — failed to delete DM thread: \(error.localizedDescription)")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ deleteAccount — failed to fetch DM threads: \(error.localizedDescription)")
            #endif
        }

        // 6. Delete avatar from Storage
        let avatarRef = Storage.storage().reference().child("avatars/\(uid).jpg")
        do { try await avatarRef.delete() } catch {
            #if DEBUG
            print("DEBUG: ⚠️ deleteAccount — failed to delete avatar: \(error.localizedDescription)")
            #endif
        }

        // 7. Delete user document
        do { try await db.collection("users").document(uid).delete() } catch {
            #if DEBUG
            print("DEBUG: ⚠️ deleteAccount — failed to delete user doc: \(error.localizedDescription)")
            #endif
        }

        // 8. Clear local data
        SwiftDataSyncService.shared.clearAllStrips()

        // 9. Delete Firebase Auth account (must be last)
        try await auth.currentUser?.delete()

        // 10. Clear in-memory session state
        clearSessionState()
        
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
    
    // MARK: - Block & Report
    
    /// Blocks a user — adds to local blocked list in Firestore
    public func blockUser(_ blockedUserId: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        
        // Add to blocked subcollection
        try await db.collection("users").document(uid).collection("blocked").document(blockedUserId).setData([
            "blockedAt": FieldValue.serverTimestamp()
        ])
        
        // Remove friendship if exists (both sides)
        do {
            try await db.collection("users").document(uid).collection("friendships").document(blockedUserId).delete()
            try await db.collection("users").document(blockedUserId).collection("friendships").document(uid).delete()
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ blockUser — failed to remove friendships: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Unblocks a user — removes from blocked subcollection in Firestore
    public func unblockUser(_ blockedUserId: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        try await db.collection("users").document(uid).collection("blocked").document(blockedUserId).delete()
    }
    
    /// Reports a user for inappropriate behavior
    public func reportUser(_ reportedUserId: String, reason: String) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }

        let reportData: [String: Any] = [
            "reporterId": uid,
            "reportedUserId": reportedUserId,
            "reason": reason,
            "timestamp": FieldValue.serverTimestamp()
        ]

        try await db.collection("reports").addDocument(data: reportData)
    }

    /// Reports a specific piece of content (photo or message)
    public func reportContent(
        contentType: String,
        contentId: String,
        contentOwnerId: String,
        reason: String
    ) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }

        let reportData: [String: Any] = [
            "reporterId": uid,
            "reportedUserId": contentOwnerId,
            "contentType": contentType,
            "contentId": contentId,
            "reason": reason,
            "timestamp": FieldValue.serverTimestamp()
        ]

        try await db.collection("reports").addDocument(data: reportData)
    }
    
    /// Returns the list of blocked user IDs (cached for 5 minutes)
    private var cachedBlockedIds: Set<String>?
    private var blockedCacheTime: Date?

    public func fetchBlockedUserIds() async throws -> Set<String> {
        if let cached = cachedBlockedIds,
           let time = blockedCacheTime,
           -time.timeIntervalSinceNow < 300 {
            return cached
        }
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        let docs = try await db.collection("users").document(uid).collection("blocked").getDocuments()
        let ids = Set(docs.documents.map { $0.documentID })
        cachedBlockedIds = ids
        blockedCacheTime = Date()
        return ids
    }

    /// Invalidate blocked users cache (call after block/unblock)
    public func invalidateBlockedCache() {
        cachedBlockedIds = nil
        blockedCacheTime = nil
    }
}
