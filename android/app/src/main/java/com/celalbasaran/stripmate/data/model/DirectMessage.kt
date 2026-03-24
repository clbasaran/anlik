package com.celalbasaran.stripmate.data.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import java.util.Date
import java.util.UUID

data class DirectMessage(
    val id: String = UUID.randomUUID().toString(),
    val senderId: String = "",
    val receiverId: String = "",
    val text: String = "",
    val timestamp: Date = Date(),
    val readAt: Date? = null,
    val replyToId: String? = null,
    val replyToText: String? = null,
    val replyToSenderId: String? = null,
    val reactions: Map<String, String>? = null, // userId -> emoji
    val isDeleted: Boolean? = null
) {
    fun toMap(): Map<String, Any?> = buildMap {
        put("id", id)
        put("senderId", senderId)
        put("receiverId", receiverId)
        put("text", text)
        put("timestamp", Timestamp(timestamp))
        readAt?.let { put("readAt", Timestamp(it)) }
        replyToId?.let { put("replyToId", it) }
        replyToText?.let { put("replyToText", it) }
        replyToSenderId?.let { put("replyToSenderId", it) }
        reactions?.let { put("reactions", it) }
        isDeleted?.let { put("isDeleted", it) }
    }

    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromDocument(doc: DocumentSnapshot): DirectMessage? {
            if (!doc.exists()) return null
            return DirectMessage(
                id = doc.id,
                senderId = doc.getString("senderId") ?: "",
                receiverId = doc.getString("receiverId") ?: "",
                text = doc.getString("text") ?: "",
                timestamp = doc.getTimestamp("timestamp")?.toDate() ?: Date(),
                readAt = doc.getTimestamp("readAt")?.toDate(),
                replyToId = doc.getString("replyToId"),
                replyToText = doc.getString("replyToText"),
                replyToSenderId = doc.getString("replyToSenderId"),
                reactions = doc.get("reactions") as? Map<String, String>,
                isDeleted = doc.getBoolean("isDeleted")
            )
        }
    }
}
