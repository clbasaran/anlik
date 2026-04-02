package com.celalbasaran.stripmate.data.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import java.util.Date
import java.util.UUID

data class Strip(
    val id: String = UUID.randomUUID().toString(),
    val senderId: String = "",
    val receiverIds: List<String> = emptyList(),
    val imageUrl: String = "",
    val timestamp: Date = Date(),
    val latitude: Double? = null,
    val longitude: Double? = null,
    val cityName: String? = null,
    val thumbnailUrl: String? = null,
    val smallThumbnailUrl: String? = null,
    val flagged: Boolean = false,
    val flagReason: String? = null,
    val voiceUrl: String? = null,
    val reactions: Map<String, List<String>>? = null, // emoji -> list of userIds
    val isSecret: Boolean = false,
    val unlockedBy: List<String> = emptyList(),
    val videoUrl: String? = null,
    val videoDuration: Double? = null
) {
    val isVideo: Boolean get() = videoUrl != null

    /** Bu strip gizli mi ve henüz userId tarafından açılmamış mı? */
    fun isLockedFor(userId: String): Boolean {
        if (!isSecret || senderId == userId) return false
        return !unlockedBy.contains(userId)
    }

    fun toMap(): Map<String, Any?> = buildMap {
        put("id", id)
        put("senderId", senderId)
        put("receiverIds", receiverIds)
        put("imageUrl", imageUrl)
        put("timestamp", Timestamp(timestamp))
        latitude?.let { put("latitude", it) }
        longitude?.let { put("longitude", it) }
        cityName?.let { put("cityName", it) }
        thumbnailUrl?.let { put("thumbnailUrl", it) }
        smallThumbnailUrl?.let { put("smallThumbnailUrl", it) }
        put("flagged", flagged)
        flagReason?.let { put("flagReason", it) }
        voiceUrl?.let { put("voiceUrl", it) }
        reactions?.let { put("reactions", it) }
        put("isSecret", isSecret)
        if (unlockedBy.isNotEmpty()) put("unlockedBy", unlockedBy)
        videoUrl?.let { put("videoUrl", it) }
        videoDuration?.let { put("videoDuration", it) }
    }

    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromDocument(doc: DocumentSnapshot): Strip? {
            if (!doc.exists()) return null
            return Strip(
                id = doc.id,
                senderId = doc.getString("senderId") ?: "",
                receiverIds = doc.get("receiverIds") as? List<String> ?: emptyList(),
                imageUrl = doc.getString("imageUrl") ?: "",
                timestamp = doc.getTimestamp("timestamp")?.toDate() ?: Date(),
                latitude = doc.getDouble("latitude"),
                longitude = doc.getDouble("longitude"),
                cityName = doc.getString("cityName"),
                thumbnailUrl = doc.getString("thumbnailUrl"),
                smallThumbnailUrl = doc.getString("smallThumbnailUrl"),
                flagged = doc.getBoolean("flagged") ?: false,
                flagReason = doc.getString("flagReason"),
                voiceUrl = doc.getString("voiceUrl"),
                reactions = doc.get("reactions") as? Map<String, List<String>>,
                isSecret = doc.getBoolean("isSecret") ?: false,
                unlockedBy = doc.get("unlockedBy") as? List<String> ?: emptyList(),
                videoUrl = doc.getString("videoUrl"),
                videoDuration = (doc.get("videoDuration") as? Number)?.toDouble()
            )
        }
    }
}
