package com.celalbasaran.stripmate.service.photo

import android.graphics.Bitmap
import com.celalbasaran.stripmate.data.model.Comment
import com.celalbasaran.stripmate.data.model.Strip
import kotlinx.coroutines.flow.Flow

interface PhotoRepository {

    suspend fun sendPhoto(
        bitmap: Bitmap,
        receiverIds: List<String>,
        latitude: Double?,
        longitude: Double?,
        cityName: String?,
        voiceData: ByteArray? = null
    ): String

    fun listenToHistory(userId: String): Flow<List<Strip>>

    suspend fun loadMoreHistory(userId: String, beforeTimestamp: java.util.Date): List<Strip>

    suspend fun fetchStrip(stripId: String): Strip?

    suspend fun deleteStrip(strip: Strip)

    suspend fun clearHistory()

    suspend fun toggleReaction(photoId: String, emoji: String)

    suspend fun sendStripChatMessage(
        text: String,
        stripId: String,
        chatPartnerId: String,
        replyToId: String? = null,
        replyToText: String? = null,
        replyToSenderId: String? = null,
        voiceUrl: String? = null
    )

    fun listenToStripChat(stripId: String, chatPartnerId: String): Flow<List<Comment>>

    suspend fun toggleChatReaction(
        stripId: String,
        chatPartnerId: String,
        messageId: String,
        emoji: String
    )
}
