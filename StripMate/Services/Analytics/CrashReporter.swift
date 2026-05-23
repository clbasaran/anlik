import Foundation
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Centralized crash reporting wrapper.
/// Add FirebaseCrashlytics SPM product from firebase-ios-sdk to enable.
public final class CrashReporter {
    public static let shared = CrashReporter()

    private init() {}

    // MARK: - Identity

    /// Set the current user ID for crash attribution
    public func setUserId(_ userId: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(userId)
        #endif
    }

    /// Clear the user attribution on logout — otherwise the next user's
    /// crashes get attributed to whoever was signed in before.
    public func clearUserId() {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID("")
        #endif
    }

    // MARK: - Errors

    /// Log a non-fatal error
    public func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
        #endif
        AppLogger.app.error("non-fatal: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Breadcrumbs

    /// Drop a breadcrumb that will be attached to the next crash report. Keep
    /// these short and high-signal — what the user was doing, not implementation
    /// detail. PII must NOT appear here; Crashlytics persists logs across
    /// launches.
    public func breadcrumb(_ category: Category, _ message: String) {
        let line = "[\(category.rawValue)] \(message)"
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(line)
        #endif
    }

    public enum Category: String {
        case auth, nav, camera, chat, dm, push, widget, watch, payment, app
    }

    /// Free-form log when no category fits.
    public func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif
    }

    // MARK: - Custom keys

    /// Set a custom key-value pair for crash context
    public func setCustomValue(_ value: Any, forKey key: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }

    /// Standard custom keys — a short, fixed set so the Crashlytics dashboard
    /// stays consistent. New keys should be added here, not stringified
    /// inline at call sites.
    public enum Key {
        public static let lastTabVisited = "last_tab_visited"
        public static let lastScreenVisited = "last_screen_visited"
        public static let networkClass = "network_class"
        public static let hasGrantedNotifPerm = "has_granted_notif_perm"
        public static let hasGrantedCameraPerm = "has_granted_camera_perm"
        public static let hasGrantedMicPerm = "has_granted_mic_perm"
        public static let appLaunchCount = "app_launch_count"
        public static let lastUploadOutcome = "last_upload_outcome"
    }
}
