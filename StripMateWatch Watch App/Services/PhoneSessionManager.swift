
import Foundation
import Combine
import WatchConnectivity
import WatchKit

/// Manages WatchConnectivity from the Watch side.
/// Receives streak, photo, and prompt data from the paired iPhone.
final class PhoneSessionManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = PhoneSessionManager()

    /// Throttle: don't fire `requestSync` more than once every 5 seconds.
    /// The iPhone side already throttles at 30s, so spamming requests just
    /// burns battery and pollutes sync-state UI (each rejected request would
    /// otherwise flip the badge red).
    private let requestThrottle: TimeInterval = 5
    private var lastRequestTime: Date = .distantPast
    private let requestLock = NSLock()

    private override init() {
        super.init()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var isReachable: Bool {
        WCSession.default.isReachable
    }

    // MARK: - Request Sync from iPhone

    /// Ask the iPhone to send fresh data.
    func requestSync() {
        // Client-side debounce — see `requestThrottle`.
        requestLock.lock()
        let now = Date()
        if now.timeIntervalSince(lastRequestTime) < requestThrottle {
            requestLock.unlock()
            #if DEBUG
            print("Watch: requestSync throttled")
            #endif
            return
        }
        lastRequestTime = now
        requestLock.unlock()

        guard WCSession.default.isReachable else {
            DispatchQueue.main.async {
                WatchDataStore.shared.markSyncUnavailable()
            }
            #if DEBUG
            print("Watch: iPhone not reachable, skipping sync request")
            #endif
            return
        }

        DispatchQueue.main.async {
            WatchDataStore.shared.markSyncStarted()
        }

        WCSession.default.sendMessage(
            [WatchMessageKey.action: WatchMessageKey.requestSync],
            replyHandler: { [weak self] reply in
                #if DEBUG
                print("Watch: Sync reply received — status: \(reply["status"] ?? "unknown")")
                #endif

                // Parse payload directly from reply
                if let payloadData = reply[WatchMessageKey.syncPayload] as? Data {
                    self?.handleSyncPayload(payloadData)
                } else {
                    DispatchQueue.main.async {
                        WatchDataStore.shared.markSyncFailed()
                    }
                }
            },
            errorHandler: { error in
                DispatchQueue.main.async {
                    WatchDataStore.shared.markSyncFailed()
                }
                #if DEBUG
                print("Watch: requestSync error: \(error.localizedDescription)")
                #endif
            }
        )
    }

    /// Parse and apply sync payload data.
    private func handleSyncPayload(_ data: Data) {
        let payload: WatchSyncPayload
        do {
            payload = try JSONDecoder().decode(WatchSyncPayload.self, from: data)
        } catch {
            // Surface the failure in the sync-state UI; previously this only
            // logged silently, leaving the user staring at a "fresh" badge
            // while local state stayed stale.
            DispatchQueue.main.async {
                WatchDataStore.shared.markSyncFailed()
            }
            #if DEBUG
            print("Watch: Failed to decode sync payload: \(error)")
            #endif
            return
        }

        // Save photo thumbnail to the App Group container so both the Watch
        // app UI (LatestPhotoView) and the widget extension (PhotoComplication)
        // can read it. Per-target documents/ paths are isolated; this is the
        // only shared filesystem.
        var photoURL: URL? = nil
        if let photoData = payload.latestPhotoData, !photoData.isEmpty,
           let destURL = WatchAppGroup.latestPhotoURL {
            do {
                try photoData.write(to: destURL, options: .atomic)
                photoURL = destURL
                #if DEBUG
                print("Watch: Saved photo thumbnail (\(photoData.count) bytes) to App Group container")
                #endif
            } catch {
                #if DEBUG
                print("Watch: Failed to save photo: \(error)")
                #endif
            }
        }

        // `isAuthoritative == true` (or unset, for legacy payloads): empty
        // arrays mean "no data — clear local state". This lets the iPhone tell
        // the watch "all streaks gone, all photos cleared" without ambiguity.
        // `isAuthoritative == false`: only overwrite when the payload carries
        // non-empty data (partial / delta update).
        let authoritative = payload.isAuthoritative ?? true

        DispatchQueue.main.async {
            let store = WatchDataStore.shared

            if authoritative || !payload.streaks.isEmpty {
                store.streaks = payload.streaks
            }
            if authoritative || !payload.latestPhotos.isEmpty {
                store.latestPhotos = payload.latestPhotos
            }
            if authoritative || payload.dailyPrompt != nil {
                store.dailyPrompt = payload.dailyPrompt
            }
            if let userId = payload.currentUserId {
                store.currentUserId = userId
            }
            if let url = photoURL {
                store.latestPhotoFileURL = url
                store.latestPhotoId = payload.latestPhotos.first?.id
            }
            store.markSyncSucceeded(at: payload.syncTimestamp)

            store.persistForComplications()

            WKInterfaceDevice.current().play(.notification)
        }

        #if DEBUG
        print("Watch: Parsed sync payload v\(payload.payloadVersion ?? 1) authoritative=\(authoritative) — \(payload.streaks.count) streaks, \(payload.latestPhotos.count) photos, photo data: \(payload.latestPhotoData?.count ?? 0) bytes, prompt: \(payload.dailyPrompt?.promptText ?? "none")")
        #endif
    }

    // MARK: - Open Camera on iPhone

    /// Tell the iPhone to open the camera screen.
    func openCameraOnPhone() {
        guard WCSession.default.isReachable else {
            DispatchQueue.main.async {
                WatchDataStore.shared.markSyncUnavailable()
            }
            WKInterfaceDevice.current().play(.failure)
            return
        }

        WCSession.default.sendMessage(
            [WatchMessageKey.action: WatchMessageKey.openCamera],
            replyHandler: { reply in
                #if DEBUG
                print("Watch: Camera open — response: \(reply)")
                #endif
                // Play haptic to confirm
                WKInterfaceDevice.current().play(.success)
            },
            errorHandler: { error in
                #if DEBUG
                print("Watch: openCamera error: \(error.localizedDescription)")
                #endif
                WKInterfaceDevice.current().play(.failure)
            }
        )
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        #if DEBUG
        print("Watch: Session activation completed — state: \(activationState.rawValue)")
        #endif
        if error != nil {
            DispatchQueue.main.async {
                WatchDataStore.shared.markSyncFailed()
            }
        }

        if activationState == .activated {
            // Request initial data from iPhone
            requestSync()
        } else {
            DispatchQueue.main.async {
                WatchDataStore.shared.markSyncUnavailable()
            }
        }
    }

    /// Called when iPhone becomes reachable/unreachable.
    func sessionReachabilityDidChange(_ session: WCSession) {
        #if DEBUG
        print("Watch: Reachability changed — isReachable: \(session.isReachable)")
        #endif
        if session.isReachable {
            requestSync()
        } else {
            DispatchQueue.main.async {
                WatchDataStore.shared.markSyncUnavailable()
            }
        }
    }

    /// Receive queued data from iPhone (transferUserInfo — guaranteed delivery).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let payloadData = userInfo[WatchMessageKey.syncPayload] as? Data else { return }
        handleSyncPayload(payloadData)
    }

    /// Receive photo thumbnail file from iPhone. Written to the App Group
    /// container at a fixed path (overwrites any previous photo) so both
    /// the Watch app UI and complications read the same bytes.
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadata = file.metadata ?? [:]
        let photoId = metadata[WatchMessageKey.photoId] as? String ?? UUID().uuidString

        guard let destURL = WatchAppGroup.latestPhotoURL else {
            #if DEBUG
            print("Watch: App Group container unavailable, dropping photo")
            #endif
            return
        }

        do {
            // Overwrite any prior thumbnail in place.
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: file.fileURL, to: destURL)

            DispatchQueue.main.async {
                WatchDataStore.shared.latestPhotoFileURL = destURL
                WatchDataStore.shared.latestPhotoId = photoId
                WatchDataStore.shared.persistForComplications()
            }

            #if DEBUG
            print("Watch: Received photo thumbnail — \(photoId) → App Group")
            #endif
        } catch {
            #if DEBUG
            print("Watch: Failed to save photo file: \(error)")
            #endif
        }
    }

    /// Handle real-time messages from iPhone.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Currently no iPhone→Watch real-time messages needed,
        // but this is where you'd handle them.
    }
}
