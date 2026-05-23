import BackgroundTasks
import WidgetKit
import Foundation

/// Owns the BGAppRefreshTask lifecycle for the home widget. Pulled out of
/// `AppDelegate` so the registration, scheduling, and handler logic live in
/// one place — and so the delegate stops conflating "I am a Firebase delegate"
/// with "I am a BGTaskScheduler client".
///
/// Lifecycle:
/// 1. `register()` runs once during `application(_:didFinishLaunchingWithOptions:)`.
/// 2. `schedule()` is called whenever the app is about to lose foreground.
/// 3. iOS calls back into `handle(_:)` when it decides to give us time.
public final class WidgetRefreshTaskCoordinator {
    public static let shared = WidgetRefreshTaskCoordinator()

    private static let taskIdentifier = "com.celalbasaran.stripmate.widget-refresh"

    private init() {}

    /// Register the handler. Must be called before app launch returns —
    /// BGTaskScheduler will assert if a submitted task has no registered
    /// handler at firing time.
    public func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handle(refreshTask)
        }
    }

    /// Submit a refresh request. Idempotent — if iOS has already queued one,
    /// this just resets the earliest-begin window.
    public func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: AppLimits.widgetRefreshInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // iOS throttles submission once the app exceeds its background budget;
            // logging keeps "widget never refreshes" investigations honest.
            AppLogger.app.error("BG widget refresh schedule failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Run when iOS hands us a refresh window. Compares NSE-written timestamps
    /// against the widget's last render and reloads only if new data exists,
    /// then reschedules for the next window before reporting completion.
    private func handle(_ task: BGAppRefreshTask) {
        // iOS gives BGAppRefreshTask ~30s before it kills the task. If we exceed
        // that without calling setTaskCompleted, iOS throttles future
        // scheduling. The expiration handler ensures we always report
        // completion (even as failure).
        task.expirationHandler = {
            AppLogger.app.error("BG widget refresh expired before completion")
            task.setTaskCompleted(success: false)
        }

        // App Group container is required to coordinate with NSE; if it's nil,
        // either entitlements are misconfigured or the system is in a degraded
        // state. Report failure so iOS knows this run didn't accomplish its
        // work and can throttle gracefully.
        guard let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID) else {
            AppLogger.app.error("BG widget refresh failed: app group defaults unavailable")
            schedule()
            task.setTaskCompleted(success: false)
            return
        }

        let nseTime = sharedDefaults.double(forKey: AppGroupKeys.latestPhotoTime)
        let widgetTime = sharedDefaults.double(forKey: AppGroupKeys.widgetLastTimeline)

        if nseTime > widgetTime {
            // NSE saved newer data than the widget last rendered.
            WidgetCenter.shared.reloadTimelines(ofKind: "StripMateWidget")
        }

        // Reschedule for next check (best-effort; logs on failure).
        schedule()
        task.setTaskCompleted(success: true)
    }
}
