import Foundation
import WidgetKit

/// Centralized constants used across the app and extensions.
public enum AppConstants: Sendable {
    /// App Group identifier shared between the main app and widget extension.
    nonisolated static let appGroupID = "group.V99XFMU3L7.com.celalbasaran.stripmate"
}

// MARK: - App Group Storage Schema

/// Single source of truth for every key written to / read from the App Group
/// UserDefaults suite. Three targets share this container — main app, the
/// notification service extension, and the widget — so a stray rename in any
/// one of them silently breaks the others. Keep all keys here, document the
/// owner, and bump `schemaVersion` whenever the meaning of an existing key
/// changes (not just additions).
///
/// On launch, the main app should compare the persisted version against
/// `AppGroupSchema.currentVersion` and run any migration code before reading.
public enum AppGroupKeys: Sendable {
    /// Bumped whenever the meaning of an existing key changes. Migrations live
    /// in `AppGroupSchema.runMigrations` (currently a no-op).
    public static let currentSchemaVersion: Int = 1

    /// Schema version stored in the suite. Compare against `currentSchemaVersion`.
    public static let schemaVersion = "app_group_schema_version"

    // MARK: Latest photo (NSE writes, Widget reads)

    /// Most recent strip's image URL.
    public static let latestPhotoUrl = "latest_photo_url"
    /// Lower-resolution thumbnail URL for the widget snapshot.
    public static let latestThumbnailUrl = "latest_thumbnail_url"
    /// Strip id of the most recent photo.
    public static let latestPhotoId = "latest_photo_id"
    /// Unix timestamp when NSE last wrote the latest photo metadata.
    public static let latestPhotoTime = "latest_photo_time"
    /// Latitude of the latest photo (only set if non-zero).
    public static let latestPhotoLat = "latest_photo_lat"
    /// Longitude of the latest photo (only set if non-zero).
    public static let latestPhotoLon = "latest_photo_lon"
    /// City label rendered alongside the latest photo.
    public static let latestPhotoCity = "latest_photo_city"

    // MARK: Widget bookkeeping

    /// Last time the widget timeline reloaded (used to detect NSE-newer state).
    public static let widgetLastTimeline = "widget_last_timeline"
    /// User-pinned friend whose photos take priority on the widget.
    public static let pinnedFriendId = "pinned_friend_id"

    // MARK: Push tokens (legacy — Keychain is canonical)

    /// APNs device token used by Cloud Functions to push the widget directly.
    /// Kept for backwards compatibility with installs that haven't migrated to
    /// Keychain yet — new code should read from `KeychainManager`.
    public static let widgetPushToken = "widgetPushToken"

    // MARK: User invite metadata (Main → QR widget)

    public static let userInviteCode = "user_invite_code"
    public static let userDisplayName = "user_display_name"
    public static let userUsername = "user_username"

    // MARK: User location (Main writes, Widget reads for distance)

    public static let userLastLat = "user_last_lat"
    public static let userLastLon = "user_last_lon"

    // MARK: Camera launch handoff (Control Widget → Main)

    /// Set to `true` when the Control Center widget intent fires; the main app
    /// reads this on foreground and routes to the camera, then clears it.
    public static let pendingCameraLaunch = "pending_camera_launch"

    // MARK: Block list (defense-in-depth fallback)

    /// Persisted blocked user ids — fail-closed cache for realtime listeners
    /// when the live Firestore fetch errors out.
    public static let blockedUserIds = "blocked_user_ids"
}

/// Lightweight schema version coordinator for the App Group container.
/// Run `AppGroupSchema.installCurrentVersionIfNeeded()` once on launch so the
/// version stamp is present from day one — migrations added later can then
/// read the existing version and decide what to migrate.
public enum AppGroupSchema {
    public static func installCurrentVersionIfNeeded() {
        let suite = UserDefaults(suiteName: AppConstants.appGroupID)
        let stored = suite?.integer(forKey: AppGroupKeys.schemaVersion) ?? 0
        if stored == 0 {
            // Stamp the current version so future launches can compare.
            suite?.set(AppGroupKeys.currentSchemaVersion, forKey: AppGroupKeys.schemaVersion)
        } else if stored < AppGroupKeys.currentSchemaVersion {
            runMigrations(from: stored, to: AppGroupKeys.currentSchemaVersion)
            suite?.set(AppGroupKeys.currentSchemaVersion, forKey: AppGroupKeys.schemaVersion)
        }
    }

    private static func runMigrations(from oldVersion: Int, to newVersion: Int) {
        // No migrations yet — version 1 is the baseline. When changing the
        // semantics of an existing key, add a `case oldVersion` here that
        // rewrites the relevant entries.
        AppLogger.app.info("App Group schema migrate \(oldVersion, privacy: .public) -> \(newVersion, privacy: .public)")
    }
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
            print("Widget reload throttled -- last reload \(Int(now.timeIntervalSince(lastReloadTime)))s ago")
            #endif
            return false
        }
        
        lastReloadTime = now
        WidgetCenter.shared.reloadAllTimelines()
        #if DEBUG
        print("Widget reload executed (throttled)")
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
    /// Posted whenever the friend list changes (request accepted, friend added,
    /// friend removed, blocked). Camera/preview/inbox listen and refresh their
    /// cached friend lists so the user doesn't have to relaunch the app to see
    /// the new sender choice.
    nonisolated static let friendListChanged = NSNotification.Name("FriendListChanged")
}

// MARK: - App Limits

public enum AppLimits {
    static let minimumRegistrationAge = 16

    // Friends
    static let maxFriends = 50
    static let maxReceivers = 50

    // Content
    static let messageMaxLength = 2000
    static let commentMaxLength = 500
    static let bioMaxLength = 150
    static let usernameMinLength = 3
    static let usernameMaxLength = 20

    // Media
    static let imageMaxDimension: CGFloat = 1440
    static let jpegQuality: CGFloat = 0.92
    static let thumbnailSize: CGFloat = 400
    static let smallThumbnailSize: CGFloat = 150
    static let avatarSize: CGFloat = 512
    static let voiceMaxDuration: TimeInterval = 15

    // Rate Limits
    static let maxStripsPerDay = 100
    static let maxDMsPerDay = 500
    static let maxNudgesPerDay = 3

    // Pagination
    static let pageSize = 20
    static let initialLoadSize = 50

    // Cache
    static let imageCacheTTL: TimeInterval = 86400 // 24 hours
    static let blockedUsersCacheTTL: TimeInterval = 300 // 5 minutes
    static let urlCacheMemory = 50 * 1024 * 1024 // 50MB
    static let urlCacheDisk = 150 * 1024 * 1024 // 150MB

    // Background tasks
    static let widgetRefreshInterval: TimeInterval = 5 * 60 // 5 minutes

    // User Defaults keys
    enum ReviewPromptKeys {
        static let openCount = "review_app_open_count"
        static let lastPromptDate = "review_last_prompt_date"
    }

    static var latestAllowedBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -minimumRegistrationAge, to: Date()) ?? Date()
    }

    static var recommendedDefaultBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? latestAllowedBirthDate
    }

    static func meetsMinimumRegistrationAge(_ birthDate: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let age = calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0
        return age >= minimumRegistrationAge
    }
}
