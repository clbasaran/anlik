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
    @State private var currentZoom: CGFloat = 1.0
    @State private var availableLenses: [(factor: CGFloat, label: String)] = [(1.0, "1×")]
    @State private var detectedQRCode: String?
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusRing = false
    @State private var pinchBaseZoom: CGFloat = 1.0
    @State private var shutterLongPressStarted = false
    @State private var shutterPressTime: Date?
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
        }
        .ignoresSafeArea()
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
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isInPreviewMode = (newValue != nil) || viewModel.showCollageView || (viewModel.capturedVideoURL != nil)
                    if newValue != nil {
                        showExposureSlider = false
                        // In collage mode, auto-add captured photo to collage
                        if viewModel.isCollageMode && !viewModel.showCollageView {
                            viewModel.addToCollage()
                        }
                    }
                }
            }
            .onChange(of: viewModel.capturedVideoURL) { _, newValue in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isInPreviewMode = (newValue != nil) || viewModel.showCollageView || (viewModel.capturedPhotoData != nil)
                    if newValue != nil {
                        showExposureSlider = false
                    }
                }
            }
            .onChange(of: viewModel.showCollageView) { _, newValue in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isInPreviewMode = newValue || (viewModel.capturedPhotoData != nil) || (viewModel.capturedVideoURL != nil)
                }
            }
            .errorAlert(errorMessage: $viewModel.errorMessage, retryAction: viewModel.canRetry ? { viewModel.retrySend() } : nil)
            .sheet(isPresented: $showSettingsSheet) {
                if let profile = currentUserProfile {
                    SettingsView(profile: profile, onLogout: {
                        showSettingsSheet = false
                        AnalyticsService.shared.log(.logout)
                        Task {
                            try? DependencyContainer.shared.userRepository.logout()
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
        ZStack {
            if viewModel.isAuthorized && !hasCapture {
                cameraHUD
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
            if viewModel.showCollageView {
                // Collage layout picker
                CollageView(
                    photos: viewModel.collagePhotos,
                    onFinalize: { collageImage in
                        viewModel.finalizeCollage(image: collageImage)
                    },
                    onCancel: {
                        viewModel.cancelCollage()
                    },
                    onAddMore: {
                        viewModel.addMoreFromCollage()
                    },
                    onRemovePhoto: { index in
                        viewModel.removeFromCollage(at: index)
                    },
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
                    onRetake: {
                        if viewModel.isCollageMode {
                            viewModel.capturedPhotoData = nil
                            viewModel.startSession()
                        } else {
                            viewModel.retakePhoto()
                        }
                    },
                    onSend: { viewModel.sendPhotoInBackground() },
                    onCollage: viewModel.isCollageMode ? nil : {
                        viewModel.startCollage()
                    }
                )
                .transition(.opacity)
            } else if let videoURL = viewModel.capturedVideoURL {
                // Video clip preview
                PreviewView(
                    image: viewModel.extractThumbnail(from: videoURL) ?? UIImage(),
                    isUploading: viewModel.isUploading,
                    showSuccess: viewModel.isSuccessBoomActive,
                    availableFriends: viewModel.availableFriends,
                    selectedReceiverIds: $viewModel.selectedReceiverIds,
                    initialComment: $viewModel.initialComment,
                    voiceData: $viewModel.voiceData,
                    isSecret: $viewModel.isSecret,
                    onRetake: { viewModel.retakePhoto() },
                    onSend: { viewModel.sendPhotoInBackground() },
                    videoURL: videoURL,
                    videoDuration: viewModel.videoDuration
                )
                .transition(.opacity)
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

                        Text("kamera izni gerekli")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("fotoğraf çekebilmek için\nayarlardan kamera iznini aç.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)

                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text("ayarlara git")
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
            // ── Top bar: respects safe area via safeAreaInset ──
            HStack {
                // Top Left: Profile
                Button {
                    HapticsManager.playImpact(style: .light)
                    showSettingsSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        if let profile = currentUserProfile,
                           let urlString = profile.avatarUrl,
                           let url = URL(string: urlString) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                                    .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                            } placeholder: {
                                profileInitialCircle
                            }
                        } else {
                            profileInitialCircle
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel(String(localized: "Profil ve Ayarlar"))
                .accessibilityHint(String(localized: "Ayarları açıp profilini görmek için çift dokun"))

                Spacer()
                
                // Top Middle: Friends Pill
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(String(localized: "\(viewModel.availableFriends.count) arkadaş"))
                        .font(.system(.subheadline, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                .accessibilityLabel(String(localized: "\(viewModel.availableFriends.count) arkadaş bağlı"))

                Spacer()
                
                // Empty spacer for balance (inbox moved to friends tab)
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

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

            // ── Bottom HUD: Flash, Shutter, Flip ──
            HStack {
                // Left side controls
                VStack(spacing: 10) {
                    // Flash Toggle (off → on → auto)
                    Button {
                        viewModel.toggleFlash()
                    } label: {
                    Image(systemName: viewModel.flashSetting.icon)
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundColor(viewModel.flashSetting == .off ? .white : .yellow)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(String(localized: "Flaş: \(viewModel.flashSetting.label)"))
                    

                }
                
                Spacer()

                // Shutter (tap = photo, long-press = video)
                ZStack {
                    // Progress ring (visible during video recording)
                    if viewModel.isRecordingVideo {
                        Circle()
                            .trim(from: 0, to: viewModel.videoRecordingProgress)
                            .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 84, height: 84)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.05), value: viewModel.videoRecordingProgress)
                    }

                    // Outer ring
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 2.5)
                        .frame(width: 78, height: 78)

                    // Inner circle
                    Circle()
                        .fill(viewModel.isRecordingVideo ? Color.red : Color.white)
                        .frame(
                            width: viewModel.isRecordingVideo ? 72 : 62,
                            height: viewModel.isRecordingVideo ? 72 : 62
                        )
                        .animation(.easeInOut(duration: 0.2), value: viewModel.isRecordingVideo)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            // Basili tutuldu — video kayda basla (ilk frame'de)
                            if !viewModel.isRecordingVideo && !shutterLongPressStarted && viewModel.capturedPhotoData == nil && viewModel.capturedVideoURL == nil {
                                shutterLongPressStarted = true
                                shutterPressTime = Date()
                                // 0.3sn bekle, hala basili tutuluyorsa video basla
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if shutterLongPressStarted && !viewModel.isRecordingVideo && viewModel.capturedPhotoData == nil && viewModel.capturedVideoURL == nil {
                                        viewModel.startVideoRecording()
                                    }
                                }
                            }
                        }
                        .onEnded { _ in
                            let elapsed = Date().timeIntervalSince(shutterPressTime ?? Date())
                            if viewModel.isRecordingVideo {
                                // Video kaydediyorduk — durdur
                                viewModel.stopVideoRecording()
                            } else if elapsed < 0.3 && viewModel.capturedPhotoData == nil && viewModel.capturedVideoURL == nil {
                                // Kisa dokunma — foto cek
                                Task { await viewModel.capturePhoto() }
                            }
                            shutterLongPressStarted = false
                            shutterPressTime = nil
                        }
                )
                .accessibilityLabel(String(localized: viewModel.isRecordingVideo ? "Kaydi Durdur" : "Fotograf Cek"))
                
                Spacer()
                
                // Right side controls stack
                VStack(spacing: 10) {
                                        // Exposure
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            showExposureSlider.toggle()
                        }
                        HapticsManager.playSelection()
                    } label: {
                        Image(systemName: viewModel.exposureBias == 0 ? "sun.max" : "sun.max.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(String(localized: "Pozlama"))
                }
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
                    .stroke(Color.yellow, lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .position(point)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showFocusRing)
    }
    
        private var profileInitialCircle: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(currentUserProfile?.displayName?.prefix(1) ?? "?"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.white)
            )
            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}
