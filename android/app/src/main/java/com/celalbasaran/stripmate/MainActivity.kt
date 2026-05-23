package com.celalbasaran.stripmate

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.service.invite.InviteRepository
import com.celalbasaran.stripmate.service.update.AppUpdateService
import com.celalbasaran.stripmate.ui.screen.update.AppUpdateOverlay
import com.celalbasaran.stripmate.ui.navigation.AppNavHost
import com.celalbasaran.stripmate.ui.screen.guard.BannedScreen
import com.celalbasaran.stripmate.ui.screen.guard.GuardState
import com.celalbasaran.stripmate.ui.screen.guard.GuardViewModel
import com.celalbasaran.stripmate.ui.screen.guard.MaintenanceScreen
import com.celalbasaran.stripmate.ui.screen.guard.SuspendedScreen
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateTheme
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import android.content.SharedPreferences
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.messaging.FirebaseMessaging
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    companion object {
        /** Pending deep link destination from notification tap (cold or warm start). */
        var pendingDeepLinkDestination: String? = null
        var pendingDeepLinkId: String? = null
    }

    /// Hilt injects the same EncryptedSharedPreferences that AppModule
    /// provides — keeps onboarding/widget flags consistent across the app.
    @Inject
    lateinit var securePrefs: SharedPreferences

    @Inject
    lateinit var inviteRepository: InviteRepository

    @Inject
    lateinit var appUpdateService: AppUpdateService

    private val firebaseAuth by lazy { FirebaseAuth.getInstance() }
    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) {
        syncPushPermissionState()
    }
    private val authStateListener = FirebaseAuth.AuthStateListener { auth ->
        if (auth.currentUser != null) {
            registerFCMToken()
            syncPushPermissionState()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Request notification permission (Android 13+)
        requestNotificationPermission()
        syncPushPermissionState()

        // Handle deep link from notification tap (cold start)
        handleNotificationIntent(intent)
        // Handle invite link from app/universal link or custom scheme
        handleInviteIntent(intent)

        setContent {
            StripMateTheme {
                // Self-hosted update overlay — visible across guard / nav host
                // states. Renders bottom sheet for soft updates, full screen for
                // forced updates, progress for ongoing downloads.
                AppUpdateOverlay()

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

                // Read onboarding flag from the same encrypted prefs that
                // AppModule provides — bypassing it would fall back to the
                // legacy plaintext file which is wiped after the migration.
                val hasSeenOnboarding by remember {
                    mutableStateOf(securePrefs.getBoolean("hasSeenOnboarding", false))
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

    override fun onStart() {
        super.onStart()
        firebaseAuth.addAuthStateListener(authStateListener)
        observeInviteEvents()
    }

    @OptIn(DelicateCoroutinesApi::class)
    private fun observeInviteEvents() {
        GlobalScope.launch(Dispatchers.Main) {
            inviteRepository.events.collect { event ->
                when (event) {
                    is InviteRepository.Event.InviteAccepted -> {
                        val msg = if (event.alreadyFriends) {
                            if (event.displayName.isNotEmpty())
                                "${event.displayName} ile zaten arkadaşsınız"
                            else
                                "zaten arkadaşsınız"
                        } else {
                            if (event.displayName.isNotEmpty())
                                "${event.displayName} ile arkadaş oldun"
                            else
                                "anlık.'a hoş geldin"
                        }
                        android.widget.Toast.makeText(
                            this@MainActivity,
                            msg,
                            android.widget.Toast.LENGTH_LONG
                        ).show()
                    }
                }
            }
        }
    }

    override fun onStop() {
        firebaseAuth.removeAuthStateListener(authStateListener)
        super.onStop()
    }

    override fun onResume() {
        super.onResume()
        syncPushPermissionState()
        // Self-hosted update check — refreshes whenever the user returns to the
        // app. Service handles its own dedup; this is safe to call repeatedly.
        GlobalScope.launch(Dispatchers.IO) {
            try { appUpdateService.checkForUpdates() } catch (_: Exception) {}
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
        handleInviteIntent(intent)
    }

    /**
     * Routes ACTION_VIEW intents that carry an invite URL (https://anlik.web.app/i/<CODE>
     * or stripmate://invite?code=<CODE>) through InviteRepository so the user
     * gets auto-friended with the inviter.
     *
     * Also runs an opportunistic clipboard check on every cold/warm start so a
     * deferred install (web landing page wrote payload before install) gets
     * picked up the moment the app is opened.
     */
    @OptIn(DelicateCoroutinesApi::class)
    private fun handleInviteIntent(intent: Intent?) {
        val data = intent?.data
        GlobalScope.launch(Dispatchers.IO) {
            try {
                if (data != null) inviteRepository.handleIncoming(data)
                inviteRepository.checkClipboardForDeferredInvite()
                inviteRepository.redeemPendingIfAny()
            } catch (e: Exception) {
                Log.w("StripMateInvite", "invite handling failed", e)
            }
        }
    }

    /**
     * Extracts deep link data from notification PendingIntent extras.
     * Maps notification types to navigation routes matching iOS behavior:
     *   - strip / comment -> PhotoDetail
     *   - chat -> DirectMessage
     *   - strip_chat -> PhotoDetail (with chat)
     *   - friend_request -> Notifications (inbox)
     */
    /**
     * Allowlist of destinations the notification system may navigate to. A
     * stray (or hostile) push payload landing here can otherwise direct the
     * app to anywhere the navigation graph reaches — including back-stack
     * configurations the user can't legitimately get to from the UI.
     */
    private val allowedDeepLinkDestinations = setOf(
        "photo_detail",
        "direct_message",
        "strip_chat",
        "inbox",
        "notifications",
        "friend_profile",
        "history",
        "recap"
    )

    private val deepLinkIdPattern = Regex("^[A-Za-z0-9_-]{1,128}$")

    private fun handleNotificationIntent(intent: Intent?) {
        val rawDestination = intent?.getStringExtra("deeplink_destination") ?: return
        val rawId = intent.getStringExtra("deeplink_id")

        // Reject destinations that aren't in the allowlist. Logging the raw
        // value (truncated) lets us see if a real push is using a name the
        // app version doesn't know about, vs. a garbage payload.
        if (rawDestination !in allowedDeepLinkDestinations) {
            Log.w("StripMateDeepLink", "Rejected unknown destination: ${rawDestination.take(32)}")
            intent.removeExtra("deeplink_destination")
            intent.removeExtra("deeplink_id")
            return
        }

        // Reject ids that don't look like Firestore document ids (alphanumeric
        // + underscore/hyphen, ≤128 chars). Anything else is either malformed
        // or an injection attempt; either way it can't reach the route.
        val safeId = rawId?.takeIf { deepLinkIdPattern.matches(it) }
        if (rawId != null && safeId == null) {
            Log.w("StripMateDeepLink", "Rejected malformed deeplink_id (len=${rawId.length})")
        }

        pendingDeepLinkDestination = rawDestination
        pendingDeepLinkId = safeId

        Log.d("StripMateDeepLink", "Deep link: destination=$rawDestination, id=$safeId")

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
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    private fun registerFCMToken() {
        val uid = firebaseAuth.currentUser?.uid ?: return
        FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
            Log.d("StripMateFCM", "FCM token obtained: ${token.take(20)}...")
            val db = FirebaseFirestore.getInstance()
            val tokenData = mapOf(
                "fcmToken" to token,
                "platform" to "android",
                "updatedAt" to FieldValue.serverTimestamp()
            )
            db.collection("users").document(uid)
                .collection("private").document("tokens")
                .set(tokenData, SetOptions.merge())
            db.collection("users").document(uid)
                .update("fcmToken", token)
        }
    }

    private fun syncPushPermissionState() {
        val uid = firebaseAuth.currentUser?.uid ?: return
        val notificationsEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            NotificationManagerCompat.from(this).areNotificationsEnabled()
        }

        FirebaseFirestore.getInstance()
            .collection("users")
            .document(uid)
            .update("notificationPreferences.push_enabled", notificationsEnabled)
            .addOnFailureListener { error ->
                Log.w("StripMateFCM", "Failed to sync push_enabled: ${error.message}")
            }
    }
}
