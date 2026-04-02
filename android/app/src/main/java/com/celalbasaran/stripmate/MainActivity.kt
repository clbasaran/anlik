package com.celalbasaran.stripmate

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.ui.navigation.AppNavHost
import com.celalbasaran.stripmate.ui.screen.guard.BannedScreen
import com.celalbasaran.stripmate.ui.screen.guard.GuardState
import com.celalbasaran.stripmate.ui.screen.guard.GuardViewModel
import com.celalbasaran.stripmate.ui.screen.guard.MaintenanceScreen
import com.celalbasaran.stripmate.ui.screen.guard.SuspendedScreen
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateTheme
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.messaging.FirebaseMessaging
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    companion object {
        /** Pending deep link destination from notification tap (cold or warm start). */
        var pendingDeepLinkDestination: String? = null
        var pendingDeepLinkId: String? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Request notification permission (Android 13+)
        requestNotificationPermission()

        // Register FCM token
        registerFCMToken()

        // Handle deep link from notification tap (cold start)
        handleNotificationIntent(intent)

        setContent {
            StripMateTheme {
                val firebaseAuth = remember { FirebaseAuth.getInstance() }
                var isAuthenticated by remember {
                    mutableStateOf(firebaseAuth.currentUser != null)
                }

                // Reactively observe Firebase auth state changes
                DisposableEffect(firebaseAuth) {
                    val listener = FirebaseAuth.AuthStateListener { auth ->
                        isAuthenticated = auth.currentUser != null
                    }
                    firebaseAuth.addAuthStateListener(listener)
                    onDispose {
                        firebaseAuth.removeAuthStateListener(listener)
                    }
                }

                val prefs = remember {
                    getSharedPreferences("stripmate_prefs", MODE_PRIVATE)
                }
                val hasSeenOnboarding by remember {
                    mutableStateOf(prefs.getBoolean("hasSeenOnboarding", false))
                }

                // Guard check - only for authenticated users
                if (isAuthenticated) {
                    val guardViewModel: GuardViewModel = hiltViewModel()
                    val guardState by guardViewModel.guardState.collectAsState()

                    when (val state = guardState) {
                        is GuardState.Loading -> {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(PureBlack),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator()
                            }
                        }
                        is GuardState.Banned -> {
                            BannedScreen(reason = state.reason)
                        }
                        is GuardState.Suspended -> {
                            SuspendedScreen(until = state.until, reason = state.reason)
                        }
                        is GuardState.Maintenance -> {
                            MaintenanceScreen(message = state.message)
                        }
                        is GuardState.Clear -> {
                            Surface(modifier = Modifier.fillMaxSize()) {
                                AppNavHost(
                                    isAuthenticated = true,
                                    hasCompletedOnboarding = hasSeenOnboarding
                                )
                            }
                        }
                    }
                } else {
                    Surface(modifier = Modifier.fillMaxSize()) {
                        AppNavHost(
                            isAuthenticated = false,
                            hasCompletedOnboarding = hasSeenOnboarding
                        )
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
    }

    /**
     * Extracts deep link data from notification PendingIntent extras.
     * Maps notification types to navigation routes matching iOS behavior:
     *   - strip / comment -> PhotoDetail
     *   - chat -> DirectMessage
     *   - strip_chat -> PhotoDetail (with chat)
     *   - friend_request -> Notifications (inbox)
     */
    private fun handleNotificationIntent(intent: Intent?) {
        val destination = intent?.getStringExtra("deeplink_destination") ?: return
        val id = intent.getStringExtra("deeplink_id")

        pendingDeepLinkDestination = destination
        pendingDeepLinkId = id

        Log.d("StripMateDeepLink", "Deep link: destination=$destination, id=$id")

        // Clear the extras so we don't re-process on config change
        intent.removeExtra("deeplink_destination")
        intent.removeExtra("deeplink_id")
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
