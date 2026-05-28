import UIKit
import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import FirebaseAuth
import WidgetKit
import SwiftData
import WatchConnectivity
import BackgroundTasks
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

/// UIKit-side app entry point. Handles Firebase configuration, push notification
/// setup (APNs registration, foreground/tap routing, inline reply actions),
/// Watch Connectivity activation, and background-task scheduling.
///
/// SwiftUI lifecycle owns the `StripMateApp` struct; this delegate plugs the
/// UIKit/UIApplication bits in via `@UIApplicationDelegateAdaptor`.
final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    /// Stores the deep link URL from a notification tap — survives before views are mounted.
    static var pendingDeepLinkURL: URL?

    // MARK: - Lifecycle

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Configure Firebase — guard against double-configure crash
        guard FirebaseApp.app() == nil else { return true }

        // Configure App Check BEFORE Firebase.configure()
        #if canImport(FirebaseAppCheck)
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        let providerFactory = DeviceCheckProviderFactory()
        #endif
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif

        FirebaseApp.configure()

        // Log launch event after Firebase is configured (Analytics needs Firebase ready)
        AnalyticsService.shared.log(.appLaunch)

        // ── UI Test Reset Hook ──
        // When launched with -ui-test-reset, wipe UserDefaults so each XCUITest
        // starts from a clean "first launch" state (no onboarding-seen flag, no
        // friend-gate-passed flag, no auth tokens). Production launches never
        // pass this flag, so this is safe.
        if ProcessInfo.processInfo.arguments.contains("-ui-test-reset") {
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
            try? Auth.auth().signOut()
        }

        // ── Fresh Install Detection ──
        // iOS Keychain survives app deletion, so Firebase Auth session persists.
        // UserDefaults IS cleared on uninstall, so we use it as a "first launch" flag.
        let hasLaunchedKey = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            // First launch after install/reinstall → clear stale Keychain session
            try? Auth.auth().signOut()
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        }

        // Enable offline persistence with 100MB cache for offline-first behavior
        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber)
        Firestore.firestore().settings = firestoreSettings

        // Optimize Cache for 'Native' feel (Snapchat/WhatsApp style)
        let memoryCapacity = 50 * 1024 * 1024 // 50MB
        let diskCapacity = 150 * 1024 * 1024 // 150MB
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "image_cache")
        URLCache.shared = cache

        // Set up Push Notifications
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Register inline reply actions
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: String(localized: "Yanıtla"),
            icon: UNNotificationActionIcon(systemImageName: "arrowshape.turn.up.left.fill"),
            textInputButtonTitle: String(localized: "Gönder"),
            textInputPlaceholder: String(localized: "Mesajınız...")
        )

        let stripChatCategory = UNNotificationCategory(
            identifier: "strip_chat",
            actions: [replyAction],
            intentIdentifiers: []
        )
        let dmCategory = UNNotificationCategory(
            identifier: "direct_message",
            actions: [replyAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([stripChatCategory, dmCategory])

        // NOTE: Permission request moved out of launch — asking for notifications
        // before the user has seen any value kills accept rates. Instead, the app
        // requests permission AFTER the first meaningful moment (first photo
        // sent / first friend added). See NotificationPermissionPrompter.
        // We still register for remote notifications on launch so APNs token
        // arrives early — the user just won't see the permission dialog yet.
        application.registerForRemoteNotifications()

        // Stamp the App Group schema version so future migrations have a
        // baseline to compare against. This must run before any code reads
        // shared UserDefaults for the first time on a fresh install.
        AppGroupSchema.installCurrentVersionIfNeeded()

        // Activate WatchConnectivity for Apple Watch companion app
        WatchSessionManager.shared.activate()

        // Setup SwiftData early
        Task {
            await SwiftDataSyncService.shared.setModelContainer(sharedModelContainer)
        }

        // Register background task for widget refresh — handler logic now
        // lives in WidgetRefreshTaskCoordinator so AppDelegate stays focused
        // on Firebase + UNUserNotificationCenter delegate plumbing.
        WidgetRefreshTaskCoordinator.shared.register()

        return true
    }

    /// Compatibility shim — existing call sites use `AppDelegate.scheduleWidgetRefresh()`;
    /// they all forward into the coordinator now.
    func scheduleWidgetRefresh() {
        WidgetRefreshTaskCoordinator.shared.schedule()
    }

    // MARK: - Remote Notifications (APNs)

    /// Pass APNs token to Firebase explicitly.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenHex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        AppLogger.push.debug("APNs registered tokenLen=\(tokenHex.count, privacy: .public)")
        CrashReporter.shared.setCustomValue(true, forKey: CrashReporter.Key.hasGrantedNotifPerm)
        CrashReporter.shared.breadcrumb(.push, "APNs registered")

        // Persist APNs device token in Keychain (for widget push use).
        // Still mirror into App Group UserDefaults so existing widget reads keep working,
        // but Keychain is the source of truth for sensitive storage.
        KeychainManager.save(tokenHex, forKey: KeychainManager.Key.widgetPushToken)
        UserDefaults(suiteName: AppConstants.appGroupID)?.set(tokenHex, forKey: "widgetPushToken")

        // Let Firebase know about the APNs token
        Messaging.messaging().apnsToken = deviceToken

        // Manually trigger FCM token fetch now that APNs is registered (since swizzling is disabled)
        Messaging.messaging().token { token, error in
            if let error = error {
                AppLogger.push.error("FCM token fetch failed: \(error.localizedDescription, privacy: .public)")
            } else if let token = token {
                AppLogger.push.debug("FCM token received len=\(token.count, privacy: .public)")
                Task {
                    await AuthService.shared.updateFCMToken(token)
                }
            }
        }
    }

    /// Log APNs registration errors.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppLogger.push.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
        CrashReporter.shared.setCustomValue(false, forKey: CrashReporter.Key.hasGrantedNotifPerm)
        CrashReporter.shared.breadcrumb(.push, "APNs registration failed")
    }

    // MARK: - Firebase Messaging

    /// Receive FCM Token.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        AppLogger.push.debug("FCM registration token received len=\(token.count, privacy: .public)")

        // Hand off to AuthService to persist in Firestore
        Task {
            await AuthService.shared.updateFCMToken(token)
        }
    }

    // MARK: - Foreground / Tap Routing

    /// Handle foreground notifications — show sound+badge via system, show custom in-app banner instead of system banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Parse push payload to show our own in-app banner
        let content = notification.request.content
        let userInfo = content.userInfo
        let type = userInfo["type"] as? String ?? ""

        let title: String
        let icon: String
        var deepLink: URL?

        switch type {
        case "new_strip":
            title = String(localized: "Yeni An!")
            icon = "camera.fill"
            if let stripId = userInfo["stripId"] as? String, !stripId.isEmpty {
                deepLink = URL(string: "stripmate://chat/\(stripId)")
            }
        case "new_comment":
            title = String(localized: "Yeni Yorum")
            icon = "bubble.left.fill"
            if let stripId = userInfo["stripId"] as? String, !stripId.isEmpty {
                deepLink = URL(string: "stripmate://chat/\(stripId)")
            }
        case "new_strip_chat":
            // Suppress if user is already viewing this strip chat
            if let stripId = userInfo["stripId"] as? String,
               let receiverId = userInfo["receiverId"] as? String,
               ActiveChatState.currentActiveStripChatKey() == "\(stripId)_\(receiverId)" {
                completionHandler([])
                return
            }
            title = content.title.isEmpty ? String(localized: "Yeni Mesaj") : content.title
            icon = "bubble.left.fill"
            if let stripId = userInfo["stripId"] as? String, !stripId.isEmpty {
                let receiverId = userInfo["receiverId"] as? String ?? ""
                deepLink = URL(string: "stripmate://chat/\(stripId)/\(receiverId)")
            }
        case "direct_message":
            // Suppress notification if user is already viewing this DM
            if let dmSenderId = userInfo["senderId"] as? String {
                // Thread-safe read — avoids DispatchQueue.main.sync deadlock risk
                let isViewingThisDM = ActiveChatState.currentActiveDMPartnerId() == dmSenderId
                if isViewingThisDM {
                    completionHandler([])
                    return
                }
            }

            // Use sender name from push title (format: "anlık. — SenderName")
            let pushTitle = content.title
            if pushTitle.contains("—") {
                title = String(pushTitle.split(separator: "—").last ?? "").trimmingCharacters(in: .whitespaces)
            } else {
                title = pushTitle.isEmpty ? String(localized: "Yeni Mesaj") : pushTitle
            }
            icon = "envelope.fill"
            if let threadId = userInfo["threadId"] as? String, !threadId.isEmpty {
                deepLink = URL(string: "stripmate://dm/\(threadId)")
            }
        case "friend_request":
            title = String(localized: "Arkadaşlık İsteği")
            icon = "person.badge.plus.fill"
            deepLink = URL(string: "stripmate://inbox")
        default:
            title = content.title.isEmpty ? String(localized: "Bildirim") : content.title
            icon = "bell.fill"
        }

        // Show sound, badge and list — our custom banner replaces the system banner,
        // but .list ensures the notification also appears in the system notification center.
        completionHandler([.sound, .badge, .list])

        let body = content.body

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .showInAppBanner,
                object: nil,
                userInfo: [
                    "title": title,
                    "body": body,
                    "icon": icon,
                    "deepLink": deepLink as Any
                ]
            )
        }
    }

    /// Handle notification tap or inline reply.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Inline reply from notification
        if response.actionIdentifier == "REPLY_ACTION",
           let textResponse = response as? UNTextInputNotificationResponse {
            // Sanitize the same way the in-app composers do: trim and cap at
            // 2000 chars. Firestore rules also enforce length, but applying it
            // client-side avoids a wasted network round trip and a rejected
            // notification reply experience.
            let trimmed = textResponse.userText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                completionHandler()
                return
            }
            let sanitized = String(trimmed.prefix(2000))

            // Request background execution time so the async send completes before iOS suspends us
            var bgTask: UIBackgroundTaskIdentifier = .invalid
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "InlineReply") {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }

            Task {
                await NotificationRouter.handleInlineReply(text: sanitized, userInfo: userInfo)
                completionHandler()
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
            return
        }

        // Normal tap — deep link
        routeDeepLink(from: userInfo)
        completionHandler()
    }

    /// Resolves the deep-link URL for a notification payload (via
    /// `NotificationRouter`) and dispatches it to active views, plus stashes
    /// it on AppDelegate for cold-start scenarios where no view has mounted yet.
    private func routeDeepLink(from userInfo: [AnyHashable: Any]) {
        guard let url = NotificationRouter.deepLink(for: userInfo) else { return }
        CrashReporter.shared.breadcrumb(.nav, "deep link route host=\(url.host ?? "?")")

        // Store statically for cold-start scenarios (view not yet mounted)
        AppDelegate.pendingDeepLinkURL = url

        // Also post for warm-start scenarios (view already mounted)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .deepLinkNotification,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }

    // MARK: - Orientation

    /// Lock to portrait on iPhone — prevents landscape rotation regardless of device type.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

    // MARK: - Background Push (Silent / Content-Available)

    /// Handle background notifications to refresh the widget.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Schedule next background refresh
        scheduleWidgetRefresh()

        // If we receive a "new_strip" push, download image and refresh widget
        if let type = userInfo["type"] as? String, type == "new_strip" {
            // Pick first non-empty URL (same logic as NSE)
            let imageUrl: String = {
                for key in ["smallThumbnailUrl", "thumbnailUrl", "imageUrl"] {
                    if let val = userInfo[key] as? String, !val.isEmpty { return val }
                }
                return ""
            }()
            let stripId = userInfo["stripId"] as? String ?? ""
            let cityName = userInfo["cityName"] as? String
            let lat = Double(userInfo["latitude"] as? String ?? "")
            let lon = Double(userInfo["longitude"] as? String ?? "")

            var backgroundTask: UIBackgroundTaskIdentifier = .invalid
            backgroundTask = application.beginBackgroundTask(withName: "WidgetBackgroundDownload") {
                application.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }

            Task {
                await CacheService.shared.downloadAndSaveForWidget(
                    urlString: imageUrl,
                    stripId: stripId,
                    cityName: cityName,
                    lat: lat,
                    lon: lon
                )
                completionHandler(.newData)
                application.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        } else {
            completionHandler(.noData)
        }
    }
}
