package com.celalbasaran.stripmate.data.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import java.util.Date

data class Friend(
    val userId: String = "",
    val isPending: Boolean = false,
    val requesterId: String? = null,
    val timestamp: Date = Date(),
    val profile: UserProfile? = null,
    /** Sender-side flag — surfaced at the top of recipient pickers and friends list. */
    val isFavorite: Boolean = false
) {
    fun toMap(): Map<String, Any?> = buildMap {
        put("userId", userId)
        put("isPending", isPending)
        requesterId?.let { put("requesterId", it) }
        put("timestamp", Timestamp(timestamp))
        put("isFavorite", isFavorite)
    }

    companion object {
        fun fromDocument(doc: DocumentSnapshot): Friend? {
            if (!doc.exists()) return null
            return Friend(
                userId = doc.id,
                isPending = doc.getBoolean("isPending") ?: false,
                requesterId = doc.getString("requesterId"),
                timestamp = doc.getTimestamp("timestamp")?.toDate() ?: Date(),
                isFavorite = doc.getBoolean("isFavorite") ?: false
            )
        }
    }
}
