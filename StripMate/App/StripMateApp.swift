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

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    /// Stores the deep link URL from a notification tap — survives before views are mounted.
    static var pendingDeepLinkURL: URL?
    
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


    // Pass APNs token to Firebase explicitly
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

    // Log APNs registration errors
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppLogger.push.error("APNs registration failed: \(error.localizedDescription, privacy: .public)")
        CrashReporter.shared.setCustomValue(false, forKey: CrashReporter.Key.hasGrantedNotifPerm)
        CrashReporter.shared.breadcrumb(.push, "APNs registration failed")
    }


    // Receive FCM Token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        AppLogger.push.debug("FCM registration token received len=\(token.count, privacy: .public)")
        
        // Hand off to AuthService to persist in Firestore
        Task {
            await AuthService.shared.updateFCMToken(token)
        }
    }
    
    // Handle foreground notifications — show sound+badge via system, show custom in-app banner instead of system banner
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
    
    // Handle notification tap or inline reply
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
    
    // Lock to portrait on iPhone — prevents landscape rotation regardless of device type
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }

    // Handle background notifications to refresh the widget
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

// MARK: - SwiftData Schema Versioning

/// Schema versions are kept side-by-side so the migration plan can declare the
/// path between them. When you add or remove a field on a `@Model` type, copy
/// the most recent enum (e.g. StripMateSchemaV2) into a new StripMateSchemaV3,
/// flip the `models` types in `sharedModelContainer` to the new shape, and
/// append a `MigrationStage` from the previous version to the new one.
///
/// Without a defined path, an in-flight on-disk store risks being wiped on
/// upgrade (see fallback in `sharedModelContainer`). With it, lightweight
/// migrations stay automatic and additive changes are seamless.
enum StripMateSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [User.self, Friend.self, Strip.self]
    }
}

/// V2 is shape-identical to V1 today — the bump exists to install the
/// migration pipeline so the next field change has a place to live. Future:
/// when Comment / DirectMessage / Achievement / Streak become @Model classes
/// (currently Codable structs cached only in memory), bump to V3 and add the
/// new model types here plus a custom MigrationStage if any data needs
/// transforming.
enum StripMateSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [User.self, Friend.self, Strip.self]
    }
}

/// V3 adds `Friend.isFavorite: Bool` (default false). Lightweight migration —
/// SwiftData backfills the new column with the default value for every
/// existing row. Without this stage, V2 stores crash on launch with
/// `NSLightweightMigrationStage initWithVersionChecksums` (the classic
/// "schema changed without a stage to bridge it" failure).
enum StripMateSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [User.self, Friend.self, Strip.self]
    }
}

enum StripMateMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StripMateSchemaV1.self, StripMateSchemaV2.self, StripMateSchemaV3.self]
    }

    /// V1 → V2 is a no-op shape-wise; declaring it as `lightweight` lets
    /// SwiftData's inference handle the version metadata bump without a
    /// destructive rebuild of an existing user's local cache.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: StripMateSchemaV1.self,
        toVersion: StripMateSchemaV2.self
    )

    /// V2 → V3 adds Friend.isFavorite — pure additive, lightweight is enough.
    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: StripMateSchemaV2.self,
        toVersion: StripMateSchemaV3.self
    )

    static var stages: [MigrationStage] { [migrateV1toV2, migrateV2toV3] }
}

/// Bumped on every additive schema change — when this string differs from the
/// last value stored in UserDefaults at launch, we nuke the on-disk SwiftData
/// store before opening it. The store is just a cache of Firestore, so losing
/// it is safe; the next listener tick refills it.
///
/// This sidesteps SwiftData's `NSLightweightMigrationStage initWithVersionChecksums`
/// crash, which fires when the in-code schema and on-disk schema disagree
/// AND the migration plan can't compute checksums (since both versioned
/// schemas in the plan now reference the live model type, not a snapshot).
private let kSwiftDataSchemaFingerprint = "v3-friend-isFavorite-2026-04-27"
private let kSwiftDataFingerprintKey = "stripmate.swiftdata.schemaFingerprint"

