package com.celalbasaran.stripmate.service.chat

import com.celalbasaran.stripmate.data.model.DirectMessage
import com.celalbasaran.stripmate.data.model.ThreadSummary
import kotlinx.coroutines.flow.Flow
import java.util.Date

interface ChatRepository {

    fun listenToMessages(partnerId: String): Flow<List<DirectMessage>>

    suspend fun loadMoreMessages(partnerId: String, beforeTimestamp: Date): List<DirectMessage>

    suspend fun sendMessage(
        partnerId: String,
        text: String,
        replyToId: String? = null,
        replyToText: String? = null,
        replyToSenderId: String? = null
    )

    suspend fun markAsRead(partnerId: String)

    suspend fun deleteMessage(partnerId: String, messageId: String)

    suspend fun toggleReaction(partnerId: String, messageId: String, emoji: String)

    suspend fun fetchThreadSummary(partnerId: String): ThreadSummary?

    suspend fun setTypingIndicator(partnerId: String, isTyping: Boolean)

    fun listenToTypingIndicator(partnerId: String): Flow<Boolean>
}
