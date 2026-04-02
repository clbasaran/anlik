import SwiftUI
import AVFoundation
import Photos

// MARK: - Preview View (Full-Screen Takeover)

public struct PreviewView: View {
    let image: UIImage
    var isUploading: Bool
    var showSuccess: Bool
    var availableFriends: [FriendStatus]
    @Binding var selectedReceiverIds: Set<String>
    @Binding var initialComment: String
    @Binding var voiceData: Data?
    @Binding var isSecret: Bool
    var onRetake: () -> Void
    var onSend: () -> Void
    var onCollage: (() -> Void)?
    var videoURL: URL?
    var videoDuration: Double?

    init(image: UIImage, isUploading: Bool, showSuccess: Bool, availableFriends: [FriendStatus], selectedReceiverIds: Binding<Set<String>>, initialComment: Binding<String>, voiceData: Binding<Data?>, isSecret: Binding<Bool>, onRetake: @escaping () -> Void, onSend: @escaping () -> Void, onCollage: (() -> Void)? = nil, videoURL: URL? = nil, videoDuration: Double? = nil) {
        self.image = image
        self.isUploading = isUploading
        self.showSuccess = showSuccess
        self.availableFriends = availableFriends
        self._selectedReceiverIds = selectedReceiverIds
        self._initialComment = initialComment
        self._voiceData = voiceData
        self._isSecret = isSecret
        self.onRetake = onRetake
        self.onSend = onSend
        self.onCollage = onCollage
        self.videoURL = videoURL
        self.videoDuration = videoDuration
    }

    @State private var showFriendSheet = false
    @State private var controlsVisible = false
    @State private var isRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingTimer: Timer?
    @State private var hasVoice = false
    @State private var isSavingToGallery = false
    @State private var showSavedToast = false

