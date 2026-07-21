import SwiftUI
import AVFoundation
import AVKit
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

    /// Hardware capture-button interaction (Camera Control / volume buttons),
    /// kept so updateUIView can toggle isEnabled with surface visibility.
    var captureEventInteraction: AVCaptureEventInteraction?

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
    /// Fired when the user presses a hardware capture button — the Camera
    /// Control full press (iPhone 16+) or a volume button.
    var onHardwareCapture: (() -> Void)? = nil
    /// Gates hardware capture events so volume buttons behave normally when the
    /// camera isn't the active surface (other tab, preview open).
    var hardwareCaptureEnabled: Bool = true

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.session = session
        view.videoGravity = videoGravity

        if let onHardwareCapture {
            // Camera Control full press and volume-button presses arrive here
            // while a capture session is active and this view is on screen.
            let interaction = AVCaptureEventInteraction { event in
                guard event.phase == .began else { return }
                onHardwareCapture()
            }
            interaction.isEnabled = hardwareCaptureEnabled
            view.addInteraction(interaction)
            view.captureEventInteraction = interaction
        }
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        uiView.session = session
        uiView.videoGravity = videoGravity
        uiView.captureEventInteraction?.isEnabled = hardwareCaptureEnabled
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
    @State private var showCaptureFlash = false
    @AppStorage("camera.firstRunHints.dismissed") private var cameraHintsDismissed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                CameraPreviewView(
                    session: session,
                    onHardwareCapture: {
                        // Camera Control full press / volume button: same
                        // behavior as the on-screen shutter.
                        guard TabBarState.shared.selectedTab == .camera, !hasCapture else { return }
                        if viewModel.isRecordingVideo {
                            viewModel.stopVideoRecording()
                        } else {
                            triggerCapture()
                        }
                    },
                    hardwareCaptureEnabled: TabBarState.shared.selectedTab == .camera && !hasCapture
                )
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
            .overlay(captureFlashOverlay)
            .overlay(cameraHUDOverlay)
            // Coach mark lives in the lower third, just above the controls it
            // explains — the center of the viewfinder (the subject) stays clear.
            .overlay(alignment: .bottom) {
                if viewModel.isAuthorized && !hasCapture && !cameraHintsDismissed {
                    CameraFirstRunHints {
                        withAnimation(.easeOut(duration: 0.22)) {
                            cameraHintsDismissed = true
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 258)
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // While a first moment sits in the queue (or a request is
                // pending), every foreground is a chance the friend accepted —
                // refresh so the waiting chip flips to "şimdi gönder" without
                // extra taps (yeni-kullanici-1 / yeni-kullanici-6). The
                // friend cache never holds an empty list, so this always
                // hits the network only when it matters.
                if (viewModel.hasQueuedFirstMoment || viewModel.hasPendingFriendRequest)
                    && viewModel.availableFriends.isEmpty {
                    Task { await viewModel.fetchAvailableFriends() }
                }
            }
            // Hardware Camera Control sliders (iPhone 16+) drive the device
            // directly — mirror their values into the on-screen HUD.
            .onReceive(NotificationCenter.default.publisher(for: .cameraControlZoomChanged)) { note in
                if let zoom = note.userInfo?["zoom"] as? CGFloat {
                    currentZoom = zoom
                    pinchBaseZoom = zoom
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .cameraControlExposureChanged)) { note in
                if let bias = note.userInfo?["bias"] as? Float {
                    viewModel.exposureBias = bias
                }
            }
            .onChange(of: viewModel.capturedPhotoData) { _, newValue in
                // Shutter confirmation: a brief white flash over the
                // viewfinder the instant a capture lands. Skipped entirely
                // under Reduce Motion.
                if newValue != nil && !reduceMotion {
                    withAnimation(.easeOut(duration: 0.06)) {
                        showCaptureFlash = true
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(90))
                        withAnimation(.easeOut(duration: 0.22)) {
                            showCaptureFlash = false
                        }
                    }
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
                // Top banner slot — exactly one of three surfaces:
                // 1) Persisted-draft retry banner (failed upload, guven-5)
                // 2) Queued first-moment chip (yeni-kullanici-1)
                // 3) Pending-request waiting chip (yeni-kullanici-6)
                if viewModel.canRetry && !isInPreviewMode {
                    DraftRetryBanner(
                        onRetry: { viewModel.retrySend() },
                        onCancel: { viewModel.cancelDraft() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else if viewModel.hasQueuedFirstMoment
                            && !isInPreviewMode
                            && viewModel.isAuthorized {
                    QueuedFirstMomentChip(
                        isReadyToSend: !viewModel.availableFriends.isEmpty,
                        onSendNow: { viewModel.sendQueuedFirstMoment() },
                        onDiscard: { viewModel.discardQueuedFirstMoment() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else if viewModel.availableFriends.isEmpty
                            && viewModel.hasPendingFriendRequest
                            && !isInPreviewMode
                            && viewModel.isAuthorized {
                    PendingRequestWaitChip()
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.canRetry)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.hasQueuedFirstMoment)
            // One-time first-send celebration (yeni-kullanici-8). Sits above
            // every camera surface; tap anywhere to dismiss — the deferred
            // notification-permission ask fires only after dismissal.
            .overlay {
                if viewModel.showFirstSendOverlay {
                    FirstSendCelebrationOverlay {
                        viewModel.dismissFirstSendOverlay()
                    }
                    .transition(.opacity)
                }
            }
            .animationAccessible(Brand.Animations.standard, value: viewModel.showFirstSendOverlay)
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
                            .font(Brand.scaledFont(size: 14, weight: .bold, relativeTo: .footnote))
                            .foregroundColor(.white)
                            .accessibilityHidden(true)

                        // Vertical slider via rotated horizontal Slider
                        Slider(value: Binding(
                            get: { viewModel.exposureBias },
                            set: { viewModel.setExposure($0) }
                        ), in: -2.0...2.0, step: 0.1)
                        .tint(.white)
                        .frame(width: 180)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 30, height: 180)
                        .accessibilityLabel(String(localized: "pozlama"))
                        .accessibilityValue(Text(viewModel.exposureBias.formatted(.number.precision(.fractionLength(1)))))

                        Image(systemName: "sun.min")
                            .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
                            .foregroundColor(.white.opacity(0.5))
                            .accessibilityHidden(true)

                        // Reset button
                        Button {
                            viewModel.setExposure(0)
                            HapticsManager.playSelection()
                        } label: {
                            Text("0")
                                .font(Brand.scaledFont(size: 12, weight: .heavy, relativeTo: .caption))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(viewModel.exposureBias == 0 ? Color.white.opacity(0.15) : Color.white.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(String(localized: "pozlamayı sıfırla"))
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
                        } else if viewModel.availableFriends.isEmpty
                                    && TabBarState.shared.selectedTab != .camera {
                            // yeni-kullanici-1: this retake is the tail of the
                            // "arkadaş ekle" redirect (PreviewSendButton
                            // switches to the friends tab first, then calls
                            // onRetake) — park the capture as a queued first
                            // moment instead of discarding it.
                            viewModel.queueCaptureForFirstFriend()
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
                    onRetake: {
                        if viewModel.availableFriends.isEmpty
                            && TabBarState.shared.selectedTab != .camera {
                            // Same first-moment rescue as the photo path
                            // (yeni-kullanici-1).
                            viewModel.queueCaptureForFirstFriend()
                        } else {
                            viewModel.retakePhoto()
                        }
                    },
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
                            .font(Brand.scaledFont(size: 20, weight: .bold, relativeTo: .title3))
                            .foregroundColor(.white)

                        Text(String(localized: "fotoğraf ve video çekmek için izin gerekli."))
                            .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(String(localized: "ayarlara git"))
                                .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
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
            // One dark blur capsule holding every lens (Apple Camera language):
            // stays legible over any scene, light or dark. The active lens is
            // full-white text on a subtle white fill — solid white is reserved
            // for the shutter, the single hero of this deck. Highlight follows
            // the *nearest* lens so continuous zoom (pinch, Camera Control
            // slider) never leaves the row unselected.
            if availableLenses.count > 1 {
                let activeFactor = availableLenses.min {
                    abs($0.factor - currentZoom) < abs($1.factor - currentZoom)
                }?.factor
                HStack(spacing: 2) {
                    ForEach(Array(availableLenses.enumerated()), id: \.offset) { _, lens in
                        let isSelected = lens.factor == activeFactor
                        Button {
                            currentZoom = lens.factor
                            pinchBaseZoom = lens.factor
                            Task { await CameraManager.shared.switchLens(to: lens.factor) }
                            HapticsManager.playSelection()
                        } label: {
                            Text(isSelected ? lens.label : String(lens.label.dropLast()))
                                .font(.system(size: isSelected ? 13 : 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(isSelected ? 0.18 : 0)))
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "lens \(lens.label)"))
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 4)
                .background(Capsule().fill(Color.black.opacity(0.32)))
                .background(Capsule().fill(.ultraThinMaterial).opacity(0.5))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
                .clipShape(Capsule())
                .animation(Brand.Animations.snap, value: activeFactor)
                .padding(.bottom, Brand.Spacing.md)
            }

            // ── REC Indicator ──
            if viewModel.isRecordingVideo {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(String(format: "%.1fs", viewModel.videoDuration))
                        .font(Brand.scaledFont(size: 14, weight: .semibold, design: .monospaced, relativeTo: .footnote))
                        .foregroundColor(.white)
                }
                .transition(.opacity)
                .padding(.bottom, 4)
            }

            if let message = viewModel.videoGuidanceMessage, !hasCapture {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isVideoReadyToFinish ? "checkmark.circle.fill" : "record.circle")
                        .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(viewModel.isVideoReadyToFinish ? .black : .white.opacity(0.85))

                    Text(message)
                        .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
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

            // ── Daily prompt banner (günün görevi) — duygusal-9 ──
            // Sits directly above the mode picker; hidden while recording so
            // the REC HUD keeps its space. Dismissable per day; flips to its
            // "gönderildi" state in place when the day's first strip is sent.
            if !viewModel.isRecordingVideo,
               !viewModel.isDailyPromptBannerDismissed,
               viewModel.dailyPrompt != nil {
                DailyPromptBannerView(
                    prompt: viewModel.dailyPrompt,
                    isCompleted: viewModel.isDailyPromptCompleted,
                    onDismiss: {
                        withAnimation(Brand.Animations.standard) {
                            viewModel.dismissDailyPromptBanner()
                        }
                    }
                )
                .animationAccessible(Brand.Animations.standard, value: viewModel.isDailyPromptCompleted)
                .padding(.bottom, 10)
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
                .padding(.bottom, Brand.Spacing.lg)
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
                        .font(Brand.scaledFont(size: 18, weight: .semibold, relativeTo: .title3))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .glassEffect(.regular.interactive(), in: .circle)
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
                // VoiceOver intercepts drag gestures, so the DragGesture above is
                // unreachable with VoiceOver running. Expose the same capabilities
                // as explicit accessibility actions: default activate = capture
                // (or stop an active recording), named action = start/stop video.
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(String(localized: "fotoğraf için dokun, video için basılı tut"))
                .accessibilityAction {
                    if viewModel.isRecordingVideo {
                        viewModel.stopVideoRecording()
                    } else if viewModel.capturedPhotoData == nil && viewModel.capturedVideoURL == nil {
                        triggerCapture()
                    }
                }
                .accessibilityAction(named: Text(String(localized: viewModel.isRecordingVideo ? "videoyu durdur" : "video kaydet"))) {
                    if viewModel.isRecordingVideo {
                        viewModel.stopVideoRecording()
                    } else if viewModel.capturedPhotoData == nil && viewModel.capturedVideoURL == nil {
                        viewModel.startVideoRecording()
                    }
                }
                .accessibilityValue(
                    viewModel.collageState != nil
                        ? Text(String(localized: "kolaj \(viewModel.collageState?.photos.count ?? 0)/\(viewModel.kolajPlannedCount)"))
                        : Text("")
                )

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
                        .font(Brand.scaledFont(size: 18, weight: .semibold, relativeTo: .title3))
                        .foregroundStyle(viewModel.exposureBias == 0 ? .white : .black)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(viewModel.exposureBias == 0 ? Color.clear : Color.white)
                        )
                        .glassEffect(.regular.interactive(), in: .circle)
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

        // Daily prompt for the HUD banner (cached per day inside the VM)
        await viewModel.loadDailyPrompt()

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

    // MARK: - Capture Flash Overlay

    /// Brief full-screen white flash confirming a photo capture — snaps in
    /// (0.06s) and eases out (0.22s). Never shown when Reduce Motion is on.
    private var captureFlashOverlay: some View {
        Group {
            if showCaptureFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

/// First-run gesture hints. Design intent: a single quiet card that sits just
/// above the controls it explains (never over the viewfinder's center), reads
/// as one left-aligned list instead of floating chips, dismisses on tap
/// anywhere, on "tamam", or by itself after 8 seconds — a coach mark, not a
/// modal.
private struct CameraFirstRunHints: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            hintRow(icon: "record.circle", text: String(localized: "basılı tut: video"))
            hintRow(icon: "arrow.triangle.2.circlepath.camera", text: String(localized: "çift dokun: kamera çevir"))
            hintRow(icon: "plus.magnifyingglass", text: String(localized: "yakınlaştırmak için sıkıştır"))

            HStack {
                Spacer()
                Text(String(localized: "tamam"))
                    .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white, in: Capsule())
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: 280, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous))
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
        // The whole card is the dismiss control — no tiny target hunting.
        .contentShape(RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous))
        .onTapGesture {
            HapticsManager.playSelection()
            onDismiss()
        }
        .task {
            // Self-dismiss so the card never overstays; the explicit tap path
            // remains for users who want it gone sooner (and for VoiceOver).
            try? await Task.sleep(for: .seconds(8))
            onDismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(String(localized: "kapatmak için dokun"))
    }

    private func hintRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.white)
                .frame(width: 20)
            Text(text)
                .font(Brand.scaledFont(size: 13, weight: .medium, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

// MARK: - Queued First Moment Chip (yeni-kullanici-1)

/// Waiting card for the parked first moment. Two states: waiting (no
/// accepted friend yet) and ready (friend list non-empty → one-tap "şimdi
/// gönder"). Auto-send is deliberately avoided — the moment leaves only on
/// an explicit tap. Discard is gated behind a confirm dialog because the
/// draft holds the only copy of the capture.
private struct QueuedFirstMomentChip: View {
    let isReadyToSend: Bool
    let onSendNow: () -> Void
    let onDiscard: () -> Void

    @State private var showDiscardConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isReadyToSend ? "paperplane.circle" : "clock")
                .font(Brand.scaledFont(size: 14, weight: .semibold, relativeTo: .footnote))
                .foregroundStyle(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "ilk anın hazır."))
                    .font(Brand.scaledFont(size: 13, weight: .bold, relativeTo: .footnote))
                    .foregroundStyle(.white)
                Text(isReadyToSend
                     ? String(localized: "şimdi gönderebilirsin.")
                     : String(localized: "arkadaşın kabul edince gönderilecek."))
                    .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer()
            if isReadyToSend {
                Button {
                    HapticsManager.playImpact(style: .medium)
                    onSendNow()
                } label: {
                    Text(String(localized: "şimdi gönder"))
                        .font(Brand.scaledFont(size: 12, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Button {
                showDiscardConfirm = true
            } label: {
                Image(systemName: "xmark")
                    .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "taslağı sil"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        .confirmationDialog(
            String(localized: "taslağı sil?"),
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "taslağı sil"), role: .destructive) {
                onDiscard()
            }
            Button(String(localized: "vazgeç"), role: .cancel) {}
        } message: {
            Text(String(localized: "gönderilmeyen an kalıcı olarak silinir."))
        }
    }
}

// MARK: - Pending Request Wait Chip (yeni-kullanici-6)

/// Camera waiting state while a friend request is still pending: explains
/// why sending isn't possible yet and routes to the friends tab on tap.
private struct PendingRequestWaitChip: View {
    var body: some View {
        Button {
            HapticsManager.playSelection()
            TabBarState.shared.selectedTab = .friends
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "hourglass")
                    .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.7))
                Text(String(localized: "istek bekliyor — kabul edilince gönderebilirsin."))
                    .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint(String(localized: "arkadaşlar sekmesini açar."))
    }
}

// MARK: - First Send Celebration (yeni-kullanici-8)

/// One-time overlay after the very first send: quiet monochrome celebration
/// plus a pointer at where moments accumulate. The whole screen is the
/// dismiss control.
private struct FirstSendCelebrationOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                Text(String(localized: "ilk anın yolda."))
                    .font(Brand.scaledFont(size: 22, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(.white)
                Text(String(localized: "anıların geçmişte birikir."))
                    .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.6))
                Text(String(localized: "kapatmak için dokun"))
                    .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 18)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(String(localized: "kapatmak için dokun"))
    }
}
