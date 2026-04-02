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

    // Retry state for failed uploads
    private var pendingRetryImage: UIImage?
    private var pendingRetryReceivers: [String] = []
    private var pendingRetryLat: Double?
    private var pendingRetryLon: Double?
    private var pendingRetryCity: String?
    private var pendingRetryComment: String?
    private var pendingRetryVoice: Data?
    private var pendingRetrySecret: Bool = false
    public var canRetry: Bool { pendingRetryImage != nil }

    public func retrySend() {
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
                // Save again for another retry
                self.pendingRetryImage = image
                self.pendingRetryReceivers = receivers
                self.pendingRetryLat = lat
                self.pendingRetryLon = lon
                self.pendingRetryCity = city
                self.pendingRetryComment = comment
                self.pendingRetryVoice = voice
                self.pendingRetrySecret = secret
                self.errorMessage = "gönderilemedi. tekrar dene."
            }
            TabBarState.shared.isSendingPhoto = false
        }
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
    }

    // Flash mode (off/on/auto)
    public var flashSetting: FlashSetting = .off
    
    // Exposure control
    public var exposureBias: Float = 0.0
    

    
    // Location data for current capture
    public var currentLatitude: Double? = nil
    public var currentLongitude: Double? = nil
    public var currentCityName: String? = nil
    
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
    public var isRecordingVideo: Bool = false
    public var videoRecordingProgress: Double = 0  // 0.0 to 1.0
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    public var isVideoMode: Bool { capturedVideoURL != nil }

    // Collage mode
    public var collagePhotos: [UIImage] = []
    public var isCollageMode: Bool = false
    public var collageLayout: CollageLayout = .twoHorizontal
    public var showCollageView: Bool = false
    public var collageReplaceIndex: Int?

    public var isFrontCamera: Bool = false

    // Ring flash state
    public var showRingFlash: Bool = false

    private let cameraManager = CameraManager.shared
    private let deps = DependencyContainer.shared

    public init() {
        // Restore last used camera lens
        self.isFrontCamera = UserDefaults.standard.bool(forKey: "last_camera_front")
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
        videoRecordingProgress = 0
        recordingStartTime = Date()

        HapticsManager.playImpact(style: .heavy)

        // Progress timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startTime = self.recordingStartTime else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                self.videoRecordingProgress = min(elapsed / 5.0, 1.0)
                self.videoDuration = elapsed
            }
        }

        Task {
            do {
                let videoURL = try await cameraManager.startVideoRecording()
                self.capturedVideoURL = videoURL
                self.videoDuration = min(self.videoDuration, 5.0)
                self.isRecordingVideo = false
                self.recordingTimer?.invalidate()
                self.recordingTimer = nil

                // Fetch location and friends in parallel
                if LocationManager.shared.authorizationStatus == .authorizedWhenInUse || LocationManager.shared.authorizationStatus == .authorizedAlways {
                    let (location, city) = await LocationManager.shared.fetchLocation()
                    self.currentLatitude = location?.coordinate.latitude
                    self.currentLongitude = location?.coordinate.longitude
                    self.currentCityName = city
                }
                await fetchAvailableFriends()
            } catch {
                self.isRecordingVideo = false
                self.recordingTimer?.invalidate()
                self.recordingTimer = nil
                self.errorMessage = "Video kaydedilemedi"
            }
        }
    }

    public func stopVideoRecording() {
        guard isRecordingVideo else { return }
        let elapsed = Date().timeIntervalSince(recordingStartTime ?? Date())

        if elapsed < 2.0 {
            Task { await cameraManager.stopVideoRecording() }
            isRecordingVideo = false
            recordingTimer?.invalidate()
            recordingTimer = nil
            capturedVideoURL = nil
            videoRecordingProgress = 0
            errorMessage = "En az 2 saniye kaydet"
        } else {
            Task { await cameraManager.stopVideoRecording() }
        }
    }

    public func extractThumbnail(from videoURL: URL) -> UIImage? {
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
    }

    public func retakePhoto() {
        // Clear video state
        if let videoURL = capturedVideoURL {
            try? FileManager.default.removeItem(at: videoURL)
        }
        capturedVideoURL = nil
        videoDuration = 0
        videoRecordingProgress = 0
        isRecordingVideo = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        self.capturedPhotoData = nil
        self.currentLatitude = nil
        self.currentLongitude = nil
        self.currentCityName = nil
        self.initialComment = ""
        self.voiceData = nil
        self.isSecret = false
        // Clear collage state on full retake
        self.collagePhotos = []
        self.isCollageMode = false
        self.showCollageView = false
        self.collageReplaceIndex = nil
        self.startSession()
    }
    
    // MARK: - Collage Mode

    /// Starts collage mode with the currently captured photo as the first image.
    public func startCollage() {
        guard let data = capturedPhotoData, let image = UIImage(data: data) else { return }
        collagePhotos = [image]
        isCollageMode = true
        showCollageView = false
        // Reset capture so camera reopens for next photo
        capturedPhotoData = nil
        startSession()
    }

    /// Adds the current captured photo to the collage array and reopens the camera.
    public func addToCollage() {
        guard let data = capturedPhotoData, let image = UIImage(data: data) else { return }

        if let replaceIdx = collageReplaceIndex, replaceIdx < collagePhotos.count {
            collagePhotos[replaceIdx] = image
            collageReplaceIndex = nil
        } else {
            collagePhotos.append(image)
        }
        capturedPhotoData = nil

        if collagePhotos.count >= 2 {
            showCollageView = true
        } else {
            startSession()
        }
    }

    /// Removes a photo from the collage at the given index.
    /// If only 1 photo remains, reopens camera to capture more.
    public func removeFromCollage(at index: Int) {
        guard index < collagePhotos.count else { return }
        collagePhotos.remove(at: index)
        if collagePhotos.count < 2 {
            showCollageView = false
            startSession()
        }
    }

    /// Opens camera from collage view to capture another photo.
    public func addMoreFromCollage() {
        showCollageView = false
        capturedPhotoData = nil
        startSession()
    }

    /// Uses CollageBuilder to create the final image and sets it as capturedPhotoData.
    public func finalizeCollage(image: UIImage) {
        let quality = NetworkMonitor.shared.recommendedJPEGQuality
        if let data = image.jpegData(compressionQuality: quality) {
            capturedPhotoData = data
        }
        isCollageMode = false
        showCollageView = false
        collagePhotos = []
        collageReplaceIndex = nil
        stopSession()
    }

    /// Cancels collage mode, clears all collage state.
    public func cancelCollage() {
        collagePhotos = []
        isCollageMode = false
        showCollageView = false
        collageLayout = .twoHorizontal
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
        let lat = currentLatitude
        let lon = currentLongitude
        let city = currentCityName
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
                
                AnalyticsService.shared.log(.sendPhoto, parameters: ["recipient_count": receivers.count])
                
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
        let lat = currentLatitude
        let lon = currentLongitude
        let city = currentCityName
        let secret = isSecret
        let duration = videoDuration
        let comment = initialComment.trimmingCharacters(in: .whitespacesAndNewlines)

        // Save selected receivers for next session
        UserDefaults.standard.set(Array(selectedReceiverIds), forKey: "last_selected_receiver_ids")
        TabBarState.shared.isSendingPhoto = true
        retakePhoto()

        Task {
            do {
                let photoId = try await deps.stripRepository.sendPhoto(
                    thumbnail,
                    to: receivers,
                    latitude: lat,
                    longitude: lon,
                    cityName: city,
                    voiceData: nil,
                    isSecret: secret,
                    videoFileURL: videoURL,
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
            } catch {
                HapticsManager.playNotification(type: .error)
                await MainActor.run {
                    self.errorMessage = "Video gonderilemedi: \(error.localizedDescription)"
                }
            }
            TabBarState.shared.isSendingPhoto = false
            try? FileManager.default.removeItem(at: videoURL)
        }
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
