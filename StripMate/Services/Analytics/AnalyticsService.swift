import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// Centralized analytics wrapper for tracking user events throughout the app.
/// Add FirebaseAnalytics SPM product from firebase-ios-sdk to enable.
public enum AnalyticsEvent: String {
    // Auth
    case login = "sm_login"
    case signUp = "sm_sign_up"
    case appleSignIn = "sm_apple_sign_in"
    case logout = "sm_logout"
    
    // Social
    case sendFriendRequest = "sm_send_friend_request"
    case acceptFriendRequest = "sm_accept_friend_request"
    case removeFriend = "sm_remove_friend"
    
    // Photo
    case capturePhoto = "sm_capture_photo"
    case sendPhoto = "sm_send_photo"
    case clearHistory = "sm_clear_history"
    
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
 print(" Analytics: \(event.rawValue) \(parameters ?? [:])")
        #endif
    }
    
    /// Set the current user ID for analytics attribution
    public func setUserId(_ userId: String?) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(userId)
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
