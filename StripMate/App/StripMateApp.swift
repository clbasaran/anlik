import SwiftUI
import AppIntents
import AVFoundation
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
                            deliver(deepLink: url)
                        }
                    },
                    onDismiss: {
                        currentBanner = nil
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animationAccessible(Brand.Animations.standard, value: currentBanner != nil)
            }
        }
        .preferredColorScheme(.dark)
        // Dynamic Type is supported across the app (Brand.scaledFont); cap at
        // the second accessibility size so extreme sizes don't shatter the
        // camera/feed layouts. Raise the cap screen-by-screen as layouts are
        // verified at larger sizes.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onOpenURL { url in
            // Invite links bypass the regular deep-link routing; the service
            // calls acceptInvite and posts a notification for the welcome toast.
            if InviteService.shared.handleIncoming(url: url) { return }
            deliver(deepLink: url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            // Universal Links land here. Same routing logic as onOpenURL.
            guard let url = activity.webpageURL else { return }
            if InviteService.shared.handleIncoming(url: url) { return }
            deliver(deepLink: url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkNotification)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                deliver(deepLink: url)
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
                    self.deliver(deepLink: url)
                }
            }

            // Check for widget camera launch
            let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
            if sharedDefaults?.bool(forKey: AppGroupKeys.pendingCameraLaunch) == true {
                sharedDefaults?.set(false, forKey: AppGroupKeys.pendingCameraLaunch)
                if let url = URL(string: "stripmate://camera") {
                    deliver(deepLink: url)
                }
            }
        }
        .task {
            // gunluk-dongu-1: warm the camera session while the splash plays
            // so the shutter is ready the moment the camera tab mounts. Needs
            // no auth and must never wait for the Firestore fetches below.
            // Gated on already-granted permission so a cold launch can never
            // trigger the system camera prompt; configureSession is
            // idempotent, so the camera tab's later call is a fast no-op.
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                Task { try? await CameraManager.shared.configureSession() }
            }

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


    // MARK: - Deep Link Delivery

    /// Single funnel for every deep-link entry point (URL open, universal
    /// link, push tap, in-app banner, widget launch) so URL side effects run
    /// exactly once before `MainTabView` performs the tab routing.
    @MainActor
    private func deliver(deepLink url: URL) {
        performDeepLinkSideEffects(for: url)
        pendingDeepLink = url
    }

    /// Side effects that live outside `MainTabView`'s tab switching:
    /// - `stripmate://camera/streak/{streakId}` — a streak push routes to the
    ///   camera; pre-select the at-risk friend as receiver so the
    ///   streak-saving send is one tap away. The streak id is sorted
    ///   "uid1_uid2"; the id that isn't ours is the friend. Written to the
    ///   same UserDefaults key the camera pre-populates its selection from.
    /// - `stripmate://recap[/{year}/{week}]` — after `MainTabView` switches to
    ///   the history tab, ask `HistoryView` (which owns the listener) to
    ///   present the weekly recap story instead of stranding the user on the
    ///   plain feed.
    @MainActor
    private func performDeepLinkSideEffects(for url: URL) {
        guard url.scheme == "stripmate" else { return }
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch url.host {
        case "camera":
            guard pathComponents.count >= 2,
                  pathComponents[0] == "streak",
                  let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
            let ids = pathComponents[1].split(separator: "_").map(String.init)
            guard ids.count == 2, ids.contains(uid),
                  let friendId = ids.first(where: { $0 != uid }) else { return }
            UserDefaults.standard.set([friendId], forKey: "last_selected_receiver_ids")

        case "recap":
            var info: [AnyHashable: Any] = [:]
            if pathComponents.count >= 2 {
                info["year"] = pathComponents[0]
                info["week"] = pathComponents[1]
            }
            // Short delay so the history tab has mounted before the recap
            // story presents (tabs are lazily mounted on first visit).
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                NotificationCenter.default.post(
                    name: Notification.Name("openWeeklyRecap"),
                    object: nil,
                    userInfo: info.isEmpty ? nil : info
                )
            }

        default:
            break
        }
    }

    // MARK: - Guard Checks

    private func performGuardChecks() async {
        // lastActive is telemetry, not a gate — write it fire-and-forget and
        // at most once per 15 minutes so cold start never serializes behind
        // a Firestore write (gunluk-dongu-1).
        if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
            let throttleKey = "last_active_write_at"
            let lastWrite = UserDefaults.standard.object(forKey: throttleKey) as? Date
            if lastWrite == nil || Date().timeIntervalSince(lastWrite ?? .distantPast) > 900 {
                UserDefaults.standard.set(Date(), forKey: throttleKey)
                Task {
                    try? await Firestore.firestore().collection("users").document(uid)
                        .updateData(["lastActive": FieldValue.serverTimestamp()])
                }
            }
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
                .font(Brand.scaledFont(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.white)
            Text(maintenanceMessage.isEmpty ? "Uygulama şu anda bakımda. Lütfen daha sonra tekrar deneyin." : maintenanceMessage)
                .font(Brand.scaledFont(size: 15, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button {
                Task { await performGuardChecks() }
            } label: {
                Text("Tekrar Dene")
                    .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
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
                .font(Brand.scaledFont(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.white)
            if !banMessage.isEmpty {
                Text("Sebep: \(banMessage)")
                    .font(Brand.scaledFont(size: 14, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Text("Bu kararın hatalı olduğunu düşünüyorsanız destek ile iletişime geçin.")
                .font(Brand.scaledFont(size: 13, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button {
                Task { try? await AuthService.shared.logout() }
            } label: {
                Text("Çıkış Yap")
                    .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
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
                .font(Brand.scaledFont(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.white)
            if let until = suspendedUntil {
                Text("Bitiş: \(until.formatted(date: .abbreviated, time: .shortened))")
                    .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                    .foregroundStyle(Brand.error)
            }
            if !banMessage.isEmpty {
                Text("Sebep: \(banMessage)")
                    .font(Brand.scaledFont(size: 14, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Spacer()
            Button {
                Task { await performGuardChecks() }
            } label: {
                Text("Tekrar Kontrol Et")
                    .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
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

// MARK: - Camera Control Launch Intent (iPhone 16+)

/// App context shared with a future LockedCameraCapture extension. Empty for
/// now — the type exists because CameraCaptureIntent requires a Codable context.
struct AnlikCameraAppContext: Codable, Sendable {}

/// Implementing CameraCaptureIntent lists "anlık." in Settings → Camera Control
/// (and the Action button's camera options), so a Camera Control press can
/// launch straight into the app's camera. Reuses the same App Group flag as the
/// Control Center button and the watch, so AppRootRouter routes to the camera
/// tab on foreground.
struct AnlikCameraCaptureIntent: CameraCaptureIntent {
    typealias AppContext = AnlikCameraAppContext

    static let title: LocalizedStringResource = "Kamerayı Aç"
    static let description = IntentDescription("anlık. kamerasını açar")

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: AppConstants.appGroupID)?
            .set(true, forKey: AppGroupKeys.pendingCameraLaunch)
        return .result()
    }
}
