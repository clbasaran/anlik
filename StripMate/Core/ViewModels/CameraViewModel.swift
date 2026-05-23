import Foundation
import AVFoundation
import SwiftUI
import CoreLocation
import WidgetKit
import FirebaseAuth

@MainActor
@Observable
public final class CameraViewModel {
    public var capturedPhotoData: Data? = nil
    public var isFlashActive: Bool = false
    public var isFlashModeOn: Bool = false
    public var isAuthorized: Bool = false
    public var permissionDenied: Bool = false
    public var isSessionRunning: Bool = false
    public var isUploading: Bool = false
    public var isSuccessBoomActive: Bool = false
    public var errorMessage: String?

    // Retry state for failed uploads (photo or video)
    private var pendingRetryImage: UIImage?
    private var pendingRetryReceivers: [String] = []
    private var pendingRetryLat: Double?
    private var pendingRetryLon: Double?
    private var pendingRetryCity: String?
    private var pendingRetryComment: String?
    private var pendingRetryVoice: Data?
    private var pendingRetrySecret: Bool = false
    private var pendingRetryVideoURL: URL?
    private var pendingRetryVideoDuration: Double = 0
    private var pendingRetryVideoWithSound: Bool = true
    public var canRetry: Bool { pendingRetryImage != nil || pendingRetryVideoURL != nil }

    public func retrySend() {
        // Video retry
        if let videoURL = pendingRetryVideoURL {
            let receivers = pendingRetryReceivers
            let lat = pendingRetryLat
            let lon = pendingRetryLon
            let city = pendingRetryCity
            let comment = pendingRetryComment
            let secret = pendingRetrySecret
            let duration = pendingRetryVideoDuration
            let sendWithSound = pendingRetryVideoWithSound
            let thumbnail = extractThumbnail(from: videoURL)

            guard let thumbnail else {
                // Keep retry state intact so user can try again
                errorMessage = "video önizlemesi oluşturulamadı, tekrar dene."
                return
            }

            clearRetryState()

            TabBarState.shared.isSendingPhoto = true
            Task {
                do {
                    let preparedVideoURL = try await preparedVideoURLForSending(from: videoURL, includeAudio: sendWithSound)
                    let photoId = try await deps.stripRepository.sendPhoto(
                        thumbnail, to: receivers, latitude: lat, longitude: lon,
                        cityName: city, voiceData: nil, isSecret: secret,
                        videoFileURL: preparedVideoURL, videoDuration: duration
                    )
                    if let comment, !comment.isEmpty {
                        for receiverId in receivers where receiverId != Auth.auth().currentUser?.uid {
                            try? await deps.stripRepository.sendStripChatMessage(
                                text: comment, stripId: photoId, chatPartnerId: receiverId,
                                replyToId: nil, replyToText: nil, replyToSenderId: nil, voiceUrl: nil
                            )
                        }
                    }
                    HapticsManager.playNotification(type: .success)
                    SoundManager.shared.playSound(effect: .paperplaneWhoosh)
                    WidgetCenter.shared.reloadAllTimelines()
                    if preparedVideoURL != videoURL {
                        try? FileManager.default.removeItem(at: preparedVideoURL)
                    }
                    try? FileManager.default.removeItem(at: videoURL)
                } catch {
                    HapticsManager.playNotification(type: .error)
                    self.pendingRetryVideoURL = videoURL
                    self.pendingRetryReceivers = receivers
                    self.pendingRetryLat = lat
                    self.pendingRetryLon = lon
                    self.pendingRetryCity = city
                    self.pendingRetryComment = comment
                    self.pendingRetrySecret = secret
                    self.pendingRetryVideoDuration = duration
                    self.pendingRetryVideoWithSound = sendWithSound
                    self.persistDraft()
                    self.errorMessage = "video gönderilemedi. tekrar dene."
                }
                TabBarState.shared.isSendingPhoto = false
            }
            return
        }

        // Photo retry
        guard let image = pendingRetryImage else { return }
        let receivers = pendingRetryReceivers
        let lat = pendingRetryLat
        let lon = pendingRetryLon
        let city = pendingRetryCity
        let comment = pendingRetryComment
        let voice = pendingRetryVoice
        let secret = pendingRetrySecret
        clearRetryState()

        TabBarState.shared.isSendingPhoto = true
        Task {
            do {
                let photoId = try await deps.stripRepository.sendPhoto(
                    image, to: receivers, latitude: lat, longitude: lon,
                    cityName: city, voiceData: voice, isSecret: secret
                )
                if let comment, !comment.isEmpty {
                    for receiverId in receivers where receiverId != Auth.auth().currentUser?.uid {
                        try? await deps.stripRepository.sendStripChatMessage(
                            text: comment, stripId: photoId, chatPartnerId: receiverId,
                            replyToId: nil, replyToText: nil, replyToSenderId: nil, voiceUrl: nil
                        )
                    }
                }
                HapticsManager.playNotification(type: .success)
                SoundManager.shared.playSound(effect: .paperplaneWhoosh)
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                HapticsManager.playNotification(type: .error)
                self.pendingRetryImage = image
                self.pendingRetryReceivers = receivers
                self.pendingRetryLat = lat
                self.pendingRetryLon = lon
                self.pendingRetryCity = city
                self.pendingRetryComment = comment
                self.pendingRetryVoice = voice
                self.pendingRetrySecret = secret
                self.persistDraft()
                self.errorMessage = "gönderilemedi. tekrar dene."
            }
            TabBarState.shared.isSendingPhoto = false
        }
    }

