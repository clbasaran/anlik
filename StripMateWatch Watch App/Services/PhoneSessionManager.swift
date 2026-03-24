
import Foundation
import Combine
import WatchConnectivity
import WatchKit

/// Manages WatchConnectivity from the Watch side.
/// Receives streak, photo, and prompt data from the paired iPhone.
final class PhoneSessionManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = PhoneSessionManager()
    
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
        guard WCSession.default.isReachable else {
            print("⌚ Watch: iPhone not reachable, skipping sync request")
            return
        }
        
        WCSession.default.sendMessage(
            [WatchMessageKey.action: WatchMessageKey.requestSync],
            replyHandler: { [weak self] reply in
                print("⌚ Watch: Sync reply received — status: \(reply["status"] ?? "unknown")")
                
                // Parse payload directly from reply
                if let payloadData = reply[WatchMessageKey.syncPayload] as? Data {
                    self?.handleSyncPayload(payloadData)
                }
            },
            errorHandler: { error in
                print("⌚ Watch: requestSync error: \(error.localizedDescription)")
            }
        )
    }
    
    /// Parse and apply sync payload data.
    private func handleSyncPayload(_ data: Data) {
        do {
            let payload = try JSONDecoder().decode(WatchSyncPayload.self, from: data)
            
            // Save photo thumbnail to disk if included
            var photoURL: URL? = nil
            if let photoData = payload.latestPhotoData, !photoData.isEmpty {
                let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let photoId = payload.latestPhotos.first?.id ?? "latest"
                let destURL = docsDir.appendingPathComponent("photo_\(photoId).jpg")
                do {
                    try photoData.write(to: destURL)
                    photoURL = destURL
                    print("⌚ Watch: Saved photo thumbnail (\(photoData.count) bytes) to \(destURL.lastPathComponent)")
                } catch {
                    print("⌚ Watch: Failed to save photo: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                let store = WatchDataStore.shared
                
                if !payload.streaks.isEmpty {
                    store.streaks = payload.streaks
                }
                if !payload.latestPhotos.isEmpty {
                    store.latestPhotos = payload.latestPhotos
                }
                if let prompt = payload.dailyPrompt {
                    store.dailyPrompt = prompt
                }
                if let userId = payload.currentUserId {
                    store.currentUserId = userId
                }
                if let url = photoURL {
                    store.latestPhotoFileURL = url
                    store.latestPhotoId = payload.latestPhotos.first?.id
                }
                store.lastSyncDate = payload.syncTimestamp
                
                store.persistForComplications()
                
                WKInterfaceDevice.current().play(.notification)
            }
            
            print("⌚ Watch: Parsed sync payload — \(payload.streaks.count) streaks, \(payload.latestPhotos.count) photos, photo data: \(payload.latestPhotoData?.count ?? 0) bytes, prompt: \(payload.dailyPrompt?.promptText ?? "none")")
        } catch {
            print("⌚ Watch: Failed to decode sync payload: \(error)")
        }
    }
    
    // MARK: - Open Camera on iPhone
    
    /// Tell the iPhone to open the camera screen.
    func openCameraOnPhone() {
        guard WCSession.default.isReachable else { return }
        
        WCSession.default.sendMessage(
            [WatchMessageKey.action: WatchMessageKey.openCamera],
            replyHandler: { reply in
                print("⌚ Watch: Camera open — response: \(reply)")
                // Play haptic to confirm
                WKInterfaceDevice.current().play(.success)
            },
            errorHandler: { error in
                print("⌚ Watch: openCamera error: \(error.localizedDescription)")
                WKInterfaceDevice.current().play(.failure)
            }
        )
    }
}

// MARK: - WCSessionDelegate

extension PhoneSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("⌚ Watch: Session activation completed — state: \(activationState.rawValue)")
        
        if activationState == .activated {
            // Request initial data from iPhone
            requestSync()
        }
    }
    
    /// Called when iPhone becomes reachable/unreachable.
    func sessionReachabilityDidChange(_ session: WCSession) {
        print("⌚ Watch: Reachability changed — isReachable: \(session.isReachable)")
        if session.isReachable {
            requestSync()
        }
    }
    
    /// Receive queued data from iPhone (transferUserInfo — guaranteed delivery).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let payloadData = userInfo[WatchMessageKey.syncPayload] as? Data else { return }
        
        do {
            let payload = try JSONDecoder().decode(WatchSyncPayload.self, from: payloadData)
            
            DispatchQueue.main.async {
                let store = WatchDataStore.shared
                
                // Merge data — only update non-empty arrays (partial updates are valid)
                if !payload.streaks.isEmpty {
                    store.streaks = payload.streaks
                }
                if !payload.latestPhotos.isEmpty {
                    store.latestPhotos = payload.latestPhotos
                }
                if let prompt = payload.dailyPrompt {
                    store.dailyPrompt = prompt
                }
                if let userId = payload.currentUserId {
                    store.currentUserId = userId
                }
                store.lastSyncDate = payload.syncTimestamp
                
                // Persist to UserDefaults for complications
                store.persistForComplications()
                
                // Play haptic for new data
                WKInterfaceDevice.current().play(.notification)
            }
            
            print("⌚ Watch: Received sync payload — \(payload.streaks.count) streaks, \(payload.latestPhotos.count) photos")
        } catch {
            print("⌚ Watch: Failed to decode payload: \(error)")
        }
    }
    
    /// Receive photo thumbnail file from iPhone.
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadata = file.metadata ?? [:]
        let photoId = metadata[WatchMessageKey.photoId] as? String ?? UUID().uuidString
        
        // Move file to permanent location in the watch's documents directory
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = docsDir.appendingPathComponent("photo_\(photoId).jpg")
        
        do {
            // Remove old file if exists
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.moveItem(at: file.fileURL, to: destURL)
            
            DispatchQueue.main.async {
                WatchDataStore.shared.latestPhotoFileURL = destURL
                WatchDataStore.shared.latestPhotoId = photoId
            }
            
            print("⌚ Watch: Received photo thumbnail — \(photoId)")
        } catch {
            print("⌚ Watch: Failed to save photo file: \(error)")
        }
    }
    
    /// Handle real-time messages from iPhone.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Currently no iPhone→Watch real-time messages needed,
        // but this is where you'd handle them.
    }
}
