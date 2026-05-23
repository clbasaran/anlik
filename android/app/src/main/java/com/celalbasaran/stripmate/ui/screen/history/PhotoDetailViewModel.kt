package com.celalbasaran.stripmate.ui.screen.history

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import android.content.Context
import android.graphics.Bitmap
import com.celalbasaran.stripmate.data.model.Comment
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class PhotoDetailViewModel @Inject constructor(
    private val photoRepository: PhotoRepository,
    private val authRepository: AuthRepository,
    @ApplicationContext private val appContext: Context
) : ViewModel() {

    private val chatOpenedPrefs by lazy {
        appContext.getSharedPreferences("strip_chat_opened", Context.MODE_PRIVATE)
    }

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

    /** Per-receiver latest message metadata, used to sort the receiver bar by activity. */
    private val _chatMeta = MutableStateFlow<Map<String, PhotoRepository.ChatMeta>>(emptyMap())

    /** Per-receiver "sender opened this chat at" timestamps (epoch millis). Persisted in SharedPreferences. */
    private val _lastOpenedAt = MutableStateFlow<Map<String, Long>>(emptyMap())

    /**
     * Receiver profiles ordered by latest chat activity (most recent first).
     * Receivers with no messages keep their original order at the end.
     */
    val sortedReceiverProfiles: StateFlow<List<UserProfile>> = combine(
        _receiverProfiles, _chatMeta
    ) { profiles, meta ->
        val withActivity = profiles.filter { meta[it.id] != null }
            .sortedByDescending { meta[it.id]?.timestampMillis ?: 0L }
        val withoutActivity = profiles.filter { meta[it.id] == null }
        withActivity + withoutActivity
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    /**
     * Receivers who replied since the sender last opened that chat — for the red unread badge.
     */
    val unreadReceivers: StateFlow<Set<String>> = combine(
        _chatMeta, _lastOpenedAt
    ) { meta, opened ->
        meta.entries
            .filter { (receiverId, m) ->
                m.senderId == receiverId && m.timestampMillis > (opened[receiverId] ?: 0L)
            }
            .map { it.key }
            .toSet()
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptySet())

    private val _senderDisplayName = MutableStateFlow<String>("")
    val senderDisplayName: StateFlow<String> = _senderDisplayName.asStateFlow()

    /** True if the strip is secret and locked for the current user */
    private val _isSecretLocked = MutableStateFlow(false)
    val isSecretLocked: StateFlow<Boolean> = _isSecretLocked.asStateFlow()

    /** True while the unlock animation is playing */
    private val _showUnlockAnimation = MutableStateFlow(false)
    val showUnlockAnimation: StateFlow<Boolean> = _showUnlockAnimation.asStateFlow()

    private var chatPartnerId: String? = null

    fun loadStrip(stripId: String) {
        viewModelScope.launch {
            val fetchedStrip = photoRepository.fetchStrip(stripId) ?: return@launch
            _strip.value = fetchedStrip

            val currentUserId = authRepository.currentUserId() ?: return@launch
            _isSender.value = fetchedStrip.senderId == currentUserId
            _isSecretLocked.value = fetchedStrip.isLockedFor(currentUserId)

            // Load sender display name
            val senderProfile = authRepository.fetchProfile(fetchedStrip.senderId)
            _senderDisplayName.value = senderProfile?.displayName
                ?: senderProfile?.username
                ?: fetchedStrip.senderId

            // Determine chat document ID — always the receiver's uid
            // Path: strips/{stripId}/chats/{receiverId}/messages
            chatPartnerId = if (fetchedStrip.senderId == currentUserId) {
                fetchedStrip.receiverIds.firstOrNull().also { id ->
                    if (id == null) Log.w("PhotoDetailVM", "No receivers found for strip ${fetchedStrip.id}, chat disabled")
                }
            } else {
                currentUserId  // receiver writes to their own chat doc
            }

            // Load receiver profiles if sender (parallel — sequential fetch
            // made the receiver bar feel sluggish on multi-recipient strips).
            if (_isSender.value) {
                val otherReceivers = fetchedStrip.receiverIds.filter { it != fetchedStrip.senderId }
                val profiles: List<UserProfile> = coroutineScope {
                    val deferred = otherReceivers.map { uid ->
                        async(Dispatchers.IO) { authRepository.fetchProfile(uid) }
                    }
                    deferred.map { it.await() }.filterNotNull()
                }
                _receiverProfiles.value = profiles

                // Hydrate last-opened timestamps from SharedPreferences (per-strip, per-receiver)
                _lastOpenedAt.value = otherReceivers.associateWith { id ->
                    chatOpenedPrefs.getLong("${fetchedStrip.id}.$id", 0L)
                }

                // Fetch latest message in each receiver chat to drive sort + badge
                refreshChatActivity()
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
        val strip = _strip.value ?: return
        val partnerId = chatPartnerId ?: return
        val reply = _replyingTo.value
        val wasLocked = _isSecretLocked.value

        viewModelScope.launch {
            try {
                photoRepository.sendStripChatMessage(
                    text = text,
                    stripId = strip.id,
                    chatPartnerId = partnerId,
                    replyToId = reply?.id,
                    replyToText = reply?.text,
                    replyToSenderId = reply?.senderId
                )
                _inputText.value = ""
                _replyingTo.value = null

                // If strip was secret-locked and this is the first reply, unlock it
                if (wasLocked && strip.isSecret) {
                    try {
                        photoRepository.unlockSecret(strip.id)
                        _showUnlockAnimation.value = true
                        _isSecretLocked.value = false
                    } catch (e: Exception) {
                        Log.e("PhotoDetailVM", "Failed to unlock secret", e)
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("PhotoDetailVM", "sendMessage failed", e)
            }
        }
    }

    fun onUnlockAnimationComplete() {
        _showUnlockAnimation.value = false
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

    /**
     * Sends a photo reply (selfie) in the strip chat.
     * Uploads the bitmap to Firebase Storage, gets the URL, and sends it as a message.
     */
    fun sendPhotoReply(bitmap: Bitmap) {
        val strip = _strip.value ?: return
        val partnerId = chatPartnerId ?: return

        viewModelScope.launch {
            try {
                val photoUrl = photoRepository.uploadChatPhoto(bitmap, strip.id)
                if (photoUrl != null) {
                    photoRepository.sendStripChatMessage(
                        text = "[photo_reply]$photoUrl",
                        stripId = strip.id,
                        chatPartnerId = partnerId
                    )
                }
            } catch (e: Exception) {
                Log.e("PhotoDetailVM", "Failed to send photo reply", e)
            }
        }
    }

    fun sendGiphyMessage(giphyUrl: String) {
        val strip = _strip.value ?: return
        val partnerId = chatPartnerId ?: return

        viewModelScope.launch {
            photoRepository.sendStripChatMessage(
                text = giphyUrl,
                stripId = strip.id,
                chatPartnerId = partnerId
            )
        }
    }

    fun isMyMessage(comment: Comment): Boolean {
        return comment.senderId == authRepository.currentUserId()
    }

    fun selectReceiver(userId: String) {
        chatPartnerId = userId
        val stripId = _strip.value?.id ?: return
        markChatOpened(userId)
        viewModelScope.launch {
            photoRepository.listenToStripChat(stripId, userId).collect { comments ->
                _messages.value = comments.sortedBy { it.timestamp }
            }
        }
    }

    /**
     * Persist that the sender has opened this receiver's strip-chat — clears the unread badge.
     */
    fun markChatOpened(receiverId: String) {
        val stripId = _strip.value?.id ?: return
        val now = System.currentTimeMillis()
        chatOpenedPrefs.edit().putLong("$stripId.$receiverId", now).apply()
        _lastOpenedAt.value = _lastOpenedAt.value + (receiverId to now)
    }

    /**
     * Re-fetch the latest message in each receiver's strip-chat. Called on initial load
     * and whenever the receiver bar regains focus, so the sort order and badge stay fresh.
     */
    fun refreshChatActivity() {
        val strip = _strip.value ?: return
        if (!_isSender.value) return
        val otherReceivers = strip.receiverIds.filter { it != strip.senderId }
        if (otherReceivers.isEmpty()) return

        viewModelScope.launch {
            try {
                val meta = photoRepository.fetchLatestStripChatMeta(strip.id, otherReceivers)
                _chatMeta.value = meta
            } catch (e: Exception) {
                Log.w("PhotoDetailVM", "Failed to refresh chat activity", e)
            }
        }
    }
}
