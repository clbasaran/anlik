package com.celalbasaran.stripmate.service.photo

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import com.celalbasaran.stripmate.data.model.Comment
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.widget.StripMateWidgetReceiver
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import com.google.firebase.storage.FirebaseStorage
import com.google.firebase.storage.StorageMetadata
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import java.io.ByteArrayOutputStream
import java.util.Date
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PhotoRepositoryImpl @Inject constructor(
    private val db: FirebaseFirestore,
    private val storage: FirebaseStorage,
    private val authRepository: AuthRepository,
    @ApplicationContext private val appContext: Context
) : PhotoRepository {

    override suspend fun sendPhoto(
        bitmap: Bitmap,
        receiverIds: List<String>,
        latitude: Double?,
        longitude: Double?,
        cityName: String?,
        voiceData: ByteArray?
    ): String {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        if (receiverIds.isEmpty()) throw Exception("No receivers specified")
        if (receiverIds.size > 50) throw Exception("Maximum 50 receivers allowed")

        // Resize to max 1080p
        val resizedBitmap = resizeBitmap(bitmap, 1080)

        // Compress to JPEG at 75% quality
        val outputStream = ByteArrayOutputStream()
        resizedBitmap.compress(Bitmap.CompressFormat.JPEG, 75, outputStream)
        val imageData = outputStream.toByteArray()

        val photoId = UUID.randomUUID().toString()

        // Upload image
        val imageRef = storage.reference.child("strips/$photoId.jpg")
        val metadata = StorageMetadata.Builder()
            .setContentType("image/jpeg")
            .build()
        imageRef.putBytes(imageData, metadata).await()
        val downloadUrl = imageRef.downloadUrl.await().toString()

        // Upload voice if present
        var voiceUrlString: String? = null
        if (voiceData != null) {
            val voiceRef = storage.reference.child("voices/$photoId.m4a")
            val voiceMeta = StorageMetadata.Builder()
                .setContentType("audio/mp4")
                .build()
            voiceRef.putBytes(voiceData, voiceMeta).await()
            voiceUrlString = voiceRef.downloadUrl.await().toString()
        }

        // Ensure sender is included in receiverIds
        val finalReceivers = if (receiverIds.contains(uid)) {
            receiverIds
        } else {
            receiverIds + uid
        }

        val documentData: MutableMap<String, Any> = mutableMapOf(
            "id" to photoId,
            "senderId" to uid,
            "receiverIds" to finalReceivers,
            "imageUrl" to downloadUrl,
            "timestamp" to FieldValue.serverTimestamp()
        )
        latitude?.let { documentData["latitude"] = it }
        longitude?.let { documentData["longitude"] = it }
        cityName?.let { documentData["cityName"] = it }
        voiceUrlString?.let { documentData["voiceUrl"] = it }

        db.collection("strips").document(photoId).set(documentData).await()

        // Recycle the resized bitmap if it is different from the original
        if (resizedBitmap !== bitmap) {
            resizedBitmap.recycle()
        }

        return photoId
    }

    override fun listenToHistory(userId: String): Flow<List<Strip>> = callbackFlow {
        var blockedIds: Set<String> = try {
            authRepository.fetchBlockedUserIds()
        } catch (_: Exception) {
            emptySet()
        }

        val query = db.collection("strips")
            .whereArrayContains("receiverIds", userId)
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .limit(50)

        val listener: ListenerRegistration = query.addSnapshotListener { snapshot, error ->
            if (error != null || snapshot == null) return@addSnapshotListener

            // Refresh blocked IDs in the background
            val currentBlockedIds = blockedIds

            val strips = snapshot.documents.mapNotNull { doc ->
                val strip = Strip.fromDocument(doc) ?: return@mapNotNull null
                // Filter blocked senders and flagged strips
                if (currentBlockedIds.contains(strip.senderId)) return@mapNotNull null
                if (strip.flagged) return@mapNotNull null
                strip
            }.sortedByDescending { it.timestamp }

            // Update widget with the latest RECEIVED photo
            val widgetPrefs = appContext.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            val filterFriendId = widgetPrefs.getString("widget_filter_friend_id", null)

            val widgetStrip = if (filterFriendId != null) {
                // Show only from selected friend
                strips.firstOrNull { it.senderId == filterFriendId }
            } else {
                // Show latest from anyone except self
                strips.firstOrNull { it.senderId != userId }
            }

            widgetStrip?.let { latest ->
                updateWidgetData(
                    imageUrl = latest.imageUrl,
                    cityName = latest.cityName,
                    photoLat = latest.latitude,
                    photoLon = latest.longitude
                )
            }

            trySend(strips)
        }

        awaitClose { listener.remove() }
    }

    override suspend fun loadMoreHistory(userId: String, beforeTimestamp: Date): List<Strip> {
        return try {
            val blockedIds = try {
                authRepository.fetchBlockedUserIds()
            } catch (_: Exception) {
                emptySet()
            }

            val snapshot = db.collection("strips")
                .whereArrayContains("receiverIds", userId)
                .orderBy("timestamp", Query.Direction.DESCENDING)
                .startAfter(Timestamp(beforeTimestamp))
                .limit(30)
                .get()
                .await()

            snapshot.documents.mapNotNull { doc ->
                val strip = Strip.fromDocument(doc) ?: return@mapNotNull null
                if (blockedIds.contains(strip.senderId)) return@mapNotNull null
                if (strip.flagged) return@mapNotNull null
                strip
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    override suspend fun fetchStrip(stripId: String): Strip? {
        return try {
            val doc = db.collection("strips").document(stripId).get().await()
            Strip.fromDocument(doc)
        } catch (e: Exception) {
            null
        }
    }

    override suspend fun deleteStrip(strip: Strip) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")
        if (strip.senderId != uid) throw Exception("Can only delete own strips")

        // 1. Delete Firestore document
        db.collection("strips").document(strip.id).delete().await()

        // 2. Delete from Storage
        try {
            val fileName = android.net.Uri.parse(strip.imageUrl).lastPathSegment ?: "${strip.id}.jpg"
            storage.reference.child("strips/$fileName").delete().await()

            // Delete thumbnails
            val baseName = fileName.substringBeforeLast(".")
            try { storage.reference.child("strips/thumbs/${baseName}_800x800.jpg").delete().await() } catch (_: Exception) { }
            try { storage.reference.child("strips/thumbs/${baseName}_200x200.jpg").delete().await() } catch (_: Exception) { }
        } catch (_: Exception) { }

        // 3. Delete chat subcollections
        try {
            val chatsSnapshot = db.collection("strips").document(strip.id)
                .collection("chats").get().await()
            for (chatDoc in chatsSnapshot.documents) {
                try {
                    val messagesSnapshot = chatDoc.reference.collection("messages").get().await()
                    val batch = db.batch()
                    for (msgDoc in messagesSnapshot.documents) {
                        batch.delete(msgDoc.reference)
                    }
                    batch.commit().await()
                } catch (_: Exception) { }
                try { chatDoc.reference.delete().await() } catch (_: Exception) { }
            }
        } catch (_: Exception) { }
    }

    override suspend fun clearHistory() {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        val snapshot = db.collection("strips")
            .whereArrayContains("receiverIds", uid)
            .get()
            .await()

        val batch = db.batch()
        for (doc in snapshot.documents) {
            @Suppress("UNCHECKED_CAST")
            val receiverIds = (doc.get("receiverIds") as? List<String>)?.toMutableList() ?: continue
            receiverIds.remove(uid)

            if (receiverIds.isEmpty()) {
                batch.delete(doc.reference)
            } else {
                batch.update(doc.reference, "receiverIds", receiverIds)
            }
        }
        batch.commit().await()
    }

    override suspend fun toggleReaction(photoId: String, emoji: String) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        val stripRef = db.collection("strips").document(photoId)

        db.runTransaction { transaction ->
            val stripDoc = transaction.get(stripRef)
            val data = stripDoc.data ?: return@runTransaction

            @Suppress("UNCHECKED_CAST")
            val reactions = (data["reactions"] as? Map<String, List<String>>)
                ?.mapValues { it.value.toMutableList() }
                ?.toMutableMap()
                ?: mutableMapOf()

            // Find if user already reacted with any emoji
            val existingEmoji = reactions.entries.firstOrNull { uid in it.value }?.key

            if (existingEmoji != null) {
                reactions[existingEmoji]?.remove(uid)
                if (reactions[existingEmoji]?.isEmpty() == true) {
                    reactions.remove(existingEmoji)
                }
                // If same emoji, just remove (toggle off)
                if (existingEmoji == emoji) {
                    transaction.update(stripRef, "reactions", reactions)
                    return@runTransaction
                }
            }

            // Add new reaction
            reactions.getOrPut(emoji) { mutableListOf() }.add(uid)
            transaction.update(stripRef, "reactions", reactions)
        }.await()
    }

    override suspend fun sendStripChatMessage(
        text: String,
        stripId: String,
        chatPartnerId: String,
        replyToId: String?,
        replyToText: String?,
        replyToSenderId: String?,
        voiceUrl: String?
    ) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        val messageId = UUID.randomUUID().toString()
        val messageRef = db.collection("strips").document(stripId)
            .collection("chats").document(chatPartnerId)
            .collection("messages").document(messageId)

        val documentData: MutableMap<String, Any> = mutableMapOf(
            "id" to messageId,
            "photoId" to stripId,
            "senderId" to uid,
            "text" to text,
            "timestamp" to FieldValue.serverTimestamp()
        )
        replyToId?.let { documentData["replyToId"] = it }
        replyToText?.let { documentData["replyToText"] = it }
        replyToSenderId?.let { documentData["replyToSenderId"] = it }
        voiceUrl?.let { documentData["voiceUrl"] = it }

        messageRef.set(documentData).await()
    }

    override fun listenToStripChat(stripId: String, chatPartnerId: String): Flow<List<Comment>> = callbackFlow {
        val query = db.collection("strips").document(stripId)
            .collection("chats").document(chatPartnerId)
            .collection("messages")
            .orderBy("timestamp", Query.Direction.ASCENDING)

        val listener = query.addSnapshotListener { snapshot, error ->
            if (error != null || snapshot == null) {
                trySend(emptyList())
                return@addSnapshotListener
            }

            val messages = snapshot.documents.mapNotNull { doc ->
                val data = doc.data ?: return@mapNotNull null
                val id = data["id"] as? String ?: return@mapNotNull null
                val photoId = data["photoId"] as? String ?: return@mapNotNull null
                val senderId = data["senderId"] as? String ?: return@mapNotNull null
                val msgText = data["text"] as? String ?: return@mapNotNull null
                val timestamp = (data["timestamp"] as? Timestamp)?.toDate() ?: Date()
                @Suppress("UNCHECKED_CAST")
                val reactions = data["reactions"] as? Map<String, String>

                Comment(
                    id = id,
                    photoId = photoId,
                    senderId = senderId,
                    text = msgText,
                    timestamp = timestamp,
                    replyToId = data["replyToId"] as? String,
                    replyToText = data["replyToText"] as? String,
                    replyToSenderId = data["replyToSenderId"] as? String,
                    reactions = reactions,
                    voiceUrl = data["voiceUrl"] as? String
                )
            }

            trySend(messages)
        }

        awaitClose { listener.remove() }
    }

    override suspend fun toggleChatReaction(
        stripId: String,
        chatPartnerId: String,
        messageId: String,
        emoji: String
    ) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        val ref = db.collection("strips").document(stripId)
            .collection("chats").document(chatPartnerId)
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
        } catch (_: Exception) { }
    }

    // MARK: - Widget Helpers

    private fun updateWidgetData(
        imageUrl: String,
        cityName: String? = null,
        photoLat: Double? = null,
        photoLon: Double? = null
    ) {
        try {
            val prefs = appContext.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            prefs.edit().apply {
                putString("widget_image_url", imageUrl)
                if (cityName != null) putString("widget_city_name", cityName) else remove("widget_city_name")
                if (photoLat != null) putFloat("widget_photo_lat", photoLat.toFloat()) else remove("widget_photo_lat")
                if (photoLon != null) putFloat("widget_photo_lon", photoLon.toFloat()) else remove("widget_photo_lon")
                apply()
            }

            // Trigger widget update
            val intent = Intent(appContext, StripMateWidgetReceiver::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                val widgetManager = AppWidgetManager.getInstance(appContext)
                val ids = widgetManager.getAppWidgetIds(
                    ComponentName(appContext, StripMateWidgetReceiver::class.java)
                )
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            appContext.sendBroadcast(intent)
        } catch (_: Exception) { }
    }

    // MARK: - Private Helpers

    private fun resizeBitmap(bitmap: Bitmap, maxDimension: Int): Bitmap {
        val width = bitmap.width
        val height = bitmap.height

        if (width <= maxDimension && height <= maxDimension) return bitmap

        val ratio = width.toFloat() / height.toFloat()
        val newWidth: Int
        val newHeight: Int

        if (width > height) {
            newWidth = maxDimension
            newHeight = (maxDimension / ratio).toInt()
        } else {
            newHeight = maxDimension
            newWidth = (maxDimension * ratio).toInt()
        }

        return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
    }
}
