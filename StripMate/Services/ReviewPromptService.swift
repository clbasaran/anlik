import Foundation

/// Tracks user engagement milestones and signals when to prompt for an App Store review.
///
/// The actual review dialog is shown via `@Environment(\.requestReview)` in MainTabView —
/// this is Apple's recommended approach and the only non-deprecated path on iOS 16+.
/// Apple limits prompts to 3 times per year regardless of how often we call.
enum ReviewPromptService {

    // MARK: - UserDefaults Keys

    private static let appOpenCountKey   = "review_app_open_count"
    private static let lastPromptDateKey = "review_last_prompt_date"
    private static let sendCountKey      = "review_photo_sent_count"
    private static let lastSendCountKey  = "review_last_send_count"

    // MARK: - Config

    /// Minimum days between our own prompts (Apple enforces 3/year on top of this).
    private static let minDaysBetweenPrompts: TimeInterval = 30 * 86_400

    /// App-open counts that trigger a prompt (3rd open is too early; 5th feels natural).
    private static let openMilestones: Set<Int> = [5, 20, 60]

    /// Photo-send counts that trigger a prompt.
    private static let sendMilestones: Set<Int> = [10, 50, 150]

    // MARK: - Public API

    /// Call when MainTabView appears with an authenticated user.
    /// Posts `.requestAppReview` if a milestone is hit and enough time has passed.
    static func recordAppOpen() {
        let count = UserDefaults.standard.integer(forKey: appOpenCountKey) + 1
        UserDefaults.standard.set(count, forKey: appOpenCountKey)
        guard openMilestones.contains(count), canShowPrompt() else { return }
        scheduleReviewRequest()
    }

    /// Call after each successful photo send.
    /// Posts `.requestAppReview` if a milestone is hit and enough time has passed.
    static func recordPhotoSent() {
        let count = UserDefaults.standard.integer(forKey: sendCountKey) + 1
        UserDefaults.standard.set(count, forKey: sendCountKey)
        let lastCount = UserDefaults.standard.integer(forKey: lastSendCountKey)
        guard sendMilestones.contains(count), count > lastCount, canShowPrompt() else { return }
        UserDefaults.standard.set(count, forKey: lastSendCountKey)
        scheduleReviewRequest()
    }

    // MARK: - Private

    private static func canShowPrompt() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastDate) >= minDaysBetweenPrompts
    }

    private static func scheduleReviewRequest() {
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
        // Small delay so the review dialog appears at a calm moment, not mid-animation
        Task {
            try? await Task.sleep(for: .seconds(2))
            NotificationCenter.default.post(name: .requestAppReview, object: nil)
        }
    }
}