    public var body: some View {
        Color.clear
            .background(
                // Background layers: full-bleed, ignores safe area
                ZStack {
                    Color.black

                    GeometryReader { geo in
                        if let videoURL {
                            VideoPlayerView(url: videoURL, startMuted: false)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .blur(radius: showSuccess ? 20 : 0)
                                .scaleEffect(showSuccess ? 1.05 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSuccess)
                                .accessibilityLabel(String(localized: "Çekilen video önizlemesi"))
                        } else {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .blur(radius: showSuccess ? 20 : 0)
                                .scaleEffect(showSuccess ? 1.05 : 1.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSuccess)
                                .allowsHitTesting(false)
                                .accessibilityLabel(String(localized: "Çekilen fotoğraf önizlemesi"))
                        }
                    }

                    // Gradient protection overlays
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.black.opacity(0.45), .black.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 160)
                        .allowsHitTesting(false)

                        Spacer()

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.15), .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                        .allowsHitTesting(false)
                    }
                }
                .ignoresSafeArea()
            )
            .overlay(
                // Controls layer: respects safe area naturally
                VStack {
                    // Top row: Retake (X)
                    HStack {
                        retakeButton
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                    Spacer()

                    // Upload progress indicator
                    if isUploading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                            Text(String(localized: "gönderiliyor..."))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Bottom controls — adaptive layout for all iPhone sizes
                    GeometryReader { geo in
                        let isCompact = geo.size.width < 380 // iPhone SE, Mini
                        let btnSize: CGFloat = isCompact ? 42 : 48
                        let btnSpacing: CGFloat = isCompact ? 10 : 14
                        let hPad: CGFloat = isCompact ? 14 : 20

                        VStack(spacing: 0) {
                            Spacer()

                            VStack(spacing: isCompact ? 10 : 14) {
                                // Status labels (gizli an / saved toast)
                                if isSecret {
                                    HStack(spacing: 6) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("gizli an")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                    .transition(.scale.combined(with: .opacity))
                                }

                                if showSavedToast {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .bold))
                                        Text(String(localized: "galeriye kaydedildi"))
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .transition(.scale.combined(with: .opacity))
                                }

                                // Video duration badge
                                if videoURL != nil, let dur = videoDuration {
                                    HStack(spacing: 6) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(String(format: "%.1f sn", dur))
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                    .transition(.scale.combined(with: .opacity))
                                }

                                // Two-row layout: action buttons on top, send button below
                                // Row 1: Tool buttons (centered)
                                HStack(spacing: btnSpacing) {
                                    // Galeriye kaydet
                                    Button {
                                        Task { await saveToGallery() }
                                    } label: {
                                        Image(systemName: isSavingToGallery ? "arrow.down.circle" : "square.and.arrow.down")
                                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.8))
                                            .frame(width: btnSize, height: btnSize)
                                            .background(Color.white.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(isSavingToGallery || isUploading || showSuccess)
                                    .accessibilityLabel(String(localized: "Galeriye kaydet"))

                                    // Kolaj
                                    if let onCollage {
                                        Button {
                                            HapticsManager.playImpact(style: .light)
                                            onCollage()
                                        } label: {
                                            Image(systemName: "square.grid.2x2")
                                                .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.8))
                                                .frame(width: btnSize, height: btnSize)
                                                .background(Color.white.opacity(0.12))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .disabled(isUploading || showSuccess)
                                        .accessibilityLabel(String(localized: "Kolaj"))
                                    }

                                    // Ses kaydı (video zaten ses içerir)
                                    if videoURL == nil {
                                        voiceRecordButton
                                    }

                                    // Gizli an toggle
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            isSecret.toggle()
                                        }
                                        HapticsManager.playImpact(style: .light)
                                    } label: {
                                        Image(systemName: isSecret ? "lock.fill" : "lock.open")
                                            .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                            .foregroundColor(isSecret ? .black : .white.opacity(0.6))
                                            .frame(width: btnSize, height: btnSize)
                                            .background(isSecret ? Color.white : Color.white.opacity(0.12))
                                            .clipShape(Circle())
                                    }
                                    .accessibilityLabel(isSecret ? "Gizli an açık" : "Gizli an kapalı")
                                }

                                // Row 2: Full-width send button
                                sendButton
                            }
                            .padding(.horizontal, hPad)
                            .padding(.bottom, isCompact ? 12 : 20)
                        }
                    }
                }
                .opacity(controlsVisible && !showSuccess ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: controlsVisible)
                .animation(.easeInOut(duration: 0.2), value: showSuccess)
            )
            .overlay(
                // Success boom: also in overlay so it's above controls
                Group {
                    if showSuccess {
                        successOverlay
                            .transition(.opacity)
                    }
                }
            )
        .onAppear {
            Task { try? await Task.sleep(for: .seconds(0.2)); withAnimation { controlsVisible = true } }
        }
        .sheet(isPresented: $showFriendSheet) {
            FriendSelectionSheet(
                friends: availableFriends,
                selectedIds: $selectedReceiverIds,
                commentText: $initialComment,
                onSend: {
                    showFriendSheet = false
                    onSend()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
    }

    // MARK: - Retake Button

    private var retakeButton: some View {
        Button {
            HapticsManager.playSelection()
            onRetake()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .bold, design: .default))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.15), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isUploading || showSuccess)
        .accessibilityLabel(String(localized: "Tekrar Çek"))
    }

    // MARK: - Voice Record Button

    private var voiceRecordButton: some View {
        HStack(spacing: 10) {
            Button {
                if isRecording {
                    stopRecording()
                } else if hasVoice {
                    // Sesi sil
                    voiceData = nil
                    hasVoice = false
                    recordingDuration = 0
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isRecording ? "stop.fill" : hasVoice ? "xmark" : "mic.fill")
                        .font(.system(size: 14, weight: .bold))
                    if isRecording {
                        Text(String(format: "%.0f sn", recordingDuration))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    } else if hasVoice {
                        Text(String(format: "%.0f sn", recordingDuration))
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundColor(isRecording ? .white : hasVoice ? .white : .white.opacity(0.8))
                .padding(.horizontal, hasVoice || isRecording ? 16 : 12)
                .padding(.vertical, 12)
                .background(
                    isRecording ? Color.white.opacity(0.3) : hasVoice ? Color.white.opacity(0.2) : Color.white.opacity(0.15),
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(isRecording ? Color.white.opacity(0.5) : hasVoice ? Color.white.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 0.5)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isUploading || showSuccess)

            if hasVoice {
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: tempURL, settings: settings)
            recorder.record()
            audioRecorder = recorder
            isRecording = true
            recordingDuration = 0
            HapticsManager.playImpact(style: .medium)

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                Task { @MainActor in
                    recordingDuration = audioRecorder?.currentTime ?? 0
                    if recordingDuration >= 15 { stopRecording() }
                }
            }
        } catch { return }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        guard let recorder = audioRecorder else { return }
        let url = recorder.url
        recorder.stop()
        audioRecorder = nil
        isRecording = false
        HapticsManager.playNotification(type: .success)

        if let data = try? Data(contentsOf: url), recordingDuration >= 0.5 {
            voiceData = data
            hasVoice = true
        }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Save to Gallery

    private func saveToGallery() async {
        isSavingToGallery = true
        defer { isSavingToGallery = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            HapticsManager.playNotification(type: .error)
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            HapticsManager.playNotification(type: .success)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showSavedToast = true
            }
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showSavedToast = false }
        } catch {
            HapticsManager.playNotification(type: .error)
        }
    }

    // MARK: - Send Button

    @State private var showNoFriendsAlert = false

    private var sendButton: some View {
        Button {
            HapticsManager.playImpact(style: .medium)
            if availableFriends.isEmpty {
                showNoFriendsAlert = true
            } else {
                showFriendSheet = true
            }
        } label: {
            HStack(spacing: 8) {
                Text(availableFriends.isEmpty ? String(localized: "arkadaş ekle") : String(localized: "gönder"))
                    .font(.system(.title3, weight: .heavy))
                Image(systemName: availableFriends.isEmpty ? "person.badge.plus" : "chevron.right")
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(showSuccess)
        .accessibilityLabel(availableFriends.isEmpty ? String(localized: "Arkadaş Ekle") : String(localized: "Fotoğraf Gönder"))
        .alert(String(localized: "arkadaş ekle"), isPresented: $showNoFriendsAlert) {
            Button(String(localized: "arkadaş ekle")) {
                TabBarState.shared.selectedTab = .friends
                onRetake()
            }
            Button(String(localized: "iptal"), role: .cancel) { }
        } message: {
            Text(String(localized: "fotoğraf göndermek için en az bir arkadaş eklemelisin."))
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 110))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.white.opacity(0.15), radius: 30, y: 10)
                    .scaleEffect(showSuccess ? 1.2 : 0.01)
                    .rotationEffect(.degrees(showSuccess ? 0 : -45))
                    .opacity(showSuccess ? 1 : 0)

                Text(String(localized: "gönderildi!"))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(showSuccess ? 1 : 0.5)
                    .opacity(showSuccess ? 1 : 0)
            }
        }
    }
}

