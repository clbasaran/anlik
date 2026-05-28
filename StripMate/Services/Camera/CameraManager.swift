import Foundation
import AVFoundation
import UIKit

public enum CameraError: Error {
    case authorizationDenied
    case deviceUnavailable
    case setupFailed
    case captureFailed
}

public enum FlashSetting: String, CaseIterable, Sendable {
    case off, on, auto

    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }

    var icon: String {
        switch self {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        }
    }

    var label: String {
        switch self {
        case .off: return "Kapalı"
        case .on: return "Açık"
        case .auto: return "Otomatik"
        }
    }
}

public actor CameraManager: NSObject {
    public static let shared = CameraManager()

    public let session = AVCaptureSession()

    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    public let videoRecorder = VideoRecorder()

    private var isConfigured = false
    private var captureContinuation: CheckedContinuation<Data, Error>?
    public var isFlashModeOn: Bool = false
    public var flashMode: FlashSetting = .off

    /// QR code detection callback — called on main thread when a QR with StripMate invite code is detected
    public var onQRCodeDetected: (@Sendable (String) -> Void)?
    /// Prevents re-firing the same QR code repeatedly
    private var lastDetectedQR: String?
    private var qrCooldownTask: Task<Void, Never>?

    public func toggleFlash() {
        isFlashModeOn.toggle()
    }

    /// Cycle flash: off → on → auto → off
    public func cycleFlashMode() {
        switch flashMode {
        case .off: flashMode = .on; isFlashModeOn = true
        case .on: flashMode = .auto; isFlashModeOn = true
        case .auto: flashMode = .off; isFlashModeOn = false
        }
    }

    /// Sets the exposure target bias (EV compensation). Range typically -8.0 to +8.0.
    public func setExposure(_ bias: Float) {
        #if !targetEnvironment(simulator)
        guard let device = videoDeviceInput?.device else { return }
        let clampedBias = max(device.minExposureTargetBias, min(bias, device.maxExposureTargetBias))
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(clampedBias, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {
            #if DEBUG
            AppLogger.camera.error("Failed to set exposure: \(error.localizedDescription, privacy: .public)")
            #endif
        }
        #endif
    }

    /// Tap to focus at a specific point (normalized 0-1 coordinates)
    public func focus(at point: CGPoint) {
        #if !targetEnvironment(simulator)
        guard let device = videoDeviceInput?.device else { return }
        guard device.isFocusPointOfInterestSupported else { return }
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            #if DEBUG
            AppLogger.camera.error("Focus failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
        #endif
    }

    /// Returns the min/max exposure bias range for the current device
    public var exposureRange: ClosedRange<Float> {
        #if targetEnvironment(simulator)
        return -2.0...2.0
        #else
        guard let device = videoDeviceInput?.device else { return -2.0...2.0 }
        return device.minExposureTargetBias...device.maxExposureTargetBias
        #endif
    }

    private override init() {
        super.init()
    }

    public func checkAuthorization() async -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
        #endif
    }

    public func configureSession() async throws {
        #if targetEnvironment(simulator)
        isConfigured = true
        return
        #else
        guard await checkAuthorization() else {
            throw CameraError.authorizationDenied
        }

        guard !isConfigured else { return }

        // Pre-flight: request audio permission before touching the session.
        // This avoids holding the session in a half-configured state during the permission dialog.
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            await AVCaptureDevice.requestAccess(for: .audio)
        }

        self.session.beginConfiguration()
        // Use .high to support both photo capture and video+audio recording.
        // .photo preset rejects audio inputs on many devices, causing FigCaptureSourceRemote errors.
        // Photo quality is maximized via photoOutput.maxPhotoQualityPrioritization = .quality instead.
        self.session.sessionPreset = .high

        // Add Video Input
        do {
            guard let videoDevice = self.bestDevice(for: .back) else {
                throw CameraError.deviceUnavailable
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                throw CameraError.setupFailed
            }
        } catch {
            self.session.commitConfiguration()
            throw error
        }

        // Add Audio Input BEFORE outputs — required for video recording with sound.
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if self.session.canAddInput(audioInput) {
                    self.session.addInput(audioInput)
                    AppLogger.camera.debug("Audio input added successfully")
                } else {
                    AppLogger.camera.debug("Session cannot add audio input")
                }
            } catch {
                AppLogger.camera.error("Could not create audio input: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Add Photo Output
        if self.session.canAddOutput(self.photoOutput) {
            self.session.addOutput(self.photoOutput)
            self.photoOutput.maxPhotoQualityPrioritization = .quality
        } else {
            self.session.commitConfiguration()
            throw CameraError.setupFailed
        }

        // Add Video Output (movieFileOutput picks up audio from the session's audio input)
        if self.session.canAddOutput(self.videoRecorder.output) {
            self.session.addOutput(self.videoRecorder.output)
        }

        // Add Metadata Output for QR code detection
        if self.session.canAddOutput(self.metadataOutput) {
            self.session.addOutput(self.metadataOutput)
            self.metadataOutput.setMetadataObjectsDelegate(self.qrDelegate, queue: DispatchQueue.main)
            if self.metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                self.metadataOutput.metadataObjectTypes = [.qr]
            }
        }

        self.session.commitConfiguration()
        self.isConfigured = true
        #endif
    }

    public func startSession() async {
        #if targetEnvironment(simulator)
        return
        #else
        guard self.isConfigured, !self.session.isRunning else { return }
        self.session.startRunning()
        #endif
    }

    public func stopSession() async {
        #if targetEnvironment(simulator)
        return
        #else
        guard self.session.isRunning else { return }
        self.session.stopRunning()
        #endif
    }

    public func toggleCamera() async throws {
        #if targetEnvironment(simulator)
        return
        #else
        guard let currentInput = self.videoDeviceInput else {
            throw CameraError.setupFailed
        }

        let currentPosition = currentInput.device.position
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

        guard let newDevice = self.bestDevice(for: newPosition) else {
            throw CameraError.deviceUnavailable
        }

        let newInput = try AVCaptureDeviceInput(device: newDevice)

        self.session.beginConfiguration()
        self.session.removeInput(currentInput)

        if self.session.canAddInput(newInput) {
            self.session.addInput(newInput)
            self.videoDeviceInput = newInput
        } else {
            self.session.addInput(currentInput)
        }
        self.session.commitConfiguration()
        #endif
    }

    public func capturePhoto() async throws -> Data {
        #if targetEnvironment(simulator)
        let rect = CGRect(x: 0, y: 0, width: 1080, height: 1920)
        let format = UIGraphicsImageRendererFormat()
        let renderer = UIGraphicsImageRenderer(size: rect.size, format: format)

        let image = renderer.image { ctx in
            // Draw gradient background
            let colors = [UIColor.systemIndigo.cgColor, UIColor.systemPurple.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else { return }
            ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1080, y: 1920), options: [])

            // Draw text
            let text = "Simulator Photo" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 80, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (rect.width - textSize.width) / 2, y: (rect.height - textSize.height) / 2), withAttributes: attributes)
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw CameraError.captureFailed
        }
        return data
        #else
        return try await withCheckedThrowingContinuation { continuation in
            if self.captureContinuation != nil {
                continuation.resume(throwing: CameraError.captureFailed)
                return
            }
            self.captureContinuation = continuation

            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .speed

            // Check if flash is available and set it if necessary
            if let input = self.videoDeviceInput, input.device.isFlashAvailable {
                settings.flashMode = self.flashMode.avFlashMode
            }

            // Fix front camera mirror effect (save as seen in preview)
            if let videoConnection = self.photoOutput.connection(with: .video) {
                if self.videoDeviceInput?.device.position == .front {
                    if videoConnection.isVideoMirroringSupported {
                        videoConnection.isVideoMirrored = true
                    }
                }
            }

            // Directly pass the local delegate to avoid MainActor isolation mismatch constraints
            let delegate = self.captureDelegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)

            // Safety timeout: if delegate never fires, resume with error after 10 seconds
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard let self else { return }
                if await self.captureContinuation != nil {
                    await self.handleCaptureTimeout()
                }
            }
        }
        #endif
    }

    private func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        // Triple > DualWide > Dual > Wide (best available)
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: position)
        return discoverySession.devices.first
    }

    /// Switch between available lenses: ultra-wide (0.5x), wide (1x), telephoto (2x)
    public func switchLens(to zoomFactor: CGFloat) async {
        #if targetEnvironment(simulator)
        return
        #else
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            let clamped = max(device.minAvailableVideoZoomFactor, min(zoomFactor, min(device.maxAvailableVideoZoomFactor, 10.0)))
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            #if DEBUG
            AppLogger.camera.error("Lens switch failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
        #endif
    }

    /// Returns available lens options as (zoomFactor, displayLabel) pairs.
    /// Current camera position (.front or .back)
    public var currentCameraPosition: AVCaptureDevice.Position {
        videoDeviceInput?.device.position ?? .back
    }

    /// Uses virtualDeviceSwitchOverVideoZoomFactors for accurate mapping.
    /// e.g. iPhone 11 DualWide: min=1.0 (ultra-wide=0.5x label), switchOver=2.0 (wide=1x label)
    public var availableLensOptions: [(factor: CGFloat, label: String)] {
        #if targetEnvironment(simulator)
        return [(1.0, "1×")]
        #else
        guard let device = videoDeviceInput?.device else { return [(1.0, "1×")] }

        // Ön kamerada her zaman tek lens
        if device.position == .front {
            return [(1.0, "1×")]
        }

        let switchOvers = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        let minZoom = device.minAvailableVideoZoomFactor

        // Multi-lens device (dual wide, triple, etc.)
        if !switchOvers.isEmpty {
            var options: [(factor: CGFloat, label: String)] = []

            // First lens = minZoom (ultra-wide on DualWide/Triple)
            options.append((minZoom, "0.5×"))

            // Each switchover point is the next lens
            guard let firstFactor = switchOvers.first else { return options }
            for (i, factor) in switchOvers.enumerated() {
                if i == 0 {
                    options.append((factor, "1×"))
                } else {
                    let multiplier = Int(factor / firstFactor)
                    options.append((factor, "\(multiplier)×"))
                }
            }

            return options
        }

        // Single lens device — just 1x
        return [(1.0, "1×")]
        #endif
    }

    // Injectable delegate object for the nonisolated callback
    private lazy var captureDelegate = CameraDelegate(manager: self)

    // QR metadata delegate
    private lazy var qrDelegate = QRMetadataDelegate(manager: self)

    fileprivate func handleQRCode(_ code: String) {
        // Only process StripMate invite links/codes
        // Accepts: "stripmate://invite/ABCDEF" or just "ABCDEF" (6-char uppercase)
        var inviteCode: String?

        if code.hasPrefix("stripmate://invite/") {
            inviteCode = String(code.dropFirst("stripmate://invite/".count))
        } else if code.count >= 5 && code.count <= 8 && code == code.uppercased() && code.allSatisfy({ $0.isLetter || $0.isNumber }) {
            inviteCode = code
        }

        guard let detectedCode = inviteCode, detectedCode != lastDetectedQR else { return }
        lastDetectedQR = detectedCode

        // Cooldown: don't re-fire same code for 10 seconds
        qrCooldownTask?.cancel()
        qrCooldownTask = Task {
            try? await Task.sleep(for: .seconds(10))
            self.lastDetectedQR = nil
        }

        // Fire callback on main thread
        let callback = onQRCodeDetected
        Task { @MainActor in
            callback?(detectedCode)
        }
    }

    /// Reset QR detection state (e.g., after dismissing the popup)
    public func resetQRDetection() {
        lastDetectedQR = nil
        qrCooldownTask?.cancel()
    }

    /// Set QR code detection callback
    public func setQRCallback(_ callback: @escaping @Sendable (String) -> Void) {
        onQRCodeDetected = callback
    }

    fileprivate func handlePhotoCapture(photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            captureContinuation?.resume(throwing: error)
        } else if let fileData = photo.fileDataRepresentation() {
            captureContinuation?.resume(returning: fileData)
        } else {
            captureContinuation?.resume(throwing: CameraError.captureFailed)
        }
        captureContinuation = nil
    }

    /// Safety net: resume continuation with an error if the delegate never fires.
    private func handleCaptureTimeout() {
        captureContinuation?.resume(throwing: CameraError.captureFailed)
        captureContinuation = nil
    }

    // MARK: - Video Recording

    public func startVideoRecording() async throws -> URL {
        // Enable torch for flash during video
        if flashMode != .off, let device = videoDeviceInput?.device, device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = .on
            device.unlockForConfiguration()
        }
        return try await videoRecorder.startRecording()
    }

    public func stopVideoRecording() {
        videoRecorder.stopRecording()
        // Disable torch after recording
        if let device = videoDeviceInput?.device, device.hasTorch {
            try? device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        }
    }

    public var isVideoRecording: Bool { videoRecorder.isRecording }
}

final class CameraDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private weak var manager: CameraManager?

    nonisolated init(manager: CameraManager) {
        self.manager = manager
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task {
            await manager?.handlePhotoCapture(photo: photo, error: error)
        }
    }
}

final class QRMetadataDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private weak var manager: CameraManager?

    nonisolated init(manager: CameraManager) {
        self.manager = manager
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let code = metadataObject.stringValue else { return }

        Task {
            await manager?.handleQRCode(code)
        }
    }
}
