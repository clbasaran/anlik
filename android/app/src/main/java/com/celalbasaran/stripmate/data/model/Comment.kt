package com.celalbasaran.stripmate.data.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import java.util.Date
import java.util.UUID

data class Comment(
    val id: String = UUID.randomUUID().toString(),
    val photoId: String = "",
    val senderId: String = "",
    val text: String = "",
    val timestamp: Date = Date(),
    val replyToId: String? = null,
    val replyToText: String? = null,
    val replyToSenderId: String? = null,
    val reactions: Map<String, String>? = null, // userId -> emoji
    val voiceUrl: String? = null
) {
    fun toMap(): Map<String, Any?> = buildMap {
        put("id", id)
        put("photoId", photoId)
        put("senderId", senderId)
        put("text", text)
        put("timestamp", Timestamp(timestamp))
        replyToId?.let { put("replyToId", it) }
        replyToText?.let { put("replyToText", it) }
        replyToSenderId?.let { put("replyToSenderId", it) }
        reactions?.let { put("reactions", it) }
        voiceUrl?.let { put("voiceUrl", it) }
    }

    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromDocument(doc: DocumentSnapshot): Comment? {
            if (!doc.exists()) return null
            return Comment(
                id = doc.id,
                photoId = doc.getString("photoId") ?: "",
                senderId = doc.getString("senderId") ?: "",
                text = doc.getString("text") ?: "",
                timestamp = doc.getTimestamp("timestamp")?.toDate() ?: Date(),
                replyToId = doc.getString("replyToId"),
                replyToText = doc.getString("replyToText"),
                replyToSenderId = doc.getString("replyToSenderId"),
                reactions = doc.get("reactions") as? Map<String, String>,
                voiceUrl = doc.getString("voiceUrl")
            )
        }
    }
}
