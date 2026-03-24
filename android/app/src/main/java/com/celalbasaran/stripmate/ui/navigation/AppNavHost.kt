package com.celalbasaran.stripmate.ui.navigation

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntOffset
import kotlin.math.abs
import kotlin.math.roundToInt
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import kotlinx.coroutines.launch
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Group
import androidx.compose.material.icons.outlined.History
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.ui.screen.auth.AuthViewModel
import com.celalbasaran.stripmate.ui.screen.auth.AppTourScreen
import com.celalbasaran.stripmate.ui.screen.auth.FriendGateScreen
import com.celalbasaran.stripmate.ui.screen.auth.LoginScreen
import com.celalbasaran.stripmate.ui.screen.auth.OnboardingScreen
import com.celalbasaran.stripmate.ui.screen.auth.ProfileCompletionScreen
import com.celalbasaran.stripmate.ui.screen.auth.SignupScreen
import com.celalbasaran.stripmate.ui.screen.appearance.AppearanceSettingsScreen
import com.celalbasaran.stripmate.ui.screen.camera.CameraScreen
import com.celalbasaran.stripmate.ui.screen.camera.DrawingOverlayScreen
import com.celalbasaran.stripmate.ui.screen.camera.PhotoPreviewScreen
import com.celalbasaran.stripmate.ui.screen.camera.ReceiverSelectionScreen
import com.celalbasaran.stripmate.ui.screen.chat.DirectMessageScreen
import com.celalbasaran.stripmate.ui.screen.consent.ConsentScreen
import com.celalbasaran.stripmate.ui.screen.daily.DailyPromptScreen
import com.celalbasaran.stripmate.ui.screen.friends.AchievementScreen
import com.celalbasaran.stripmate.ui.screen.friends.FriendsScreen
import com.celalbasaran.stripmate.ui.screen.friends.LeaderboardScreen
import com.celalbasaran.stripmate.ui.screen.history.HistoryScreen
import com.celalbasaran.stripmate.ui.screen.history.PhotoDetailScreen
import com.celalbasaran.stripmate.ui.screen.legal.AboutScreen
import com.celalbasaran.stripmate.ui.screen.legal.LegalDocumentScreen
import com.celalbasaran.stripmate.ui.screen.legal.LegalTexts
import com.celalbasaran.stripmate.ui.screen.notifications.NotificationsScreen
import com.celalbasaran.stripmate.ui.screen.privacy.BlockedUsersScreen
import com.celalbasaran.stripmate.ui.screen.privacy.PrivacySettingsScreen
import com.celalbasaran.stripmate.ui.screen.profile.EditProfileScreen
import com.celalbasaran.stripmate.ui.screen.profile.FriendProfileScreen
import com.celalbasaran.stripmate.ui.screen.qr.QRCodeScreen
import com.celalbasaran.stripmate.ui.screen.qr.QRScannerScreen
import com.celalbasaran.stripmate.ui.screen.settings.NotificationSettingsScreen
import com.celalbasaran.stripmate.ui.screen.settings.SettingsScreen
import com.celalbasaran.stripmate.ui.screen.storage.StorageSettingsScreen
import com.celalbasaran.stripmate.ui.screen.streak.StreakCelebrationScreen
import com.celalbasaran.stripmate.ui.screen.streak.StreakDetailScreen
import com.celalbasaran.stripmate.ui.screen.support.SupportScreen
import com.celalbasaran.stripmate.ui.screen.widget.WidgetSettingsScreen
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextSecondary

private data class BottomNavItem(
    val screen: Screen,
    val label: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
)

private val bottomNavItems = listOf(
    BottomNavItem(Screen.Friends, "Arkadaşlar", Icons.Filled.Group, Icons.Outlined.Group),
    BottomNavItem(Screen.Camera, "Kamera", Icons.Filled.CameraAlt, Icons.Outlined.CameraAlt),
    BottomNavItem(Screen.History, "Geçmiş", Icons.Filled.History, Icons.Outlined.History)
)

private const val TRANSITION_DURATION = 300

