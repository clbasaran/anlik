package com.celalbasaran.stripmate.ui.screen.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import android.util.Log
import com.celalbasaran.stripmate.data.model.Comment
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.guard.AppGuardRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ChatViewModel @Inject constructor(
    private val photoRepository: PhotoRepository,
    private val authRepository: AuthRepository,
    private val guardRepository: AppGuardRepository
) : ViewModel() {

    private val _messages = MutableStateFlow<List<Comment>>(emptyList())
    val messages: StateFlow<List<Comment>> = _messages.asStateFlow()

    private val _inputText = MutableStateFlow("")
    val inputText: StateFlow<String> = _inputText.asStateFlow()

    private val _replyingTo = MutableStateFlow<Comment?>(null)
    val replyingTo: StateFlow<Comment?> = _replyingTo.asStateFlow()

    private val _wordFilterError = MutableStateFlow<String?>(null)
    val wordFilterError: StateFlow<String?> = _wordFilterError.asStateFlow()

    // Offline queue
    data class PendingMessage(val text: String, val replyToId: String? = null, val replyToText: String? = null, val replyToSenderId: String? = null)
    private val _pendingMessages = MutableStateFlow<List<PendingMessage>>(emptyList())
    val pendingMessages: StateFlow<List<PendingMessage>> = _pendingMessages.asStateFlow()

    private var stripId: String = ""
    private var chatPartnerId: String = ""

    fun initialize(stripId: String, chatPartnerId: String) {
        this.stripId = stripId
        this.chatPartnerId = chatPartnerId

        viewModelScope.launch {
            photoRepository.listenToStripChat(stripId, chatPartnerId).collect { comments ->
                _messages.value = comments.sortedBy { it.timestamp }
            }
        }
    }

    fun updateInput(text: String) {
        _inputText.value = text
    }

    fun sendMessage() {
        val text = _inputText.value.trim()
        if (text.isBlank()) return
        if (text.length > 2000) {
            _wordFilterError.value = "Mesaj 2000 karakterden uzun olamaz."
            return
        }
        val reply = _replyingTo.value

        viewModelScope.launch {
            // Word filter check
            val bannedWord = guardRepository.containsBannedWord(text)
            if (bannedWord != null) {
                _wordFilterError.value = "Mesajınız uygunsuz içerik barındırıyor."
                return@launch
            }

            try {
                photoRepository.sendStripChatMessage(
                    text = text,
                    stripId = stripId,
                    chatPartnerId = chatPartnerId,
                    replyToId = reply?.id,
                    replyToText = reply?.text,
                    replyToSenderId = reply?.senderId
                )
            } catch (e: Exception) {
                Log.e("ChatViewModel", "Failed to send message, queuing for retry", e)
                // Queue for retry when network restores
                _pendingMessages.value = _pendingMessages.value + PendingMessage(
                    text = text,
                    replyToId = reply?.id,
                    replyToText = reply?.text,
                    replyToSenderId = reply?.senderId
                )
            }
            _inputText.value = ""
            _replyingTo.value = null
        }
    }

    fun clearWordFilterError() {
        _wordFilterError.value = null
    }

    fun toggleReaction(messageId: String, emoji: String) {
        viewModelScope.launch {
            photoRepository.toggleChatReaction(stripId, chatPartnerId, messageId, emoji)
        }
    }

    fun sendGiphyMessage(giphyUrl: String) {
        viewModelScope.launch {
            photoRepository.sendStripChatMessage(
                text = giphyUrl,
                stripId = stripId,
                chatPartnerId = chatPartnerId
            )
        }
    }

    fun setReply(comment: Comment) {
        _replyingTo.value = comment
    }

    fun clearReply() {
        _replyingTo.value = null
    }

    fun flushPendingMessages() {
        val queued = _pendingMessages.value.toList()
        if (queued.isEmpty()) return
        _pendingMessages.value = emptyList()
        viewModelScope.launch {
            for (msg in queued) {
                try {
                    photoRepository.sendStripChatMessage(
                        text = msg.text,
                        stripId = stripId,
                        chatPartnerId = chatPartnerId,
                        replyToId = msg.replyToId,
                        replyToText = msg.replyToText,
                        replyToSenderId = msg.replyToSenderId
                    )
                } catch (e: Exception) {
                    Log.e("ChatViewModel", "Failed to flush pending message", e)
                    _pendingMessages.value = _pendingMessages.value + msg
                }
            }
        }
    }

    fun isMyMessage(comment: Comment): Boolean {
        return comment.senderId == authRepository.currentUserId()
    }
}