private func nukeSwiftDataStoreIfSchemaChanged(at storeURL: URL?) {
    let stored = UserDefaults.standard.string(forKey: kSwiftDataFingerprintKey)
    guard stored != kSwiftDataSchemaFingerprint else { return }

    if let url = storeURL {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            try? fm.removeItem(atPath: url.path + suffix)
        }
        AppLogger.app.notice("SwiftData fingerprint changed; cleared on-disk store at \(url.path, privacy: .public)")
    }
    UserDefaults.standard.set(kSwiftDataSchemaFingerprint, forKey: kSwiftDataFingerprintKey)
}

var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        User.self,
        Friend.self,
        Strip.self
    ])

    // CRITICAL: Point to App Group container so Widget and Main App share the same DB
    let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)?
        .appendingPathComponent("StripMate.sqlite")

    // Nuke the store BEFORE creating the container if the schema fingerprint
    // shifted — the migration validator throws NSExceptions that Swift do/catch
    // can't catch, so we have to prevent it from running in the first place.
    nukeSwiftDataStoreIfSchemaChanged(at: storeURL)

    let modelConfiguration: ModelConfiguration
    if let url = storeURL {
        modelConfiguration = ModelConfiguration(url: url)
    } else {
        modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
    }

    do {
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    } catch {
        // Belt-and-suspenders: if creation still fails (e.g. fingerprint check
        // missed something), clear the store and rebuild empty.
        AppLogger.app.error("ModelContainer creation failed; deleting store and retrying: \(error.localizedDescription, privacy: .public)")

        if let url = storeURL {
            let fileManager = FileManager.default
            let storePath = url.path
            for suffix in ["", "-shm", "-wal"] {
                try? fileManager.removeItem(atPath: storePath + suffix)
            }
        }

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            // Last resort: in-memory container so the app can still launch
            AppLogger.app.error("ModelContainer retry failed; using in-memory store: \(error.localizedDescription, privacy: .public)")
            let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("Could not create even in-memory ModelContainer: \(error)")
            }
        }
    }
}()

@main
struct StripMateApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // App delegate handles Firebase Configuration
    }

    var body: some Scene {
        WindowGroup {
            AppRootRouter()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                delegate.scheduleWidgetRefresh()
            }
        }
    }
}

public struct AppRootRouter: View {
    @State private var isAuthenticated = false
    @State private var isChecking = true
    @State private var needsProfileCompletion = false
    @State private var needsFriendGate = false
    @State private var pendingDeepLink: URL?
    @State private var authListenerHandle: FirebaseAuth.AuthStateDidChangeListenerHandle?
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasSeenAppTour") private var hasSeenAppTour = false
    @AppStorage("hasPassedFriendGate") private var hasPassedFriendGate = false
    @State private var currentBanner: InAppBanner?
    
    // Guard states (ban, suspend, maintenance)
    @State private var isBanned = false
    @State private var banMessage = ""
    @State private var isSuspended = false
    @State private var suspendedUntil: Date?
    @State private var isInMaintenance = false
    @State private var maintenanceMessage = ""
    
    public init() {}
    
    @State private var showSplash = true

