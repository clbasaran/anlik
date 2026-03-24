package com.celalbasaran.stripmate.data.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import java.util.Date

enum class NotificationType(val value: String) {
    PHOTO_RECEIVED("photo_received"),
    COMMENT_RECEIVED("comment_received"),
    FRIEND_ADDED("friend_added");

    companion object {
        fun fromString(value: String): NotificationType? =
            entries.firstOrNull { it.value == value }
    }
}

data class AppNotification(
    val id: String = "",
    val userId: String = "",
    val senderId: String = "",
    val senderName: String = "",
    val type: NotificationType = NotificationType.PHOTO_RECEIVED,
    val relatedId: String? = null,
    val thumbnailUrl: String? = null,
    val timestamp: Date = Date(),
    val isRead: Boolean = false
) {
    fun toMap(): Map<String, Any?> = buildMap {
        put("id", id)
        put("userId", userId)
        put("senderId", senderId)
        put("senderName", senderName)
        put("type", type.value)
        relatedId?.let { put("relatedId", it) }
        thumbnailUrl?.let { put("thumbnailUrl", it) }
        put("timestamp", Timestamp(timestamp))
        put("isRead", isRead)
    }

    companion object {
        fun fromDocument(doc: DocumentSnapshot): AppNotification? {
            if (!doc.exists()) return null
            val typeStr = doc.getString("type") ?: return null
            val notificationType = NotificationType.fromString(typeStr) ?: return null
            return AppNotification(
                id = doc.id,
                userId = doc.getString("userId") ?: "",
                senderId = doc.getString("senderId") ?: "",
                senderName = doc.getString("senderName") ?: "",
                type = notificationType,
                relatedId = doc.getString("relatedId"),
                thumbnailUrl = doc.getString("thumbnailUrl"),
                timestamp = doc.getTimestamp("timestamp")?.toDate() ?: Date(),
                isRead = doc.getBoolean("isRead") ?: false
            )
        }
    }
}
