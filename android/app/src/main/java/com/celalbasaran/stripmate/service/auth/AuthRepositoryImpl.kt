package com.celalbasaran.stripmate.service.auth

import android.content.Context
import android.net.Uri
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
                        } catch (_: Exception) { }
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
        auth.signOut()
        cachedProfile = null
        profileCacheTime = 0L
        cachedBlockedIds = null
        blockedCacheTime = 0L
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
                } catch (_: Exception) { }
                try {
                    doc.reference.delete().await()
                } catch (_: Exception) { }
            }
        } catch (_: Exception) { }

        // 2. Delete private subcollection
        try {
            val privateDocs = db.collection("users").document(uid)
                .collection("private").get().await()
            for (doc in privateDocs.documents) {
                try { doc.reference.delete().await() } catch (_: Exception) { }
            }
        } catch (_: Exception) { }

        // 3. Delete notifications
        try {
            val notifSnapshot = db.collection("notifications")
                .whereEqualTo("userId", uid).get().await()
            for (doc in notifSnapshot.documents) {
                try { doc.reference.delete().await() } catch (_: Exception) { }
            }
        } catch (_: Exception) { }

        // 4. Delete sent strips and their Storage files
        try {
            val stripSnapshot = db.collection("strips")
                .whereEqualTo("senderId", uid).get().await()
            for (doc in stripSnapshot.documents) {
                val data = doc.data ?: continue
                val imageUrl = data["imageUrl"] as? String
                if (imageUrl != null) {
                    val fileName = Uri.parse(imageUrl).lastPathSegment ?: "${doc.id}.jpg"
                    try { storage.reference.child("strips/$fileName").delete().await() } catch (_: Exception) { }
                    val baseName = fileName.substringBeforeLast(".")
                    try { storage.reference.child("strips/thumbs/${baseName}_800x800.jpg").delete().await() } catch (_: Exception) { }
                    try { storage.reference.child("strips/thumbs/${baseName}_200x200.jpg").delete().await() } catch (_: Exception) { }
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
                        } catch (_: Exception) { }
                        try { chatDoc.reference.delete().await() } catch (_: Exception) { }
                    }
                } catch (_: Exception) { }
                try { doc.reference.delete().await() } catch (_: Exception) { }
            }
        } catch (_: Exception) { }

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
                } catch (_: Exception) { }
                try { dmDoc.reference.delete().await() } catch (_: Exception) { }
            }
        } catch (_: Exception) { }

        // 6. Delete avatar from Storage
        try {
            storage.reference.child("avatars/$uid.jpg").delete().await()
        } catch (_: Exception) { }

        // 7. Delete user document
        try {
            db.collection("users").document(uid).delete().await()
        } catch (_: Exception) { }

        // 8. Delete Firebase Auth account
        auth.currentUser?.delete()?.await()

        // 9. Clear cached state
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
        } catch (_: Exception) { }

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
        } catch (_: Exception) { }
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

    private suspend fun FirebaseAuth.signInWithEmail(email: String, password: String) =
        this.signInWithEmailAndPassword(email, password)

    private suspend fun FirebaseAuth.createUserWithEmail(email: String, password: String) =
        this.createUserWithEmailAndPassword(email, password)
}
