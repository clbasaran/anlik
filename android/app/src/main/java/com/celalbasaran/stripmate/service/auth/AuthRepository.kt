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

    suspend fun signInWithGoogle(idToken: String): Result<UserProfile>

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
