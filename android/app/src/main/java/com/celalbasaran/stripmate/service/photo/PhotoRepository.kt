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
        voiceData: ByteArray? = null,
        isSecret: Boolean = false,
        videoFile: java.io.File? = null,
        videoDuration: Double? = null
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

    /**
     * One-shot fetch of the latest message metadata for each chat partner under a strip.
     * Used to sort the receiver bar by activity and badge unread chats.
     * Returns timestamp (epoch millis) + senderId for whichever chats have any messages;
     * receivers with no messages are absent from the map.
     */
    suspend fun fetchLatestStripChatMeta(
        stripId: String,
        chatPartnerIds: List<String>
    ): Map<String, ChatMeta>

    data class ChatMeta(val timestampMillis: Long, val senderId: String)

    suspend fun toggleChatReaction(
        stripId: String,
        chatPartnerId: String,
        messageId: String,
        emoji: String
    )

    suspend fun unlockSecret(stripId: String)

    /** Upload a chat photo (e.g. photo reply selfie) and return its download URL. */
    suspend fun uploadChatPhoto(bitmap: Bitmap, stripId: String): String?
}
