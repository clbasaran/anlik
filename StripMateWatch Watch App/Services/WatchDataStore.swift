import Foundation
import SwiftUI
import Combine
import WidgetKit

/// Central data store for all watch-side data. Populated by PhoneSessionManager.
/// Observed by all watch views.
final class WatchDataStore: ObservableObject, @unchecked Sendable {
    static let shared = WatchDataStore()

    enum SyncState: String {
        case waiting
        case syncing
        case fresh
        case stale
        case unreachable
        case error
    }
    
    // MARK: - Published State
    
    @Published var streaks: [WatchStreak] = []
    @Published var latestPhotos: [WatchPhotoInfo] = []
    @Published var dailyPrompt: WatchPrompt?
    @Published var currentUserId: String?
    @Published var lastSyncDate: Date?
    @Published var syncState: SyncState = .waiting
    
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

    var syncStatusLabel: String {
        switch syncState {
        case .waiting:
            return String(localized: "watch.sync.waiting")
        case .syncing:
            return String(localized: "watch.sync.syncing")
        case .fresh:
            if let lastSyncDate {
                let relativeString = relativeFormatter.localizedString(for: lastSyncDate, relativeTo: Date())
                return String(format: String(localized: "watch.sync.fresh.relative"), locale: Locale.autoupdatingCurrent, relativeString)
            }
            return String(localized: "watch.sync.fresh")
        case .stale:
            return String(localized: "watch.sync.stale")
        case .unreachable:
            return String(localized: "watch.sync.unreachable")
        case .error:
            return String(localized: "watch.sync.error")
        }
    }

    /// Sync state indicator color. Monochrome by design — opacity-only for
    /// "soft" states (waiting/syncing/stale), `WatchBrand.success` for fresh,
    /// `WatchBrand.error` only for hard failures. Mirrors the iOS brand rule
    /// of avoiding accent colors except for true semantic conditions.
    var syncStatusColor: Color {
        switch syncState {
        case .fresh:
            return WatchBrand.success
        case .syncing:
            return WatchBrand.textPrimary
        case .stale:
            return WatchBrand.textSecondary
        case .unreachable, .error:
            return WatchBrand.error
        case .waiting:
            return WatchBrand.textTertiary
        }
    }

    var emptyStateHint: String {
        switch syncState {
        case .waiting:
            return String(localized: "watch.empty.sync.waiting")
        case .syncing:
            return String(localized: "watch.empty.sync.syncing")
        case .fresh:
            return String(localized: "watch.empty.sync.fresh")
        case .stale:
            return String(localized: "watch.empty.sync.stale")
        case .unreachable:
            return String(localized: "watch.empty.sync.unreachable")
        case .error:
            return String(localized: "watch.empty.sync.error")
        }
    }
    
    // MARK: - Persistence for Complications

