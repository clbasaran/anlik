package com.celalbasaran.stripmate.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.celalbasaran.stripmate.data.model.UserProfile
import java.util.Date

@Entity(tableName = "users")
data class UserEntity(
    @PrimaryKey
    val id: String,
    val inviteCode: String = "",
    val email: String? = null,
    val displayName: String? = null,
    val username: String? = null,
    val dateOfBirth: Long? = null,
    val avatarUrl: String? = null,
    val bio: String? = null,
    val statusEmoji: String? = null,
    val createdAt: Long? = null,
    val disabled: Boolean? = null,
    val lastActive: Long? = null
) {
    fun toUserProfile(): UserProfile = UserProfile(
        id = id,
        inviteCode = inviteCode,
        email = email,
        displayName = displayName,
        username = username,
        dateOfBirth = dateOfBirth?.let { Date(it) },
        avatarUrl = avatarUrl,
        bio = bio,
        statusEmoji = statusEmoji,
        createdAt = createdAt?.let { Date(it) },
        disabled = disabled,
        lastActive = lastActive?.let { Date(it) }
    )

    companion object {
        fun fromUserProfile(profile: UserProfile): UserEntity = UserEntity(
            id = profile.id,
            inviteCode = profile.inviteCode,
            email = profile.email,
            displayName = profile.displayName,
            username = profile.username,
            dateOfBirth = profile.dateOfBirth?.time,
            avatarUrl = profile.avatarUrl,
            bio = profile.bio,
            statusEmoji = profile.statusEmoji,
            createdAt = profile.createdAt?.time,
            disabled = profile.disabled,
            lastActive = profile.lastActive?.time
        )
    }
}
