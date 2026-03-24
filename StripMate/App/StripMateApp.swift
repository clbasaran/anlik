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
        
        // Configure App Check BEFORE Firebase.configure() for maximum protection
        #if canImport(FirebaseAppCheck)
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        let providerFactory = DeviceCheckProviderFactory()
        #endif
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif
        
        // Configure Firebase as early as possible
        FirebaseApp.configure()
        
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

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, _ in
            // Save notification permission status to Firestore
            Task {
                try? await AuthService.shared.updateNotificationPreference(key: "push_enabled", enabled: granted)
            }
        }
        application.registerForRemoteNotifications()
        
        // Activate WatchConnectivity for Apple Watch companion app
        WatchSessionManager.shared.activate()
        
        // Setup SwiftData early
        Task {
            await SwiftDataSyncService.shared.setModelContainer(sharedModelContainer)
        }
        
        // Register background task for widget refresh
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.celalbasaran.stripmate.widget-refresh", using: nil) { task in
            self.handleWidgetRefreshTask(task as! BGAppRefreshTask)
        }

        return true
    }

    /// Schedule periodic background widget refresh
    func scheduleWidgetRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.celalbasaran.stripmate.widget-refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60) // 5 minutes
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Handle background task: reload widget + reschedule
    private func handleWidgetRefreshTask(_ task: BGAppRefreshTask) {
        // Check if NSE saved newer data than what widget last displayed
        let sharedDefaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
        let nseTime = sharedDefaults?.double(forKey: "latest_photo_time") ?? 0
        let widgetTime = sharedDefaults?.double(forKey: "widget_last_timeline") ?? 0

        if nseTime > widgetTime {
            // NSE saved new data that widget hasn't shown yet
            WidgetCenter.shared.reloadTimelines(ofKind: "StripMateWidget")
        }

        // Reschedule for next check
        scheduleWidgetRefresh()
        task.setTaskCompleted(success: true)
    }
    
    // Pass APNs token to Firebase explicitly
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if DEBUG
        print("DEBUG: Successfully registered for APNs. Passing token to Firebase.")
        #endif
        #if DEBUG
        print("DEBUG: APNs Device Token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        #endif
        
        // Let Firebase know about the APNs token
        Messaging.messaging().apnsToken = deviceToken
        
        // Manually trigger FCM token fetch now that APNs is registered (since swizzling is disabled)
        Messaging.messaging().token { token, error in
            if let error = error {
                #if DEBUG
                print("DEBUG: Error fetching FCM registration token: \(error)")
                #endif
            } else if let token = token {
                #if DEBUG
                print("DEBUG: FCM registration token: \(token)")
                #endif
                Task {
                    await AuthService.shared.updateFCMToken(token)
                }
            }
        }
    }
    
    // Log APNs registration errors
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("DEBUG: Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }

    
    // Receive FCM Token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        #if DEBUG
        print("DEBUG: Firebase registration token: \(token)")
        #endif
        
        // Hand off to AuthService to persist in Firestore
        Task {
            await AuthService.shared.updateFCMToken(token)
        }
    }
    
    // Handle foreground notifications — show sound+badge via system, show custom in-app banner instead of system banner
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show sound and badge via system, but suppress the system banner (we have our own)
        completionHandler([.sound, .badge])
        
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
            title = content.title.isEmpty ? String(localized: "Yeni Mesaj") : content.title
            icon = "bubble.left.fill"
            if let stripId = userInfo["stripId"] as? String, !stripId.isEmpty {
                let receiverId = userInfo["receiverId"] as? String ?? ""
                deepLink = URL(string: "stripmate://chat/\(stripId)/\(receiverId)")
            }
        case "direct_message":
            // Suppress notification if user is already viewing this DM
            if let dmSenderId = userInfo["senderId"] as? String {
                var isViewingThisDM = false
                if Thread.isMainThread {
                    isViewingThisDM = ActiveChatState.shared.activeDMPartnerId == dmSenderId
                } else {
                    DispatchQueue.main.sync {
                        isViewingThisDM = ActiveChatState.shared.activeDMPartnerId == dmSenderId
                    }
                }
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
            let replyText = textResponse.userText
            guard !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                completionHandler()
                return
            }

            // Request background execution time so the async send completes before iOS suspends us
            var bgTask: UIBackgroundTaskIdentifier = .invalid
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "InlineReply") {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }

            Task {
                await handleInlineReply(text: replyText, userInfo: userInfo)
                completionHandler()
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
            return
        }

        // Normal tap — deep link
        handleNotificationPayload(userInfo)
        completionHandler()
    }

    /// Sends a message from the notification inline reply
    private func handleInlineReply(text: String, userInfo: [AnyHashable: Any]) async {
        let type = userInfo["type"] as? String ?? ""

        do {
            switch type {
            case "new_strip", "new_strip_chat":
                let stripId = userInfo["stripId"] as? String ?? ""
                let senderId = userInfo["senderId"] as? String ?? ""
                guard !stripId.isEmpty, !senderId.isEmpty else { return }
                try await PhotoService.shared.sendStripChatMessage(
                    text: text,
                    stripId: stripId,
                    chatPartnerId: senderId
                )
            case "direct_message":
                let senderId = userInfo["senderId"] as? String ?? ""
                guard !senderId.isEmpty else { return }
                try await ChatService.shared.sendDirectMessage(
                    to: senderId,
                    text: text
                )
            default:
                break
            }
        } catch {
            #if DEBUG
            print("Inline reply failed: \(error.localizedDescription)")
            #endif
        }
    }
    
    /// Shared handler: converts notification payload into a deep link URL.
    /// Posts via NotificationCenter for active views, or stores in static property for cold start.
    private func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        let type = userInfo["type"] as? String ?? ""
        
        var deepLinkUrl: URL?
        
        switch type {
        case "new_strip", "new_comment":
            if let stripId = userInfo["stripId"] as? String, !stripId.isEmpty {
                deepLinkUrl = URL(string: "stripmate://chat/\(stripId)")
            }
        case "new_strip_chat":
            if let stripId = userInfo["stripId"] as? String, !stripId.isEmpty {
                let receiverId = userInfo["receiverId"] as? String ?? ""
                deepLinkUrl = URL(string: "stripmate://chat/\(stripId)/\(receiverId)")
            }
        case "direct_message":
            if let threadId = userInfo["threadId"] as? String, !threadId.isEmpty {
                deepLinkUrl = URL(string: "stripmate://dm/\(threadId)")
            }
        case "friend_request":
            deepLinkUrl = URL(string: "stripmate://inbox")
        case "weekly_summary":
            let week = userInfo["weekNumber"] as? String ?? ""
            let yr = userInfo["year"] as? String ?? ""
            if !week.isEmpty, !yr.isEmpty {
                deepLinkUrl = URL(string: "stripmate://recap/\(yr)/\(week)")
            } else {
                deepLinkUrl = URL(string: "stripmate://history")
            }
        default:
            break
        }
        
        guard let url = deepLinkUrl else { return }
        
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

