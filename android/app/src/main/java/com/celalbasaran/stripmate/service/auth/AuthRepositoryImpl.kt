package com.celalbasaran.stripmate.service.auth

import android.content.Context
import android.net.Uri
import android.util.Log
import com.celalbasaran.stripmate.data.model.UserProfile
import dagger.hilt.android.qualifiers.ApplicationContext
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.storage.FirebaseStorage
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthRepositoryImpl @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val auth: FirebaseAuth,
    private val db: FirebaseFirestore,
    private val storage: FirebaseStorage,
    private val messaging: FirebaseMessaging
) : AuthRepository {

    @Volatile
    private var cachedProfile: UserProfile? = null
    private var profileCacheTime: Long = 0L
    private val profileCacheTTL: Long = 5 * 60 * 1000L // 5 minutes

    @Volatile
    private var cachedBlockedIds: Set<String>? = null
    private var blockedCacheTime: Long = 0L
    private val blockedCacheTTL: Long = 5 * 60 * 1000L // 5 minutes

    override suspend fun login(email: String, password: String): Result<UserProfile> {
        return try {
            val result = auth.signInWithEmail(email, password).await()
            val uid = result.user?.uid ?: return Result.failure(Exception("Login failed: no user"))
            persistFCMTokenInternal(uid)
            val profile = fetchProfile(uid)
                ?: return Result.failure(Exception("Profile not found"))
            cachedProfile = profile
            profileCacheTime = System.currentTimeMillis()
            Result.success(profile)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun signup(
        email: String,
        password: String,
        displayName: String,
        username: String,
        dateOfBirth: Date
    ): Result<UserProfile> {
        return try {
            val result = auth.createUserWithEmail(email, password).await()
            val uid = result.user?.uid
                ?: return Result.failure(Exception("Signup failed: no user"))

            val inviteCode = generateUniqueInviteCode()
            val profile = UserProfile(
                id = uid,
                inviteCode = inviteCode,
                email = email,
                displayName = displayName,
                username = username,
                dateOfBirth = dateOfBirth,
                createdAt = Date()
            )

            val initialData: Map<String, Any> = buildMap {
                put("id", uid)
                put("inviteCode", inviteCode)
                put("email", email)
                put("displayName", displayName)
                put("username", username)
                put("dateOfBirth", Timestamp(dateOfBirth))
                put("createdAt", FieldValue.serverTimestamp())
            }

            db.collection("users").document(uid).set(initialData).await()
            persistFCMTokenInternal(uid)
            cachedProfile = profile
            profileCacheTime = System.currentTimeMillis()
            Result.success(profile)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun signInWithGoogle(idToken: String): Result<UserProfile> {
        return try {
            val credential = GoogleAuthProvider.getCredential(idToken, null)
            val result = auth.signInWithCredential(credential).await()
            val uid = result.user?.uid
                ?: return Result.failure(Exception("Google sign-in failed: no user"))
            val googleEmail = result.user?.email

            val userDoc = db.collection("users").document(uid).get().await()

            if (userDoc.exists()) {
                // Existing user
                val profile = UserProfile.fromDocument(userDoc)
                    ?: return Result.failure(Exception("Failed to parse profile"))

                // Update email if needed
                if (googleEmail != null && googleEmail.isNotEmpty()) {
                    val storedEmail = userDoc.getString("email") ?: ""
                    if (storedEmail.isEmpty()) {
                        try {
                            db.collection("users").document(uid)
                                .set(mapOf("email" to googleEmail), com.google.firebase.firestore.SetOptions.merge())
                                .await()
                        } catch (e: Exception) { Log.e("AuthRepository", "Failed to update Google email", e) }
                    }
                }

                persistFCMTokenInternal(uid)
                cachedProfile = profile
                profileCacheTime = System.currentTimeMillis()
                Result.success(profile)
            } else {
                // New user
                val inviteCode = generateUniqueInviteCode()
                val name = result.user?.displayName ?: "Google User"
                val profile = UserProfile(
                    id = uid,
                    inviteCode = inviteCode,
                    email = googleEmail,
                    displayName = name,
                    createdAt = Date()
                )

                val initialData: Map<String, Any?> = buildMap {
                    put("id", uid)
                    put("inviteCode", inviteCode)
                    put("email", googleEmail)
                    put("displayName", name)
                    put("createdAt", FieldValue.serverTimestamp())
                }

                db.collection("users").document(uid).set(initialData).await()
                persistFCMTokenInternal(uid)
                cachedProfile = profile
                profileCacheTime = System.currentTimeMillis()
                Result.success(profile)
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun fetchProfile(uid: String): UserProfile? {
        // Return cached profile if within TTL (only for non-self profiles)
        val currentUid = auth.currentUser?.uid
        if (uid != currentUid) {
            val now = System.currentTimeMillis()
            val cached = cachedProfile
            if (cached != null && cached.id == uid && (now - profileCacheTime) < profileCacheTTL) {
                return cached
            }
        }

        return try {
            val doc = db.collection("users").document(uid).get().await()
            val profile = UserProfile.fromDocument(doc)

            if (profile != null) {
                if (uid == currentUid) {
                    cachedProfile = profile
                    profileCacheTime = System.currentTimeMillis()
                    syncInviteCodeToWidget(profile)
                }
            }
            profile
        } catch (e: Exception) {
            null
        }
    }

    override suspend fun updateProfile(data: Map<String, Any>) {
        val uid = auth.currentUser?.uid ?: return
        db.collection("users").document(uid).update(data).await()
        // Invalidate profile cache
        cachedProfile = null
        profileCacheTime = 0L
    }

    override suspend fun uploadAvatar(uri: Uri): String {
        val uid = auth.currentUser?.uid ?: throw Exception("Not authenticated")

        // Compress image before upload (like iOS does)
        val compressed = withContext(kotlinx.coroutines.Dispatchers.IO) {
            val inputStream = appContext.contentResolver.openInputStream(uri)
                ?: throw Exception("Cannot open image")
            val bitmap = android.graphics.BitmapFactory.decodeStream(inputStream)
            inputStream.close()

            // Scale down if too large (max 1024px)
            val maxDim = 1024
            val scaled = if (bitmap.width > maxDim || bitmap.height > maxDim) {
                val ratio = minOf(maxDim.toFloat() / bitmap.width, maxDim.toFloat() / bitmap.height)
                android.graphics.Bitmap.createScaledBitmap(
                    bitmap,
                    (bitmap.width * ratio).toInt(),
                    (bitmap.height * ratio).toInt(),
                    true
                )
            } else bitmap

            val baos = java.io.ByteArrayOutputStream()
            scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 80, baos)
            baos.toByteArray()
        }

        val storageRef = storage.reference.child("avatars/$uid.jpg")
        storageRef.putBytes(compressed).await()
        val downloadUrl = storageRef.downloadUrl.await().toString()

        db.collection("users").document(uid)
            .update("avatarUrl", downloadUrl)
            .await()

        // Update cached profile
        cachedProfile = cachedProfile?.copy(avatarUrl = downloadUrl)
        profileCacheTime = System.currentTimeMillis()

        return downloadUrl
    }

    override suspend fun logout() {
        // Clear FCM token from Firestore before signing out
        val uid = auth.currentUser?.uid
        if (uid != null) {
            try {
                db.collection("users").document(uid)
                    .collection("private").document("tokens")
                    .update("fcmToken", FieldValue.delete())
                    .await()
            } catch (e: Exception) {
                Log.e("AuthRepository", "Failed to clear FCM token from private/tokens", e)
            }
            try {
                db.collection("users").document(uid)
                    .update("fcmToken", FieldValue.delete())
                    .await()
            } catch (e: Exception) {
                Log.e("AuthRepository", "Failed to clear FCM token from user doc", e)
            }
        }

        auth.signOut()
        cachedProfile = null
        profileCacheTime = 0L
        cachedBlockedIds = null
        blockedCacheTime = 0L

        // Clear widget data
        try {
            val prefs = appContext.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                remove("user_invite_code")
                remove("user_display_name")
                remove("user_username")
                apply()
            }
        } catch (_: Exception) { }
    }

    override suspend fun deleteAccount() {
        val uid = auth.currentUser?.uid ?: throw Exception("Not authenticated")

        // 1. Delete friendships (both sides)
        try {
            val friendDocs = db.collection("users").document(uid)
                .collection("friendships").get().await()
            for (doc in friendDocs.documents) {
                val friendId = doc.id
                try {
                    db.collection("users").document(friendId)
                        .collection("friendships").document(uid).delete().await()
                } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete reverse friendship for $friendId", e) }
                try {
                    doc.reference.delete().await()
                } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete friendship doc", e) }
            }
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete friendships", e) }

        // 2. Delete private subcollection
        try {
            val privateDocs = db.collection("users").document(uid)
                .collection("private").get().await()
            for (doc in privateDocs.documents) {
                try { doc.reference.delete().await() } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete private doc", e) }
            }
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete private subcollection", e) }

        // 3. Delete notifications
        try {
            val notifSnapshot = db.collection("notifications")
                .whereEqualTo("userId", uid).get().await()
            for (doc in notifSnapshot.documents) {
                try { doc.reference.delete().await() } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete notification", e) }
            }
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete notifications", e) }

        // 4. Delete sent strips and their Storage files
        try {
            val stripSnapshot = db.collection("strips")
                .whereEqualTo("senderId", uid).get().await()
            for (doc in stripSnapshot.documents) {
                val data = doc.data ?: continue
                val imageUrl = data["imageUrl"] as? String
                if (imageUrl != null) {
                    val fileName = Uri.parse(imageUrl).lastPathSegment ?: "${doc.id}.jpg"
                    try { storage.reference.child("strips/$fileName").delete().await() } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete strip image", e) }
                    val baseName = fileName.substringBeforeLast(".")
                    try { storage.reference.child("strips/thumbs/${baseName}_800x800.jpg").delete().await() } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete strip thumb 800", e) }
                    try { storage.reference.child("strips/thumbs/${baseName}_200x200.jpg").delete().await() } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete strip thumb 200", e) }
                }
                // Delete chat subcollections
                try {
                    val chatsSnapshot = doc.reference.collection("chats").get().await()
                    for (chatDoc in chatsSnapshot.documents) {
                        try {
                            val messagesSnapshot = chatDoc.reference.collection("messages").get().await()
                            val batch = db.batch()
                            for (msgDoc in messagesSnapshot.documents) {
                                batch.delete(msgDoc.reference)
                            }
                            batch.commit().await()
                        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete chat messages", e) }
                        try { chatDoc.reference.delete().await() } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete chat doc", e) }
                    }
                } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete strip chats", e) }
                try { doc.reference.delete().await() } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete strip doc", e) }
            }
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete strips", e) }

        // 5. Delete DM threads
        try {
            val dmThreads = db.collection("direct_messages")
                .whereArrayContains("participants", uid).get().await()
            for (dmDoc in dmThreads.documents) {
                try {
                    val messagesSnapshot = dmDoc.reference.collection("messages").get().await()
                    val batch = db.batch()
                    for (msg in messagesSnapshot.documents) {
                        batch.delete(msg.reference)
                    }
                    batch.commit().await()
                } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete DM messages", e) }
                try { dmDoc.reference.delete().await() } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete DM thread", e) }
            }
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete DM threads", e) }

        // 6. Delete achievements subcollection
        try {
            val achievementsDocs = db.collection("users").document(uid)
                .collection("achievements").get().await()
            if (achievementsDocs.documents.isNotEmpty()) {
                val batch = db.batch()
                for (doc in achievementsDocs.documents) { batch.delete(doc.reference) }
                batch.commit().await()
            }
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete achievements", e) }

        // 7. Delete streaks the user is part of
        try {
            val streaksDocs = db.collection("streaks")
                .whereArrayContains("userIds", uid).get().await()
            if (streaksDocs.documents.isNotEmpty()) {
                val batch = db.batch()
                for (doc in streaksDocs.documents) { batch.delete(doc.reference) }
                batch.commit().await()
            }
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete streaks", e) }

        // 8. Delete support chat
        try {
            val supportMsgs = db.collection("support_chats").document(uid)
                .collection("messages").get().await()
            if (supportMsgs.documents.isNotEmpty()) {
                val batch = db.batch()
                for (doc in supportMsgs.documents) { batch.delete(doc.reference) }
                batch.commit().await()
            }
            db.collection("support_chats").document(uid).delete().await()
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete support chat", e) }

        // 9. Delete avatar from Storage
        try {
            storage.reference.child("avatars/$uid.jpg").delete().await()
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete avatar", e) }

        // 10. Delete username reservation
        try {
            val userData = db.collection("users").document(uid).get().await()
            val username = userData.getString("username")
            if (!username.isNullOrBlank()) {
                db.collection("usernames").document(username.lowercase()).delete().await()
            }
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete username reservation", e) }

        // 11. Delete user document
        try {
            db.collection("users").document(uid).delete().await()
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to delete user document", e) }

        // 12. Delete Firebase Auth account
        auth.currentUser?.delete()?.await()

        // 13. Clear cached state
        cachedProfile = null
        profileCacheTime = 0L
        cachedBlockedIds = null
        blockedCacheTime = 0L
    }

    override suspend fun generateInviteCode(): String {
        return generateUniqueInviteCode()
    }

    override suspend fun searchUserByCode(code: String): UserProfile? {
        return try {
            val uppercaseCode = code.uppercase()
            val snapshot = db.collection("users")
                .whereEqualTo("inviteCode", uppercaseCode)
                .limit(1)
                .get()
                .await()

            val doc = snapshot.documents.firstOrNull() ?: return null
            UserProfile.fromDocument(doc)
        } catch (e: Exception) {
            null
        }
    }

    override suspend fun searchUserByUsername(username: String): UserProfile? {
        return try {
            val lowercaseUsername = username.lowercase()
            val snapshot = db.collection("users")
                .whereEqualTo("username", lowercaseUsername)
                .limit(1)
                .get()
                .await()

            val doc = snapshot.documents.firstOrNull() ?: return null
            UserProfile.fromDocument(doc)
        } catch (e: Exception) {
            null
        }
    }

    override fun isLoggedIn(): Boolean {
        return auth.currentUser != null
    }

    override fun currentUserId(): String? {
        return auth.currentUser?.uid
    }

    override suspend fun persistFCMToken() {
        val uid = auth.currentUser?.uid ?: return
        persistFCMTokenInternal(uid)
    }

    override suspend fun fetchBlockedUserIds(): Set<String> {
        val now = System.currentTimeMillis()
        val cached = cachedBlockedIds
        if (cached != null && (now - blockedCacheTime) < blockedCacheTTL) {
            return cached
        }

        val uid = auth.currentUser?.uid ?: return emptySet()
        return try {
            val docs = db.collection("users").document(uid)
                .collection("blocked").get().await()
            val ids = docs.documents.map { it.id }.toSet()
            cachedBlockedIds = ids
            blockedCacheTime = System.currentTimeMillis()
            ids
        } catch (e: Exception) {
            emptySet()
        }
    }

    override suspend fun blockUser(userId: String) {
        val uid = auth.currentUser?.uid ?: throw Exception("Not authenticated")

        // Add to blocked subcollection
        db.collection("users").document(uid)
            .collection("blocked").document(userId)
            .set(mapOf("blockedAt" to FieldValue.serverTimestamp()))
            .await()

        // Remove friendship if exists (both sides)
        try {
            db.collection("users").document(uid)
                .collection("friendships").document(userId).delete().await()
            db.collection("users").document(userId)
                .collection("friendships").document(uid).delete().await()
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to remove friendship on block", e) }

        // Invalidate blocked cache
        cachedBlockedIds = null
        blockedCacheTime = 0L
    }

    override suspend fun unblockUser(userId: String) {
        val uid = auth.currentUser?.uid ?: throw Exception("Not authenticated")
        db.collection("users").document(uid)
            .collection("blocked").document(userId).delete().await()

        // Invalidate blocked cache
        cachedBlockedIds = null
        blockedCacheTime = 0L
    }

    override suspend fun reportUser(userId: String, reason: String) {
        val uid = auth.currentUser?.uid ?: throw Exception("Not authenticated")

        val reportData: Map<String, Any> = mapOf(
            "reporterId" to uid,
            "reportedUserId" to userId,
            "reason" to reason,
            "timestamp" to FieldValue.serverTimestamp()
        )

        db.collection("reports").add(reportData).await()
    }

    override suspend fun reportContent(contentType: String, contentId: String, contentOwnerId: String, reason: String) {
        val uid = auth.currentUser?.uid ?: throw Exception("Not authenticated")

        val reportData: Map<String, Any> = mapOf(
            "reporterId" to uid,
            "reportedUserId" to contentOwnerId,
            "contentType" to contentType,
            "contentId" to contentId,
            "reason" to reason,
            "timestamp" to FieldValue.serverTimestamp()
        )

        db.collection("reports").add(reportData).await()
    }

    override fun needsProfileCompletion(): Boolean {
        return cachedProfile?.needsProfileCompletion ?: false
    }

    override suspend fun resetPassword(email: String) {
        auth.sendPasswordResetEmail(email).await()
    }

    // MARK: - Private Helpers

    private suspend fun persistFCMTokenInternal(uid: String) {
        try {
            val token = messaging.token.await()
            db.collection("users").document(uid)
                .collection("private").document("tokens")
                .set(mapOf("fcmToken" to token), com.google.firebase.firestore.SetOptions.merge())
                .await()
        } catch (e: Exception) { Log.e("AuthRepository", "Failed to persist FCM token", e) }
    }

    private suspend fun generateUniqueInviteCode(maxAttempts: Int = 5): String {
        for (i in 0 until maxAttempts) {
            val candidate = UUID.randomUUID().toString()
                .replace("-", "")
                .take(8)
                .uppercase()

            val snapshot = db.collection("users")
                .whereEqualTo("inviteCode", candidate)
                .limit(1)
                .get()
                .await()

            if (snapshot.documents.isEmpty()) {
                return candidate
            }
        }
        // Extremely unlikely fallback
        return UUID.randomUUID().toString()
            .replace("-", "")
            .take(10)
            .uppercase()
    }

    private fun syncInviteCodeToWidget(profile: UserProfile) {
        try {
            val prefs = appContext.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                val code = profile.inviteCode
                if (code.isNotBlank()) {
                    putString("user_invite_code", code)
                    putString("user_display_name", profile.displayName)
                    putString("user_username", profile.username)
                } else {
                    remove("user_invite_code")
                    remove("user_display_name")
                    remove("user_username")
                }
                apply()
            }
        } catch (e: Exception) {
            Log.e("AuthRepository", "Failed to sync invite code to widget", e)
        }
    }

    private suspend fun FirebaseAuth.signInWithEmail(email: String, password: String) =
        this.signInWithEmailAndPassword(email, password)

    private suspend fun FirebaseAuth.createUserWithEmail(email: String, password: String) =
        this.createUserWithEmailAndPassword(email, password)
}
