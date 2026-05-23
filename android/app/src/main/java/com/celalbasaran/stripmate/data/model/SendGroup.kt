package com.celalbasaran.stripmate.data.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import java.util.Date
import java.util.UUID

/**
 * User-defined recipient group for the send sheet. Stored at
 * users/{uid}/send_groups/{groupId}. Tap a group → all its members get
 * selected at once.
 */
data class SendGroup(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val memberIds: List<String> = emptyList(),
    val createdAt: Date = Date()
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "name" to name,
        "memberIds" to memberIds,
        "createdAt" to Timestamp(createdAt)
    )

    companion object {
        fun fromDocument(doc: DocumentSnapshot): SendGroup? {
            if (!doc.exists()) return null
            @Suppress("UNCHECKED_CAST")
            val members = doc.get("memberIds") as? List<String> ?: return null
            val name = doc.getString("name") ?: return null
            val createdAt = doc.getTimestamp("createdAt")?.toDate() ?: Date()
            return SendGroup(
                id = doc.id,
                name = name,
                memberIds = members,
                createdAt = createdAt
            )
        }
    }
}
