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
                    withAnimation(Brand.Animations.fade) {
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
                .animation(Brand.Animations.standard, value: currentBanner != nil)
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