    public var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            } else if isChecking {
                Color.black.ignoresSafeArea()
            } else if !hasSeenOnboarding {
                OnboardingView()
            } else if !isAuthenticated {
                AuthView()
            } else if needsProfileCompletion {
                ProfileCompletionView {
                    withAnimation {
                        needsProfileCompletion = false
                    }
                }
            } else if !hasSeenAppTour {
                AppTourView()
            } else if needsFriendGate {
                FriendGateView {
                    hasPassedFriendGate = true
                    withAnimation {
                        needsFriendGate = false
                    }
                }
            } else if isBanned {
                bannedScreen
            } else if isSuspended {
                suspendedScreen
            } else if isInMaintenance {
                maintenanceScreen
            } else {
                MainTabView(pendingDeepLink: $pendingDeepLink)
            }
            
            // In-app notification banner overlay — pinned to top, pass-through everywhere else
            if let banner = currentBanner {
                InAppBannerView(
                    banner: banner,
                    onTap: {
                        if let url = banner.deepLink {
                            pendingDeepLink = url
                        }
                    },
                    onDismiss: {
                        currentBanner = nil
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentBanner != nil)
            }
        }
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            // Invite links bypass the regular deep-link routing; the service
            // calls acceptInvite and posts a notification for the welcome toast.
            if InviteService.shared.handleIncoming(url: url) { return }
            pendingDeepLink = url
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            // Universal Links land here. Same routing logic as onOpenURL.
            guard let url = activity.webpageURL else { return }
            if InviteService.shared.handleIncoming(url: url) { return }
            pendingDeepLink = url
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkNotification)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                pendingDeepLink = url
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Reset badge count when app is opened
            UNUserNotificationCenter.current().setBadgeCount(0)
            
            // Refresh widgets (throttled to preserve Apple's daily reload budget)
            WidgetReloadThrottle.shared.throttledReload()

            // Sync widget push token to Firestore (if WidgetPushHandler provided a new token)
            Task { await AuthService.shared.syncWidgetPushToken() }
            
            // Re-check ban/suspend and maintenance on foreground
            if isAuthenticated {
                Task { await performGuardChecks() }
                // Sync notification permission status to Firestore
                Task {
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let enabled = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                    try? await AuthService.shared.updateNotificationPreference(key: "push_enabled", enabled: enabled)
                }
                // Deferred deep link: if the web landing page wrote an invite
                // payload to the clipboard before install, pick it up now.
                Task { @MainActor in
                    InviteService.shared.checkClipboardForDeferredInvite()
                    await InviteService.shared.redeemPendingIfAny()
                }
            }
            
            // Check for pending deep link from notification tap (cold start or background)
            if let url = AppDelegate.pendingDeepLinkURL {
                AppDelegate.pendingDeepLinkURL = nil
                // Wait for MainTabView to be mounted before delivering the deep link
                Task { @MainActor in
                    await TabBarState.shared.waitUntilReady()
                    self.pendingDeepLink = url
                }
            }
            
            // Check for widget camera launch
            let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
            if sharedDefaults?.bool(forKey: "pending_camera_launch") == true {
                sharedDefaults?.set(false, forKey: "pending_camera_launch")
                pendingDeepLink = URL(string: "stripmate://camera")
            }
        }
        .task {
            // Attempt auto-login — set gates BEFORE isAuthenticated to prevent flash
            if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
                CrashReporter.shared.setUserId(uid)
                AnalyticsService.shared.setUserId(uid)
                Messaging.messaging().subscribe(toTopic: "daily_prompt") { _ in }

                // Fetch profile + friends + guards in parallel
                async let profileTask: UserProfile? = {
                    try? await AuthService.shared.fetchProfile(for: uid)
                }()
                async let friendsTask = FriendshipService.shared.hasAnyFriendship()
                async let guardTask: () = performGuardChecks()

                let profile = await profileTask
                let hasFriends = await friendsTask
                await guardTask

                // Orphaned auth: Firebase user exists but no Firestore profile
                if profile == nil {
                    try? Auth.auth().signOut()
                    self.isAuthenticated = false
                    self.isChecking = false
                    return
                }

                applyAuthenticatedFlowState(
                    profile: profile,
                    hasFriends: hasFriends
                )

                // THEN show authenticated UI
                withAnimation {
                    self.isAuthenticated = true
                }
                self.isChecking = false
            } else {
                self.isAuthenticated = false
                self.isChecking = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
            Task {
                // Parallel: token + friends + guard
                async let tokenTask: () = AuthService.shared.persistCachedFCMToken()
                async let friendsTask = FriendshipService.shared.hasAnyFriendship()
                async let guardTask: () = performGuardChecks()

                await tokenTask
                let hasFriends = await friendsTask
                await guardTask

                if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
                    CrashReporter.shared.setUserId(uid)
                    AnalyticsService.shared.setUserId(uid)
                }

                let profile = await AuthService.shared.currentUserProfile
                applyAuthenticatedFlowState(
                    profile: profile,
                    hasFriends: hasFriends
                )
                withAnimation {
                    self.isAuthenticated = true
                }
                // Sign-in just completed — redeem any pending invite stashed
                // before auth (universal link tap on a fresh install).
                Task { @MainActor in
                    await InviteService.shared.redeemPendingIfAny()
                    InviteService.shared.checkClipboardForDeferredInvite()
                }
            }
            Messaging.messaging().subscribe(toTopic: "daily_prompt")
            WatchSessionManager.shared.performFullSync()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
            withAnimation {
                self.isAuthenticated = false
                self.needsProfileCompletion = false
                self.needsFriendGate = false
                self.isBanned = false
                self.isSuspended = false
                self.isInMaintenance = false
            }
            // Reset persisted friend gate so next account starts fresh
            hasPassedFriendGate = false
            Task { await AppGuardService.shared.clearCache() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showInAppBanner)) { notification in
            guard let info = notification.userInfo else { return }
            let title = info["title"] as? String ?? "Notification"
            let body = info["body"] as? String ?? ""
            let icon = info["icon"] as? String ?? "bell.fill"
            let deepLink = info["deepLink"] as? URL
            
            withAnimation {
                currentBanner = InAppBanner(
                    title: title,
                    body: body,
                    icon: icon,
                    deepLink: deepLink
                )
            }
        }
        // Auth state listener — only handle sign-out events.
        // Login is handled by .userDidLogin which sets gate flags first.
        .onAppear {
            authListenerHandle = FirebaseAuth.Auth.auth().addStateDidChangeListener { _, user in
                if user == nil && self.isAuthenticated && !self.isChecking {
                    withAnimation {
                        self.isAuthenticated = false
                    }
                }
                if let uid = user?.uid {
                    CrashReporter.shared.setUserId(uid)
                    AnalyticsService.shared.setUserId(uid)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // Refresh widgets when app goes to background (throttled to preserve reload budget)
            WidgetReloadThrottle.shared.throttledReload()
        }
        .onDisappear {
            if let handle = authListenerHandle {
                FirebaseAuth.Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    
    // MARK: - Guard Checks
    
    private func performGuardChecks() async {
        // Update lastActive timestamp
        if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
            try? await Firestore.firestore().collection("users").document(uid)
                .updateData(["lastActive": FieldValue.serverTimestamp()])
        }

        // Check maintenance mode
        let maintenance = await AppGuardService.shared.checkMaintenance()
        await MainActor.run {
            self.isInMaintenance = maintenance.isActive
            self.maintenanceMessage = maintenance.message
        }
        
        // Check ban/suspend
        let status = await AppGuardService.shared.checkUserStatus()
        await MainActor.run {
            switch status {
            case .active:
                self.isBanned = false
                self.isSuspended = false
            case .banned(let reason):
                self.isBanned = true
                self.banMessage = reason
            case .suspended(let until, let reason):
                self.isSuspended = true
                self.suspendedUntil = until
                self.banMessage = reason
            }
        }
    }

    @MainActor
    private func applyAuthenticatedFlowState(profile: UserProfile?, hasFriends: Bool) {
        let requiresProfileCompletion = profile?.needsProfileCompletion ?? false
        needsProfileCompletion = requiresProfileCompletion
        needsFriendGate = !requiresProfileCompletion && !hasFriends && !hasPassedFriendGate
    }
    
    // MARK: - Guard Screens
    
    private var maintenanceScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.6))
            Text("Bakım Modu")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Text(maintenanceMessage.isEmpty ? "Uygulama şu anda bakımda. Lütfen daha sonra tekrar deneyin." : maintenanceMessage)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button {
                Task { await performGuardChecks() }
            } label: {
                Text("Tekrar Dene")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
    
    private var bannedScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "nosign")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.7))
            Text("Hesabınız Engellendi")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            if !banMessage.isEmpty {
                Text("Sebep: \(banMessage)")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Text("Bu kararın hatalı olduğunu düşünüyorsanız destek ile iletişime geçin.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button {
                Task { try? await AuthService.shared.logout() }
            } label: {
                Text("Çıkış Yap")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.15), in: Capsule())
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
    
    private var suspendedScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.6))
            Text("Hesabınız Askıya Alındı")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            if let until = suspendedUntil {
                Text("Bitiş: \(until.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.orange)
            }
            if !banMessage.isEmpty {
                Text("Sebep: \(banMessage)")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Button {
                Task { await performGuardChecks() }
            } label: {
                Text("Tekrar Kontrol Et")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

}
