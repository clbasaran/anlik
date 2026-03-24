package com.celalbasaran.stripmate.service.notification

import com.celalbasaran.stripmate.data.model.AppNotification
import com.celalbasaran.stripmate.data.model.NotificationType
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NotificationRepositoryImpl @Inject constructor(
    private val db: FirebaseFirestore,
    private val authRepository: AuthRepository
) : NotificationRepository {

    override fun listenToNotifications(): Flow<List<AppNotification>> = callbackFlow {
        val uid = authRepository.currentUserId()
        if (uid == null) {
            trySend(emptyList())
            close()
            return@callbackFlow
        }

        val query = db.collection("notifications")
            .whereEqualTo("userId", uid)
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(50)

        val listener: ListenerRegistration = query.addSnapshotListener { snapshot, error ->
            if (error != null || snapshot == null) {
                return@addSnapshotListener
            }

            val notifications = snapshot.documents.mapNotNull { doc ->
                val data = doc.data ?: return@mapNotNull null
                val id = data["id"] as? String ?: return@mapNotNull null
                val notifUserId = data["userId"] as? String ?: return@mapNotNull null
                val senderId = data["senderId"] as? String ?: return@mapNotNull null
                val senderName = data["senderName"] as? String ?: return@mapNotNull null
                val typeString = data["type"] as? String ?: return@mapNotNull null
                val type = NotificationType.fromString(typeString) ?: return@mapNotNull null
                val timestamp = (data["timestamp"] as? Timestamp)?.toDate() ?: return@mapNotNull null

                AppNotification(
                    id = id,
                    userId = notifUserId,
                    senderId = senderId,
                    senderName = senderName,
                    type = type,
                    relatedId = data["relatedId"] as? String,
                    thumbnailUrl = data["thumbnailUrl"] as? String,
                    timestamp = timestamp,
                    isRead = data["isRead"] as? Boolean ?: false
                )
            }

            trySend(notifications)
        }

        awaitClose { listener.remove() }
    }

    override suspend fun markAsRead(notificationId: String) {
        try {
            db.collection("notifications").document(notificationId)
                .update("isRead", true)
                .await()
        } catch (_: Exception) { }
    }

    override fun getUnreadCount(): Flow<Int> {
        return listenToNotifications().map { notifications ->
            notifications.count { !it.isRead }
        }
    }
}
