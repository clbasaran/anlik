import Foundation
import SwiftUI
import Combine
import WidgetKit

/// Central data store for all watch-side data. Populated by PhoneSessionManager.
/// Observed by all watch views.
final class WatchDataStore: ObservableObject, @unchecked Sendable {
    static let shared = WatchDataStore()
    
    // MARK: - Published State
    
    @Published var streaks: [WatchStreak] = []
    @Published var latestPhotos: [WatchPhotoInfo] = []
    @Published var dailyPrompt: WatchPrompt?
    @Published var currentUserId: String?
    @Published var lastSyncDate: Date?
    
    /// URL to the latest photo thumbnail saved on disk.
    @Published var latestPhotoFileURL: URL?
    @Published var latestPhotoId: String?
    
    // MARK: - Computed
    
    var activeStreaks: [WatchStreak] {
        streaks.filter { $0.currentStreak > 0 }.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    var expiringStreaks: [WatchStreak] {
        streaks.filter { $0.isExpiringSoon }
    }
    
    var topStreak: WatchStreak? {
        activeStreaks.first
    }
    
    var totalActiveStreakCount: Int {
        activeStreaks.count
    }
    
    var isStale: Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > 600 // 10 minutes
    }
    
    // MARK: - Persistence for Complications
    
    private let defaults = UserDefaults.standard
    
    func persistForComplications() {
        // Save key values so WidgetKit complications can read them
        defaults.set(totalActiveStreakCount, forKey: "watch_active_streak_count")
        defaults.set(topStreak?.currentStreak ?? 0, forKey: "watch_top_streak")
        defaults.set(topStreak?.friendName ?? "", forKey: "watch_top_streak_friend")
        defaults.set(topStreak?.tierEmoji ?? "🌱", forKey: "watch_top_streak_emoji")
        defaults.set(dailyPrompt?.promptText ?? "", forKey: "watch_prompt_text")
        defaults.set(dailyPrompt?.emoji ?? "📸", forKey: "watch_prompt_emoji")
        defaults.set(dailyPrompt?.isCompletedToday ?? false, forKey: "watch_prompt_completed")
        defaults.set(expiringStreaks.count, forKey: "watch_expiring_count")
        defaults.synchronize()
        
        // Reload complications
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Load Persisted State
    
    func loadPersistedState() {
        // Complications data is available via UserDefaults
        // Full data comes from WatchConnectivity
    }
    
    private init() {}
}
