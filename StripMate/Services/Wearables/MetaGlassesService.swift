import Foundation
import SwiftUI
import MWDATCore
import MWDATCamera

// Ray-Ban Meta / Meta Ray-Ban Display entegrasyonu (Meta Wearables Device
// Access Toolkit). Gözlük kamerasından canlı akış alır; yakalanan kare
// CameraViewModel'in normal önizleme/gönderim hattına düşer.
//
// Kayıt akışı Meta AI uygulaması üzerinden yürür (SDK gereği): ilk kullanımda
// startRegistration() Meta AI'a yönlendirir, dönüş stripmate:// URL'siyle
// gelir ve AppRootRouter onOpenURL'den handleUrl'e iletilir.

/// Gözlük akış durumu — UI bu tek enum'dan beslenir.
enum GlassesStreamPhase: Equatable {
    case idle
    case connecting
    case streaming
    case failed(String)
}

@MainActor
@Observable
final class MetaGlassesService {
    static let shared = MetaGlassesService()

    /// configure() başarıyla çalıştıysa true — UI girişleri buna bakar.
    private(set) var isAvailable = false
    /// Meta AI kaydı tamamlandı mı.
    private(set) var isRegistered = false
    var phase: GlassesStreamPhase = .idle
    /// Gözlük kamerasından gelen son kare (canlı vizör).
    var currentFrame: UIImage?
    /// capturePhoto sonucu — tüketen taraf almalı ve nil'lemeli.
    var capturedPhotoData: Data?
    var isCapturingPhoto = false

    private var deviceSession: DeviceSession?
    private var stream: MWDATCamera.Stream?
    private var stateToken: AnyListenerToken?
    private var frameToken: AnyListenerToken?
    private var errorToken: AnyListenerToken?
    private var photoToken: AnyListenerToken?
    private var registrationTask: Task<Void, Never>?

    private init() {}

    // MARK: - Yaşam döngüsü

    /// Uygulama açılışında bir kez çağrılır. SDK yapılandırılamazsa özellik
    /// sessizce kapalı kalır — çekirdek deneyime etkisi yoktur.
    func configureAtLaunch() {
        do {
            try Wearables.configure()
            isAvailable = true
            observeRegistration()
        } catch {
            isAvailable = false
            AppLogger.service.error("MetaGlasses: configure başarısız: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Meta AI kayıt dönüş URL'si — AppRootRouter.onOpenURL'den çağrılır.
    /// Dönüş: URL SDK tarafından işlendiyse true.
    func handleUrl(_ url: URL) async -> Bool {
        guard isAvailable else { return false }
        return (try? await Wearables.shared.handleUrl(url)) ?? false
    }

    private func observeRegistration() {
        registrationTask?.cancel()
        registrationTask = Task { [weak self] in
            for await state in Wearables.shared.registrationStateStream() {
                guard let self else { return }
                self.isRegistered = (state == .registered)
            }
        }
    }

    /// Meta AI üzerinden kayıt akışını başlatır (Meta AI uygulamasına yönlendirir).
    func startRegistration() async {
        guard isAvailable else { return }
        do {
            try await Wearables.shared.startRegistration()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Akış

    /// Gözlük kamera iznini isteyip oturum + akış başlatır.
    func startStreaming() async {
        guard isAvailable, phase != .streaming, phase != .connecting else { return }
        phase = .connecting
        do {
            var status = try await Wearables.shared.checkPermissionStatus(.camera)
            if status != .granted {
                status = try await Wearables.shared.requestPermission(.camera)
            }
            guard status == .granted else {
                phase = .failed(String(localized: "gözlük kamera izni verilmedi."))
                return
            }

            let selector = AutoDeviceSelector(wearables: Wearables.shared)
            let session = try Wearables.shared.createSession(deviceSelector: selector)
            deviceSession = session
            try session.start()
            for await state in session.stateStream() {
                if state == .started { break }
                if state == .stopped {
                    phase = .failed(String(localized: "gözlük bulunamadı. meta ai'da bağlı olduğundan emin ol."))
                    return
                }
            }

            let config = StreamConfiguration(
                videoCodec: VideoCodec.raw,
                resolution: StreamingResolution.low,
                frameRate: 24
            )
            guard let newStream = try session.addStream(config: config) else {
                phase = .failed(String(localized: "akış başlatılamadı. tekrar dene."))
                return
            }
            stream = newStream
            setupListeners(for: newStream)
            newStream.start()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Akıştaki son yüksek çözünürlüklü kareyi fotoğraf olarak ister.
    /// Sonuç `capturedPhotoData`'ya düşer.
    func capturePhoto() {
        guard let stream, phase == .streaming, !isCapturingPhoto else { return }
        isCapturingPhoto = true
        if !stream.capturePhoto(format: .jpeg) {
            isCapturingPhoto = false
            // Donanım fotoğraf isteği reddedilirse canlı kareye düş —
            // kullanıcının bastığı an asla boşa gitmesin.
            if let frame = currentFrame, let data = frame.jpegData(compressionQuality: 0.92) {
                capturedPhotoData = data
            }
        }
    }

    func stopStreaming() {
        stream?.stop()
        stream = nil
        stateToken = nil
        frameToken = nil
        errorToken = nil
        photoToken = nil
        deviceSession?.stop()
        deviceSession = nil
        currentFrame = nil
        phase = .idle
    }

    // MARK: - Dinleyiciler

    private func setupListeners(for stream: MWDATCamera.Stream) {
        stateToken = stream.statePublisher.listen { [weak self] state in
            Task { @MainActor in self?.handleState(state) }
        }
        frameToken = stream.videoFramePublisher.listen { [weak self] frame in
            Task { @MainActor in
                self?.currentFrame = frame.makeUIImage()
            }
        }
        errorToken = stream.errorPublisher.listen { [weak self] error in
            Task { @MainActor in self?.phase = .failed(error.localizedDescription) }
        }
        photoToken = stream.photoDataPublisher.listen { [weak self] photo in
            Task { @MainActor in
                self?.isCapturingPhoto = false
                self?.capturedPhotoData = photo.data
            }
        }
    }

    private func handleState(_ state: StreamState) {
        switch state {
        case .streaming:
            phase = .streaming
        case .stopped:
            if case .failed = phase { break }
            phase = .idle
            currentFrame = nil
        case .waitingForDevice, .starting, .stopping, .paused:
            if phase != .streaming { phase = .connecting }
        @unknown default:
            break
        }
    }
}
