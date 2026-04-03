package com.celalbasaran.stripmate.ui.screen.chat

import android.content.Context
import android.net.ConnectivityManager
import android.util.Log
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import com.google.firebase.storage.FirebaseStorage
import kotlinx.coroutines.tasks.await
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.DirectMessage
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.chat.ChatRepository
import com.celalbasaran.stripmate.service.guard.AppGuardRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject

@HiltViewModel
class DirectMessageViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val chatRepository: ChatRepository,
    private val authRepository: AuthRepository,
    private val guardRepository: AppGuardRepository,
    @ApplicationContext private val context: Context
) : ViewModel() {

    data class PendingMessage(
        val text: String,
        val replyToId: String? = null,
        val replyToText: String? = null,
        val replyToSenderId: String? = null,
        val timestamp: Long = System.currentTimeMillis()
    )

    private val partnerId: String = savedStateHandle["userId"] ?: ""

    private val _messages = MutableStateFlow<List<DirectMessage>>(emptyList())
    val messages: StateFlow<List<DirectMessage>> = _messages.asStateFlow()

    private val _inputText = MutableStateFlow("")
    val inputText: StateFlow<String> = _inputText.asStateFlow()

    private val _replyingTo = MutableStateFlow<DirectMessage?>(null)
    val replyingTo: StateFlow<DirectMessage?> = _replyingTo.asStateFlow()

    private val _wordFilterError = MutableStateFlow<String?>(null)
    val wordFilterError: StateFlow<String?> = _wordFilterError.asStateFlow()

    private val _isPartnerTyping = MutableStateFlow(false)
    val isPartnerTyping: StateFlow<Boolean> = _isPartnerTyping.asStateFlow()

    private val _partnerProfile = MutableStateFlow<UserProfile?>(null)
    val partnerProfile: StateFlow<UserProfile?> = _partnerProfile.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isLoadingMore = MutableStateFlow(false)
    val isLoadingMore: StateFlow<Boolean> = _isLoadingMore.asStateFlow()

    private val _pendingMessages = MutableStateFlow<List<PendingMessage>>(emptyList())
    val pendingMessages: StateFlow<List<PendingMessage>> = _pendingMessages.asStateFlow()

    private var hasMorePages = true

    private val prefs = context.getSharedPreferences("pending_messages", Context.MODE_PRIVATE)

    private val connectivityManager =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            flushPendingMessages()
        }
    }

    init {
        loadPendingFromDisk()
        loadPartnerProfile()
        listenToMessages()
        listenToTyping()
        markAsRead()
        registerConnectivityListener()
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
                if (_isLoading.value) _isLoading.value = false
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

            if (!isOnline()) {
                // Queue message for later delivery
                val pending = PendingMessage(
                    text = text,
                    replyToId = reply?.id,
                    replyToText = reply?.text,
                    replyToSenderId = reply?.senderId
                )
                _pendingMessages.value = _pendingMessages.value + pending
                savePendingToDisk()
                _inputText.value = ""
                _replyingTo.value = null
                return@launch
            }

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

    fun clearWordFilterError() {
        _wordFilterError.value = null
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

    fun sendGiphyMessage(giphyUrl: String) {
        viewModelScope.launch {
            chatRepository.sendMessage(
                partnerId = partnerId,
                text = giphyUrl
            )
        }
    }

    fun sendPhotoMessage(uri: Uri) {
        viewModelScope.launch {
            try {
                val ref = FirebaseStorage.getInstance().reference
                    .child("dm_photos/${authRepository.currentUserId()}_${java.util.UUID.randomUUID()}.jpg")
                ref.putFile(uri).await()
                val downloadUrl = ref.downloadUrl.await().toString()
                chatRepository.sendMessage(partnerId = partnerId, text = downloadUrl)
            } catch (e: Exception) {
                Log.e("DirectMessageVM", "Failed to send photo message", e)
            }
        }
    }

    fun setTyping(isTyping: Boolean) {
        viewModelScope.launch {
            chatRepository.setTypingIndicator(partnerId, isTyping)
        }
    }

    fun isMyMessage(message: DirectMessage): Boolean {
        return message.senderId == authRepository.currentUserId()
    }

    // -- Offline queue helpers --

    private fun isOnline(): Boolean {
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun flushPendingMessages() {
        val pending = _pendingMessages.value
        if (pending.isEmpty()) return

        viewModelScope.launch {
            val failed = mutableListOf<PendingMessage>()
            for (msg in pending) {
                try {
                    chatRepository.sendMessage(
                        partnerId = partnerId,
                        text = msg.text,
                        replyToId = msg.replyToId,
                        replyToText = msg.replyToText,
                        replyToSenderId = msg.replyToSenderId
                    )
                } catch (e: Exception) {
                    Log.e("DirectMessageVM", "Failed to flush pending message", e)
                    failed.add(msg)
                }
            }
            _pendingMessages.value = failed
            savePendingToDisk()
        }
    }

    private fun registerConnectivityListener() {
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        try {
            connectivityManager.registerNetworkCallback(request, networkCallback)
        } catch (e: Exception) {
            Log.w("DirectMessageVM", "Failed to register network callback", e)
        }
    }

    private fun savePendingToDisk() {
        val key = "pending_$partnerId"
        val arr = JSONArray()
        for (msg in _pendingMessages.value) {
            val obj = JSONObject().apply {
                put("text", msg.text)
                put("replyToId", msg.replyToId ?: "")
                put("replyToText", msg.replyToText ?: "")
                put("replyToSenderId", msg.replyToSenderId ?: "")
                put("timestamp", msg.timestamp)
            }
            arr.put(obj)
        }
        prefs.edit().putString(key, arr.toString()).apply()
    }

    private fun loadPendingFromDisk() {
        val key = "pending_$partnerId"
        val raw = prefs.getString(key, null) ?: return
        try {
            val arr = JSONArray(raw)
            val list = mutableListOf<PendingMessage>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                list.add(
                    PendingMessage(
                        text = obj.getString("text"),
                        replyToId = obj.getString("replyToId").ifEmpty { null },
                        replyToText = obj.getString("replyToText").ifEmpty { null },
                        replyToSenderId = obj.getString("replyToSenderId").ifEmpty { null },
                        timestamp = obj.getLong("timestamp")
                    )
                )
            }
            _pendingMessages.value = list
        } catch (e: Exception) {
            Log.w("DirectMessageVM", "Corrupted pending messages data, clearing", e)
            prefs.edit().remove(key).apply()
        }
    }

    override fun onCleared() {
        super.onCleared()
        try {
            connectivityManager.unregisterNetworkCallback(networkCallback)
        } catch (e: Exception) {
            Log.w("DirectMessageVM", "Failed to unregister network callback", e)
        }
    }
}
