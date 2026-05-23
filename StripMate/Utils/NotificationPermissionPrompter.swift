import Foundation
import UIKit
import UserNotifications

/// Delayed notification permission prompter.
///
/// Launch-time permission prompts kill accept rates — the user has no context,
/// no value shown, and clicks "Don't Allow". This helper requests permission
/// only at meaningful moments (after first photo sent, first friend added,
/// first DM received, etc.) where the value is obvious.
///
/// Call `requestIfUndetermined()` from high-intent moments in the app. It's
/// safe to call repeatedly — it only actually prompts once.
public enum NotificationPermissionPrompter {
    private static let hasPromptedKey = "notif_permission_prompted"

    /// Request notification permission if the system hasn't decided yet.
    /// Does nothing if the user previously granted or denied.
    public static func requestIfUndetermined() {
        guard !UserDefaults.standard.bool(forKey: hasPromptedKey) else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                // Already granted or denied — mark as prompted so we don't re-check
                UserDefaults.standard.set(true, forKey: hasPromptedKey)
                return
            }
            let options: UNAuthorizationOptions = [.alert, .badge, .sound]
            AnalyticsService.shared.log(.notificationPermissionPrompted)
            UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
                UserDefaults.standard.set(true, forKey: hasPromptedKey)
                AnalyticsService.shared.log(
                    granted ? .notificationPermissionGranted : .notificationPermissionDenied
                )

                // Mirror grant state into Firestore so Cloud Functions know
                // whether to attempt a push.
                Task {
                    try? await AuthService.shared.updateNotificationPreference(
                        key: "push_enabled",
                        enabled: granted
                    )
                }

                // Register for APNs so FCM token arrives after grant.
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
    }
}
