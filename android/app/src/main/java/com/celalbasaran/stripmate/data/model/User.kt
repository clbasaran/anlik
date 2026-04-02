package com.celalbasaran.stripmate.data.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import java.util.Date

data class UserProfile(
    val id: String = "",
    val inviteCode: String = "",
    val email: String? = null,
    val displayName: String? = null,
    val username: String? = null,
    val dateOfBirth: Date? = null,
    val avatarUrl: String? = null,
    val bio: String? = null,
    val statusEmoji: String? = null,
    val favoriteSong: String? = null,
    val zodiacSign: String? = null,
    val personalityEmojis: List<String>? = null,
    val createdAt: Date? = null,
    val disabled: Boolean? = null,
    val lastActive: Date? = null,
    val notificationPreferences: Map<String, Boolean>? = null
) {
    val needsProfileCompletion: Boolean
        get() {
            val name = displayName?.trim().orEmpty()
            val user = username?.trim().orEmpty()
            return name.isEmpty() || user.isEmpty() || name == "Apple User"
        }

    fun toMap(): Map<String, Any?> = buildMap {
        put("id", id)
        put("inviteCode", inviteCode)
        email?.let { put("email", it) }
        displayName?.let { put("displayName", it) }
        username?.let { put("username", it) }
        dateOfBirth?.let { put("dateOfBirth", Timestamp(it)) }
        avatarUrl?.let { put("avatarUrl", it) }
        bio?.let { put("bio", it) }
        statusEmoji?.let { put("statusEmoji", it) }
        favoriteSong?.let { put("favoriteSong", it) }
        zodiacSign?.let { put("zodiacSign", it) }
        personalityEmojis?.let { put("personalityEmojis", it) }
        createdAt?.let { put("createdAt", Timestamp(it)) }
        disabled?.let { put("disabled", it) }
        lastActive?.let { put("lastActive", Timestamp(it)) }
        notificationPreferences?.let { put("notificationPreferences", it) }
    }

    companion object {
        fun fromDocument(doc: DocumentSnapshot): UserProfile? {
            if (!doc.exists()) return null
            return UserProfile(
                id = doc.id,
                inviteCode = doc.getString("inviteCode") ?: "",
                email = doc.getString("email"),
                displayName = doc.getString("displayName"),
                username = doc.getString("username"),
                dateOfBirth = doc.getTimestamp("dateOfBirth")?.toDate(),
                avatarUrl = doc.getString("avatarUrl"),
                bio = doc.getString("bio"),
                statusEmoji = doc.getString("statusEmoji"),
                favoriteSong = doc.getString("favoriteSong"),
                zodiacSign = doc.getString("zodiacSign"),
                personalityEmojis = (doc.get("personalityEmojis") as? List<*>)?.filterIsInstance<String>(),
                createdAt = doc.getTimestamp("createdAt")?.toDate(),
                disabled = doc.getBoolean("disabled"),
                lastActive = doc.getTimestamp("lastActive")?.toDate(),
                notificationPreferences = doc.get("notificationPreferences") as? Map<String, Boolean>
            )
        }
    }
}
