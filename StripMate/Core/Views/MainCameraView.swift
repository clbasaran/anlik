import SwiftUI
import AVFoundation
import FirebaseAuth

// MARK: - UIKit Camera Preview Bridge

final class VideoPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // layerClass is set to AVCaptureVideoPreviewLayer, so this cast should always succeed
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            // Fallback: create and insert a preview layer manually instead of crashing
            let fallbackLayer = AVCaptureVideoPreviewLayer()
            fallbackLayer.frame = bounds
            layer.addSublayer(fallbackLayer)
            return fallbackLayer
        }
        return previewLayer
    }

    var session: AVCaptureSession? {
        get { videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }

    var videoGravity: AVLayerVideoGravity {
        get { videoPreviewLayer.videoGravity }
        set { videoPreviewLayer.videoGravity = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        videoPreviewLayer.videoGravity = .resizeAspectFill
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.session = session
        view.videoGravity = videoGravity
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.session = session
        uiView.videoGravity = videoGravity
    }
}

// MARK: - Main Camera View

public struct MainCameraView: View {
    @State private var viewModel = CameraViewModel()
    @State private var captureSession: AVCaptureSession?
    @State private var showSettingsSheet = false
    @State private var currentUserProfile: UserProfile?
    @State private var showExposureSlider = false
    @State private var timerCountdown: Int = 0
    @State private var isTimerActive = false
    @State private var selectedTimerDuration: Int = 0  // 0 = off, 3, 5, 10
    @State private var toolClusterExpanded: Bool = false
    @State private var pendingTimerTask: Task<Void, Never>?
    @State private var currentZoom: CGFloat = 1.0
    @State private var availableLenses: [(factor: CGFloat, label: String)] = [(1.0, "1×")]
    @State private var detectedQRCode: String?
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusRing = false
    @State private var pinchBaseZoom: CGFloat = 1.0
    @State private var shutterLongPressStarted = false
    @State private var shutterPressTime: Date?
    @State private var shutterDragStartZoom: CGFloat?
    @AppStorage("camera.firstRunHints.dismissed") private var cameraHintsDismissed = false
    @Binding var isInPreviewMode: Bool

    public init(isInPreviewMode: Binding<Bool>) {
        self._isInPreviewMode = isInPreviewMode
    }

    // Computed: are we showing the preview overlay?
    private var hasCapture: Bool { viewModel.capturedPhotoData != nil || viewModel.capturedVideoURL != nil || viewModel.showCollageView }

    private var cameraBackground: some View {
        ZStack {
            // ── Layer 0: Ambient background ──
            Color.black

            // ── Layer 1: Live camera feed — full screen WYSIWYG ──
            if viewModel.isAuthorized, let session = captureSession {
                CameraPreviewView(session: session)
                    .allowsHitTesting(false)
            }

            // ── Layer 2: Rule-of-thirds composition grid ──
            if viewModel.isAuthorized && viewModel.gridEnabled && !hasCapture {
                CameraGridOverlay()
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(Brand.Animations.fadeFast, value: viewModel.gridEnabled)
    }

    public var body: some View {
        Color.clear
            .background(cameraBackground)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                guard !hasCapture else { return }
                viewModel.toggleCamera()
            }
            .simultaneousGesture(
                // Pinch to zoom
                MagnifyGesture()
                    .onChanged { value in
                        guard !hasCapture else { return }
                        let newZoom = pinchBaseZoom * value.magnification
                        let clamped = max(0.5, min(newZoom, 10.0))
                        currentZoom = clamped
                        Task { await CameraManager.shared.switchLens(to: clamped) }
                    }
                    .onEnded { _ in
                        pinchBaseZoom = currentZoom
                    }
            )
            .onTapGesture(count: 1) { location in
                guard !hasCapture else { return }
                // Convert tap to normalized coordinates for focus
                let screenSize = UIScreen.current.bounds.size
                let normalizedPoint = CGPoint(
                    x: location.x / screenSize.width,
                    y: location.y / screenSize.height
                )
                viewModel.focusAt(normalizedPoint)

                // Show focus ring animation
                focusPoint = location
                showFocusRing = true
                HapticsManager.playSelection()

                Task {
                    try? await Task.sleep(for: .seconds(1))
                    withAnimation(.easeOut(duration: 0.3)) {
                        showFocusRing = false
                    }
                }
            }
            .overlay(focusRingOverlay)
            // ringFlashOverlay removed
            .overlay(cameraHUDOverlay)
            .overlay(alignment: .center) {
                if viewModel.isAuthorized && !hasCapture && !cameraHintsDismissed {
                    CameraFirstRunHints {
                        withAnimation(.easeOut(duration: 0.22)) {
                            cameraHintsDismissed = true
                        }
                    }
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .padding(.horizontal, 24)
                }
            }
            .overlay {
                if isTimerActive {
                    TimerCountdownOverlay(value: timerCountdown)
                }
            }
            .overlay(previewOverlay)
            .overlay(loadingOverlay)
            .task {
                await loadInitialData()
            }
            .onAppear {
                // Fallback: if profile wasn't loaded during .task (post-signup race condition)
                if currentUserProfile == nil {
                    Task { await loadInitialData() }
                }
            }
            .onChange(of: viewModel.capturedPhotoData) { _, newValue in
                // Kolaj mid-capture: route the photo straight into the
                // collage and stay on camera, no preview flash. This is
                // what makes the from-camera kolaj flow feel like IG Layout.
                if newValue != nil
                    && viewModel.isCollageMode
                    && !viewModel.showCollageView {
                    showExposureSlider = false
                    viewModel.addToCollage()
                    return
                }
                withAnimation(Brand.Animations.standard) {
                    isInPreviewMode = (newValue != nil) || viewModel.showCollageView || (viewModel.capturedVideoURL != nil)
                    if newValue != nil {
                        showExposureSlider = false
                    }
                }
            }
            .onChange(of: viewModel.captureMode) { _, newMode in
                // Mode switching out of kolaj mid-capture wipes the
                // in-progress collage; entering kolaj resets to a fresh one.
                // exitKolajMode preserves a finalized CollageScreen.
                if newMode == .kolaj {
                    viewModel.enterKolajMode(count: viewModel.kolajPlannedCount)
                } else {
                    viewModel.exitKolajMode()
                }
            }
            .onChange(of: viewModel.capturedVideoURL) { _, newValue in
                withAnimation(Brand.Animations.standard) {
                    isInPreviewMode = (newValue != nil) || viewModel.showCollageView || (viewModel.capturedPhotoData != nil)
                    if newValue != nil {
                        showExposureSlider = false
                    }
                }
            }
            .onChange(of: viewModel.showCollageView) { _, newValue in
                withAnimation(Brand.Animations.standard) {
                    isInPreviewMode = newValue || (viewModel.capturedPhotoData != nil) || (viewModel.capturedVideoURL != nil)
                }
            }
            .errorAlert(errorMessage: $viewModel.errorMessage, retryAction: viewModel.canRetry ? { viewModel.retrySend() } : nil)
            .overlay(alignment: .top) {
                // Persisted-draft banner — visible whenever the camera VM has
                // a retry queued (live error or rehydrated from a prior
                // launch). Cleared either by tapping "tekrar dene" (via
                // retrySend) or "vazgeç" (clearRetry).
                if viewModel.canRetry && !isInPreviewMode {
                    DraftRetryBanner(
                        onRetry: { viewModel.retrySend() },
                        onCancel: { viewModel.cancelDraft() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.canRetry)
            .sheet(isPresented: $showSettingsSheet) {
                if let profile = currentUserProfile {
                    SettingsView(profile: profile, onLogout: {
                        showSettingsSheet = false
                        AnalyticsService.shared.log(.logout)
                        Task {
                            try? await DependencyContainer.shared.userRepository.logout()
                        }
                    })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.black)
                }
            }

            .sheet(isPresented: Binding(
                get: { detectedQRCode != nil },
                set: { if !$0 {
                    detectedQRCode = nil
                    Task { await CameraManager.shared.resetQRDetection() }
                }}
            )) {
                if let code = detectedQRCode {
                    QRFriendAddPopup(inviteCode: code) {
                        detectedQRCode = nil
                        Task { await CameraManager.shared.resetQRDetection() }
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.black)
                    .presentationCornerRadius(28)
                }
            }
            .onChange(of: viewModel.capturedPhotoData) { _, newValue in
                if newValue != nil && !viewModel.isCollageMode {
                    viewModel.stopSession()
                }
            }
            .onChange(of: viewModel.isFrontCamera) { _, _ in
                Task {
                    self.availableLenses = await CameraManager.shared.availableLensOptions
                    self.currentZoom = 1.0
                }
            }
    }

    private var cameraHUDOverlay: some View {
        ZStack(alignment: .topTrailing) {
            if viewModel.isAuthorized && !hasCapture {
                cameraHUD
                    .transition(.opacity)
                CameraToolCluster(viewModel: viewModel, isExpanded: $toolClusterExpanded)
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                    .transition(.opacity)

                // Vertical Exposure Slider — right side of screen
                if showExposureSlider {
                    VStack(spacing: 10) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)

                        // Vertical slider via rotated horizontal Slider
                        Slider(value: Binding(
                            get: { viewModel.exposureBias },
                            set: { viewModel.setExposure($0) }
                        ), in: -2.0...2.0, step: 0.1)
                        .tint(.white)
                        .frame(width: 180)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 30, height: 180)

                        Image(systemName: "sun.min")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))

                        // Reset button
                        Button {
                            viewModel.setExposure(0)
                            HapticsManager.playSelection()
                        } label: {
                            Text("0")
                                .font(.system(size: 12, weight: .heavy, design: .default))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(viewModel.exposureBias == 0 ? Color.white.opacity(0.15) : Color.white.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
    }

    private var previewOverlay: some View {
        Group {
            if viewModel.showCollageView, let collageState = viewModel.collageState {
                // Kolaj v2 — single-screen state machine
                CollageScreen(
                    state: collageState,
                    onCancel: { viewModel.cancelCollage() },
                    onUse: { image in viewModel.finalizeCollage(image: image) },
                    onAddPhotoTap: { viewModel.addMoreFromCollage() },
                    onReplacePhoto: { index in
                        viewModel.collageReplaceIndex = index
                        viewModel.addMoreFromCollage()
                    }
                )
                .transition(.opacity)
            } else if let data = viewModel.capturedPhotoData, let image = UIImage(data: data) {
                PreviewView(
                    image: image,
                    isUploading: viewModel.isUploading,
                    showSuccess: viewModel.isSuccessBoomActive,
                    availableFriends: viewModel.availableFriends,
                    selectedReceiverIds: $viewModel.selectedReceiverIds,
                    initialComment: $viewModel.initialComment,
                    voiceData: $viewModel.voiceData,
                    isSecret: $viewModel.isSecret,
                    sendVideoWithSound: $viewModel.sendVideoWithSound,
                    onRetake: {
                        if viewModel.isCollageMode {
                            viewModel.capturedPhotoData = nil
                            viewModel.startSession()
                        } else {
                            viewModel.retakePhoto()
                        }
                    },
                    onSend: { viewModel.sendPhotoInBackground() }
                )
                .transition(.opacity)
            } else if let videoURL = viewModel.capturedVideoURL {
                // Video clip preview — thumbnail extracted async to avoid main thread freeze
                PreviewView(
                    image: viewModel.extractThumbnail(from: videoURL) ?? UIImage(),
                    isUploading: viewModel.isUploading,
                    showSuccess: viewModel.isSuccessBoomActive,
                    availableFriends: viewModel.availableFriends,
                    selectedReceiverIds: $viewModel.selectedReceiverIds,
                    initialComment: $viewModel.initialComment,
                    voiceData: $viewModel.voiceData,
                    isSecret: $viewModel.isSecret,
                    sendVideoWithSound: $viewModel.sendVideoWithSound,
                    onRetake: { viewModel.retakePhoto() },
                    onSend: { viewModel.sendPhotoInBackground() },
                    videoURL: videoURL,
                    videoDuration: viewModel.videoDuration
                )
                .transition(.opacity)
                .task {
                    // Pre-warm thumbnail async for next access
                    _ = await viewModel.extractThumbnailAsync(from: videoURL)
                }
            }
        }
    }

    private var loadingOverlay: some View {
        Group {
            if !viewModel.isAuthorized {
                if viewModel.permissionDenied {
                    // Camera permission denied — show settings redirect
                    VStack(spacing: 20) {
                        Image(systemName: "camera.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))

                    Text(String(localized: "kameraya ihtiyacımız var"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text(String(localized: "fotoğraf ve video çekmek için izin gerekli."))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(String(localized: "ayarlara git"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }

    // MARK: - Camera HUD

    private var cameraHUD: some View {
        VStack(spacing: 0) {
            // Top bar lives full-width so the friends pill stays centred on
            // screen. Tool cluster is layered above as a top-trailing overlay
            // (see `cameraHUDOverlay`) — keeping them in separate stacks
            // prevents the cluster from squeezing the bar's internal layout.
            CameraTopBar(
                profile: currentUserProfile,
                friendsCount: viewModel.availableFriends.count,
                onProfileTap: { showSettingsSheet = true }
            )

            Spacer()

            // ── Lens Selector ──
            if availableLenses.count > 1 {
                HStack(spacing: 8) {
                    ForEach(Array(availableLenses.enumerated()), id: \.offset) { _, lens in
                        Button {
                            currentZoom = lens.factor
                            Task { await CameraManager.shared.switchLens(to: lens.factor) }
                            HapticsManager.playSelection()
                        } label: {
                            Text(lens.label)
                                .font(.system(size: 13, weight: currentZoom == lens.factor ? .heavy : .semibold, design: .rounded))
                                .foregroundColor(currentZoom == lens.factor ? .black : .white.opacity(0.7))
                                .frame(width: 40, height: 40)
                                .background(currentZoom == lens.factor ? Color.white : Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.bottom, 12)
            }

            // ── REC Indicator ──
            if viewModel.isRecordingVideo {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(String(format: "%.1fs", viewModel.videoDuration))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .transition(.opacity)
                .padding(.bottom, 4)
            }

            if let message = viewModel.videoGuidanceMessage, !hasCapture {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isVideoReadyToFinish ? "checkmark.circle.fill" : "record.circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(viewModel.isVideoReadyToFinish ? .black : .white.opacity(0.85))

                    Text(message)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewModel.isVideoReadyToFinish ? .black : .white.opacity(0.88))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(viewModel.isVideoReadyToFinish ? Color.white : Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            viewModel.isVideoReadyToFinish ? Color.clear : Color.white.opacity(0.08),
                            lineWidth: 0.5
                        )
                )
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Kolaj count selector (only before first photo of a kolaj run) ──
            if viewModel.captureMode == .kolaj
                && (viewModel.collageState?.photos.count ?? 0) == 0
                && !viewModel.isRecordingVideo {
                KolajCountSelector(
                    count: Binding(
                        get: { viewModel.kolajPlannedCount },
                        set: { viewModel.kolajPlannedCount = $0 }
                    ),
                    onChange: { viewModel.setKolajPlannedCount($0) }
                )
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // ── Mode picker (above shutter) ──
            if !viewModel.isRecordingVideo {
                CameraModePicker(
                    mode: Binding(
                        get: { viewModel.captureMode },
                        set: { viewModel.captureMode = $0 }
                    )
                )
                .padding(.bottom, 14)
                .transition(.opacity)
            }

            // ── Bottom HUD: Flip · Shutter · Exposure ──
            HStack {
                // Left: camera flip — most-used control, always reachable.
                Button {
                    viewModel.toggleCamera()
                    HapticsManager.playImpact(style: .light)
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(String(localized: "kamera çevir"))

                Spacer()

                // Center: animated shutter — morphs by mode, gesture preserved.
                CameraShutter(
                    mode: viewModel.captureMode,
                    isRecordingVideo: viewModel.isRecordingVideo,
                    videoRecordingProgress: viewModel.videoRecordingProgress,
                    kolajCaptured: viewModel.collageState?.photos.count ?? 0,
                    kolajTarget: viewModel.kolajPlannedCount
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Basili tutuldu — video kayda basla (ilk frame'de).
                            if !viewModel.isRecordingVideo
                                && !shutterLongPressStarted
                                && viewModel.capturedPhotoData == nil
                                && viewModel.capturedVideoURL == nil {
                                shutterLongPressStarted = true
                                shutterPressTime = Date()
                                shutterDragStartZoom = currentZoom
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if shutterLongPressStarted && !viewModel.isRecordingVideo && viewModel.capturedPhotoData == nil && viewModel.capturedVideoURL == nil {
                                        viewModel.startVideoRecording()
                                    }
                                }
                            }

                            if viewModel.isRecordingVideo {
                                if shutterDragStartZoom == nil {
                                    shutterDragStartZoom = currentZoom
                                }

                                let startZoom = shutterDragStartZoom ?? currentZoom
                                let verticalTravel = max(0, -value.translation.height)
                                let zoomDelta = (verticalTravel / 160) * 4.0
                                let proposedZoom = max(0.5, min(startZoom + zoomDelta, 10.0))

                                if abs(proposedZoom - currentZoom) > 0.02 {
                                    currentZoom = proposedZoom
                                    pinchBaseZoom = proposedZoom
                                    Task { await CameraManager.shared.switchLens(to: proposedZoom) }
                                }
                            }
                        }
                        .onEnded { _ in
                            let elapsed = Date().timeIntervalSince(shutterPressTime ?? Date())
                            if viewModel.isRecordingVideo {
                                // Video kaydediyorduk — durdur
                                viewModel.stopVideoRecording()
                            } else if elapsed < 0.3 && viewModel.capturedPhotoData == nil && viewModel.capturedVideoURL == nil {
                                // Kisa dokunma — foto cek (timer varsa geri sayımı başlat)
                                triggerCapture()
                            }
                            shutterLongPressStarted = false
                            shutterPressTime = nil
                            shutterDragStartZoom = nil
                        }
                )
                .accessibilityLabel(String(localized: viewModel.isRecordingVideo ? "Kaydı Durdur" : "Fotoğraf Çek"))

                Spacer()

                // Right: exposure access — only present, not loud. Tap to
                // open the slider, lights up only when bias ≠ 0 so the user
                // can see at a glance that exposure is being shifted.
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        showExposureSlider.toggle()
                    }
                    HapticsManager.playSelection()
                } label: {
                    Image(systemName: viewModel.exposureBias == 0 ? "sun.max" : "sun.max.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.exposureBias == 0 ? .white : .black)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(viewModel.exposureBias == 0 ? Color.clear : Color.white)
                        )
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(String(localized: "Pozlama"))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 120)
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        await viewModel.checkAndConfigure()
        self.captureSession = await CameraManager.shared.session
        await viewModel.fetchAvailableFriends()

        // Load profile — retry if nil (post-signup race condition)
        var profile = await DependencyContainer.shared.userRepository.currentUserProfile
        if profile == nil {
            // Profile may not be ready yet after signup — wait briefly and retry
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            if let uid = FirebaseAuth.Auth.auth().currentUser?.uid {
                profile = try? await AuthService.shared.fetchProfile(for: uid)
            }
        }
        self.currentUserProfile = profile


        // Load available lenses
        self.availableLenses = await CameraManager.shared.availableLensOptions

        // QR code auto-detection: when camera sees a QR, show friend-add popup
        await CameraManager.shared.setQRCallback { code in
            Task { @MainActor [self] in
                guard !isInPreviewMode else { return }
                self.detectedQRCode = code
                HapticsManager.playNotification(type: .success)
            }
        }
    }


    // MARK: - Focus Ring Overlay

    private var focusRingOverlay: some View {
        Group {
            if showFocusRing, let point = focusPoint {
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .position(point)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(Brand.Animations.fade, value: showFocusRing)
    }

    // MARK: - Capture (with optional self-timer)

    /// Routes shutter taps through the self-timer (foto/kolaj) or the
    /// boomerang capture pipeline. Boomerang ignores the timer for now —
    /// the burst is too fast for a delay to feel useful.
    private func triggerCapture() {
        pendingTimerTask?.cancel()
        pendingTimerTask = nil

        let duration = viewModel.timerSetting.rawValue
        guard duration > 0 else {
            Task { await viewModel.capturePhoto() }
            return
        }

        timerCountdown = duration
        isTimerActive = true
        pendingTimerTask = Task { @MainActor in
            for n in stride(from: duration, through: 1, by: -1) {
                timerCountdown = n
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { isTimerActive = false; return }
            }
            isTimerActive = false
            await viewModel.capturePhoto()
        }
    }

    // profileInitialCircle moved into CameraTopBar.
}

private struct CameraFirstRunHints: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                hint(icon: "record.circle", text: String(localized: "basılı tut: video"))
                hint(icon: "arrow.triangle.2.circlepath.camera", text: String(localized: "çift dokun: kamera çevir"))
            }

            hint(icon: "plus.magnifyingglass", text: String(localized: "yakınlaştırmak için sıkıştır"))

            Button {
                HapticsManager.playSelection()
                onDismiss()
            } label: {
                Text(String(localized: "tamam"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }

    private func hint(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.1), in: Capsule())
    }
}
