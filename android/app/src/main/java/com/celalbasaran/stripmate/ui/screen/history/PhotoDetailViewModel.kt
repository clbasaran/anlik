package com.celalbasaran.stripmate.ui.screen.history

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Comment
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PhotoDetailViewModel @Inject constructor(
    private val photoRepository: PhotoRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _strip = MutableStateFlow<Strip?>(null)
    val strip: StateFlow<Strip?> = _strip.asStateFlow()

    private val _messages = MutableStateFlow<List<Comment>>(emptyList())
    val messages: StateFlow<List<Comment>> = _messages.asStateFlow()

    private val _inputText = MutableStateFlow("")
    val inputText: StateFlow<String> = _inputText.asStateFlow()

    private val _replyingTo = MutableStateFlow<Comment?>(null)
    val replyingTo: StateFlow<Comment?> = _replyingTo.asStateFlow()

    private val _isSender = MutableStateFlow(false)
    val isSender: StateFlow<Boolean> = _isSender.asStateFlow()

    private val _receiverProfiles = MutableStateFlow<List<UserProfile>>(emptyList())
    val receiverProfiles: StateFlow<List<UserProfile>> = _receiverProfiles.asStateFlow()

    private val _senderDisplayName = MutableStateFlow<String>("")
    val senderDisplayName: StateFlow<String> = _senderDisplayName.asStateFlow()

    private var chatPartnerId: String? = null

    fun loadStrip(stripId: String) {
        viewModelScope.launch {
            val fetchedStrip = photoRepository.fetchStrip(stripId) ?: return@launch
            _strip.value = fetchedStrip

            val currentUserId = authRepository.currentUserId() ?: return@launch
            _isSender.value = fetchedStrip.senderId == currentUserId

            // Load sender display name
            val senderProfile = authRepository.fetchProfile(fetchedStrip.senderId)
            _senderDisplayName.value = senderProfile?.displayName
                ?: senderProfile?.username
                ?: fetchedStrip.senderId

            // Determine chat partner
            chatPartnerId = if (fetchedStrip.senderId == currentUserId) {
                fetchedStrip.receiverIds.firstOrNull()
            } else {
                fetchedStrip.senderId
            }

            // Load receiver profiles if sender
            if (_isSender.value) {
                val profiles = fetchedStrip.receiverIds.mapNotNull { uid ->
                    authRepository.fetchProfile(uid)
                }
                _receiverProfiles.value = profiles
            }

            // Listen to strip chat
            chatPartnerId?.let { partnerId ->
                photoRepository.listenToStripChat(stripId, partnerId).collect { comments ->
                    _messages.value = comments.sortedBy { it.timestamp }
                }
            }
        }
    }

    fun updateInput(text: String) {
        _inputText.value = text
    }

    fun sendMessage() {
        val text = _inputText.value.trim()
        if (text.isBlank()) return
        val stripId = _strip.value?.id ?: return
        val partnerId = chatPartnerId ?: return
        val reply = _replyingTo.value

        viewModelScope.launch {
            photoRepository.sendStripChatMessage(
                text = text,
                stripId = stripId,
                chatPartnerId = partnerId,
                replyToId = reply?.id,
                replyToText = reply?.text,
                replyToSenderId = reply?.senderId
            )
            _inputText.value = ""
            _replyingTo.value = null
        }
    }

    fun setReply(comment: Comment) {
        _replyingTo.value = comment
    }

    fun clearReply() {
        _replyingTo.value = null
    }

    fun toggleReaction(photoId: String, emoji: String) {
        viewModelScope.launch {
            photoRepository.toggleReaction(photoId, emoji)
        }
    }

    fun deleteStrip(strip: Strip) {
        viewModelScope.launch {
            photoRepository.deleteStrip(strip)
        }
    }

    fun isMyMessage(comment: Comment): Boolean {
        return comment.senderId == authRepository.currentUserId()
    }

    fun selectReceiver(userId: String) {
        chatPartnerId = userId
        val stripId = _strip.value?.id ?: return
        viewModelScope.launch {
            photoRepository.listenToStripChat(stripId, userId).collect { comments ->
                _messages.value = comments.sortedBy { it.timestamp }
            }
        }
    }
}
