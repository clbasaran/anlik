package com.celalbasaran.stripmate.ui.screen.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Comment
import com.celalbasaran.stripmate.service.auth.AuthRepository
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
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _messages = MutableStateFlow<List<Comment>>(emptyList())
    val messages: StateFlow<List<Comment>> = _messages.asStateFlow()

    private val _inputText = MutableStateFlow("")
    val inputText: StateFlow<String> = _inputText.asStateFlow()

    private val _replyingTo = MutableStateFlow<Comment?>(null)
    val replyingTo: StateFlow<Comment?> = _replyingTo.asStateFlow()

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
        val reply = _replyingTo.value

        viewModelScope.launch {
            photoRepository.sendStripChatMessage(
                text = text,
                stripId = stripId,
                chatPartnerId = chatPartnerId,
                replyToId = reply?.id,
                replyToText = reply?.text,
                replyToSenderId = reply?.senderId
            )
            _inputText.value = ""
            _replyingTo.value = null
        }
    }

    fun toggleReaction(messageId: String, emoji: String) {
        viewModelScope.launch {
            photoRepository.toggleChatReaction(stripId, chatPartnerId, messageId, emoji)
        }
    }

    fun setReply(comment: Comment) {
        _replyingTo.value = comment
    }

    fun clearReply() {
        _replyingTo.value = null
    }

    fun isMyMessage(comment: Comment): Boolean {
        return comment.senderId == authRepository.currentUserId()
    }
}
