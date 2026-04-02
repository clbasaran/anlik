package com.celalbasaran.stripmate.service.chat

import android.util.Log
import com.celalbasaran.stripmate.data.model.DirectMessage
import com.celalbasaran.stripmate.data.model.ThreadSummary
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ChatRepositoryImpl @Inject constructor(
    private val db: FirebaseFirestore,
    private val authRepository: AuthRepository
) : ChatRepository {

    private fun getThreadId(user1: String, user2: String): String {
        return if (user1 < user2) "${user1}_${user2}" else "${user2}_${user1}"
    }

    override fun listenToMessages(partnerId: String): Flow<List<DirectMessage>> = callbackFlow {
        val uid = authRepository.currentUserId()
        if (uid == null) {
            trySend(emptyList())
            close()
            return@callbackFlow
        }

        val threadId = getThreadId(uid, partnerId)
        val query = db.collection("direct_messages").document(threadId)
            .collection("messages")
            .orderBy("timestamp", Query.Direction.ASCENDING)
            .limitToLast(50)

        val listener: ListenerRegistration = query.addSnapshotListener { snapshot, error ->
            if (error != null || snapshot == null) {
                return@addSnapshotListener
            }

            val messages = snapshot.documents.mapNotNull { doc ->
                DirectMessage.fromDocument(doc)
            }

            trySend(messages)
        }

        awaitClose { listener.remove() }
    }

    override suspend fun loadMoreMessages(partnerId: String, beforeTimestamp: Date): List<DirectMessage> {
        val uid = authRepository.currentUserId() ?: return emptyList()
        val threadId = getThreadId(uid, partnerId)

        return try {
            val snapshot = db.collection("direct_messages").document(threadId)
                .collection("messages")
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .whereLessThan("timestamp", Timestamp(beforeTimestamp))
                .limit(30)
                .get()
                .await()

            snapshot.documents.mapNotNull { DirectMessage.fromDocument(it) }
                .reversed()
        } catch (e: Exception) {
            emptyList()
        }
    }

    override suspend fun sendMessage(
        partnerId: String,
        text: String,
        replyToId: String?,
        replyToText: String?,
        replyToSenderId: String?
    ) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        val trimmedText = text.trim()
        if (trimmedText.isEmpty()) return

        val threadId = getThreadId(uid, partnerId)
        val messageId = UUID.randomUUID().toString()
        val messageRef = db.collection("direct_messages").document(threadId)
            .collection("messages").document(messageId)

        val documentData: MutableMap<String, Any> = mutableMapOf(
            "id" to messageId,
            "senderId" to uid,
            "receiverId" to partnerId,
            "text" to trimmedText,
            "timestamp" to FieldValue.serverTimestamp()
        )
        replyToId?.let { documentData["replyToId"] = it }
        replyToText?.let { documentData["replyToText"] = it }
        replyToSenderId?.let { documentData["replyToSenderId"] = it }

        messageRef.set(documentData).await()
    }

    override suspend fun markAsRead(partnerId: String) {
        val uid = authRepository.currentUserId() ?: return
        val threadId = getThreadId(uid, partnerId)

        try {
            val snapshot = db.collection("direct_messages").document(threadId)
                .collection("messages")
                .whereEqualTo("senderId", partnerId)
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(100)
                .get()
                .await()

            val unreadDocs = snapshot.documents.filter { doc ->
                val data = doc.data ?: return@filter false
                val isForMe = (data["receiverId"] as? String) == uid
                val isUnread = data["readAt"] == null
                isForMe && isUnread
            }

            if (unreadDocs.isEmpty()) return

            val batch = db.batch()
            for (doc in unreadDocs) {
                batch.update(doc.reference, "readAt", FieldValue.serverTimestamp())
            }
            batch.commit().await()
        } catch (e: Exception) { Log.e("ChatRepository", "Failed to mark messages as read", e) }
    }

    override suspend fun deleteMessage(partnerId: String, messageId: String) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")
        val threadId = getThreadId(uid, partnerId)

        db.collection("direct_messages").document(threadId)
            .collection("messages").document(messageId)
            .update(
                mapOf(
                    "isDeleted" to true,
                    "text" to "bu mesaj silindi"
                )
            )
            .await()
    }

    override suspend fun toggleReaction(partnerId: String, messageId: String, emoji: String) {
        val uid = authRepository.currentUserId() ?: return
        val threadId = getThreadId(uid, partnerId)

        val ref = db.collection("direct_messages").document(threadId)
            .collection("messages").document(messageId)

        try {
            val doc = ref.get().await()
            val data = doc.data ?: return
            @Suppress("UNCHECKED_CAST")
            val reactions = data["reactions"] as? Map<String, String> ?: emptyMap()

            if (reactions[uid] == emoji) {
                // Remove reaction
                ref.update("reactions.$uid", FieldValue.delete()).await()
            } else {
                // Add/change reaction
                ref.update("reactions.$uid", emoji).await()
            }
        } catch (e: Exception) { Log.e("ChatRepository", "Failed to toggle reaction", e) }
    }

    override suspend fun fetchThreadSummary(partnerId: String): ThreadSummary? {
        val uid = authRepository.currentUserId() ?: return null
        val threadId = getThreadId(uid, partnerId)

        return try {
            val recentSnapshot = db.collection("direct_messages").document(threadId)
                .collection("messages")
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .limit(30)
                .get()
                .await()

            val lastDoc = recentSnapshot.documents.firstOrNull() ?: return null
            val lastData = lastDoc.data ?: return null
            val lastText = lastData["text"] as? String ?: ""
            val lastSenderId = lastData["senderId"] as? String ?: ""
            val lastTimestamp = (lastData["timestamp"] as? Timestamp)?.toDate() ?: Date()
            val isDeleted = lastData["isDeleted"] as? Boolean ?: false

            // Count unread messages from the last 30
            val unreadCount = recentSnapshot.documents.count { doc ->
                val data = doc.data ?: return@count false
                val fromPartner = (data["senderId"] as? String) == partnerId
                val isForMe = (data["receiverId"] as? String) == uid
                val isUnread = data["readAt"] == null
                fromPartner && isForMe && isUnread
            }

            ThreadSummary(
                partnerId = partnerId,
                lastMessage = if (isDeleted) "bu mesaj silindi" else lastText,
                lastMessageSenderId = lastSenderId,
                lastMessageTimestamp = lastTimestamp,
                unreadCount = unreadCount
            )
        } catch (e: Exception) {
            null
        }
    }

    override suspend fun setTypingIndicator(partnerId: String, isTyping: Boolean) {
        val uid = authRepository.currentUserId() ?: return
        val threadId = getThreadId(uid, partnerId)

        try {
            db.collection("direct_messages").document(threadId)
                .set(
                    mapOf(
                        "typing_$uid" to isTyping,
                        "typing_${uid}_at" to FieldValue.serverTimestamp()
                    ),
                    SetOptions.merge()
                )
                .await()
        } catch (e: Exception) { Log.e("ChatRepository", "Failed to set typing indicator", e) }
    }

    override fun listenToTypingIndicator(partnerId: String): Flow<Boolean> = callbackFlow {
        val uid = authRepository.currentUserId()
        if (uid == null) {
            trySend(false)
            close()
            return@callbackFlow
        }

        val threadId = getThreadId(uid, partnerId)
        val threadRef = db.collection("direct_messages").document(threadId)

        val listener = threadRef.addSnapshotListener { snapshot, error ->
            if (error != null || snapshot == null || !snapshot.exists()) {
                trySend(false)
                return@addSnapshotListener
            }

            val data = snapshot.data ?: run {
                trySend(false)
                return@addSnapshotListener
            }

            val isTyping = data["typing_$partnerId"] as? Boolean ?: false
            val typingAt = (data["typing_${partnerId}_at"] as? Timestamp)?.toDate()

            // Consider typing stale after 10 seconds
            val isRecent = typingAt != null &&
                    (System.currentTimeMillis() - typingAt.time) < 10_000L

            trySend(isTyping && isRecent)
        }

        awaitClose { listener.remove() }
    }
}