@Composable
fun AppNavHost(
    isAuthenticated: Boolean,
    hasCompletedOnboarding: Boolean,
    navController: NavHostController = rememberNavController()
) {
    val startDestination = when {
        !hasCompletedOnboarding -> Screen.Onboarding.route
        !isAuthenticated -> Screen.Login.route
        else -> Screen.Main.route
    }

    NavHost(
        navController = navController,
        startDestination = startDestination,
        enterTransition = {
            fadeIn(animationSpec = tween(TRANSITION_DURATION))
        },
        exitTransition = {
            fadeOut(animationSpec = tween(TRANSITION_DURATION))
        }
    ) {
        // Auth flow
        composable(Screen.Login.route) {
            val context = androidx.compose.ui.platform.LocalContext.current
            val authViewModel: AuthViewModel = hiltViewModel()
            val coroutineScope = rememberCoroutineScope()
            LoginScreen(
                viewModel = authViewModel,
                onNavigateToSignup = { navController.navigate(Screen.Signup.route) },
                onGoogleSignIn = {
                    coroutineScope.launch {
                        try {
                            val credentialManager = androidx.credentials.CredentialManager.create(context)
                            val googleIdOption = com.google.android.libraries.identity.googleid.GetGoogleIdOption.Builder()
                                .setFilterByAuthorizedAccounts(false)
                                .setServerClientId("854219960693-rdoeflpkpg1ogkapeaqd48jc3vqihapq.apps.googleusercontent.com")
                                .build()
                            val request = androidx.credentials.GetCredentialRequest.Builder()
                                .addCredentialOption(googleIdOption)
                                .build()
                            val result = credentialManager.getCredential(context as android.app.Activity, request)
                            val credential = result.credential
                            val googleIdTokenCredential = com.google.android.libraries.identity.googleid.GoogleIdTokenCredential.createFrom(credential.data)
                            authViewModel.signInWithGoogle(googleIdTokenCredential.idToken)
                        } catch (e: Exception) {
                            android.util.Log.e("GoogleSignIn", "Failed", e)
                        }
                    }
                },
                onLoginSuccess = {
                    val prefs = context.getSharedPreferences("stripmate_prefs", android.content.Context.MODE_PRIVATE)
                    val dest = if (!prefs.getBoolean("hasSeenAppTour", false)) Screen.AppTour.route else Screen.Main.route
                    navController.navigate(dest) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                }
            )
        }
        composable(Screen.Signup.route) {
            val context = androidx.compose.ui.platform.LocalContext.current
            val authViewModel: AuthViewModel = hiltViewModel()
            SignupScreen(
                viewModel = authViewModel,
                onNavigateToLogin = { navController.popBackStack() },
                onSignupSuccess = {
                    navController.navigate(Screen.AppTour.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                }
            )
        }
        composable(Screen.Onboarding.route) {
            val context = androidx.compose.ui.platform.LocalContext.current
            OnboardingScreen(
                onComplete = {
                    context.getSharedPreferences("stripmate_prefs", android.content.Context.MODE_PRIVATE)
                        .edit().putBoolean("hasSeenOnboarding", true).apply()
                    navController.navigate(Screen.Login.route) {
                        popUpTo(Screen.Onboarding.route) { inclusive = true }
                    }
                }
            )
        }
        composable(Screen.AppTour.route) {
            val context = androidx.compose.ui.platform.LocalContext.current
            AppTourScreen(
                onComplete = {
                    context.getSharedPreferences("stripmate_prefs", android.content.Context.MODE_PRIVATE)
                        .edit().putBoolean("hasSeenAppTour", true).apply()
                    navController.navigate(Screen.Main.route) {
                        popUpTo(Screen.AppTour.route) { inclusive = true }
                    }
                }
            )
        }
        composable(Screen.ProfileCompletion.route) {
            val authViewModel: AuthViewModel = hiltViewModel()
            ProfileCompletionScreen(
                viewModel = authViewModel,
                onComplete = {
                    navController.navigate(Screen.Main.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                }
            )
        }
        composable(Screen.FriendGate.route) {
            val authViewModel: AuthViewModel = hiltViewModel()
            FriendGateScreen(
                viewModel = authViewModel,
                onGatePassed = {
                    navController.navigate(Screen.Main.route) {
                        popUpTo(Screen.Login.route) { inclusive = true }
                    }
                }
            )
        }
        composable(Screen.Consent.route) {
            ConsentScreen(
                onAcceptAll = {
                    navController.navigate(Screen.Signup.route) {
                        popUpTo(Screen.Consent.route) { inclusive = true }
                    }
                },
                onReadDocument = { type ->
                    navController.navigate(Screen.LegalDocument.createRoute(type))
                }
            )
        }

        // Main screen with bottom navigation
        composable(Screen.Main.route) {
            MainScreen(navController = navController)
        }

        // Detail screens
        composable(
            route = Screen.PhotoDetail.route,
            arguments = listOf(navArgument("stripId") { type = NavType.StringType })
        ) { backStackEntry ->
            val stripId = backStackEntry.arguments?.getString("stripId") ?: ""
            PhotoDetailScreen(
                stripId = stripId,
                onBack = { navController.popBackStack() },
                onReceiverClick = { userId ->
                    navController.navigate(Screen.DirectMessage.createRoute(userId))
                }
            )
        }

        composable(
            route = Screen.DirectMessage.route,
            arguments = listOf(navArgument("userId") { type = NavType.StringType })
        ) {
            DirectMessageScreen(
                onBack = { navController.popBackStack() },
                onProfileClick = { userId ->
                    navController.navigate(Screen.FriendProfile.createRoute(userId))
                }
            )
        }

        composable(
            route = Screen.FriendProfile.route,
            arguments = listOf(navArgument("userId") { type = NavType.StringType })
        ) { backStackEntry ->
            val userId = backStackEntry.arguments?.getString("userId") ?: ""
            FriendProfileScreen(
                userId = userId,
                onBack = { navController.popBackStack() },
                onMessage = { uid ->
                    navController.navigate(Screen.DirectMessage.createRoute(uid))
                },
                onPhotoClick = { photoId ->
                    navController.navigate(Screen.PhotoDetail.createRoute(photoId))
                }
            )
        }

        composable(
            route = Screen.StreakDetail.route,
            arguments = listOf(navArgument("userId") { type = NavType.StringType })
        ) {
            StreakDetailScreen(
                onBack = { navController.popBackStack() },
                onMessage = { userId ->
                    navController.navigate(Screen.DirectMessage.createRoute(userId))
                }
            )
        }

        composable(
            route = Screen.StreakCelebration.route,
            arguments = listOf(
                navArgument("userId") { type = NavType.StringType },
                navArgument("count") { type = NavType.IntType }
            )
        ) { backStackEntry ->
            val count = backStackEntry.arguments?.getInt("count") ?: 0
            val userId = backStackEntry.arguments?.getString("userId") ?: ""
            StreakCelebrationScreen(
                streakCount = count,
                friendName = userId,
                onDismiss = { navController.popBackStack() }
            )
        }

        // Settings & Profile
        composable(Screen.EditProfile.route) {
            EditProfileScreen(
                onBack = { navController.popBackStack() }
            )
        }
        composable(Screen.Settings.route) {
            SettingsScreen(
                onBack = { navController.popBackStack() },
                onEditProfile = { navController.navigate(Screen.EditProfile.route) },
                onNotificationSettings = { navController.navigate(Screen.NotificationSettings.route) },
                onPrivacySettings = { navController.navigate(Screen.PrivacySettings.route) },
                onAppearanceSettings = { navController.navigate(Screen.AppearanceSettings.route) },
                onWidgetSettings = { navController.navigate(Screen.WidgetSettings.route) },
                onStorageSettings = { navController.navigate(Screen.StorageSettings.route) },
                onSupport = { navController.navigate(Screen.Support.route) },
                onAbout = { navController.navigate(Screen.About.route) },
                onBlockedUsers = { navController.navigate(Screen.BlockedUsers.route) },
                onPrivacyPolicy = { navController.navigate(Screen.PrivacyPolicy.route) },
                onTermsOfService = { navController.navigate(Screen.TermsOfService.route) },
                onLoggedOut = {
                    navController.navigate(Screen.Login.route) {
                        popUpTo(0) { inclusive = true }
                    }
                }
            )
        }
        composable(Screen.Leaderboard.route) {
            LeaderboardScreen(onBack = { navController.popBackStack() })
        }
        composable(Screen.Achievements.route) {
            AchievementScreen(onBack = { navController.popBackStack() })
        }

        // QR
        composable(Screen.QRCode.route) {
            QRCodeScreen(
                onBack = { navController.popBackStack() }
            )
        }
        composable(Screen.QRScanner.route) {
            QRScannerScreen(
                onBack = { navController.popBackStack() },
                onCodeScanned = { code ->
                    navController.popBackStack()
                }
            )
        }

        // Notifications
        composable(Screen.Notifications.route) {
            NotificationsScreen(
                onBack = { navController.popBackStack() },
                onPhotoClick = { stripId ->
                    navController.navigate(Screen.PhotoDetail.createRoute(stripId))
                },
                onFriendsClick = {
                    navController.popBackStack()
                }
            )
        }

        // Blocked users
        composable(Screen.BlockedUsers.route) {
            BlockedUsersScreen(
                onBack = { navController.popBackStack() }
            )
        }

        // About
        composable(Screen.About.route) {
            AboutScreen(
                onBack = { navController.popBackStack() },
                onPrivacyPolicy = { navController.navigate(Screen.PrivacyPolicy.route) },
                onTermsOfService = { navController.navigate(Screen.TermsOfService.route) }
            )
        }

        // Legal documents
        composable(Screen.PrivacyPolicy.route) {
            LegalDocumentScreen(
                title = "Gizlilik Politikası",
                content = LegalTexts.privacyPolicy,
                onBack = { navController.popBackStack() }
            )
        }
        composable(Screen.TermsOfService.route) {
            LegalDocumentScreen(
                title = "Kullanim Kosullari",
                content = LegalTexts.termsOfService,
                onBack = { navController.popBackStack() }
            )
        }
        composable(
            route = Screen.LegalDocument.route,
            arguments = listOf(navArgument("type") { type = NavType.StringType })
        ) { backStackEntry ->
            val type = backStackEntry.arguments?.getString("type") ?: "terms"
            val (title, content) = when (type) {
                "privacy" -> "Gizlilik Politikası" to LegalTexts.privacyPolicy
                "kvkk" -> "KVKK Aydinlatma Metni" to LegalTexts.privacyPolicy
                "eula" -> "EULA" to LegalTexts.termsOfService
                else -> "Kullanim Kosullari" to LegalTexts.termsOfService
            }
            LegalDocumentScreen(
                title = title,
                content = content,
                onBack = { navController.popBackStack() }
            )
        }

        // Camera flow
        composable(Screen.ReceiverSelection.route) {
            ReceiverSelectionScreen(
                onBack = { navController.popBackStack() },
                onSend = { selectedIds ->
                    navController.popBackStack()
                }
            )
        }
        composable(Screen.PhotoPreview.route) {
            PhotoPreviewScreen(
                onBack = { navController.popBackStack() },
                onSend = { navController.popBackStack() },
                onDraw = { navController.navigate(Screen.DrawingOverlay.route) }
            )
        }
        composable(Screen.DrawingOverlay.route) {
            DrawingOverlayScreen(
                onDone = { navController.popBackStack() },
                onCancel = { navController.popBackStack() }
            )
        }
        composable(Screen.DailyPrompt.route) {
            DailyPromptScreen(
                onBack = { navController.popBackStack() },
                onTakePhoto = {
                    navController.popBackStack()
                }
            )
        }

        // Settings sub-screens
        composable(Screen.NotificationSettings.route) {
            NotificationSettingsScreen(
                onBack = { navController.popBackStack() }
            )
        }
        composable(Screen.PrivacySettings.route) {
            PrivacySettingsScreen(
                onBack = { navController.popBackStack() },
                onBlockedUsers = { navController.navigate(Screen.BlockedUsers.route) }
            )
        }
        composable(Screen.StorageSettings.route) {
            StorageSettingsScreen(
                onBack = { navController.popBackStack() }
            )
        }
        composable(Screen.AppearanceSettings.route) {
            AppearanceSettingsScreen(
                onBack = { navController.popBackStack() }
            )
        }
        composable(Screen.Support.route) {
            SupportScreen(
                onBack = { navController.popBackStack() }
            )
        }
        composable(Screen.WidgetSettings.route) {
            WidgetSettingsScreen(
                onBack = { navController.popBackStack() }
            )
        }
    }
}

@Composable
private fun MainScreen(navController: NavHostController) {
    var selectedTab by rememberSaveable { mutableIntStateOf(1) } // Start on Camera like iOS
    val coroutineScope = rememberCoroutineScope()
    val dragOffset = remember { Animatable(0f) }
    var isCameraPreviewMode by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        val innerPadding = PaddingValues(0.dp)
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .pointerInput(selectedTab, isCameraPreviewMode) {
                    if (isCameraPreviewMode) return@pointerInput
                    val pageWidth = size.width.toFloat()
                    val threshold = pageWidth * 0.2f
                    detectHorizontalDragGestures(
                        onDragEnd = {
                            val current = dragOffset.value
                            coroutineScope.launch {
                                if (current < -threshold && selectedTab < 2) {
                                    selectedTab++
                                    dragOffset.snapTo(0f)
                                } else if (current > threshold && selectedTab > 0) {
                                    selectedTab--
                                    dragOffset.snapTo(0f)
                                } else {
                                    dragOffset.animateTo(
                                        0f,
                                        animationSpec = spring<Float>(
                                            dampingRatio = 0.7f,
                                            stiffness = 300f
                                        )
                                    )
                                }
                            }
                        },
                        onDragCancel = {
                            coroutineScope.launch { dragOffset.animateTo(0f) }
                        },
                        onHorizontalDrag = { _, dragAmount ->
                            val newOffset = dragOffset.value + dragAmount
                            // Edge resistance like iOS (0.2x at edges)
                            val isAtEdge = (selectedTab == 0 && newOffset > 0) ||
                                    (selectedTab == 2 && newOffset < 0)
                            val applied = if (isAtEdge) {
                                dragOffset.value + dragAmount * 0.2f
                            } else {
                                newOffset
                            }
                            coroutineScope.launch { dragOffset.snapTo(applied) }
                        }
                    )
                }
        ) {
            val pageWidthPx = constraints.maxWidth.toFloat()
            val offsetPx = dragOffset.value
            val isDragging = offsetPx != 0f

            // Single clipped container that slides all content together
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clipToBounds()
            ) {
                for (tabIndex in 0..2) {
                    val tabOffsetPx = ((tabIndex - selectedTab) * pageWidthPx + offsetPx).roundToInt()

                    // Only compose if current tab or adjacent during drag
                    if (tabIndex == selectedTab || (isDragging && abs(tabIndex - selectedTab) == 1)) {
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .offset { IntOffset(tabOffsetPx, 0) }
                        ) {
                            when (tabIndex) {
                                0 -> FriendsScreen(
                                    onFriendClick = { userId ->
                                        navController.navigate(Screen.DirectMessage.createRoute(userId))
                                    },
                                    onQRClick = { navController.navigate(Screen.QRCode.route) },
                                    onInboxClick = { navController.navigate(Screen.Notifications.route) }
                                )
                                1 -> CameraScreen(
                                    onNavigateToSettings = {
                                        navController.navigate(Screen.Settings.route)
                                    },
                                    onPreviewStateChange = { isPreview ->
                                        isCameraPreviewMode = isPreview
                                    }
                                )
                                2 -> HistoryScreen(
                                    onPhotoClick = { photoId ->
                                        navController.navigate(Screen.PhotoDetail.createRoute(photoId))
                                    },
                                    onNotificationsClick = {
                                        navController.navigate(Screen.Notifications.route)
                                    }
                                )
                        }
                    }
                }
            }
        }
        }

        // Floating pill tab bar (iOS style) - hidden during photo preview/success
        if (!isCameraPreviewMode) Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(horizontal = 44.dp)
                .padding(bottom = 24.dp)
                .navigationBarsPadding()
                .background(
                    color = Color.Black.copy(alpha = 0.45f),
                    shape = RoundedCornerShape(50)
                )
                .border(
                    width = 0.5.dp,
                    color = Color.White.copy(alpha = 0.1f),
                    shape = RoundedCornerShape(50)
                )
                .padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            bottomNavItems.forEachIndexed { index, item ->
                val selected = selectedTab == index
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .weight(1f)
                        .clickable(
                            indication = null,
                            interactionSource = remember { MutableInteractionSource() }
                        ) {
                            coroutineScope.launch { dragOffset.animateTo(0f) }
                            selectedTab = index
                        }
                        .padding(vertical = 14.dp)
                ) {
                    Icon(
                        imageVector = if (selected) item.selectedIcon else item.unselectedIcon,
                        contentDescription = item.label,
                        tint = if (selected) Color.White else Color.White.copy(alpha = 0.35f),
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(modifier = Modifier.height(5.dp))
                    Box(
                        modifier = Modifier
                            .size(4.dp)
                            .background(
                                color = if (selected) Color.White else Color.Transparent,
                                shape = CircleShape
                            )
                    )
                }
            }
        }
    }
}
