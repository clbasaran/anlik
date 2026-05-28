import Foundation
import FirebaseFirestore
import WidgetKit

/// Fetches today's daily prompt from Firestore.
/// The prompt is created by a Cloud Function each day; this service reads it.
public actor DailyPromptService {
    public static let shared = DailyPromptService()
    private let db = Firestore.firestore()
    private let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID)

    /// Cached today's prompt
    private var cachedPrompt: DailyPrompt?
    private var cachedDate: String?

    private init() {}

    // MARK: - Fetch Today's Prompt

    /// Returns today's daily prompt. Caches the result for repeated calls.
    public func todaysPrompt() async -> DailyPrompt? {
        let todayString = Self.dateString(for: Date())

        // Return cached if same day
        if let cached = cachedPrompt, cachedDate == todayString {
            return cached
        }

        // Try Firestore
        do {
            let doc = try await db.collection("daily_prompts").document(todayString).getDocument()
            if doc.exists, let data = doc.data() {
                let prompt = parsePrompt(from: data, id: todayString)
                cachedPrompt = prompt
                cachedDate = todayString
                syncPromptToWidget(prompt)
                return prompt
            }
        } catch {
            #if DEBUG
            AppLogger.service.error("DailyPromptService: Failed to fetch from Firestore: \(error.localizedDescription, privacy: .public)")
            #endif
        }

        // Fallback: generate locally based on day-of-year (deterministic)
        let fallback = localFallbackPrompt(for: Date())
        cachedPrompt = fallback
        cachedDate = todayString
        syncPromptToWidget(fallback)
        return fallback
    }

    /// Whether the user has already completed today's prompt (sent a strip today)
    public func hasCompletedToday(userId: String) async -> Bool {
        let todayString = Self.dateString(for: Date())
        do {
            let doc = try await db.collection("daily_prompts").document(todayString)
                .collection("completions").document(userId).getDocument()
            return doc.exists
        } catch {
            return false
        }
    }

    /// Mark today's prompt as completed by the user
    public func markCompleted(userId: String) async {
        let todayString = Self.dateString(for: Date())
        do {
            try await db.collection("daily_prompts").document(todayString)
                .collection("completions").document(userId).setData([
                    "completedAt": FieldValue.serverTimestamp(),
                    "userId": userId
                ])
        } catch {
            #if DEBUG
            AppLogger.service.error("DailyPromptService: Failed to mark completion: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    // MARK: - Helpers

    /// Syncs the prompt text and emoji to App Group so the DailyPrompt widget can read it
    private func syncPromptToWidget(_ prompt: DailyPrompt) {
        let currentText = sharedDefaults?.string(forKey: "daily_prompt_text")
        let currentEmoji = sharedDefaults?.string(forKey: "daily_prompt_emoji")

        // Only write + reload if data actually changed
        guard currentText != prompt.promptText || currentEmoji != prompt.emoji else { return }

        sharedDefaults?.set(prompt.promptText, forKey: "daily_prompt_text")
        sharedDefaults?.set(prompt.emoji, forKey: "daily_prompt_emoji")
        sharedDefaults?.synchronize()

        WidgetCenter.shared.reloadAllTimelines()
        WidgetReloadThrottle.shared.recordDirectReload()

        // Also push to Apple Watch
        let watchPrompt = WatchPrompt(
            id: prompt.id,
            promptText: prompt.promptText,
            emoji: prompt.emoji,
            category: prompt.category.rawValue,
            isCompletedToday: false
        )
        WatchSessionManager.shared.sendPromptUpdate(watchPrompt)

        #if DEBUG
        AppLogger.service.debug("DailyPromptService: Synced prompt to widget + watch — \(prompt.emoji) \(prompt.promptText)")
        #endif
    }

    /// Format date as "yyyy-MM-dd"
    nonisolated static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    /// Deterministic local fallback based on day-of-year
    private nonisolated func localFallbackPrompt(for date: Date) -> DailyPrompt {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let library = DailyPrompt.promptLibrary
        let index = (dayOfYear - 1) % library.count
        let entry = library[index]

        return DailyPrompt(
            id: Self.dateString(for: date),
            promptText: entry.text,
            promptKey: "",
            emoji: entry.emoji,
            category: entry.category,
            activeDate: date
        )
    }

    private nonisolated func parsePrompt(from data: [String: Any], id: String) -> DailyPrompt {
        let categoryRaw = data["category"] as? String ?? "random"
        let category = DailyPrompt.PromptCategory(rawValue: categoryRaw) ?? .random
        let activeDate = (data["activeDate"] as? Timestamp)?.dateValue() ?? Date()

        return DailyPrompt(
            id: id,
            promptText: data["promptText"] as? String ?? "Take a creative photo!",
            promptKey: data["promptKey"] as? String ?? "",
            emoji: data["emoji"] as? String ?? "camera.fill",
            category: category,
            activeDate: activeDate
        )
    }
}
