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
    
    /// Override image from drawing — if set, sendPhoto() uses this instead of raw data
    public var overrideImage: UIImage? = nil
    
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

    // Voice recording data
    public var voiceData: Data?
    

    
    public var isFrontCamera: Bool = false
    
    // Ring flash state
    public var showRingFlash: Bool = false
    
    private let cameraManager = CameraManager.shared
    private let deps = DependencyContainer.shared
    
    public init() {}
    
    public func checkAndConfigure() async {
        let authorized = await cameraManager.checkAuthorization()
        self.isAuthorized = authorized
        self.permissionDenied = !authorized && AVCaptureDevice.authorizationStatus(for: .video) == .denied

        if authorized {
            do {
                try await cameraManager.configureSession()
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
        } catch {
            #if DEBUG
            print("Failed to fetch friends: \(error.localizedDescription)")
            #endif
        }
    }
    
    public func capturePhoto() async {
        guard isSessionRunning else { return }
        
        HapticsManager.playImpact(style: .medium)
        
        // Ring flash for front camera
        if isFrontCamera {
            self.showRingFlash = true
            try? await Task.sleep(for: .milliseconds(150))
        }
        
        do {
            // Fire camera capture and location fetch in parallel — location never blocks the shutter
            async let photoTask = cameraManager.capturePhoto()
            async let locationTask = LocationManager.shared.fetchLocation()
            
            let photoData = try await photoTask
            
            // Dismiss ring flash
            self.showRingFlash = false
            

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
            
            // Preload friends for the Send Sheet
            do {
                let friends = try await deps.friendRepository.fetchFriends()
                self.availableFriends = friends.filter { !$0.isPending }
            } catch {
                #if DEBUG
                print("Failed to preload friends: \(error.localizedDescription)")
                #endif
            }
        } catch {
            #if DEBUG
            print("Failed to capture photo: \(error.localizedDescription)")
            #endif
        }
    }
    
    public func retakePhoto() {
        self.capturedPhotoData = nil
        self.overrideImage = nil
        self.currentLatitude = nil
        self.currentLongitude = nil
        self.currentCityName = nil
        self.initialComment = ""
        self.voiceData = nil
        self.startSession()
    }
    
    /// Prepares image and sends in background — returns immediately so preview can dismiss.
    public func sendPhotoInBackground() {
        guard let data = capturedPhotoData else { return }
        
        let image: UIImage
        
        // If user applied drawing, use that image directly
        if let overrideImage {
            image = overrideImage
        } else {
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
            image = cropToScreenRatio(correctedImage, ratio: screenRatio)
        }
        
        // Capture values before resetting
        let receivers = Array(selectedReceiverIds)
        let lat = currentLatitude
        let lon = currentLongitude
        let city = currentCityName
        let comment = initialComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let voice = voiceData

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
                    voiceData: voice
                )
                
                // Send voice as chat comment to each receiver if voice was recorded
                if voice != nil {
                    // voiceUrl is saved on the strip doc — read it back
                    let stripDoc = try? await PhotoService.shared.fetchStrip(byId: photoId)
                    if let voiceUrlStr = stripDoc?.voiceUrl {
                        for receiverId in receivers where receiverId != Auth.auth().currentUser?.uid {
                            try? await deps.stripRepository.sendStripChatMessage(
                                text: "🎤 sesli yorum",
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
                    self.errorMessage = String(localized: "Fotoğraf gönderilemedi. Tekrar dene.")
                }
            }
            
            // Hide loading overlay
            TabBarState.shared.isSendingPhoto = false
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
