package com.celalbasaran.stripmate.ui.screen.chat

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.DirectMessage
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.chat.ChatRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class DirectMessageViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val chatRepository: ChatRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val partnerId: String = savedStateHandle["userId"] ?: ""

    private val _messages = MutableStateFlow<List<DirectMessage>>(emptyList())
    val messages: StateFlow<List<DirectMessage>> = _messages.asStateFlow()

    private val _inputText = MutableStateFlow("")
    val inputText: StateFlow<String> = _inputText.asStateFlow()

    private val _replyingTo = MutableStateFlow<DirectMessage?>(null)
    val replyingTo: StateFlow<DirectMessage?> = _replyingTo.asStateFlow()

    private val _isPartnerTyping = MutableStateFlow(false)
    val isPartnerTyping: StateFlow<Boolean> = _isPartnerTyping.asStateFlow()

    private val _partnerProfile = MutableStateFlow<UserProfile?>(null)
    val partnerProfile: StateFlow<UserProfile?> = _partnerProfile.asStateFlow()

    private val _isLoadingMore = MutableStateFlow(false)
    val isLoadingMore: StateFlow<Boolean> = _isLoadingMore.asStateFlow()

    private var hasMorePages = true

    init {
        loadPartnerProfile()
        listenToMessages()
        listenToTyping()
        markAsRead()
    }

    private fun loadPartnerProfile() {
        viewModelScope.launch {
            _partnerProfile.value = authRepository.fetchProfile(partnerId)
        }
    }

    private fun listenToMessages() {
        viewModelScope.launch {
            chatRepository.listenToMessages(partnerId).collect { msgs ->
                _messages.value = msgs.sortedByDescending { it.timestamp }
            }
        }
    }

    private fun listenToTyping() {
        viewModelScope.launch {
            chatRepository.listenToTypingIndicator(partnerId).collect { typing ->
                _isPartnerTyping.value = typing
            }
        }
    }

    fun markAsRead() {
        viewModelScope.launch {
            chatRepository.markAsRead(partnerId)
        }
    }

    fun updateInput(text: String) {
        _inputText.value = text
        viewModelScope.launch {
            chatRepository.setTypingIndicator(partnerId, text.isNotBlank())
        }
    }

    fun sendMessage() {
        val text = _inputText.value.trim()
        if (text.isBlank()) return
        val reply = _replyingTo.value

        viewModelScope.launch {
            chatRepository.sendMessage(
                partnerId = partnerId,
                text = text,
                replyToId = reply?.id,
                replyToText = reply?.text,
                replyToSenderId = reply?.senderId
            )
            _inputText.value = ""
            _replyingTo.value = null
            chatRepository.setTypingIndicator(partnerId, false)
        }
    }

    fun loadMore() {
        if (_isLoadingMore.value || !hasMorePages) return
        val lastMessage = _messages.value.lastOrNull() ?: return

        viewModelScope.launch {
            _isLoadingMore.value = true
            val moreMessages = chatRepository.loadMoreMessages(partnerId, lastMessage.timestamp)
            if (moreMessages.isEmpty()) {
                hasMorePages = false
            } else {
                _messages.value = _messages.value + moreMessages.sortedByDescending { it.timestamp }
            }
            _isLoadingMore.value = false
        }
    }

    fun deleteMessage(messageId: String) {
        viewModelScope.launch {
            chatRepository.deleteMessage(partnerId, messageId)
        }
    }

    fun toggleReaction(messageId: String, emoji: String) {
        viewModelScope.launch {
            chatRepository.toggleReaction(partnerId, messageId, emoji)
        }
    }

    fun setReply(message: DirectMessage) {
        _replyingTo.value = message
    }

    fun clearReply() {
        _replyingTo.value = null
    }

    fun setTyping(isTyping: Boolean) {
        viewModelScope.launch {
            chatRepository.setTypingIndicator(partnerId, isTyping)
        }
    }

    fun isMyMessage(message: DirectMessage): Boolean {
        return message.senderId == authRepository.currentUserId()
    }
}