    /// Shared with the `StripMateWatchWidgets` extension via App Group.
    /// Writing to `UserDefaults.standard` would be invisible to complications
    /// because each target gets its own sandbox.
    private let defaults = WatchAppGroup.defaults
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.unitsStyle = .short
        return formatter
    }()

    private enum PersistenceKey {
        static let streaks = "watch_persisted_streaks"
        static let latestPhotos = "watch_persisted_latest_photos"
        static let dailyPrompt = "watch_persisted_daily_prompt"
        static let currentUserId = "watch_persisted_current_user_id"
        static let lastSyncDate = "watch_persisted_last_sync_date"
        static let latestPhotoId = "watch_persisted_latest_photo_id"
        static let latestPhotoFilename = "watch_persisted_latest_photo_filename"
    }

    func markSyncStarted() {
        syncState = .syncing
    }

    func markSyncSucceeded(at date: Date) {
        lastSyncDate = date
        syncState = isStale ? .stale : .fresh
    }

    func markSyncUnavailable() {
        syncState = lastSyncDate == nil ? .unreachable : .stale
    }

    func markSyncFailed() {
        syncState = lastSyncDate == nil ? .error : .stale
    }

    func refreshSyncState() {
        guard syncState != .syncing else { return }
        if lastSyncDate == nil {
            if syncState != .unreachable && syncState != .error {
                syncState = .waiting
            }
            return
        }
        syncState = isStale ? .stale : .fresh
    }
    
    func persistForComplications() {
        // Save key values so WidgetKit complications can read them.
        // NOTE: `watch_top_streak_symbol` stores an SF Symbol identifier (e.g.
        // "leaf.fill"), not an emoji. Complications render with Image(systemName:).
        defaults.set(totalActiveStreakCount, forKey: "watch_active_streak_count")
        defaults.set(topStreak?.currentStreak ?? 0, forKey: "watch_top_streak")
        defaults.set(topStreak?.friendName ?? "", forKey: "watch_top_streak_friend")
        defaults.set(topStreak?.tierEmoji ?? "leaf.fill", forKey: "watch_top_streak_symbol")
        defaults.set(dailyPrompt?.promptText ?? "", forKey: "watch_prompt_text")
        defaults.set(dailyPrompt?.isCompletedToday ?? false, forKey: "watch_prompt_completed")
        defaults.set(expiringStreaks.count, forKey: "watch_expiring_count")
        defaults.set(currentUserId, forKey: PersistenceKey.currentUserId)
        defaults.set(lastSyncDate, forKey: PersistenceKey.lastSyncDate)
        defaults.set(latestPhotoId, forKey: PersistenceKey.latestPhotoId)
        // Filename no longer stored — image lives at a fixed path in the App
        // Group container (WatchAppGroup.latestPhotoURL). Clear any legacy
        // value left from prior installs.
        defaults.removeObject(forKey: PersistenceKey.latestPhotoFilename)

        // Clean up the legacy emoji key so old installs don't leak emoji into
        // complications after upgrade.
        defaults.removeObject(forKey: "watch_top_streak_emoji")
        defaults.removeObject(forKey: "watch_prompt_emoji")

        if let data = try? JSONEncoder().encode(streaks) {
            defaults.set(data, forKey: PersistenceKey.streaks)
        }
        if let data = try? JSONEncoder().encode(latestPhotos) {
            defaults.set(data, forKey: PersistenceKey.latestPhotos)
        }
        if let dailyPrompt, let data = try? JSONEncoder().encode(dailyPrompt) {
            defaults.set(data, forKey: PersistenceKey.dailyPrompt)
        } else {
            defaults.removeObject(forKey: PersistenceKey.dailyPrompt)
        }

        // Snapshot the photo metadata needed by the photo complication.
        // (The image bytes live at WatchAppGroup.latestPhotoURL — written by
        // PhoneSessionManager — and are picked up by PhotoComplicationProvider.)
        if let firstPhoto = latestPhotos.first {
            defaults.set(firstPhoto.senderName, forKey: "watch_latest_photo_sender")
            defaults.set(firstPhoto.cityName ?? "", forKey: "watch_latest_photo_city")
            defaults.set(firstPhoto.timestamp, forKey: "watch_latest_photo_time")
        } else {
            defaults.removeObject(forKey: "watch_latest_photo_sender")
            defaults.removeObject(forKey: "watch_latest_photo_city")
            defaults.removeObject(forKey: "watch_latest_photo_time")
        }

        defaults.synchronize()

        // Reload complications
        WidgetCenter.shared.reloadAllTimelines()

        // Prune any legacy thumbnails written before we moved to the App Group
        // container. Safe no-op on fresh installs.
        cleanupLegacyPhotoFiles()
    }

    /// One-time cleanup of `photo_*.jpg` files in the Watch app's private
    /// documents directory. These were written by an earlier code path that
    /// stored thumbnails per-target; everything now lives in the App Group
    /// container shared with the widget extension.
    private func cleanupLegacyPhotoFiles() {
        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: docsDir.path)
            for file in files where file.hasPrefix("photo_") && file.hasSuffix(".jpg") {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(file))
            }
        } catch {
            // Silent — best-effort cleanup, no user-visible impact if it fails.
        }
    }
    
    // MARK: - Load Persisted State
    
    func loadPersistedState() {
        if let data = defaults.data(forKey: PersistenceKey.streaks),
           let decoded = try? JSONDecoder().decode([WatchStreak].self, from: data) {
            streaks = decoded
        }
        if let data = defaults.data(forKey: PersistenceKey.latestPhotos),
           let decoded = try? JSONDecoder().decode([WatchPhotoInfo].self, from: data) {
            latestPhotos = decoded
        }
        if let data = defaults.data(forKey: PersistenceKey.dailyPrompt),
           let decoded = try? JSONDecoder().decode(WatchPrompt.self, from: data) {
            dailyPrompt = decoded
        }

        currentUserId = defaults.string(forKey: PersistenceKey.currentUserId)
        latestPhotoId = defaults.string(forKey: PersistenceKey.latestPhotoId)
        lastSyncDate = defaults.object(forKey: PersistenceKey.lastSyncDate) as? Date

        // The image is at a fixed path in the App Group container, shared
        // with the widget extension. Only surface the URL if the file is
        // actually present (e.g. fresh install hasn't received any photos).
        if let url = WatchAppGroup.latestPhotoURL,
           FileManager.default.fileExists(atPath: url.path) {
            latestPhotoFileURL = url
        }

        refreshSyncState()
    }
    
    private init() {}
}
