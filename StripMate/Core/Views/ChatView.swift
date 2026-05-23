import SwiftUI
import FirebaseFirestore
import AVFoundation
import Combine

/// 1-on-1 strip chat overlay — shows messages between sender and a specific receiver
public struct ChatView: View {
    @State private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showReportSheet = false
    @State private var showPhotoReply = false
    @State private var reportTargetMessageId: String?
    @State private var playingVoiceId: String?
    @State private var voicePlayer: AVPlayer?
    @State private var voicePlaybackProgress: Double = 0
    @State private var voiceDuration: Double = 0
    @State private var voiceCurrentTime: Double = 0
    @State private var voiceTimeObserver: Any?
    @State private var voiceEndObserver: NSObjectProtocol?
    @State private var reportTargetSenderId: String?
    @State private var stickerTargetMessage: Comment?  // GIPHY picker target
    @State private var showScrollToBottom = false
    @State private var heartAnimationMessageId: String?
    
    /// Initialize with stripId and the chat partner's userId.
    public init(stripId: String, chatPartnerId: String) {
        _viewModel = State(wrappedValue: ChatViewModel(stripId: stripId, chatPartnerId: chatPartnerId))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Messages List — pinned to bottom, grows upward
            ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 6) {
                                Text(String(localized: "henüz mesaj yok"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text(String(localized: "ilk mesajı yazmanın tam sırası."))
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.25))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }

                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let isMe = message.senderId == viewModel.currentUserId
                            HStack {
                                if isMe { Spacer() }

                                VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                                    // Reply reference
                                    if let replyText = message.replyToText {
                                        HStack(spacing: 6) {
                                            RoundedRectangle(cornerRadius: 1.5)
                                                .fill(Color.white.opacity(0.8))
                                                .frame(width: 3, height: 20)

                                            Text(replyText)
                                                .font(.system(.caption, weight: .medium))
                                                .foregroundColor(.white.opacity(0.6))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                    }

                                    messageBubbleContent(message: message, isMe: isMe)
                                        .overlay(alignment: isMe ? .topLeading : .topTrailing) {
                                            stickerOverlay(for: message)
                                        }
                                        .contextMenu {
                                            Button {
                                                stickerTargetMessage = message
                                            } label: {
                                                Label(String(localized: "çıkartma ekle"), systemImage: "face.smiling")
                                            }

                                            // Remove sticker (if current user has one)
                                            if let uid = viewModel.currentUserId,
                                               message.stickers?[uid] != nil {
                                                Button(role: .destructive) {
                                                    viewModel.removeSticker(from: message)
                                                } label: {
                                                    Label(String(localized: "çıkartmayı kaldır"), systemImage: "xmark.circle")
                                                }
                                            }

                                            Divider()

                                            Button {
                                                UIPasteboard.general.string = message.text
                                                HapticsManager.playNotification(type: .success)
                                            } label: {
                                                Label(String(localized: "kopyala"), systemImage: "doc.on.doc")
                                            }

                                            if !isMe {
                                                Divider()
                                                Button(role: .destructive) {
                                                    reportTargetMessageId = message.id
                                                    reportTargetSenderId = message.senderId
                                                    showReportSheet = true
                                                } label: {
                                                    Label(String(localized: "mesajı bildir"), systemImage: "exclamationmark.bubble")
                                                }
                                            }
                                        }

                                    MessageHeartBadge(
                                        reactions: message.reactions,
                                        currentUserId: viewModel.currentUserId ?? "",
                                        isMyMessage: isMe
                                    )

                                    // Relative timestamp (only if >5 min gap)
                                    if shouldShowTimestamp(at: index) {
                                        Text(ChatView.turkishRelativeTime(from: message.timestamp))
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                                }

                                if !isMe { Spacer() }
                            }
                            .padding(.horizontal, 16)
                            .id(message.id)
                            .swipeToReply {
                                viewModel.replyingTo = message
                                HapticsManager.playImpact(style: .light)
                            }
                        }