// MARK: - Friend Selection Sheet

struct FriendSelectionSheet: View {
    let friends: [FriendStatus]
    @Binding var selectedIds: Set<String>
    @Binding var commentText: String
    let onSend: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Handle + Header ──
            VStack(spacing: 6) {
                Text(String(localized: "arkadaş seç"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            // ── Scrollable friend list ──
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    // Individual friends — multi-select with toggle
                    ForEach(friends, id: \.userId) { friend in
                        let name = friend.profile?.displayName ?? friend.profile?.username ?? String(localized: "bilinmeyen")
                        let avatarUrl = friend.profile?.avatarUrl
                        friendRow(
                            label: name,
                            subtitle: nil,
                            isSelected: selectedIds.contains(friend.userId),
                            avatarUrl: avatarUrl,
                            icon: "person.fill",
                            iconSize: 16
                        ) {
                            HapticsManager.playSelection()
                            // Multi-select toggle
                            if selectedIds.contains(friend.userId) {
                                selectedIds.remove(friend.userId)
                            } else {
                                selectedIds.insert(friend.userId)
                            }
                        }
                    }
                    
                    // Select All row
                    if friends.count > 1 {
                        friendRow(
                            label: String(localized: "herkese gönder"),
                            subtitle: "\(friends.count) arkadaş",
                            isSelected: selectedIds.count == friends.count,
                            icon: "person.2.fill",
                            iconSize: 16
                        ) {
                            HapticsManager.playSelection()
                            if selectedIds.count == friends.count {
                                selectedIds.removeAll()
                            } else {
                                selectedIds = Set(friends.map { $0.userId })
                            }
                        }
                    }
                }
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)

            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            // ── Pinned action area: message field + send button ──
            VStack(spacing: 12) {
                // Message text field
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                    
                    TextField(String(localized: "Mesaj ekle..."), text: $commentText, axis: .vertical)
                        .font(.system(.body, design: .default).weight(.medium))
                        .foregroundColor(.white)
                        .lineLimit(1...4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                
                sendNowButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0), .black, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                .allowsHitTesting(false)
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }

    // MARK: - Send Now Button

    private var selectedFriendName: String? {
        guard let selectedId = selectedIds.first else { return nil }
        let friend = friends.first(where: { $0.userId == selectedId })
        return friend?.profile?.displayName ?? friend?.profile?.username
    }

    private var sendButtonLabel: String {
        if selectedIds.isEmpty {
            return String(localized: "arkadaş seç")
        } else if selectedIds.count == 1, let name = selectedFriendName {
            return "\(name)'e gönder"
        } else {
            return "\(selectedIds.count) kişiye gönder"
        }
    }

    private var sendNowButton: some View {
        Button {
            HapticsManager.playImpact(style: .heavy)
            onSend()
        } label: {
            Text(sendButtonLabel)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(selectedIds.isEmpty ? .white : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    Group {
                        if selectedIds.isEmpty {
                            Color.white.opacity(0.1)
                        } else {
                            Color.white
                        }
                    }
                )
                .clipShape(Capsule())
                .scaleEffect(appeared && !selectedIds.isEmpty ? 1.0 : 0.97)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedIds.isEmpty)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(selectedIds.isEmpty && !friends.isEmpty)
        .modifier(PulseGlowModifier())
    }

    // MARK: - Friend Row

    private func friendRow(
        label: String,
        subtitle: String?,
        isSelected: Bool,
        avatarUrl: String? = nil,
        icon: String,
        iconSize: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Avatar circle — show profile photo if available
                if let urlStr = avatarUrl, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1.5)
                            )
                    } placeholder: {
                        friendAvatarPlaceholder(label: label, isSelected: isSelected, icon: icon, iconSize: iconSize)
                    }
                } else {
                    friendAvatarPlaceholder(label: label, isSelected: isSelected, icon: icon, iconSize: iconSize)
                }

                // Name + optional subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.caption, weight: .regular))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }

                Spacer()

                // Checkbox
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 26, height: 26)

                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
    
    private func friendAvatarPlaceholder(label: String, isSelected: Bool, icon: String, iconSize: CGFloat) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: isSelected ? [Color.white.opacity(0.6), Color.white.opacity(0.4)] : [Color.white.opacity(0.1), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(label.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            )
    }
}