/// Schema version tracking for safe migrations.
/// When modifying @Model types, create a new VersionedSchema and add a MigrationPlan stage.
enum StripMateSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [User.self, Friend.self, Strip.self]
    }
}

enum StripMateMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StripMateSchemaV1.self]
    }
    
    // Add migration stages here when schema changes in future versions.
    // Example:
    // static var stages: [MigrationStage] { [migrateV1toV2] }
    // static let migrateV1toV2 = MigrationStage.lightweight(fromVersion: StripMateSchemaV1.self, toVersion: StripMateSchemaV2.self)
    static var stages: [MigrationStage] { [] }
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

    let modelConfiguration: ModelConfiguration
    if let url = storeURL {
        modelConfiguration = ModelConfiguration(url: url)
    } else {
        modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
    }

    do {
        return try ModelContainer(
            for: schema,
            migrationPlan: StripMateMigrationPlan.self,
            configurations: [modelConfiguration]
        )
    } catch {
        // Schema migration failed — delete corrupt/incompatible store and recreate.
        // Local SwiftData is a cache of Firestore; data will resync on next launch.
        #if DEBUG
        print("ModelContainer creation failed: \(error). Deleting old store and retrying.")
        #endif

        if let url = storeURL {
            let fileManager = FileManager.default
            let storePath = url.path
            // SQLite uses journal files that must also be removed
            for suffix in ["", "-shm", "-wal"] {
                try? fileManager.removeItem(atPath: storePath + suffix)
            }
        }

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: StripMateMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            // Last resort: in-memory container so the app can still launch
            #if DEBUG
            print("ModelContainer retry failed: \(error). Falling back to in-memory store.")
            #endif
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
    @State private var currentBanner: InAppBanner?
    
    // Guard states (ban, suspend, maintenance)
    @State private var isBanned = false
    @State private var banMessage = ""
    @State private var isSuspended = false
    @State private var suspendedUntil: Date?
    @State private var isInMaintenance = false
    @State private var maintenanceMessage = ""
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if isChecking {
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
                    withAnimation {
                        needsFriendGate = false
                    }
                }
            } else if isInMaintenance {
                maintenanceScreen
            } else if isBanned {
                bannedScreen
            } else if isSuspended {
                suspendedScreen
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
            }
            
            // Check for pending deep link from notification tap (cold start or background)
            if let url = AppDelegate.pendingDeepLinkURL {
                AppDelegate.pendingDeepLinkURL = nil
                // Delay to ensure MainTabView is mounted after cold start
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
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
            // Attempt auto-login (Optimistic for Native feel)
            if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
                self.isAuthenticated = true
                self.isChecking = false
                
                CrashReporter.shared.setUserId(uid)
                AnalyticsService.shared.setUserId(uid)
                
                // Subscribe to topic-based push notifications
                Messaging.messaging().subscribe(toTopic: "daily_prompt")
                
                Task {
                    // Paralelize: profile + friends + guard checks ayni anda
                    async let profileTask = AuthService.shared.fetchProfile(for: uid)
                    async let friendsTask = FriendshipService.shared.hasAnyFriendship()
                    async let guardTask: () = performGuardChecks()

                    let profile = try? await profileTask
                    let hasFriends = await friendsTask
                    await guardTask

                    if let profile, profile.needsProfileCompletion {
                        self.needsProfileCompletion = true
                    }
                    self.needsFriendGate = !hasFriends
                }
            } else {
                self.isAuthenticated = false
                self.isChecking = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
            Task {
                // Paralelize: token + friends + guard ayni anda
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

                let needsCompletion = await AuthService.shared.needsProfileCompletion

                self.needsProfileCompletion = needsCompletion
                self.needsFriendGate = !hasFriends
                withAnimation {
                    self.isAuthenticated = true
                }
            }
            // Subscribe to topic-based push
            Messaging.messaging().subscribe(toTopic: "daily_prompt")
            
            // Sync all data to Apple Watch after login
            WatchSessionManager.shared.performFullSync()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
            withAnimation {
                self.isAuthenticated = false
                self.isBanned = false
                self.isSuspended = false
                self.isInMaintenance = false
            }
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
        // Use Firebase's official auth state listener instead of unreliable onChange
        .onAppear {
            authListenerHandle = FirebaseAuth.Auth.auth().addStateDidChangeListener { _, user in
                let newAuth = (user != nil)
                if self.isAuthenticated != newAuth && !self.isChecking {
                    withAnimation {
                        self.isAuthenticated = newAuth
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
                .foregroundStyle(.red.opacity(0.7))
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
                try? AuthService.shared.logout()
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
                .foregroundStyle(.orange.opacity(0.7))
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
