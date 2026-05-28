import Foundation
import WatchConnectivity
import UIKit

/// Manages WatchConnectivity from the iPhone side.
/// Pushes streak, photo, and prompt data to the paired Apple Watch.
/// Singleton — activated once in AppDelegate.
public final class WatchSessionManager: NSObject, @unchecked Sendable {
    public static let shared = WatchSessionManager()

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    /// Throttle: avoid sending data more often than every 30 seconds to reduce
    /// Firestore read quota and battery drain from repeated profile fetches.
    private var lastSyncTime: Date = .distantPast
    private let syncThrottleInterval: TimeInterval = 30
    private let lock = NSLock()

    private override init() {
        super.init()
    }

    // MARK: - Activation

    /// Call once from AppDelegate.didFinishLaunchingWithOptions
    public func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    public var isReachable: Bool {
        session?.isReachable ?? false
    }

    public var isPaired: Bool {
        session?.isPaired ?? false
    }

    // MARK: - Send Full Sync Payload

    /// Sends the complete data payload to the watch.
    /// Uses `transferUserInfo` for guaranteed delivery (queued if watch is unreachable).
    public func sendSyncPayload(_ payload: WatchSyncPayload) {
        guard let session, session.activationState == .activated, session.isPaired else { return }

        // Throttle
        lock.lock()
        let now = Date()
        guard now.timeIntervalSince(lastSyncTime) >= syncThrottleInterval else {
            lock.unlock()
            return
        }
        lastSyncTime = now
        lock.unlock()

        do {
            let data = try JSONEncoder().encode(payload)
            let userInfo: [String: Any] = [WatchMessageKey.syncPayload: data]
            session.transferUserInfo(userInfo)
            #if DEBUG
 AppLogger.service.debug("WatchSessionManager: Sent sync payload (\(data.count) bytes, \(payload.streaks.count) streaks, \(payload.latestPhotos.count) photos)")
            #endif
        } catch {
            #if DEBUG
 AppLogger.service.error("WatchSessionManager: Failed to encode payload: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    // MARK: - Send Photo Thumbnail File

    /// Transfers a photo thumbnail to the watch via file transfer.
    /// The thumbnail should be small (≤100KB, ~200px).
    public func sendPhotoThumbnail(_ imageData: Data, photoId: String) {
        guard let session, session.activationState == .activated, session.isPaired else { return }

        // Write to a temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("watch_thumb_\(photoId).jpg")
        do {
            try imageData.write(to: tempURL)
            let metadata: [String: Any] = [WatchMessageKey.photoId: photoId]
            session.transferFile(tempURL, metadata: metadata)
            #if DEBUG
 AppLogger.service.debug("WatchSessionManager: Transferred photo thumbnail (\(imageData.count) bytes, id: \(photoId))")
            #endif
        } catch {
            #if DEBUG
 AppLogger.service.error("WatchSessionManager: Failed to write temp file: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    // MARK: - Convenience: Send Streaks Only

    /// Quick method to push only streak updates to the watch.
    /// Marked non-authoritative so empty arrays in this payload don't wipe
    /// existing latestPhotos / prompt on the watch.
    public func sendStreakUpdate(_ streaks: [WatchStreak]) {
        let payload = WatchSyncPayload(streaks: streaks, isAuthoritative: false)
        sendSyncPayload(payload)
    }

    // MARK: - Convenience: Send Prompt Only

    /// Quick method to push only the daily prompt to the watch.
    /// Marked non-authoritative so empty streaks/photos don't wipe watch state.
    public func sendPromptUpdate(_ prompt: WatchPrompt) {
        let payload = WatchSyncPayload(dailyPrompt: prompt, isAuthoritative: false)
        sendSyncPayload(payload)
    }

    // MARK: - Build Payload from Current App State

    /// Builds a complete WatchSyncPayload from the current app state.
    /// Call this when the watch requests a sync or on app launch.
    public func buildFullPayload() async -> WatchSyncPayload {
        // Ensure streak listener is active (it's lazy — only starts when friends tab is visited)
        let currentUserId = await AuthService.shared.currentUserProfile?.id
        if let uid = currentUserId {
            await StreakService.shared.startListening(for: uid)
            // Wait for streak listener to receive first snapshot (max 2 seconds)
            for _ in 0..<20 {
                let streaks = await StreakService.shared.allStreaksByScore()
                if !streaks.isEmpty { break }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms intervals
            }
        }

        // Gather streaks
        let streakPairs = await StreakService.shared.allStreaksByScore()

        #if DEBUG
 AppLogger.service.debug("WatchSessionManager: buildFullPayload — userId: \(currentUserId ?? "nil"), streakCache count: \(streakPairs.count)")
        #endif

        var watchStreaks: [WatchStreak] = []
        for (friendId, streak) in streakPairs {
            let profile = try? await AuthService.shared.fetchProfile(for: friendId)
            watchStreaks.append(WatchStreak(
                id: streak.id,
                friendId: friendId,
                friendName: profile?.displayName ?? profile?.username ?? String(localized: "arkadaş"),
                friendAvatarUrl: profile?.avatarUrl,
                currentStreak: streak.currentStreak,
                longestStreak: streak.longestStreak,
                totalExchanges: streak.totalExchanges,
                lastExchangeDate: streak.lastExchangeDate,
                lastSenderId: streak.lastSenderId,
                friendshipScore: streak.friendshipScore
            ))
        }

        // Gather latest photos
        let cachedPhotos = await CacheService.shared.lastHistory
        let recentPhotos = Array(cachedPhotos.prefix(5))

        // Batch-fetch sender profiles for all unique senderIds
        let uniqueSenderIds = Set(recentPhotos.map { $0.senderId })
        var senderProfiles: [String: (name: String, avatarUrl: String?)] = [:]
        for senderId in uniqueSenderIds {
            if let profile = try? await AuthService.shared.fetchProfile(for: senderId) {
                senderProfiles[senderId] = (
                    name: profile.displayName ?? profile.username ?? String(localized: "arkadaş"),
                    avatarUrl: profile.avatarUrl
                )
            }
        }

        let latestPhotos: [WatchPhotoInfo] = recentPhotos.compactMap { photo in
            let sender = senderProfiles[photo.senderId]
            return WatchPhotoInfo(
                id: photo.id,
                senderName: sender?.name ?? String(localized: "arkadaş"),
                senderAvatarUrl: sender?.avatarUrl,
                timestamp: photo.timestamp,
                cityName: photo.cityName,
                latitude: photo.latitude,
                longitude: photo.longitude
            )
        }

        // Gather daily prompt
        let prompt = await DailyPromptService.shared.todaysPrompt()
        let isCompleted: Bool
        if let uid = currentUserId {
            isCompleted = await DailyPromptService.shared.hasCompletedToday(userId: uid)
        } else {
            isCompleted = false
        }

        let watchPrompt: WatchPrompt? = prompt.map {
            WatchPrompt(
                id: $0.id,
                promptText: $0.promptText,
                emoji: $0.emoji,
                category: $0.category.rawValue,
                isCompletedToday: isCompleted
            )
        }

        // Download latest photo thumbnail to include in payload
        var photoData: Data? = nil
        if let latestPhoto = cachedPhotos.first(where: { $0.senderId != (currentUserId ?? "") }) {
            let urlString = latestPhoto.smallThumbnailUrl ?? latestPhoto.thumbnailUrl ?? latestPhoto.imageUrl
            if let url = URL(string: urlString) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    // Downsample to ≤200px
                    if let image = UIImage(data: data),
                       let downsampled = await image.byPreparingThumbnail(ofSize: CGSize(width: 200, height: 200)),
                       let thumbData = downsampled.jpegData(compressionQuality: 0.5) {
                        photoData = thumbData
                    } else {
                        photoData = data
                    }
                    #if DEBUG
 AppLogger.service.debug("WatchSessionManager: Photo thumbnail downloaded (\(photoData?.count ?? 0) bytes)")
                    #endif
                } catch {
                    #if DEBUG
 AppLogger.service.error("WatchSessionManager: Failed to download photo: \(error.localizedDescription, privacy: .public)")
                    #endif
                }
            }
        }

        return WatchSyncPayload(
            streaks: watchStreaks,
            latestPhotos: latestPhotos,
            dailyPrompt: watchPrompt,
            currentUserId: currentUserId,
            latestPhotoData: photoData
        )
    }

    /// Builds and sends a full sync payload.
    public func performFullSync() {
        Task {
            let payload = await buildFullPayload()
            sendSyncPayload(payload)

            // Also send the latest photo thumbnail
            await sendLatestPhotoThumbnail()
        }
    }

    /// Downloads and transfers the latest photo thumbnail to the watch.
    private func sendLatestPhotoThumbnail() async {
        let photos = await CacheService.shared.lastHistory
        let currentUserId = await AuthService.shared.currentUserProfile?.id ?? ""
        guard let latest = photos.first(where: { $0.senderId != currentUserId }) else { return }

        // Prefer smallest thumbnail
        let urlString = latest.smallThumbnailUrl ?? latest.thumbnailUrl ?? latest.imageUrl
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            // Downsample to ≤200px for watch
            if let image = UIImage(data: data),
               let downsampled = await image.byPreparingThumbnail(ofSize: CGSize(width: 200, height: 200)),
               let thumbData = downsampled.jpegData(compressionQuality: 0.6) {
                sendPhotoThumbnail(thumbData, photoId: latest.id)
            } else {
                // Use original data if downsampling fails (shouldn't happen)
                sendPhotoThumbnail(data, photoId: latest.id)
            }
        } catch {
            #if DEBUG
 AppLogger.service.error("WatchSessionManager: Failed to download thumbnail: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        #if DEBUG
 AppLogger.service.debug("WatchSessionManager: Activation completed — state: \(activationState.rawValue), error: \(error?.localizedDescription ?? "none")")
        #endif

        if activationState == .activated && session.isPaired {
            // Send initial sync when session activates
            performFullSync()
        }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {
        #if DEBUG
 AppLogger.service.debug("WatchSessionManager: Session became inactive")
        #endif
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        #if DEBUG
 AppLogger.service.debug("WatchSessionManager: Session deactivated — reactivating")
        #endif
        // Reactivate for multi-watch support
        WCSession.default.activate()
    }

    /// Handle real-time messages from the watch (e.g. "open camera", "request sync").
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let action = message[WatchMessageKey.action] as? String else {
            replyHandler(["status": "unknown_action"])
            return
        }

        switch action {
        case WatchMessageKey.openCamera:
            // Tell the iOS app to open the camera (same mechanism as widget)
            DispatchQueue.main.async {
                let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
                sharedDefaults?.set(true, forKey: "pending_camera_launch")
                NotificationCenter.default.post(
                    name: .deepLinkNotification,
                    object: nil,
                    userInfo: ["url": URL(string: "stripmate://camera") as Any]
                )
            }
            replyHandler(["status": "camera_opened"])

        case WatchMessageKey.requestSync:
            // Watch is requesting fresh data — send payload directly in reply for immediate delivery
            Task {
                let payload = await buildFullPayload()
                do {
                    let data = try JSONEncoder().encode(payload)
                    replyHandler([
                        "status": "sync_completed",
                        WatchMessageKey.syncPayload: data
                    ])
                    #if DEBUG
 AppLogger.service.debug("WatchSessionManager: Sent sync payload in reply (\(data.count) bytes, \(payload.streaks.count) streaks, \(payload.latestPhotos.count) photos, prompt: \(payload.dailyPrompt?.promptText ?? "nil"))")
                    #endif
                } catch {
                    replyHandler(["status": "sync_error"])
                    #if DEBUG
 AppLogger.service.error("WatchSessionManager: Failed to encode payload: \(error.localizedDescription, privacy: .public)")
                    #endif
                }
                // Also send photo thumbnail via file transfer (separate channel)
                await sendLatestPhotoThumbnail()
            }

        default:
            replyHandler(["status": "unknown_action"])
        }
    }

    /// Handle messages without reply handler.
    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message[WatchMessageKey.action] as? String else { return }

        if action == WatchMessageKey.requestSync {
            performFullSync()
        }
    }

    /// Called when Watch becomes reachable/unreachable.
    public func sessionReachabilityDidChange(_ session: WCSession) {
        #if DEBUG
 AppLogger.service.debug("WatchSessionManager: Reachability changed — isReachable: \(session.isReachable)")
        #endif
        if session.isReachable {
            performFullSync()
        }
    }

    /// Called when a file transfer completes.
    public func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        // Clean up temp file after transfer
        let fileURL = fileTransfer.file.fileURL
        if fileURL.path.contains("watch_thumb_") {
            try? FileManager.default.removeItem(at: fileURL)
        }
        #if DEBUG
        if let error {
 AppLogger.service.error("WatchSessionManager: File transfer failed: \(error.localizedDescription, privacy: .public)")
        } else {
 AppLogger.service.debug("WatchSessionManager: File transfer completed successfully")
        }
        #endif
    }
}
