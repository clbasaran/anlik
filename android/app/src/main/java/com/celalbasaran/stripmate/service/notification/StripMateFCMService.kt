package com.celalbasaran.stripmate.service.notification

import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import com.celalbasaran.stripmate.MainActivity
import com.celalbasaran.stripmate.R
import com.celalbasaran.stripmate.widget.StripMateWidgetReceiver
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.net.URL

class StripMateFCMService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "StripMateFCM"
        private const val KEY_TEXT_REPLY = "key_text_reply"
        private const val CHANNEL_PHOTO = "stripmate_photo"
        private const val CHANNEL_CHAT = "stripmate_chat"
        private const val CHANNEL_FRIEND = "stripmate_friend"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM token: ${token.take(20)}...")
        saveFCMToken(token)
    }

    private fun saveFCMToken(token: String) {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        // Save to both locations for compatibility
        val db = FirebaseFirestore.getInstance()
        db.collection("users").document(uid)
            .collection("private").document("tokens")
            .set(mapOf("fcmToken" to token, "platform" to "android"), SetOptions.merge())
        // Also save at user document level
        db.collection("users").document(uid)
            .update(mapOf("fcmToken" to token, "platform" to "android"))
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        Log.d(TAG, "Message received: ${message.data}")

        val data = message.data
        val type = data["type"] ?: return
        val senderName = data["senderName"] ?: "StripMate"
        val relatedId = data["relatedId"] ?: data["stripId"]
        val senderId = data["senderId"]

        when (type) {
            "new_strip" -> {
                val isSecret = data["isSecret"] == "true"
                // Secret moments must NOT include image in notification (privacy)
                showStripNotification(senderName, relatedId, if (isSecret) null else data["imageUrl"])
                // Widget should not show secret photo
                if (!isSecret) {
                    updateWidgetFromPush(data)
                }
            }
            "direct_message" -> showChatNotification(senderName, senderId, data["messageText"])
            "new_strip_chat" -> showStripChatNotification(senderName, relatedId, data["messageText"])
            "friend_request" -> showFriendRequestNotification(senderName, senderId)
            "new_comment" -> showCommentNotification(senderName, relatedId)
            "support_reply" -> showSupportReplyNotification(data["messageText"])
            "nudge" -> showNudgeNotification(senderName, senderId)
        }
    }

    private fun updateWidgetFromPush(data: Map<String, String>) {
        scope.launch {
            try {
                val imageUrl = data["smallThumbnailUrl"]?.takeIf { it.isNotEmpty() }
                    ?: data["thumbnailUrl"]?.takeIf { it.isNotEmpty() }
                    ?: data["imageUrl"]?.takeIf { it.isNotEmpty() }
                    ?: return@launch

                val cityName = data["cityName"]?.takeIf { it.isNotEmpty() }
                val lat = data["latitude"]?.toFloatOrNull() ?: 0f
                val lon = data["longitude"]?.toFloatOrNull() ?: 0f

                // Check widget filter preference
                val prefs = getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
                val filterFriendId = prefs.getString("widget_filter_friend_id", null)
                val senderId = data["senderId"]

                // If filtered to specific friend, only update if sender matches
                if (filterFriendId != null && senderId != filterFriendId) {
                    Log.d(TAG, "Widget filtered to different friend, skipping")
                    return@launch
                }

                // Download image FIRST, only update prefs if successful
                var bmp: android.graphics.Bitmap? = null
                try {
                    val connection = URL(imageUrl).openConnection()
                    connection.connectTimeout = 15000
                    connection.readTimeout = 15000
                    val input = connection.getInputStream()
                    bmp = BitmapFactory.decodeStream(input)
                    input.close()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to download widget image", e)
                }

                if (bmp != null) {
                    // Save to cache file
                    val cacheFile = java.io.File(cacheDir, "widget_image.jpg")
                    cacheFile.outputStream().use { out ->
                        bmp.compress(android.graphics.Bitmap.CompressFormat.JPEG, 85, out)
                    }
                    bmp.recycle()

                    // Now update prefs with new data
                    prefs.edit().apply {
                        putString("widget_image_url", imageUrl)
                        putString("widget_cached_url", imageUrl)
                        if (cityName != null) putString("widget_city_name", cityName) else remove("widget_city_name")
                        putFloat("widget_photo_lat", lat)
                        putFloat("widget_photo_lon", lon)
                        apply()
                    }
                    Log.d(TAG, "Widget image cached successfully")
                } else {
                    // Image download failed - still save URL so it can retry later
                    prefs.edit().apply {
                        putString("widget_image_url", imageUrl)
                        if (cityName != null) putString("widget_city_name", cityName) else remove("widget_city_name")
                        apply()
                    }
                    Log.w(TAG, "Widget image download failed, saved URL for later")
                }

                // Directly update all widget instances
                val appWidgetManager = AppWidgetManager.getInstance(this@StripMateFCMService)
                val widgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(this@StripMateFCMService, StripMateWidgetReceiver::class.java)
                )

                if (widgetIds.isNotEmpty()) {
                    // Build views and update directly
                    val views = StripMateWidgetReceiver.buildWidgetViews(this@StripMateFCMService)
                    for (id in widgetIds) {
                        appWidgetManager.updateAppWidget(id, views)
                    }
                    Log.d(TAG, "Widget updated from push (${widgetIds.size} widgets)")
                } else {
                    Log.d(TAG, "No widget instances found")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget from push", e)
            }
        }
    }

    private fun showStripNotification(senderName: String, stripId: String?, imageUrl: String?) {
        val intent = createDeepLinkIntent("strip", stripId)
        val pendingIntent = createPendingIntent(stripId.hashCode(), intent)

        val builder = NotificationCompat.Builder(this, CHANNEL_PHOTO)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Yeni Anlik!")
            .setContentText("$senderName sana bir anlik gonderdi")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        // Try to load image for rich notification (like iOS)
        if (imageUrl != null) {
            try {
                val url = URL(imageUrl)
                val connection = url.openConnection()
                connection.connectTimeout = 5000
                connection.readTimeout = 5000
                val input = connection.getInputStream()
                val bmp = BitmapFactory.decodeStream(input)
                input.close()

                if (bmp != null) {
                    builder.setStyle(
                        NotificationCompat.BigPictureStyle()
                            .bigPicture(bmp)
                            .bigLargeIcon(null as android.graphics.Bitmap?)
                    )
                    builder.setLargeIcon(bmp)
                }
            } catch (_: Exception) { }
        }

        getNotificationManager().notify(stripId.hashCode(), builder.build())
    }

    private fun showChatNotification(senderName: String, senderId: String?, messageText: String?) {
        val intent = createDeepLinkIntent("chat", senderId)
        val pendingIntent = createPendingIntent(2001, intent)

        // Inline reply support
        val remoteInput = RemoteInput.Builder(KEY_TEXT_REPLY)
            .setLabel("Yanit yaz...")
            .build()

        val replyIntent = createDeepLinkIntent("chat_reply", senderId)
        val replyPendingIntent = PendingIntent.getActivity(
            this,
            2002,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val replyAction = NotificationCompat.Action.Builder(
            R.drawable.ic_notification,
            "Yanit",
            replyPendingIntent
        )
            .addRemoteInput(remoteInput)
            .build()

        val notification = NotificationCompat.Builder(this, CHANNEL_CHAT)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(senderName)
            .setContentText(messageText ?: "Yeni mesaj")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .addAction(replyAction)
            .build()

        getNotificationManager().notify(senderId.hashCode(), notification)
    }

    private fun showStripChatNotification(senderName: String, stripId: String?, messageText: String?) {
        val intent = createDeepLinkIntent("strip_chat", stripId)
        val pendingIntent = createPendingIntent(3001, intent)

        val notification = NotificationCompat.Builder(this, CHANNEL_CHAT)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("$senderName yorumladi")
            .setContentText(messageText ?: "Yeni yorum")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        getNotificationManager().notify(stripId.hashCode() + 1000, notification)
    }

    private fun showFriendRequestNotification(senderName: String, senderId: String?) {
        val intent = createDeepLinkIntent("friend_request", senderId)
        val pendingIntent = createPendingIntent(4001, intent)

        val notification = NotificationCompat.Builder(this, CHANNEL_FRIEND)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Arkadaşlık İsteği")
            .setContentText("$senderName sana arkadaşlık isteği gönderdi")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        getNotificationManager().notify(senderId.hashCode() + 2000, notification)
    }

    private fun showSupportReplyNotification(messageText: String?) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("deeplink_destination", "support_chat")
        }
        val pendingIntent = createPendingIntent(6001, intent)

        val notification = NotificationCompat.Builder(this, CHANNEL_CHAT)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("anlık. destek")
            .setContentText(messageText ?: "Destek ekibinden yeni mesaj")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        getNotificationManager().notify(6001, notification)
    }

    private fun showCommentNotification(senderName: String, stripId: String?) {
        val intent = createDeepLinkIntent("comment", stripId)
        val pendingIntent = createPendingIntent(5001, intent)

        val notification = NotificationCompat.Builder(this, CHANNEL_CHAT)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Yeni Yorum")
            .setContentText("$senderName bir yorum birakti")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        getNotificationManager().notify(stripId.hashCode() + 3000, notification)
    }

    private fun showNudgeNotification(senderName: String, senderId: String?) {
        val intent = createDeepLinkIntent("nudge", senderId)
        val pendingIntent = createPendingIntent(7001, intent)

        val notification = NotificationCompat.Builder(this, CHANNEL_FRIEND)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("anlık.")
            .setContentText("$senderName seni dürtü! \uD83D\uDCF8")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        getNotificationManager().notify((senderId ?: "nudge").hashCode() + 4000, notification)
    }

    private fun createDeepLinkIntent(destination: String, id: String?): Intent {
        return Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("deeplink_destination", destination)
            id?.let { putExtra("deeplink_id", it) }
        }
    }

    private fun createPendingIntent(requestCode: Int, intent: Intent): PendingIntent {
        return PendingIntent.getActivity(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun getNotificationManager(): NotificationManager {
        return getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    }
}
