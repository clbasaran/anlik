package com.celalbasaran.stripmate.service.auth

import android.net.Uri
import com.celalbasaran.stripmate.data.model.UserProfile

interface AuthRepository {

    suspend fun login(email: String, password: String): Result<UserProfile>

    suspend fun signup(
        email: String,
        password: String,
        displayName: String,
        username: String,
        dateOfBirth: java.util.Date
    ): Result<UserProfile>

    /// `rawNonce` MUST match the SHA-256-hashed nonce that was originally
    /// sent to Google as part of the GetGoogleIdOption request. Firebase
    /// re-hashes this and compares against the nonce embedded in the idToken
    /// to defeat replay attacks. Pass `null` only if the credential was
    /// requested without a nonce — discouraged.
    suspend fun signInWithGoogle(idToken: String, rawNonce: String?): Result<UserProfile>

    suspend fun fetchProfile(uid: String): UserProfile?

    suspend fun updateProfile(data: Map<String, Any>)

    suspend fun uploadAvatar(uri: Uri): String

    suspend fun logout()

    suspend fun deleteAccount()

    suspend fun generateInviteCode(): String

    suspend fun searchUserByCode(code: String): UserProfile?

    suspend fun searchUserByUsername(username: String): UserProfile?

    fun isLoggedIn(): Boolean

    fun currentUserId(): String?

    suspend fun persistFCMToken()

    suspend fun fetchBlockedUserIds(): Set<String>

    suspend fun blockUser(userId: String)

    suspend fun unblockUser(userId: String)

    suspend fun reportUser(userId: String, reason: String)

    suspend fun reportContent(contentType: String, contentId: String, contentOwnerId: String, reason: String)

    fun needsProfileCompletion(): Boolean

    suspend fun resetPassword(email: String)
}
