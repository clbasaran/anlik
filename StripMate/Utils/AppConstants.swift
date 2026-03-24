import Foundation
import WidgetKit

/// Centralized constants used across the app and extensions.
public enum AppConstants: Sendable {
    /// App Group identifier shared between the main app and widget extension.
    nonisolated static let appGroupID = "group.V99XFMU3L7.com.celalbasaran.stripmate"
}

// MARK: - Widget Reload Throttle

/// Prevents burning through Apple's daily widget reload budget (~40-70 calls/day).
/// Low-priority callers (app lifecycle) should use `throttledReload()`.
/// High-priority callers (push notification, photo send) can call `WidgetCenter.shared.reloadAllTimelines()` directly.
public final class WidgetReloadThrottle: @unchecked Sendable {
    public static let shared = WidgetReloadThrottle()
    
    /// Minimum interval between throttled reloads (seconds).
    private let minimumInterval: TimeInterval = 300 // 5 minutes
    private var lastReloadTime: Date = .distantPast
    private let lock = NSLock()
    
    private init() {}
    
    /// Reload widget timelines only if enough time has passed since the last reload.
    /// Returns `true` if the reload was performed, `false` if it was skipped.
    @discardableResult
    public func throttledReload() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        guard now.timeIntervalSince(lastReloadTime) >= minimumInterval else {
            #if DEBUG
            print("⏳ Widget reload throttled — last reload \(Int(now.timeIntervalSince(lastReloadTime)))s ago")
            #endif
            return false
        }
        
        lastReloadTime = now
        WidgetCenter.shared.reloadAllTimelines()
        #if DEBUG
        print("🔄 Widget reload executed (throttled)")
        #endif
        return true
    }
    
    /// Record that a direct (non-throttled) reload just happened,
    /// so the throttle window resets.
    public func recordDirectReload() {
        lock.lock()
        defer { lock.unlock() }
        lastReloadTime = Date()
    }
}

// MARK: - Type-Safe Notification Names

public extension NSNotification.Name {
    /// Posted when a user successfully logs in.
    nonisolated static let userDidLogin = NSNotification.Name("UserDidLogin")
    /// Posted when a user logs out.
    nonisolated static let userDidLogout = NSNotification.Name("UserDidLogout")
    /// Posted when a deep link URL arrives from a push notification.
    nonisolated static let deepLinkNotification = NSNotification.Name("DeepLinkNotification")
    /// Posted when a foreground push should show an in-app banner.
    nonisolated static let showInAppBanner = NSNotification.Name("ShowInAppBanner")
    /// Posted by ReviewPromptService when an App Store review prompt should be shown.
    nonisolated static let requestAppReview = NSNotification.Name("RequestAppReview")
}
