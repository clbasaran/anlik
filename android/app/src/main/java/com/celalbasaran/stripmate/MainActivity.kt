package com.celalbasaran.stripmate

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.celalbasaran.stripmate.ui.navigation.AppNavHost
import com.celalbasaran.stripmate.ui.theme.StripMateTheme
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.messaging.FirebaseMessaging
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Request notification permission (Android 13+)
        requestNotificationPermission()

        // Register FCM token
        registerFCMToken()

        setContent {
            StripMateTheme {
                val isAuthenticated by remember {
                    mutableStateOf(FirebaseAuth.getInstance().currentUser != null)
                }
                val prefs = remember {
                    getSharedPreferences("stripmate_prefs", MODE_PRIVATE)
                }
                val hasSeenOnboarding by remember {
                    mutableStateOf(prefs.getBoolean("hasSeenOnboarding", false))
                }
                Surface(modifier = Modifier.fillMaxSize()) {
                    AppNavHost(
                        isAuthenticated = isAuthenticated,
                        hasCompletedOnboarding = hasSeenOnboarding
                    )
                }
            }
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    1001
                )
            }
        }
    }

    private fun registerFCMToken() {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
            Log.d("StripMateFCM", "FCM token obtained: ${token.take(20)}...")
            val db = FirebaseFirestore.getInstance()
            val tokenData = mapOf("fcmToken" to token, "platform" to "android")
            db.collection("users").document(uid)
                .collection("private").document("tokens")
                .set(tokenData, SetOptions.merge())
            db.collection("users").document(uid)
                .update(tokenData as Map<String, Any>)
        }
    }
}
