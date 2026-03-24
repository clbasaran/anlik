package com.celalbasaran.stripmate.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.celalbasaran.stripmate.data.model.Strip
import java.util.Date

@Entity(tableName = "strips")
data class StripEntity(
    @PrimaryKey
    val id: String,
    val senderId: String = "",
    val receiverIds: String = "", // comma-separated list
    val imageUrl: String = "",
    val timestamp: Long = System.currentTimeMillis(),
    val latitude: Double? = null,
    val longitude: Double? = null,
    val cityName: String? = null,
    val thumbnailUrl: String? = null,
    val smallThumbnailUrl: String? = null,
    val flagged: Boolean = false,
    val flagReason: String? = null,
    val voiceUrl: String? = null
) {
    fun toStrip(): Strip = Strip(
        id = id,
        senderId = senderId,
        receiverIds = if (receiverIds.isBlank()) emptyList() else receiverIds.split(","),
        imageUrl = imageUrl,
        timestamp = Date(timestamp),
        latitude = latitude,
        longitude = longitude,
        cityName = cityName,
        thumbnailUrl = thumbnailUrl,
        smallThumbnailUrl = smallThumbnailUrl,
        flagged = flagged,
        flagReason = flagReason,
        voiceUrl = voiceUrl
    )

    companion object {
        fun fromStrip(strip: Strip): StripEntity = StripEntity(
            id = strip.id,
            senderId = strip.senderId,
            receiverIds = strip.receiverIds.joinToString(","),
            imageUrl = strip.imageUrl,
            timestamp = strip.timestamp.time,
            latitude = strip.latitude,
            longitude = strip.longitude,
            cityName = strip.cityName,
            thumbnailUrl = strip.thumbnailUrl,
            smallThumbnailUrl = strip.smallThumbnailUrl,
            flagged = strip.flagged,
            flagReason = strip.flagReason,
            voiceUrl = strip.voiceUrl
        )
    }
}