    /// Public escape hatch — drops the persisted draft when the user taps
    /// "vazgeç" on the camera banner. Equivalent to clearRetryState() but
    /// reachable from outside the VM and broadcasts haptic feedback.
    public func cancelDraft() {
        clearRetryState()
        HapticsManager.playImpact(style: .light)
    }

    private func clearRetryState() {
        pendingRetryImage = nil
        pendingRetryReceivers = []
        pendingRetryLat = nil
        pendingRetryLon = nil
        pendingRetryCity = nil
        pendingRetryComment = nil
        pendingRetryVoice = nil
        pendingRetrySecret = false
        pendingRetryVideoURL = nil
        pendingRetryVideoDuration = 0
        pendingRetryVideoWithSound = true
        // Wipe persisted draft too — they share the same lifecycle.
        DraftStore.shared.clear()
    }

    /// Snapshot the current pendingRetry state to disk so the upload can be
    /// resumed across app kills. Called after every site that sets retry
    /// fields (failed photo / failed video).
    private func persistDraft() {
        DraftStore.shared.save(
            receivers: pendingRetryReceivers,
            comment: pendingRetryComment,
            latitude: pendingRetryLat,
            longitude: pendingRetryLon,
            cityName: pendingRetryCity,
            isSecret: pendingRetrySecret,
            videoDuration: pendingRetryVideoURL != nil ? pendingRetryVideoDuration : nil,
            videoIncludesSound: pendingRetryVideoWithSound,
            image: pendingRetryImage,
            videoURL: pendingRetryVideoURL,
            voiceData: pendingRetryVoice
        )
    }

    /// Restore a persisted draft from a previous launch. Called once from
    /// init. Does nothing if no draft is on disk.
    private func restoreDraftFromDiskIfAny() {
        guard let restored = DraftStore.shared.restore() else { return }
        pendingRetryImage = restored.image
        pendingRetryVideoURL = restored.videoURL
        pendingRetryVoice = restored.voiceData
        let snap = restored.snapshot
        pendingRetryReceivers = snap.receivers
        pendingRetryComment = snap.comment
        pendingRetryLat = snap.latitude
        pendingRetryLon = snap.longitude
        pendingRetryCity = snap.cityName
        pendingRetrySecret = snap.isSecret
        pendingRetryVideoDuration = snap.videoDuration ?? 0
        pendingRetryVideoWithSound = snap.videoIncludesSound
    }

    // Flash mode (off/on/auto)
    public var flashSetting: FlashSetting = .off
    
    // Exposure control
    public var exposureBias: Float = 0.0
    

    
    // Location data for current capture
    public var currentLatitude: Double? = nil
    public var currentLongitude: Double? = nil
    public var currentCityName: String? = nil

    /// True when the user has explicitly disabled location attachment under
    /// Privacy → "konum paylaşımı". Defaults to false (sharing enabled).
    private var locationSharingDisabled: Bool {
        // UserDefaults stores nil on first launch → use explicit object lookup
        // so we don't silently treat missing as "off".
        let value = UserDefaults.standard.object(forKey: "privacy_share_location") as? Bool
        return value == false
    }

    /// Returns the values that should actually leave the device on a strip
    /// upload, with the location privacy toggle applied. UI state remains
    /// untouched so the camera HUD can still show the user their own city.
    private func sanitizedLocationForUpload(lat: Double?, lon: Double?, city: String?) -> (Double?, Double?, String?) {
        if locationSharingDisabled { return (nil, nil, nil) }
        return (lat, lon, city)
    }
    
    // Multi-Friend selection
    public var availableFriends: [FriendStatus] = []
    public var selectedReceiverIds: Set<String> = []

    // Initial comment to send with the photo
    public var initialComment: String = ""

    // Secret moment toggle
    public var isSecret: Bool = false

    // Voice recording data
    public var voiceData: Data?

