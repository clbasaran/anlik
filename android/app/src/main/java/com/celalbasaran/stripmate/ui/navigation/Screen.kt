package com.celalbasaran.stripmate.ui.navigation

sealed class Screen(val route: String) {
    // Auth
    data object Login : Screen("login")
    data object Signup : Screen("signup")
    data object Onboarding : Screen("onboarding")
    data object AppTour : Screen("app_tour")
    data object ProfileCompletion : Screen("profile_completion")
    data object FriendGate : Screen("friend_gate")
    data object Consent : Screen("consent")

    // Main (bottom nav tabs)
    data object Main : Screen("main")
    data object Friends : Screen("friends")
    data object Camera : Screen("camera")
    data object History : Screen("history")

    // Detail screens
    data object PhotoDetail : Screen("photo_detail/{stripId}") {
        fun createRoute(stripId: String): String = "photo_detail/$stripId"
    }

    data object DirectMessage : Screen("direct_message/{userId}") {
        fun createRoute(userId: String): String = "direct_message/$userId"
    }

    data object FriendProfile : Screen("friend_profile/{userId}") {
        fun createRoute(userId: String): String = "friend_profile/$userId"
    }

    data object EditProfile : Screen("edit_profile")
    data object Settings : Screen("settings")
    data object Leaderboard : Screen("leaderboard")
    data object Achievements : Screen("achievements")
    data object QRCode : Screen("qr_code")
    data object QRScanner : Screen("qr_scanner")
    data object Notifications : Screen("notifications")
    data object BlockedUsers : Screen("blocked_users")
    data object About : Screen("about")
    data object PrivacyPolicy : Screen("privacy_policy")
    data object TermsOfService : Screen("terms_of_service")

    data object ReceiverSelection : Screen("receiver_selection")
    data object PhotoPreview : Screen("photo_preview")
    data object DailyPrompt : Screen("daily_prompt")
    data object DrawingOverlay : Screen("drawing_overlay")

    data object StreakDetail : Screen("streak_detail/{userId}") {
        fun createRoute(userId: String): String = "streak_detail/$userId"
    }

    data object StreakCelebration : Screen("streak_celebration/{userId}/{count}") {
        fun createRoute(userId: String, count: Int): String = "streak_celebration/$userId/$count"
    }

    // Settings sub-screens
    data object NotificationSettings : Screen("notification_settings")
    data object PrivacySettings : Screen("privacy_settings")
    data object StorageSettings : Screen("storage_settings")
    data object AppearanceSettings : Screen("appearance_settings")
    data object Support : Screen("support")
    data object WidgetSettings : Screen("widget_settings")
    data object LegalDocument : Screen("legal_document/{type}") {
        fun createRoute(type: String): String = "legal_document/$type"
    }
}

enum class BottomNavTab(val route: String, val label: String, val icon: String) {
    FRIENDS(Screen.Friends.route, "Arkadaşlar", "group"),
    CAMERA(Screen.Camera.route, "Kamera", "camera"),
    HISTORY(Screen.History.route, "Geçmiş", "history")
}