                        Color.clear.frame(height: 1).id("chat_bottom")
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }
                .defaultScrollAnchor(.bottom)
                .refreshable {
                    await viewModel.listenToMessages()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    if oldCount == 0 && newCount > 0 {
                        proxy.scrollTo("chat_bottom", anchor: .bottom)
                    } else if newCount > oldCount {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("chat_bottom", anchor: .bottom)
                        }
                    }
                }

                // Scroll-to-bottom FAB
                if showScrollToBottom {
                    Button {
                        HapticsManager.playImpact(style: .light)
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("chat_bottom", anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(String(localized: "En alta git"))
                }
            } // end ZStack
            .frame(maxHeight: 420)
            .mask(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.08),
                        .init(color: .black, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            } // end ScrollViewReader

            // Reply Preview Banner
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                // Reply preview (if any)
                if let reply = viewModel.replyingTo {
                    replyBanner(reply)
                }

                // Input bar — Instagram-style
                HStack(alignment: .bottom, spacing: 10) {
                    // Camera button (gradient, left of input)
                    Button {
                        HapticsManager.playImpact(style: .light)
                        showPhotoReply = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.22))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(String(localized: "Kamera"))

                    // Input field in capsule
                    HStack(alignment: .bottom, spacing: 6) {
                        TextField(String(localized: "mesaj yaz..."), text: $viewModel.inputText, axis: .vertical)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                            .lineLimit(1...4)
                            .submitLabel(.send)
                            .onSubmit {
                                guard !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                Task { await viewModel.sendMessage() }
                            }
                            .accessibilityLabel(String(localized: "Mesaj yaz"))

                        if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                HapticsManager.playImpact(style: .light)
                                Task { await viewModel.sendMessage() }
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.black, .white)
                                    .opacity(viewModel.isSending ? 0.4 : 1.0)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .transition(.scale.combined(with: .opacity))
                            .disabled(viewModel.isSending)
                            .accessibilityLabel(String(localized: "Mesaj gönder"))
                        }
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 8)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.22))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .animation(.easeInOut(duration: 0.15), value: viewModel.inputText.isEmpty)
            }
        }
        .task {
            await viewModel.listenToMessages()
        }
        .onAppear {
            ActiveChatState.shared.setActiveStripChat(stripId: viewModel.stripId, receiverId: viewModel.chatPartnerId)
        }
        .onDisappear {
            ActiveChatState.shared.setActiveStripChat(stripId: nil, receiverId: nil)
            viewModel.stopListening()
            stopVoicePlayback()
            if let obs = voiceEndObserver {
                NotificationCenter.default.removeObserver(obs)
                voiceEndObserver = nil
            }
        }
        .onChange(of: NetworkMonitor.shared.isConnected) { _, isConnected in
            if isConnected && !viewModel.pendingMessages.isEmpty {
                Task { await viewModel.flushPendingMessages() }
            }
        }
        .errorToast(
            Binding(
                get: { viewModel.errorMessage },
                set: { viewModel.errorMessage = $0 }
            ),
            retry: {
                Task {
                    await viewModel.flushPendingMessages()
                    await viewModel.listenToMessages()
                }
            }
        )
        .sheet(isPresented: $showReportSheet) {
            ReportContentSheet(
                title: String(localized: "mesajı bildir"),
                subtitle: String(localized: "bu mesajı neden bildiriyorsun?")
            ) { reason in
                Task {
                    if let messageId = reportTargetMessageId, let senderId = reportTargetSenderId {
                        try? await DependencyContainer.shared.userRepository.reportContent(
                            contentType: "strip_message",
                            contentId: messageId,
                            contentOwnerId: senderId,
                            reason: reason
                        )
                    }
                    reportTargetMessageId = nil
                    reportTargetSenderId = nil
                    showReportSheet = false
                    HapticsManager.playNotification(type: .success)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
        .sheet(item: $stickerTargetMessage) { targetMessage in
            GiphyStickerPicker { url, mediaId in
                viewModel.addSticker(to: targetMessage, url: url, mediaId: mediaId)
            }
        }
        .sheet(isPresented: $showPhotoReply) {
            PhotoReplyCapture { image in
                Task { await viewModel.sendPhotoReply(image: image) }
            }
        }
    }

    // MARK: - Sticker Overlay

    @ViewBuilder
    private func stickerOverlay(for message: Comment) -> some View {
        if let stickers = message.stickers, !stickers.isEmpty {
            HStack(spacing: -2) {
                ForEach(Array(stickers.values.prefix(3)), id: \.mediaId) { sticker in
                    AnimatedGIFView(url: sticker.url)
                        .frame(width: 36, height: 36)
                }
            }
            .offset(x: 4, y: -10)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Message Bubble Content

    @ViewBuilder
    private func messageBubbleContent(message: Comment, isMe: Bool) -> some View {
        if let photoReplyUrl = message.photoReplyUrl, let url = URL(string: photoReplyUrl) {
            // Photo reply — circular selfie
            CachedAsyncImage(url: url) { image in
                image.resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 120)
            }
        } else if let voiceUrlStr = message.voiceUrl, let voiceUrl = URL(string: voiceUrlStr) {
            voiceMessageBubble(message: message, voiceUrl: voiceUrl, isMe: isMe)
        } else {
            Text(message.text)
                .font(.system(.body, weight: .semibold))
                .foregroundColor(isMe ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isMe ? Color.white : Color(white: 0.25))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    // Double-tap heart burst animation (Instagram-style)
                    if heartAnimationMessageId == message.id {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.red)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
                .onTapGesture(count: 2) {
                    viewModel.toggleHeart(on: message)
                    // Show heart burst
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        heartAnimationMessageId = message.id
                    }
                    Task { try? await Task.sleep(for: .seconds(0.6)); withAnimation(.easeOut(duration: 0.25)) { heartAnimationMessageId = nil } }
                }
        }
    }

    // MARK: - Voice Message Bubble

    @ViewBuilder
    private func voiceMessageBubble(message: Comment, voiceUrl: URL, isMe: Bool) -> some View {
        let isPlaying = playingVoiceId == message.id

        Button {
            if isPlaying {
                stopVoicePlayback()
            } else {
                playVoice(message: message, url: voiceUrl)
            }
        } label: {
            HStack(spacing: 10) {
                // Play / Pause button
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 28, height: 28)

                // Waveform progress
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        let barCount = 24
                        let progress = isPlaying ? voicePlaybackProgress : 0
                        HStack(spacing: 2) {
                            ForEach(0..<barCount, id: \.self) { i in
                                let seed = sin(Double(i) * 1.2 + 0.5) * 0.5 + 0.5
                                let barHeight = max(4, seed * 16)
                                let filled = Double(i) / Double(barCount) <= progress
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(filled ? (isMe ? Color.black.opacity(0.8) : Color.white.opacity(0.9)) : (isMe ? Color.black.opacity(0.25) : Color.white.opacity(0.25)))
                                    .frame(width: max((geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount), 2), height: barHeight)
                            }
                        }
                        .frame(height: 16, alignment: .center)
                    }
                    .frame(height: 16)

                    // Duration / current time
                    HStack {
                        Text(isPlaying ? formatTime(voiceCurrentTime) : String(localized: "sesli mesaj"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isMe ? .black.opacity(0.75) : .white.opacity(0.75))
                        Spacer()
                        if voiceDuration > 0 && isPlaying {
                            Text(formatTime(voiceDuration))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isMe ? .black.opacity(0.75) : .white.opacity(0.75))
                        }
                    }
                }
                .frame(width: 130)
            }
            .foregroundColor(isMe ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isMe ? Color.white : (isPlaying ? Color.white.opacity(0.2) : Color(white: 0.25)))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Voice Playback Helpers

    private func playVoice(message: Comment, url: URL) {
        // Stop any existing playback
        stopVoicePlayback()

        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        voicePlayer = player
        playingVoiceId = message.id
        voicePlaybackProgress = 0
        voiceCurrentTime = 0
        voiceDuration = 0

        // Observe duration once asset is ready
        Task { @MainActor in
            if let duration = try? await playerItem.asset.load(.duration) {
                let secs = CMTimeGetSeconds(duration)
                if secs.isFinite && secs > 0 {
                    voiceDuration = secs
                }
            }
        }

        // Periodic time observer for progress
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        let observer = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let current = CMTimeGetSeconds(time)
            voiceCurrentTime = current
            if voiceDuration > 0 {
                voicePlaybackProgress = min(current / voiceDuration, 1.0)
            }
        }
        voiceTimeObserver = observer

        // End-of-track notification — remove previous observer to prevent leak
        if let obs = voiceEndObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        voiceEndObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
            stopVoicePlayback()
        }

        player.play()
    }

    private func stopVoicePlayback() {
        voicePlayer?.pause()
        if let observer = voiceTimeObserver {
            voicePlayer?.removeTimeObserver(observer)
            voiceTimeObserver = nil
        }
        voicePlayer = nil
        playingVoiceId = nil
        voicePlaybackProgress = 0
        voiceCurrentTime = 0
        voiceDuration = 0
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }

    // MARK: - Timestamps

    /// Returns true if the timestamp should be shown (>5 min gap from previous message).
    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let prev = viewModel.messages[index - 1].timestamp
        let curr = viewModel.messages[index].timestamp
        return curr.timeIntervalSince(prev) > 300
    }

    /// Formats a Date as a Turkish relative time string.
    /// Deprecated: Use TurkishDateFormatter.shortRelative(from:) directly.
    static func turkishRelativeTime(from date: Date) -> String {
        TurkishDateFormatter.shortRelative(from: date)
    }

    // MARK: - Reply Banner

    @ViewBuilder
    func replyBanner(_ reply: Comment) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(reply.senderId == viewModel.currentUserId ? String(localized: "kendinize yanıt") : String(localized: "mesaja yanıt"))
                    .font(.system(.caption2, weight: .bold))
                    .foregroundColor(Color.white)
                Text(reply.text)
                    .font(.system(.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    viewModel.replyingTo = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
    }
}
