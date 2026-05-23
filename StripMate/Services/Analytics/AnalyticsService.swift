import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// Centralized analytics wrapper for tracking user events throughout the app.
/// Add FirebaseAnalytics SPM product from firebase-ios-sdk to enable.
///
/// Events use the `sm_` prefix so they're easy to filter in Firebase Console.
/// Funnel events use ordinal naming (`sm_signup_step_0`, `_1`...) so DebugView
/// + funnel exploration in Firebase Console pick them up automatically.
public enum AnalyticsEvent: String {
    // MARK: - Activation funnel (CRITICAL — measure these religiously)
    case appLaunch = "sm_app_launch"
    case onboardingStarted = "sm_onboarding_started"
    case onboardingCompleted = "sm_onboarding_completed"
    case onboardingSkipped = "sm_onboarding_skipped"
    case demoPreviewOpened = "sm_demo_preview_opened"
    case demoPreviewClosed = "sm_demo_preview_closed"

    // Auth funnel
    case signupStarted = "sm_signup_started"
    case signupStepCompleted = "sm_signup_step_completed"   // param: step (0,1,2)
    case signupCompleted = "sm_signup_completed"
    case signupAbandoned = "sm_signup_abandoned"            // param: at_step
    case login = "sm_login"
    case signUp = "sm_sign_up"                               // legacy alias for sm_signup_completed
    case appleSignIn = "sm_apple_sign_in"
    case logout = "sm_logout"
    case profileCompletionShown = "sm_profile_completion_shown"
    case profileCompletionFinished = "sm_profile_completion_finished"

    // Friend gate funnel — the activation killer; instrument hard
    case friendGateShown = "sm_friend_gate_shown"
    case friendGatePassed = "sm_friend_gate_passed"          // param: method (request_sent, accepted, qr, skip)
    case friendGateSkipped = "sm_friend_gate_skipped"        // soft-exit fired
    case friendGateHelpOpened = "sm_friend_gate_help_opened"
    case appTourCompleted = "sm_app_tour_completed"
    case appTourSkipped = "sm_app_tour_skipped"

    // First-magic-moment funnel
    case firstPhotoSent = "sm_first_photo_sent"
    case firstFriendAdded = "sm_first_friend_added"
    case firstReactionGiven = "sm_first_reaction_given"
    case firstStripChatMessage = "sm_first_strip_chat_message"

    // Permissions
    case notificationPermissionPrompted = "sm_notif_perm_prompted"
    case notificationPermissionGranted = "sm_notif_perm_granted"
    case notificationPermissionDenied = "sm_notif_perm_denied"
    case cameraPermissionGranted = "sm_camera_perm_granted"
    case cameraPermissionDenied = "sm_camera_perm_denied"
    case contactsPermissionGranted = "sm_contacts_perm_granted"
    case contactsPermissionDenied = "sm_contacts_perm_denied"
    case locationPermissionGranted = "sm_location_perm_granted"
    case locationPermissionDenied = "sm_location_perm_denied"

    // Social
    case sendFriendRequest = "sm_send_friend_request"
    case acceptFriendRequest = "sm_accept_friend_request"
    case removeFriend = "sm_remove_friend"
    case blockUser = "sm_block_user"
    case reportContent = "sm_report_content"

    // Photo
    case capturePhoto = "sm_capture_photo"
    case sendPhoto = "sm_send_photo"                          // param: recipient_count, has_voice, is_secret, is_video
    case sendPhotoFailed = "sm_send_photo_failed"             // param: error_code
    case sendPhotoRetried = "sm_send_photo_retried"
    case clearHistory = "sm_clear_history"
    case viewStripDetail = "sm_view_strip_detail"

    // Messaging
    case sendComment = "sm_send_comment"
    case sendDirectMessage = "sm_send_direct_message"

    // Navigation
    case openHistory = "sm_open_history"
    case openFriends = "sm_open_friends"
    case openInbox = "sm_open_inbox"
    case openNotifications = "sm_open_notifications"
    case openSettings = "sm_open_settings"

    // Widget
    case widgetTapped = "sm_widget_tapped"
    case widgetRefreshed = "sm_widget_refreshed"

    // Engagement / retention
    case streakIncreased = "sm_streak_increased"              // param: days
    case streakBroken = "sm_streak_broken"                    // param: days_at_break
    case dailyPromptViewed = "sm_daily_prompt_viewed"
    case dailyPromptAnswered = "sm_daily_prompt_answered"

    // Errors (diagnostic)
    case appError = "sm_app_error"                            // param: domain, code, message
}

public final class AnalyticsService {
    public static let shared = AnalyticsService()
    
    private init() {}
    
    /// Log a custom analytics event
    public func log(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.rawValue, parameters: parameters)
        #endif
        #if DEBUG
        AppLogger.service.debug("Analytics \(event.rawValue, privacy: .public) params=\(String(describing: parameters), privacy: .public)")
        #endif
    }

    // MARK: - First-time-event helpers
    // These wrap UserDefaults so callers can fire-and-forget; the helper only
    // logs on the FIRST occurrence per install. Useful for activation funnels.

    private static let firstEventDefaults = "sm_first_events_logged"

    /// Log only if this event hasn't been logged before for this install.
    public func logOnce(_ event: AnalyticsEvent, parameters: [String: Any]? = nil) {
        var logged = UserDefaults.standard.stringArray(forKey: Self.firstEventDefaults) ?? []
        guard !logged.contains(event.rawValue) else { return }
        logged.append(event.rawValue)
        UserDefaults.standard.set(logged, forKey: Self.firstEventDefaults)
        log(event, parameters: parameters)
    }
    
    /// Set the current user ID for analytics attribution
    public func setUserId(_ userId: String?) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(userId)
        if userId != nil {
            Analytics.setUserProperty(
                Locale.current.language.languageCode?.identifier ?? "unknown",
                forName: "user_locale"
            )
        }
        #endif
    }
    
    /// Set a user property
    public func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }
    
    /// Track screen views
    public func logScreenView(screenName: String, screenClass: String? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
        #endif
    }
}