    // MARK: - Video Clip State
    public var capturedVideoURL: URL? = nil
    public var videoDuration: Double = 0
    public var sendVideoWithSound: Bool = true
    public var isRecordingVideo: Bool = false
    public var videoRecordingProgress: Double = 0  // 0.0 to 1.0
    public var videoGuidanceMessage: String?
    public let minimumVideoDuration: Double = 2.0
    public var isVideoReadyToFinish: Bool { videoDuration >= minimumVideoDuration }
    /// Timer + Task stored in `IsolatedRef` so the nonisolated `deinit` can
    /// invalidate/cancel without `nonisolated(unsafe)`.
    private let recordingTimer = IsolatedRef<Timer?>(nil)
    private var recordingStartTime: Date?
    private let videoGuidanceDismissTask = IsolatedRef<Task<Void, Never>?>(nil)
    private var shouldDiscardCurrentRecording = false

    public var isVideoMode: Bool { capturedVideoURL != nil }

    // MARK: - Capture mode picker (Faz A)

    /// Active capture mode chosen via the bottom mode picker. Long-press on
    /// the shutter still triggers video regardless of mode (preserved from
    /// pre-Faz-A behavior). Boomerang / kolaj capture pipelines arrive in
    /// Faz B and Faz C; in Faz A those modes are selectable but route to
    /// existing flows so no behavior is broken.
    public var captureMode: CameraMode = .foto

    /// Self-timer for the next capture. Cycle off → 3sn → 10sn via the tool
    /// cluster.
    public var timerSetting: CameraTimer = .off

    /// Rule-of-thirds overlay toggle. Drawn in MainCameraView when on.
    public var gridEnabled: Bool = false

    /// Target photo count when capturing a collage from the camera (Faz B).
    /// User picks 2/3/4 from the count selector that appears in kolaj mode.
    /// Once `collageState.photos.count` hits this number, CollageScreen
    /// auto-opens for editing.
    public var kolajPlannedCount: Int = 3

    // Collage mode (v2 — single CollageState owns photos/preset/transforms)
    public var isCollageMode: Bool = false
    public var showCollageView: Bool = false
    public var collageReplaceIndex: Int?
    public var collageState: CollageState?
    /// Mirror of collageState.photos.count for the few legacy call sites
    /// that still ask "are we in collage?". Kept as a thin pass-through.
    public var collagePhotos: [UIImage] {
        get { collageState?.photos ?? [] }
        set {
            if let s = collageState {
                // Direct assignment isn't supported on @Observable in a clean
                // way; rebuild state from the new list. Used by retry paths.
                collageState = CollageState(photos: newValue, preset: s.preset)
            } else if !newValue.isEmpty {
                collageState = CollageState(photos: newValue)
            }
        }
    }

    public var isFrontCamera: Bool = false

    // Ring flash state
    public var showRingFlash: Bool = false

    private let cameraManager = CameraManager.shared
    private let deps = DependencyContainer.shared

    /// Drop the cached friend list when the global friend graph changes so
    /// the next preview / send sheet reflects the freshly added (or removed)
    /// friend without an app relaunch.
    private let friendListChangeObserver = IsolatedRef<NSObjectProtocol?>(nil)

