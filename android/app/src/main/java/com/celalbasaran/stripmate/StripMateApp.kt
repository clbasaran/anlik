package com.celalbasaran.stripmate

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import com.google.firebase.FirebaseApp
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreSettings
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class StripMateApp : Application() {

    override fun onCreate() {
        super.onCreate()

        // Firebase
        FirebaseApp.initializeApp(this)

        // App Check
        FirebaseAppCheck.getInstance().installAppCheckProviderFactory(
            PlayIntegrityAppCheckProviderFactory.getInstance()
        )

        // Firestore offline cache (100MB)
        val settings = FirebaseFirestoreSettings.Builder()
            .setCacheSizeBytes(100 * 1024 * 1024)
            .build()
        FirebaseFirestore.getInstance().firestoreSettings = settings

        // Notification channels
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        val manager = getSystemService(NotificationManager::class.java)

        val channels = listOf(
            NotificationChannel("stripmate_default", "Genel", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Genel bildirimler"
            },
            NotificationChannel("stripmate_photo", "Yeni Anlik", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Yeni fotoğraf bildirimleri"
            },
            NotificationChannel("stripmate_chat", "Mesajlar", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Mesaj bildirimleri"
            },
            NotificationChannel("stripmate_friend", "Arkadaslik", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Arkadaslik istekleri"
            }
        )

        channels.forEach { manager.createNotificationChannel(it) }
    }
}
