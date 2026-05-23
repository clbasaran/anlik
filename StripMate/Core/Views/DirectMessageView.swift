import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

public struct DirectMessageView: View {
    @State private var viewModel: DirectMessageViewModel
    @AppStorage("show_dm_warm_note") private var showWarmNote = true
    @Environment(\.dismiss) private var dismiss
    @State private var showPartnerProfile = false
    @State private var showReportSheet = false
    @State private var showBlockAlert = false
    @State private var reportTargetMessageId: String?
    @State private var showStickerPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    public init(partner: UserProfile) {
        _viewModel = State(wrappedValue: DirectMessageViewModel(partner: partner))
    }
    
    /// Convert UserProfile to FriendStatus for FriendProfileView
    private var partnerAsFriendStatus: FriendStatus {
        FriendStatus(
            userId: viewModel.partner.id,
            isPending: false,
            timestamp: Date(),
            requesterId: nil,
            profile: viewModel.partner
        )
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MeshGradientBackground().ignoresSafeArea().opacity(0.3)
            
            VStack(spacing: 0) {
                // Top Header
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(String(localized: "Geri"))
                    
                    // Partner Avatar + Name — tappable to view profile
                    Button {
                        showPartnerProfile = true
                    } label: {
                        HStack(spacing: 12) {
                            if let avatarUrlStr = viewModel.partner.avatarUrl,
                               let avatarUrl = URL(string: avatarUrlStr) {
                                CachedAsyncImage(url: avatarUrl) { image in
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                } placeholder: {
                                    dmAvatarPlaceholder
                                }
                            } else {
                                dmAvatarPlaceholder
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.partner.displayName ?? viewModel.partner.username ?? String(localized: "isimsiz"))
                                    .font(Brand.headline(size: 17))
                                    .foregroundColor(Brand.textPrimary)
                                Text("@\(viewModel.partner.username ?? String(localized: "unknown"))")
                                    .font(Brand.caption(size: 12))
                                    .foregroundColor(Brand.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Profili görüntüle: \(viewModel.partner.displayName ?? viewModel.partner.username ?? "")"))
                    
                    Spacer()

                    Menu {
                        Button {
                            showReportSheet = true
                        } label: {
                            Label(String(localized: "kullanıcıyı bildir"), systemImage: "exclamationmark.triangle")
                        }
                        Button(role: .destructive) {
                            showBlockAlert = true
                        } label: {
                            Label(String(localized: "kullanıcıyı engelle"), systemImage: "hand.raised.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(String(localized: "Daha fazla seçenek"))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                
                // Messages List
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            if viewModel.isLoading {
                                VStack(spacing: 10) {
                                    ForEach(0..<6, id: \.self) { index in
                                        SkeletonMessageRow(isRight: index % 3 == 0)
                                    }
                                }
                                .padding(.top, 20)
                            } else if viewModel.messages.isEmpty {
                                VStack(spacing: 16) {
                                    if showWarmNote {
                                        WarmNoteCard(
                                            eyebrow: String(localized: "ilk mesaj"),
                                            title: String(localized: "bir merhaba yeter"),
                                            message: String(localized: "ilk cümlelerin kusursuz olması gerekmiyor. kısa bir ses bırakır gibi yazabilirsin."),
                                            dismissLabel: String(localized: "tamam"),
                                            onDismiss: {
                                                withAnimation(.easeOut(duration: 0.2)) {
                                                    showWarmNote = false
                                                }
                                            }
                                        )
                                        .padding(.horizontal, 16)
                                    }

                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text("\(String(localized: "selam ver:")) \(viewModel.partner.displayName ?? viewModel.partner.username ?? String(localized: "isimsiz"))!")
                                        .font(.system(.body, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text(String(localized: "bazen tek bir mesaj yetiyor."))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 48)
                            }
                            
                            // Load more trigger — fires when scrolled near top
                            if viewModel.canLoadMore {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        Task { await viewModel.loadMoreMessages() }
                                    }
                            }
                            
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .tint(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                                messageRow(index: index, message: message)
                            }
                            
                            // Typing indicator (P1)
                            if viewModel.isPartnerTyping {
                                HStack {
                                    TypingIndicatorView()
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    }
                    .contentMargins(.bottom, 8, for: .scrollContent)
                    .defaultScrollAnchor(.bottom)
                    .refreshable {
                        await viewModel.listenToMessages()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                    .onChange(of: viewModel.isPartnerTyping) { _, isTyping in
                        if isTyping {
                            scrollToBottom(proxy: proxy, animated: true)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // Input Area
                    VStack(spacing: 0) {
                        // Reply Preview Banner
                        if let reply = viewModel.replyingTo {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: 4, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(
                                        reply.senderId == viewModel.currentUserId
                                        ? String(localized: "kendinize yanıt")
                                        : "\(String(localized: "yanıt:")) \(viewModel.partner.displayName ?? String(localized: "karşı taraf"))"
                                    )
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
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        HStack(alignment: .bottom, spacing: 6) {
                            // Left action buttons (hidden when typing)
                            if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                HStack(spacing: 2) {
                                    Button {
                                        showStickerPicker = true
                                    } label: {
                                        Image(systemName: "face.smiling")
                                            .font(.system(size: 22))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .frame(width: 36, height: 36)
                                    }
                                    .accessibilityLabel(String(localized: "Çıkartma"))

                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white.opacity(0.7))
                                            .frame(width: 36, height: 36)
                                    }
                                    .accessibilityLabel(String(localized: "Fotoğraf gönder"))
                                }
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            }

                            // Text field
                            TextField(String(localized: "Mesaj yaz..."), text: $viewModel.inputText, axis: .vertical)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white)
                                .lineLimit(1...6)
                                .textInputAutocapitalization(.sentences)
                                .accessibilityLabel(String(localized: "Mesaj yaz"))

                            // Send button (visible when text entered)
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.inputText.isEmpty)
                    }
                    .background {
                        Color(red: 0.08, green: 0.08, blue: 0.08)
                            .ignoresSafeArea(.container, edges: .bottom)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
        .task {
            await viewModel.listenToMessages()
        }
        .onAppear {
            TabBarState.shared.isHidden = true
            ActiveChatState.shared.setActiveDMPartner(viewModel.partner.id)
            // Mark messages as read when chat opens
            Task { await viewModel.markAsRead() }
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            // Mark new incoming messages as read
            Task { await viewModel.markAsRead() }
        }
        .onChange(of: viewModel.inputText) { _, _ in
            viewModel.handleTypingChange()
        }
        .onDisappear {
            viewModel.stopListening()
            ActiveChatState.shared.setActiveDMPartner(nil)
            TabBarState.shared.isHidden = false
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
                // Re-attempt any queued messages and re-fetch listener
                Task {
                    await viewModel.flushPendingMessages()
                    await viewModel.listenToMessages()
                }
            }
        )
        .sheet(isPresented: $showPartnerProfile) {
            NavigationStack {
                FriendProfileView(friend: partnerAsFriendStatus, visitSource: .list)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentSheet(
                title: reportTargetMessageId != nil ? String(localized: "mesajı bildir") : String(localized: "kullanıcıyı bildir"),
                subtitle: reportTargetMessageId != nil ? String(localized: "bu mesajı neden bildiriyorsun?") : String(localized: "bu kullanıcıyı neden bildiriyorsun?")
            ) { reason in
                Task {
                    if let messageId = reportTargetMessageId {
                        try? await DependencyContainer.shared.userRepository.reportContent(
                            contentType: "message",
                            contentId: messageId,
                            contentOwnerId: viewModel.partner.id,
                            reason: reason
                        )
                    } else {
                        try? await DependencyContainer.shared.userRepository.reportUser(
                            viewModel.partner.id,
                            reason: reason
                        )
                    }
                    reportTargetMessageId = nil
                    showReportSheet = false
                    HapticsManager.playNotification(type: .success)
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
        .alert(String(localized: "kullanıcıyı engelle"), isPresented: $showBlockAlert) {
            Button(String(localized: "engelle"), role: .destructive) {
                Task {
                    try? await DependencyContainer.shared.userRepository.blockUser(viewModel.partner.id)
                    HapticsManager.playNotification(type: .success)
                    dismiss()
                }
            }
            Button(String(localized: "iptal"), role: .cancel) {}
        } message: {
            Text(String(localized: "bu kullanıcıyı engellemek onu arkadaş listenden kaldırır ve gelecekteki etkileşimleri engeller."))
        }
        .sheet(isPresented: $showStickerPicker) {
            GiphyStickerPicker { stickerUrl, _ in
                showStickerPicker = false
                Task { await viewModel.sendMessage(text: stickerUrl) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePhotoSelection(newItem) }
        }
    }
    
    @ViewBuilder
    private func messageRow(index: Int, message: DirectMessage) -> some View {
        let isMe = message.senderId == viewModel.currentUserId
        HStack {
            if isMe { Spacer() }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
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

                messageBody(for: message, isMe: isMe)

                if message.isDeleted != true
                    && message.text.contains("http")
                    && Self.dmMediaKind(message.text) == nil {
                    LinkPreviewBubble(urlString: message.text)
                }

                if dmShouldShowTimestamp(at: index) {
                    HStack(spacing: 4) {
                        Text(ChatView.turkishRelativeTime(from: message.timestamp))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                        if isMe {
                            ReadReceiptView(isRead: message.readAt != nil)
                        }
                    }
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

    @ViewBuilder
    private func messageBody(for message: DirectMessage, isMe: Bool) -> some View {
        if message.isDeleted == true {
            Text(String(localized: "mesaj kaldırıldı"))
                .font(.system(.body, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .italic()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(white: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if Self.dmMediaKind(message.text) != nil {
            DMMediaBubble(
                message: message,
                isMe: isMe,
                onDelete: { deleteMessage(message) },
                onReport: { reportMessage(message) },
                onDoubleTap: { viewModel.toggleHeart(on: message) }
            )
            MessageHeartBadge(
                reactions: message.reactions,
                currentUserId: viewModel.currentUserId ?? "",
                isMyMessage: isMe
            )
        } else {
            DMTextBubble(
                message: message,
                isMe: isMe,
                onDelete: { deleteMessage(message) },
                onReport: { reportMessage(message) },
                onDoubleTap: { viewModel.toggleHeart(on: message) }
            )
            MessageHeartBadge(
                reactions: message.reactions,
                currentUserId: viewModel.currentUserId ?? "",
                isMyMessage: isMe
            )
        }
    }

    private func deleteMessage(_ message: DirectMessage) {
        Task {
            try? await ChatService.shared.deleteMessage(
                messageId: message.id,
                partnerId: viewModel.partner.id
            )
        }
    }

    private func reportMessage(_ message: DirectMessage) {
        reportTargetMessageId = message.id
        showReportSheet = true
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        // Storage rule caps DM photos at 3 MB. Resize to 1440 max-dimension and
        // compress at 0.6 — keeps modern phone shots well under the limit while
        // still looking sharp on retina displays.
        let resized = Self.resized(uiImage, maxDimension: 1440)
        guard let compressed = resized.jpegData(compressionQuality: 0.6) else {
            viewModel.errorMessage = String(localized: "fotoğraf hazırlanamadı.")
            return
        }
        let uid = Auth.auth().currentUser?.uid ?? "unknown"
        let fileName = "\(uid)_\(UUID().uuidString).jpg"
        let ref = Storage.storage().reference().child("dm_photos/\(fileName)")
        // Storage rule requires `contentType.matches('image/.*')` — without
        // explicit metadata Firebase defaults to application/octet-stream and
        // the upload silently fails. This was the root cause of "fotoğraf
        // gönderilemiyor".
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        do {
            _ = try await ref.putDataAsync(compressed, metadata: metadata)
            let url = try await ref.downloadURL()
            await viewModel.sendMessage(text: url.absoluteString)
        } catch {
            viewModel.errorMessage = String(localized: "fotoğraf şu an gitmedi. tekrar deneyelim.")
        }
    }

    /// Returns a UIImage scaled so its longer edge is `maxDimension` points (in pixels,
    /// since UIImage uses points×scale). Keeps aspect ratio. No-op when already small.
    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width
        let h = image.size.height
        let longest = max(w, h)
        guard longest > maxDimension else { return image }
        let ratio = maxDimension / longest
        let newSize = CGSize(width: w * ratio, height: h * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    /// Detects whether a DM message body is a single media URL — used to decide
    /// whether to render an inline GIF/photo vs a plain text bubble.
    enum DMMediaKind { case gif, image }
    static func dmMediaKind(_ text: String) -> DMMediaKind? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http"), !trimmed.contains(" "), !trimmed.contains("\n") else {
            return nil
        }
        let lower = trimmed.lowercased()
        // GIF — GIPHY/Tenor or any .gif URL
        if lower.contains("giphy.com")
            || lower.contains("tenor.com")
            || lower.hasSuffix(".gif")
            || lower.range(of: #"\.gif(\?|$)"#, options: .regularExpression) != nil {
            return .gif
        }
        // Photo uploaded via PhotosPicker → Firebase Storage URL containing "dm_photos"
        if lower.contains("firebasestorage.googleapis.com") && lower.contains("dm_photos") {
            return .image
        }
        return nil
    }

    /// Returns true if the timestamp should be shown (>5 min gap from previous message).
    private func dmShouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let prev = viewModel.messages[index - 1].timestamp
        let curr = viewModel.messages[index].timestamp
        return curr.timeIntervalSince(prev) > 300
    }

    private var dmAvatarPlaceholder: some View {
        Circle()
            .fill(Brand.darkGray)
            .frame(width: 44, height: 44)
            .overlay(
                Text(String((viewModel.partner.displayName ?? viewModel.partner.username ?? "U").prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.white)
            )
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard let lastId = viewModel.messages.last?.id else { return }
        Task {
            try? await Task.sleep(for: .seconds(0.05))
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}