    public init() {
        // Restore last used camera lens
        self.isFrontCamera = UserDefaults.standard.bool(forKey: "last_camera_front")

        // Rehydrate any draft from a prior launch — surfaces a "tekrar dene"
        // banner on the camera so a kill / network blip doesn't lose the user's
        // upload.
        restoreDraftFromDiskIfAny()

        // Listen for friend graph changes (new friend accepted, friend removed,
        // user blocked / unblocked) and invalidate the cached availableFriends
        // so the next fetch hits the network.
        let token = NotificationCenter.default.addObserver(
            forName: .friendListChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.friendsCacheTime = nil
                await self?.fetchAvailableFriends()
            }
        }
        friendListChangeObserver.value = token
    }

    deinit {
        recordingTimer.value?.invalidate()
        videoGuidanceDismissTask.value?.cancel()
        if let token = friendListChangeObserver.value {
            NotificationCenter.default.removeObserver(token)
        }
    }

    public func checkAndConfigure() async {
        let authorized = await cameraManager.checkAuthorization()
        self.isAuthorized = authorized
        self.permissionDenied = !authorized && AVCaptureDevice.authorizationStatus(for: .video) == .denied

        if authorized {
            do {
                try await cameraManager.configureSession()
                // Restore saved camera lens preference
                if isFrontCamera {
                    let position = await cameraManager.currentCameraPosition
                    if position != .front {
                        try? await cameraManager.toggleCamera()
                    }
                }
                self.startSession()
                // Request location permission early
                LocationManager.shared.requestPermission()
            } catch {
                #if DEBUG
                print("Failed to configure camera session: \\(error.localizedDescription)")
                #endif
            }
        }
    }
    
    public func startSession() {
        Task {
            await cameraManager.startSession()
            self.isSessionRunning = true
        }
    }
    
    public func stopSession() {
        Task { @MainActor in
            await cameraManager.stopSession()
            self.isSessionRunning = false
        }
    }
    
    public func toggleCamera() {
        HapticsManager.playSelection()
        Task {
            do {
                try await cameraManager.toggleCamera()
                // Update front/back state after switch
                let position = await cameraManager.currentCameraPosition
                self.isFrontCamera = (position == .front)
                UserDefaults.standard.set(isFrontCamera, forKey: "last_camera_front")
            } catch {
                #if DEBUG
                print("Failed to toggle camera: \\(error.localizedDescription)")
                #endif
            }
        }
    }
    
    public func toggleFlash() {
        HapticsManager.playSelection()
        Task {
            await cameraManager.cycleFlashMode()
            let setting = await cameraManager.flashMode
            let isOn = await cameraManager.isFlashModeOn
            self.flashSetting = setting
            self.isFlashModeOn = isOn
        }
    }
    

    /// Focus at normalized point
    public func focusAt(_ point: CGPoint) {
        Task {
            await cameraManager.focus(at: point)
        }
    }
    
    public func setExposure(_ bias: Float) {
        self.exposureBias = bias
        Task {
            await cameraManager.setExposure(bias)
        }
    }
    
    private var friendsCacheTime: Date?

    public func fetchAvailableFriends() async {
        // 5 dakika icinde tekrar cekme
        if !availableFriends.isEmpty,
           let cacheTime = friendsCacheTime,
           -cacheTime.timeIntervalSinceNow < 300 {
            return
        }
        do {
            let friends = try await deps.friendRepository.fetchFriends()
            self.availableFriends = friends.filter { !$0.isPending }
            self.friendsCacheTime = Date()

            // Pre-populate with last selected friends if none selected yet
            if selectedReceiverIds.isEmpty {
                let lastIds = Set(UserDefaults.standard.stringArray(forKey: "last_selected_receiver_ids") ?? [])
                let validIds = lastIds.intersection(Set(availableFriends.map { $0.userId }))
                if !validIds.isEmpty {
                    selectedReceiverIds = validIds
                }
            }
        } catch {
            #if DEBUG
            print("Failed to fetch friends: \(error.localizedDescription)")
            #endif
        }
    }
    
    public func capturePhoto() async {
        guard isSessionRunning else { return }
        
        HapticsManager.playImpact(style: .medium)
        
        do {
            // Fire camera capture and location fetch in parallel — location never blocks the shutter
            async let photoTask = cameraManager.capturePhoto()
            async let locationTask = LocationManager.shared.fetchLocation()

            let photoData = try await photoTask
            

            self.capturedPhotoData = photoData
            
            if LocationManager.shared.authorizationStatus == .authorizedWhenInUse || LocationManager.shared.authorizationStatus == .authorizedAlways {
                let (location, city) = await locationTask
                self.currentLatitude = location?.coordinate.latitude
                self.currentLongitude = location?.coordinate.longitude
                self.currentCityName = city
            } else {
                self.currentLatitude = nil
                self.currentLongitude = nil
                self.currentCityName = nil
            }
            
            AnalyticsService.shared.log(.capturePhoto, parameters: ["has_location": currentCityName != nil])
            
            // Preload friends for the Send Sheet (uses 5-minute cache)
            await fetchAvailableFriends()
        } catch {
            #if DEBUG
            print("Failed to capture photo: \(error.localizedDescription)")
            #endif
        }
    }
    
    // MARK: - Video Recording

    public func startVideoRecording() {
        guard !isRecordingVideo else { return }
        isRecordingVideo = true
        videoDuration = 0
        videoRecordingProgress = 0
        shouldDiscardCurrentRecording = false
        recordingStartTime = Date()
        updateVideoGuidance(for: 0)

        HapticsManager.playImpact(style: .heavy)

        // Progress timer
        recordingTimer.value = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, let startTime = self.recordingStartTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                self.videoRecordingProgress = min(elapsed / 5.0, 1.0)
                self.videoDuration = elapsed
                self.updateVideoGuidance(for: elapsed)
            }
        }

        Task {
            // Guarantee timer/flag cleanup on every exit path (success, error, or discard)
            defer {
                self.isRecordingVideo = false
                self.recordingTimer.value?.invalidate()
                self.recordingTimer.value = nil
            }
            do {
                let videoURL = try await cameraManager.startVideoRecording()
                // Use the actual wall-clock elapsed since recordingStartTime
                // instead of the timer-cached self.videoDuration. The timer
                // fires every 50ms, so videoDuration can lag the real elapsed
                // by up to a tick — enough to reject a 2.05s recording as
                // "1.95s < min" and silently discard it without the user ever
                // seeing the preview. Wall-clock matches what the stop path
                // already evaluates.
                let actualElapsed = Date().timeIntervalSince(self.recordingStartTime ?? Date())
                let finalDuration = min(actualElapsed, 5.0)
                let shouldDiscard = self.shouldDiscardCurrentRecording || finalDuration < self.minimumVideoDuration

                self.videoDuration = finalDuration

                CrashReporter.shared.breadcrumb(.camera, "video recorded actualElapsed=\(String(format: "%.2f", actualElapsed)) discard=\(shouldDiscard)")

                if shouldDiscard {
                    try? FileManager.default.removeItem(at: videoURL)
                    self.capturedVideoURL = nil
                    self.videoDuration = 0
                    self.videoRecordingProgress = 0
                    self.showTransientVideoGuidance(String(localized: "çok az kaldı, biraz daha uzun tut"))
                    return
                }

                self.capturedVideoURL = videoURL
                CrashReporter.shared.breadcrumb(.camera, "video preview opening duration=\(String(format: "%.2f", finalDuration))")
                self.videoGuidanceDismissTask.value?.cancel()
                self.videoGuidanceDismissTask.value = nil
                self.videoGuidanceMessage = nil

                // Fetch location and friends in parallel
                if LocationManager.shared.authorizationStatus == .authorizedWhenInUse || LocationManager.shared.authorizationStatus == .authorizedAlways {
                    let (location, city) = await LocationManager.shared.fetchLocation()
                    self.currentLatitude = location?.coordinate.latitude
                    self.currentLongitude = location?.coordinate.longitude
                    self.currentCityName = city
                }
                await fetchAvailableFriends()
            } catch {
                self.videoGuidanceDismissTask.value?.cancel()
                self.videoGuidanceDismissTask.value = nil
                self.videoGuidanceMessage = nil
                self.errorMessage = String(localized: "Video kaydedilemedi")
            }
        }
    }

    public func stopVideoRecording() {
        guard isRecordingVideo else { return }
        let elapsed = Date().timeIntervalSince(recordingStartTime ?? Date())

        if elapsed < minimumVideoDuration {
            shouldDiscardCurrentRecording = true
            Task { await cameraManager.stopVideoRecording() }
            isRecordingVideo = false
            recordingTimer.value?.invalidate()
            recordingTimer.value = nil
            updateVideoGuidance(for: elapsed)
        } else {
            Task { await cameraManager.stopVideoRecording() }
        }
    }

    /// Synchronous fallback for callers that cannot use async
    public func extractThumbnail(from videoURL: URL) -> UIImage? {
        return cachedVideoThumbnail ?? extractThumbnailSync(from: videoURL)
    }

    /// Cached thumbnail — set by async extraction
    @ObservationIgnored private var cachedVideoThumbnail: UIImage?

    /// Async thumbnail extraction — runs off main thread to avoid UI freeze
    public func extractThumbnailAsync(from videoURL: URL) async -> UIImage? {
        if let cached = cachedVideoThumbnail { return cached }
        let image: UIImage? = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let asset = AVAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1440, height: 1440)
            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                return UIImage(cgImage: cgImage)
            } catch {
                return nil
            }
        }.value
        await MainActor.run {
            cachedVideoThumbnail = image
            if image == nil {
                self.errorMessage = String(localized: "Video onizlemesi olusturulamadi")
            }
        }
        return image
    }

    private func extractThumbnailSync(from videoURL: URL) -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1440, height: 1440)
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            cachedVideoThumbnail = image
            return image
        } catch {
            #if DEBUG
            print("DEBUG: Failed to extract video thumbnail: \(error.localizedDescription)")
            #endif
            self.errorMessage = String(localized: "Video onizlemesi olusturulamadi")
            return nil
        }
    }

    public func retakePhoto() {
        // Clear video state
        if let videoURL = capturedVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        capturedVideoURL = nil
        videoDuration = 0
        videoRecordingProgress = 0
        shouldDiscardCurrentRecording = false
        isRecordingVideo = false
        recordingTimer.value?.invalidate()
        recordingTimer.value = nil
        videoGuidanceDismissTask.value?.cancel()
        videoGuidanceDismissTask.value = nil
        videoGuidanceMessage = nil

        self.capturedPhotoData = nil
        self.currentLatitude = nil
        self.currentLongitude = nil
        self.currentCityName = nil
        self.initialComment = ""
        self.voiceData = nil
        self.isSecret = false
        self.sendVideoWithSound = true
        // Clear collage state on full retake
        self.collagePhotos = []
        self.isCollageMode = false
        self.showCollageView = false
        self.collageReplaceIndex = nil
        self.startSession()
    }

    private func updateVideoGuidance(for elapsed: Double) {
        videoGuidanceDismissTask.value?.cancel()
        videoGuidanceDismissTask.value = nil

        if elapsed < minimumVideoDuration {
            videoGuidanceMessage = String(localized: "videoyu göndermek için biraz daha çek")
        } else {
            videoGuidanceMessage = String(localized: "tamam, bırakınca önizleme açılır")
        }
    }

    private func showTransientVideoGuidance(_ message: String, seconds: Double = 1.8) {
        videoGuidanceDismissTask.value?.cancel()
        videoGuidanceMessage = message
        videoGuidanceDismissTask.value = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self.videoGuidanceMessage = nil
        }
    }
    
    // MARK: - Collage Mode

    /// Starts collage mode with the currently captured photo as the first image.
    public func startCollage() {
        guard let data = capturedPhotoData, let image = UIImage(data: data) else { return }
        collageState = CollageState(photos: [image])
        isCollageMode = true
        showCollageView = false
        capturedPhotoData = nil
        startSession()
    }

    /// Adds the current captured photo to the collage. If a replace index is
    /// pending, swaps that slot and opens CollageScreen immediately. In
    /// from-camera mode, accumulates until `kolajPlannedCount` is hit, then
    /// opens CollageScreen.
    public func addToCollage() {
        guard let data = capturedPhotoData, let image = UIImage(data: data) else { return }

        let isReplacing = collageReplaceIndex != nil

        if collageState == nil {
            collageState = CollageState(photos: [image])
        } else if let s = collageState {
            if let replaceIdx = collageReplaceIndex, s.photos.indices.contains(replaceIdx) {
                s.replacePhoto(at: replaceIdx, with: image)
                collageReplaceIndex = nil
            } else {
                s.addPhoto(image)
            }
        }
        capturedPhotoData = nil

        let count = collageState?.photos.count ?? 0
        // Replace flow: always return to CollageScreen.
        // From-camera flow: stay on camera until target count is met.
        if isReplacing || count >= kolajPlannedCount {
            showCollageView = true
        } else {
            startSession()
        }
    }

    /// Enter kolaj-from-camera mode. Wipes any prior in-progress collage so
    /// switching back into kolaj from another mode always starts fresh.
    public func enterKolajMode(count: Int) {
        kolajPlannedCount = max(2, min(4, count))
        isCollageMode = true
        showCollageView = false
        collageState = nil
        collageReplaceIndex = nil
        capturedPhotoData = nil
    }

    /// Leave kolaj mode without finalizing — clears any in-progress photos.
    /// Called when the user picks a different mode mid-capture.
    public func exitKolajMode() {
        guard !showCollageView else { return }
        isCollageMode = false
        collageState = nil
        collageReplaceIndex = nil
        capturedPhotoData = nil
    }

    /// Updates target count mid-mode (only allowed before any photo is taken).
    public func setKolajPlannedCount(_ count: Int) {
        guard (collageState?.photos.count ?? 0) == 0 else { return }
        kolajPlannedCount = max(2, min(4, count))
    }

    /// Opens camera from collage view to capture another photo.
    public func addMoreFromCollage() {
        showCollageView = false
        capturedPhotoData = nil
        startSession()
    }

    /// Renders+finalizes the collage as a single JPEG and routes it through
    /// the regular photo send pipeline.
    public func finalizeCollage(image: UIImage) {
        let quality = NetworkMonitor.shared.recommendedJPEGQuality
        if let data = image.jpegData(compressionQuality: quality) {
            capturedPhotoData = data
        }
        isCollageMode = false
        showCollageView = false
        collageState = nil
        collageReplaceIndex = nil
        stopSession()
    }

    /// Cancels collage mode, clears all collage state.
    public func cancelCollage() {
        collageState = nil
        isCollageMode = false
        showCollageView = false
        collageReplaceIndex = nil
        capturedPhotoData = nil
        startSession()
    }

    /// Prepares image and sends in background — returns immediately so preview can dismiss.
    public func sendPhotoInBackground() {
        if capturedVideoURL != nil {
            sendVideoInBackground()
            return
        }
        guard let data = capturedPhotoData else { return }
        
        // CRITICAL: Normalize orientation FIRST, before any crop.
        let correctedImage: UIImage
        if let oriented = UIImage.orientationCorrectedImage(from: data) {
            correctedImage = oriented
        } else if let fallback = UIImage(data: data) {
            correctedImage = fallback.normalizedOrientation()
        } else {
            return
        }

        // Crop to screen aspect ratio (WYSIWYG — what you see is what you get)
        let screenBounds = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.bounds) ?? CGRect(x: 0, y: 0, width: 390, height: 844)
        let screenRatio = screenBounds.width / screenBounds.height
        let image = cropToScreenRatio(correctedImage, ratio: screenRatio)
        
        // Save selected receivers for next session
        UserDefaults.standard.set(Array(selectedReceiverIds), forKey: "last_selected_receiver_ids")

        // Capture values before resetting
        let receivers = Array(selectedReceiverIds)
        let (lat, lon, city) = sanitizedLocationForUpload(
            lat: currentLatitude, lon: currentLongitude, city: currentCityName
        )
        let comment = initialComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let voice = voiceData
        let secret = isSecret

        // Instagram-style: stay on camera, show progress banner at top
        TabBarState.shared.isSendingPhoto = true

        // Reset camera state immediately so user can take another photo
        self.retakePhoto()
        
        // Send in background
        Task {
            do {
                let photoId = try await deps.stripRepository.sendPhoto(
                    image,
                    to: receivers,
                    latitude: lat,
                    longitude: lon,
                    cityName: city,
                    voiceData: voice,
                    isSecret: secret
                )
                
                // Send voice as chat comment to each receiver if voice was recorded
                if voice != nil {
                    // voiceUrl is saved on the strip doc — read it back
                    let stripDoc = try? await PhotoService.shared.fetchStrip(byId: photoId)
                    if let voiceUrlStr = stripDoc?.voiceUrl {
                        for receiverId in receivers where receiverId != Auth.auth().currentUser?.uid {
                            try? await deps.stripRepository.sendStripChatMessage(
                                text: "sesli yorum",
                                stripId: photoId,
                                chatPartnerId: receiverId,
                                replyToId: nil,
                                replyToText: nil,
                                replyToSenderId: nil,
                                voiceUrl: voiceUrlStr
                            )
                        }
                    }
                }

                // Send initial message to each receiver's chat channel if provided
                if !comment.isEmpty {
                    for receiverId in receivers where receiverId != Auth.auth().currentUser?.uid {
                        try? await deps.stripRepository.sendStripChatMessage(
                            text: comment,
                            stripId: photoId,
                            chatPartnerId: receiverId,
                            replyToId: nil,
                            replyToText: nil,
                            replyToSenderId: nil,
                            voiceUrl: nil
                        )
                    }
                }
                
                AnalyticsService.shared.log(.sendPhoto, parameters: [
                    "recipient_count": receivers.count,
                    "is_secret": secret,
                    "has_voice": voice != nil,
                    "is_video": false
                ])
                // First-time event for activation funnel
                AnalyticsService.shared.logOnce(.firstPhotoSent, parameters: ["recipient_count": receivers.count])

                // High-intent moment — safe time to prompt for notification permission now that
                // the user has seen the app's core value loop.
                NotificationPermissionPrompter.requestIfUndetermined()

                // Track for App Store review prompt
                ReviewPromptService.recordPhotoSent()
                
                // Auto-save to photo library if enabled
                if UserDefaults.standard.bool(forKey: "auto_save_photos") {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                }
                
                HapticsManager.playNotification(type: .success)
                SoundManager.shared.playSound(effect: .paperplaneWhoosh)
                
                // Immediately refresh widget to show the latest photo
                WidgetCenter.shared.reloadAllTimelines()
                WidgetReloadThrottle.shared.recordDirectReload()
                
            } catch {
                HapticsManager.playNotification(type: .error)
                await MainActor.run {
                    // Save state for retry
                    self.pendingRetryImage = image
                    self.pendingRetryReceivers = receivers
                    self.pendingRetryLat = lat
                    self.pendingRetryLon = lon
                    self.pendingRetryCity = city
                    self.pendingRetryComment = comment
                    self.pendingRetryVoice = voice
                    self.pendingRetrySecret = secret
                    self.persistDraft()
                    self.errorMessage = "gönderilemedi. tekrar dene."
                }
            }

            // Hide loading overlay
            TabBarState.shared.isSendingPhoto = false
        }
    }
    

    // MARK: - Video Send

    public func sendVideoInBackground() {
        guard let videoURL = capturedVideoURL else { return }
        guard let thumbnail = extractThumbnail(from: videoURL) else {
            errorMessage = "Video thumbnail olusturulamadi"
            return
        }

        let receivers = Array(selectedReceiverIds)
        let (lat, lon, city) = sanitizedLocationForUpload(
            lat: currentLatitude, lon: currentLongitude, city: currentCityName
        )
        let secret = isSecret
        let duration = videoDuration
        let comment = initialComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let sendWithSound = sendVideoWithSound

        // Save selected receivers for next session
        UserDefaults.standard.set(Array(selectedReceiverIds), forKey: "last_selected_receiver_ids")
        TabBarState.shared.isSendingPhoto = true
        // Reset camera state but do NOT delete the video file -- it will be uploaded in the background Task
        // and cleaned up after upload completes (or fails) at the end of the Task below.
        capturedVideoURL = nil
        capturedPhotoData = nil
        videoDuration = 0
        videoRecordingProgress = 0
        initialComment = ""
        voiceData = nil
        isSecret = false
        sendVideoWithSound = true
        selectedReceiverIds = []
        startSession()

        Task {
            do {
                let preparedVideoURL = try await preparedVideoURLForSending(from: videoURL, includeAudio: sendWithSound)
                let photoId = try await deps.stripRepository.sendPhoto(
                    thumbnail,
                    to: receivers,
                    latitude: lat,
                    longitude: lon,
                    cityName: city,
                    voiceData: nil,
                    isSecret: secret,
                    videoFileURL: preparedVideoURL,
                    videoDuration: duration
                )

                if !comment.isEmpty {
                    let currentUid = Auth.auth().currentUser?.uid
                    for receiverId in receivers where receiverId != currentUid {
                        try? await deps.stripRepository.sendStripChatMessage(
                            text: comment,
                            stripId: photoId,
                            chatPartnerId: receiverId,
                            replyToId: nil,
                            replyToText: nil,
                            replyToSenderId: nil,
                            voiceUrl: nil
                        )
                    }
                }

                AnalyticsService.shared.log(.sendPhoto, parameters: ["type": "video", "duration": duration])
                ReviewPromptService.recordPhotoSent()
                HapticsManager.playNotification(type: .success)
                SoundManager.shared.playSound(effect: .paperplaneWhoosh)
                WidgetCenter.shared.reloadAllTimelines()
                WidgetReloadThrottle.shared.recordDirectReload()
                if preparedVideoURL != videoURL {
                    try? FileManager.default.removeItem(at: preparedVideoURL)
                }
            } catch {
                HapticsManager.playNotification(type: .error)
                await MainActor.run {
                    // Save video for retry instead of deleting
                    self.pendingRetryVideoURL = videoURL
                    self.pendingRetryReceivers = receivers
                    self.pendingRetryLat = lat
                    self.pendingRetryLon = lon
                    self.pendingRetryCity = city
                    self.pendingRetryComment = comment
                    self.pendingRetrySecret = secret
                    self.pendingRetryVideoDuration = duration
                    self.pendingRetryVideoWithSound = sendWithSound
                    self.persistDraft()
                    self.errorMessage = "video gönderilemedi. tekrar dene."
                }
                // Do NOT delete the video file — user can retry
                TabBarState.shared.isSendingPhoto = false
                return
            }
            // Only delete the video file after successful upload
            try? FileManager.default.removeItem(at: videoURL)
            TabBarState.shared.isSendingPhoto = false
        }
    }

    private func preparedVideoURLForSending(from originalURL: URL, includeAudio: Bool) async throws -> URL {
        guard includeAudio == false else { return originalURL }

        let asset = AVURLAsset(url: originalURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw AppError.custom("video hazırlanamadı.")
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw AppError.custom("sessiz video oluşturulamadı.")
        }

        let duration = try await asset.load(.duration)
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )
        compositionVideoTrack.preferredTransform = try await videoTrack.load(.preferredTransform)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw AppError.custom("sessiz video oluşturulamadı.")
        }

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("video_send_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        await withCheckedContinuation { continuation in
            exportSession.exportAsynchronously {
                continuation.resume()
            }
        }

        guard exportSession.status == .completed else {
            throw exportSession.error ?? AppError.custom("sessiz video oluşturulamadı.")
        }

        return outputURL
    }

    // MARK: - Image Crop
    
    /// Crops the image to match the screen's aspect ratio from center (WYSIWYG)
    private func cropToScreenRatio(_ image: UIImage, ratio: CGFloat) -> UIImage {
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        let imageRatio = imageWidth / imageHeight
        
        // If image already matches screen ratio, no crop needed
        guard abs(imageRatio - ratio) > 0.01 else { return image }
        
        var cropRect: CGRect
        
        if ratio > imageRatio {
            // Screen is wider → crop height
            let newHeight = imageWidth / ratio
            let yOffset = (imageHeight - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: imageWidth, height: newHeight)
        } else {
            // Screen is taller → crop width
            let newWidth = imageHeight * ratio
            let xOffset = (imageWidth - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageHeight)
        }
        
        // Convert to pixel coordinates (handle @2x, @3x scale)
        let scale = image.scale
        let pixelRect = CGRect(
            x: cropRect.origin.x * scale,
            y: cropRect.origin.y * scale,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )
        
        guard let cgImage = image.cgImage?.cropping(to: pixelRect) else { return image }
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }
}
