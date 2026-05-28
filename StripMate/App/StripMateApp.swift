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
