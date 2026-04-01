package com.celalbasaran.stripmate.ui.screen.support

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject

data class SupportMessage(
    val id: String = "",
    val senderId: String = "",
    val text: String = "",
    val timestamp: Date = Date(),
    val isAdmin: Boolean = false
)

@HiltViewModel
class SupportChatViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val db = FirebaseFirestore.getInstance()

    private val _messages = MutableStateFlow<List<SupportMessage>>(emptyList())
    val messages: StateFlow<List<SupportMessage>> = _messages.asStateFlow()

    private val _inputText = MutableStateFlow("")
    val inputText: StateFlow<String> = _inputText.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private var listener: ListenerRegistration? = null

    private val currentUserId: String?
        get() = authRepository.currentUserId()

    init {
        listenToMessages()
    }

    private fun listenToMessages() {
        val uid = currentUserId ?: return
        _isLoading.value = true

        listener = db
            .collection("support_chats")
            .document(uid)
            .collection("messages")
            .orderBy("timestamp", Query.Direction.ASCENDING)
            .addSnapshotListener { snapshot, error ->
                _isLoading.value = false
                if (error != null || snapshot == null) return@addSnapshotListener

                _messages.value = snapshot.documents.mapNotNull { doc ->
                    val data = doc.data ?: return@mapNotNull null
                    val senderId = data["senderId"] as? String ?: return@mapNotNull null
                    val text = data["text"] as? String ?: return@mapNotNull null
                    val isAdmin = data["isAdmin"] as? Boolean ?: false
                    val timestamp = (data["timestamp"] as? com.google.firebase.Timestamp)?.toDate() ?: Date()

                    SupportMessage(
                        id = doc.id,
                        senderId = senderId,
                        text = text,
                        timestamp = timestamp,
                        isAdmin = isAdmin
                    )
                }
            }
    }

    fun updateInput(text: String) {
        _inputText.value = text
    }

    fun sendMessage() {
        val text = _inputText.value.trim()
        if (text.isBlank()) return
        val uid = currentUserId ?: return

        _inputText.value = ""

        viewModelScope.launch {
            try {
                // Ensure parent document exists so admin app can find the thread
                val parentRef = db.collection("support_chats").document(uid)
                parentRef.set(
                    mapOf(
                        "createdAt" to FieldValue.serverTimestamp(),
                        "userId" to uid
                    ),
                    com.google.firebase.firestore.SetOptions.merge()
                ).await()

                // Add message
                val payload = hashMapOf<String, Any>(
                    "senderId" to uid,
                    "text" to text,
                    "timestamp" to FieldValue.serverTimestamp(),
                    "isAdmin" to false
                )
                parentRef.collection("messages").add(payload).await()
            } catch (_: Exception) {
                // Silently fail - message will appear when Firestore syncs
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        listener?.remove()
        listener = null
    }
}
