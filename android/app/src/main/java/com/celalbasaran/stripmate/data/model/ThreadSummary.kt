package com.celalbasaran.stripmate.data.model

import com.google.firebase.firestore.DocumentSnapshot
import java.util.Date

data class ThreadSummary(
    val partnerId: String = "",
    val lastMessage: String = "",
    val lastMessageSenderId: String = "",
    val lastMessageTimestamp: Date = Date(),
    val unreadCount: Int = 0
) {
    fun toMap(): Map<String, Any?> = buildMap {
        put("partnerId", partnerId)
        put("lastMessage", lastMessage)
        put("lastMessageSenderId", lastMessageSenderId)
        put("lastMessageTimestamp", com.google.firebase.Timestamp(lastMessageTimestamp))
        put("unreadCount", unreadCount)
    }

    companion object {
        fun fromDocument(doc: DocumentSnapshot): ThreadSummary? {
            if (!doc.exists()) return null
            return ThreadSummary(
                partnerId = doc.id,
                lastMessage = doc.getString("lastMessage") ?: "",
                lastMessageSenderId = doc.getString("lastMessageSenderId") ?: "",
                lastMessageTimestamp = doc.getTimestamp("lastMessageTimestamp")?.toDate() ?: Date(),
                unreadCount = doc.getLong("unreadCount")?.toInt() ?: 0
            )
        }
    }
}
