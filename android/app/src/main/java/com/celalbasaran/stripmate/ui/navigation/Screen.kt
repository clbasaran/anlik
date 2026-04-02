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

    data object SharedMoments : Screen("shared_moments/{userId}") {
        fun createRoute(userId: String): String = "shared_moments/$userId"
    }

    data object StreakDetail : Screen("streak_detail/{userId}") {
        fun createRoute(userId: String): String = "streak_detail/$userId"
    }

    data object StreakCelebration : Screen("streak_celebration/{friendName}/{count}") {
        fun createRoute(friendName: String, count: Int): String =
            "streak_celebration/${java.net.URLEncoder.encode(friendName, "UTF-8")}/$count"
    }

    // Settings sub-screens
    data object NotificationSettings : Screen("notification_settings")
    data object PrivacySettings : Screen("privacy_settings")
    data object StorageSettings : Screen("storage_settings")
    data object AppearanceSettings : Screen("appearance_settings")
    data object Support : Screen("support")
    data object SupportChat : Screen("support_chat")
    data object WidgetSettings : Screen("widget_settings")
    data object ContactSync : Screen("contact_sync")

    // Recap screens
    data object Summaries : Screen("summaries")
    data object WeeklyRecap : Screen("weekly_recap/{weekId}") {
        fun createRoute(weekId: String): String = "weekly_recap/$weekId"
    }
    data object MonthlyRecap : Screen("monthly_recap/{monthId}") {
        fun createRoute(monthId: String): String = "monthly_recap/$monthId"
    }

    data object LegalDocument : Screen("legal_document/{type}") {
        fun createRoute(type: String): String = "legal_document/$type"
    }

    // Feature: Collage
    data object Collage : Screen("collage")

    // Feature: Friendship Profile
    data object FriendshipProfile : Screen("friendship_profile/{userId}") {
        fun createRoute(userId: String): String = "friendship_profile/$userId"
    }

}

enum class BottomNavTab(val route: String, val label: String, val icon: String) {
    FRIENDS(Screen.Friends.route, "Arkadaşlar", "group"),
    CAMERA(Screen.Camera.route, "Kamera", "camera"),
    HISTORY(Screen.History.route, "Geçmiş", "history")
}
