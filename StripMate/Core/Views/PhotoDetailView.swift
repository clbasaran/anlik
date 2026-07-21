import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Full-screen photo detail view with 1-on-1 chat overlay.
/// - Receiver: Chat opens directly (chatPartnerId = current user's UID).
/// - Sender: Shows a horizontal receiver list at the bottom; tapping a receiver opens their isolated chat.
struct PhotoDetailView: View {
    let photo: PhotoMetadata
    let isSentByMe: Bool
    let onDelete: (() async -> Void)?
    var preSelectedReceiverId: String? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var dragOffset: CGSize = .zero
    @State private var currentUserId: String?
    @State private var showLocationMap = false
    @State private var showReportSheet = false
    @State private var showBlockAlert = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isPreparingShare = false
    /// One-shot per open: a screenshot of someone else's moment quietly
    /// notifies the sender — the strongest trust signal this app class has.
    @State private var screenshotNotified = false

    // Sender flow: which receiver's chat is open
    @State private var selectedReceiverId: String?
    // Receiver flow: auto-open chat
    @State private var showReceiverChat = false

    // Receiver profiles cache (for sender's horizontal list)
    @State private var receiverProfiles: [UserProfile] = []
    @State private var isLoadingProfiles = false

    // Per-chat last-message metadata, used to sort the receiver bar by activity
    // and badge receivers who replied since the sender last opened that chat.
    @State private var chatLatestAt: [String: Date] = [:]
    @State private var chatLatestSenderId: [String: String] = [:]
    @State private var lastOpenedAt: [String: Date] = [:]

    // Seen-by tracking
    @State private var seenByNames: [String] = []
    @State private var seenByCount: Int = 0

    // Photo reactions — hearts on the photo itself. Stored in Firestore as
    // reactions[<heart value>] = [userId], using the same escaped-unicode value
    // the chat heart uses. Rendered exclusively as SF Symbols (heart / heart.fill).
    private static let heartValue = "\u{2764}\u{FE0F}" // stored in Firestore, never rendered
    @State private var heartUserIds: [String] = []
    @State private var showHeartBurst = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // duygusal-4: first-open reveal for a received moment — the photo starts
    // covered (blur + slight scale) with the sender's name, then dissolves in.
    @State private var isRevealing: Bool
    @State private var revealSenderName: String?

    // duygusal-11: strip carries a `resharedFrom` marker → memory ribbon.
    @State private var isResharedMemory = false

    // guven-3: sender-chosen retention read from the strip document.
    // -1 sentinel = "kalıcı"; positive = days; missing = default 30 (no tag).
    @State private var retentionDays: Int?

    // guven-6: verified safety actions — failure states + in-flight guard.
    @State private var showReportError = false
    @State private var showBlockError = false
    @State private var isBlocking = false

    private let deps = DependencyContainer.shared

    private var heartCount: Int { heartUserIds.count }

    private var hasMyHeart: Bool {
        guard let uid = currentUserId else { return false }
        return heartUserIds.contains(uid)
    }

    /// Whether the chat overlay is currently visible
    private var isChatVisible: Bool {
        if isSentByMe {
            return selectedReceiverId != nil
        } else {
            return showReceiverChat
        }
    }

    /// Tracks whether current drag is confirmed as vertical (for drag-to-dismiss)
    @State private var isDragVertical: Bool? = nil

    /// Receiver IDs excluding the sender
    private var otherReceiverIds: [String] {
        photo.receiverIds.filter { $0 != photo.senderId }
    }

    /// UserDefaults key namespace for "sender opened this chat at <Date>".
    /// Scoped per stripId so the badge clears only for the chats actually viewed.
    private func lastOpenedKey(receiverId: String) -> String {
        "stripChatOpenedAt.\(photo.id).\(receiverId)"
    }

    /// True when the receiver replied after the sender last opened that chat.
    private func hasUnread(receiverId: String) -> Bool {
        guard let latestAt = chatLatestAt[receiverId],
              let latestSender = chatLatestSenderId[receiverId],
              latestSender == receiverId else { return false }
        let opened = lastOpenedAt[receiverId] ?? .distantPast
        return latestAt > opened
    }

    /// Profiles ordered: most recent chat activity first; receivers without any
    /// messages keep their original receiverIds order at the end.
    private var sortedReceiverProfiles: [UserProfile] {
        let withActivity = receiverProfiles.filter { chatLatestAt[$0.id] != nil }
            .sorted { (a, b) in
                (chatLatestAt[a.id] ?? .distantPast) > (chatLatestAt[b.id] ?? .distantPast)
            }
        let withoutActivity = receiverProfiles.filter { chatLatestAt[$0.id] == nil }
        return withActivity + withoutActivity
    }

    init(photo: PhotoMetadata, isSentByMe: Bool, onDelete: (() async -> Void)? = nil, preSelectedReceiverId: String? = nil) {
        self.photo = photo
        self.isSentByMe = isSentByMe
        self.onDelete = onDelete
        self.preSelectedReceiverId = preSelectedReceiverId

        // duygusal-4: reveal only for a receiver opening a moment that has no
        // seen-mark from them yet. Never for own strips, secret strips (they
        // have their own unlock ritual) or the system welcome strip. Decided
        // in init so the first rendered frame is already covered.
        let uid = Auth.auth().currentUser?.uid
        let shouldReveal: Bool = {
            guard !isSentByMe, !photo.isSecret, !photo.isSystemWelcomeStrip,
                  let uid, uid != photo.senderId else { return false }
            return !(photo.seenBy ?? []).contains(uid)
        }()
        self._isRevealing = State(initialValue: shouldReveal)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Main content — video or zoomable image
            Group {
                if photo.isVideo, let videoUrlStr = photo.videoUrl, let videoUrl = URL(string: videoUrlStr) {
                    VideoPlayerView(url: videoUrl, startMuted: false)
                } else {
                    ZoomableImageView(url: URL(string: photo.imageUrl))
                }
            }
            // duygusal-4: covered → dissolve-in. Reduce Motion skips the
            // blur/scale and does a simple opacity fade instead.
            .blur(radius: (isRevealing && !reduceMotion) ? 14 : 0)
            .scaleEffect((isRevealing && !reduceMotion) ? 1.05 : 1)
            .opacity((isRevealing && reduceMotion) ? 0 : 1)
            .offset(y: dragOffset.height)
            .ignoresSafeArea(.keyboard)
            // Double-tap to heart (receiver only). `.subviews` hands the gesture
            // back to ZoomableImageView's double-tap zoom on the sender's own
            // photo, so nothing changes for that flow; receivers zoom via pinch.
            .highPriorityGesture(
                TapGesture(count: 2).onEnded { toggleHeart() },
                including: isSentByMe ? .subviews : .all
            )

            // Top bar overlay
            VStack(spacing: 10) {
                topBar
                // duygusal-11: receivers should feel they were handed a memory,
                // not just another photo.
                if isResharedMemory {
                    memoryRibbon
                }
                Spacer()
            }

            // Bottom content — differs by role
            VStack {
                Spacer()

                // Location pill removed — konum bilgisi header'da gösteriliyor

                if isSentByMe {
                    // SENDER FLOW: show receiver list or open selected receiver's chat
                    senderBottomContent
                } else {
                    // RECEIVER FLOW: auto-open 1-on-1 chat with sender
                    receiverBottomContent
                }
            }

            // Loading overlay
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text(String(localized: "siliniyor..."))
                            .font(Brand.scaledFont(size: 15, weight: .regular, relativeTo: .body))
                            .foregroundColor(.white)
                    }
                }
            }

            // duygusal-4: sender-name overlay while the moment is covered.
            if isRevealing {
                revealOverlay
            }

            // Heart burst — brief center-stage pop when the receiver double-taps.
            if showHeartBurst {
                Image(systemName: "heart.fill")
                    .font(.system(size: 96, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 16)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

        }
        .opacity(1.0 - min(abs(dragOffset.height) / CGFloat(400), 0.5))
        // Drag-to-dismiss on ZStack level so it works both on photo AND chat overlay.
        // Using .simultaneousGesture so the chat ScrollView can still scroll independently.
        // Only downward vertical drags move the photo; upward scrolling (translation.height < 0)
        // is ignored so the photo doesn't jump when the user scrolls chat up.
        .simultaneousGesture(
            // Higher minimumDistance + a stronger vertical-vs-horizontal ratio
            // keep this drag from competing with the chat ScrollView. Otherwise
            // small downward scrolls inside chat make the whole photo wobble
            // with an opacity dip before springing back.
            DragGesture(minimumDistance: 40)
                .onChanged { value in
                    if isDragVertical == nil {
                        let h = abs(value.translation.width)
                        let v = abs(value.translation.height)
                        guard h + v > 24 else { return }
                        // Require a clearly vertical intent (>= 1.5x horizontal)
                        // before claiming the gesture for dismissal.
                        isDragVertical = v > h * 1.5
                    }
                    guard isDragVertical == true else { return }
                    // Only pull the photo downward — ignore upward scrolling in chat
                    guard value.translation.height > 0 else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    defer { isDragVertical = nil }
                    guard isDragVertical == true else {
                        withAnimation(Brand.Animations.tap) { dragOffset = .zero }
                        return
                    }
                    // Bumped from 150 → 180; an intentional dismiss is a clear
                    // swipe, not a wobble that grazed the threshold.
                    if value.translation.height > 180 {
                        dismiss()
                    } else {
                        withAnimation(Brand.Animations.tap) { dragOffset = .zero }
                    }
                }
        )
        .alert(String(localized: "anı sil?"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "kalıcı olarak sil"), role: .destructive) {
                Task {
                    isDeleting = true
                    await onDelete?()
                    isDeleting = false
                    dismiss()
                }
            }
            Button(String(localized: "iptal"), role: .cancel) {}
        } message: {
            Text(String(localized: "Bu fotoğraf herkes için kalıcı olarak silinecek. Bu işlem geri alınamaz."))
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showLocationMap) {
            if let lat = photo.latitude, let lon = photo.longitude {
                StripLocationMapView(latitude: lat, longitude: lon, cityName: photo.cityName)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
                    .presentationBackground(.black)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            // Screenshot awareness: only for photos someone else sent, and only
            // once per viewing so a burst of screenshots doesn't spam the sender.
            guard !isSentByMe, !screenshotNotified else { return }
            screenshotNotified = true
            Task {
                await AppNotificationService.shared.sendInAppNotification(
                    to: photo.senderId,
                    type: .screenshotTaken,
                    relatedId: photo.id,
                    thumbnailUrl: photo.thumbnailUrl
                )
            }
        }
        .task {
            currentUserId = Auth.auth().currentUser?.uid

            if isSentByMe {
                if let preId = preSelectedReceiverId, otherReceiverIds.contains(preId) {
                    // Deep link specified a receiver → auto-open that chat
                    selectedReceiverId = preId
                    markChatOpened(receiverId: preId)
                    if otherReceiverIds.count > 1 {
                        await loadReceiverProfiles()
                    }
                } else if otherReceiverIds.count == 1, let onlyId = otherReceiverIds.first {
                    // Single receiver → auto-open chat directly
                    selectedReceiverId = onlyId
                    markChatOpened(receiverId: onlyId)
                } else {
                    await loadReceiverProfiles()
                }
                // Load seen-by info for sender
                await loadSeenByInfo()
            } else {
                // duygusal-4: unwrap moment before the chat slides up.
                if isRevealing {
                    await runReceiveReveal()
                }
                // Receiver auto-opens chat
                showReceiverChat = true
                // Mark strip as seen by receiver
                await deps.stripRepository.markStripAsSeen(stripId: photo.id)
            }

            // Both roles: load current heart reactions on the photo
            await loadReactions()
        }
        .onChange(of: selectedReceiverId) { _, newValue in
            // Returning to the receiver bar — refresh activity so the bar
            // re-sorts and clears any badge for chats the sender just viewed.
            if newValue == nil && isSentByMe && otherReceiverIds.count > 1 {
                Task { await loadChatActivity(for: otherReceiverIds) }
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportContentSheet(
                title: "fotoğrafı bildir",
                subtitle: "bu fotoğrafı neden bildiriyorsun?"
            ) { reason in
                Task { await reportPhoto(reason: reason) }
            }
            // guven-6: failure surfaces over the sheet; it stays open for retry.
            .alert(String(localized: "bildirilemedi — tekrar dene."), isPresented: $showReportError) {
                Button(String(localized: "tamam"), role: .cancel) {}
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                PhotoShareSheet(image: image)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.black)
            }
        }
        .alert(String(localized: "göndereni engelle"), isPresented: $showBlockAlert) {
            Button(String(localized: "engelle"), role: .destructive) {
                Task { await blockSender() }
            }
            Button(String(localized: "iptal"), role: .cancel) {}
        } message: {
            Text(String(localized: "bu kullanıcıyı engellemek onu arkadaş listenden kaldırır ve içerikleri gizler."))
        }
        // guven-6: block failed — no false sense of safety; offer a retry.
        .alert(String(localized: "engellenemedi — tekrar dene."), isPresented: $showBlockError) {
            Button(String(localized: "tekrar dene")) {
                Task { await blockSender() }
            }
            Button(String(localized: "vazgeç"), role: .cancel) {}
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Close / Back button
            Button {
                if selectedReceiverId != nil && otherReceiverIds.count > 1 {
                    // Multiple receivers: go back to receiver list
                    withAnimation(Brand.Animations.fade) {
                        selectedReceiverId = nil
                    }
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: selectedReceiverId != nil && otherReceiverIds.count > 1 ? "chevron.left" : "xmark")
                    .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel(selectedReceiverId != nil ? String(localized: "Geri") : String(localized: "Kapat"))

            Spacer()

            VStack(spacing: 2) {
                if let cityName = photo.cityName, photo.latitude != nil {
                    Button {
                        HapticsManager.playImpact(style: .light)
                        showLocationMap = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(Brand.scaledFont(size: 10, relativeTo: .caption))
                            Text(cityName)
                                .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                        }
                        .foregroundColor(.white)
                    }
                } else {
                    Text(isSentByMe ? String(localized: "Senin Gönderdiğin") : String(localized: "Alınan"))
                        .font(Brand.scaledFont(size: 15, weight: .medium, relativeTo: .body))
                        .foregroundColor(.white)
                }
                Text(photo.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                    .foregroundColor(.white)
                    .opacity(0.6)

                // guven-3: retention honesty for receivers — a quiet tag when
                // the sender chose a non-default lifespan for this strip.
                if !isSentByMe, let tag = retentionTag {
                    Text(tag)
                        .font(Brand.scaledFont(size: 10, weight: .medium, relativeTo: .caption2))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            Spacer()

            if isSentByMe {
                HStack(spacing: 8) {
                    // Export / share button
                    Button {
                        HapticsManager.playImpact(style: .light)
                        prepareAndShare()
                    } label: {
                        if isPreparingShare {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.12), in: Circle())
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                    }
                    .disabled(isPreparingShare)
                    .accessibilityLabel(String(localized: "Disa aktar"))

                    if onDelete != nil {
                        Button {
                            HapticsManager.playImpact(style: .medium)
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
                                .foregroundColor(Brand.error.opacity(0.85))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .accessibilityLabel(String(localized: "Anı sil"))
                    }
                }
            } else {
                HStack(spacing: 8) {
                    // Heart reaction — tap toggles; double-tapping the photo does the same.
                    Button {
                        toggleHeart()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: hasMyHeart ? "heart.fill" : "heart")
                                .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
                                .contentTransition(.symbolEffect(.replace))
                            if heartCount > 0 {
                                Text("\(heartCount)")
                                    .font(Brand.scaledFont(size: 13, weight: .semibold, relativeTo: .footnote))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, heartCount > 0 ? 14 : 0)
                        .frame(minWidth: 44)
                        .frame(height: 44)
                        .background(Color.white.opacity(0.12), in: Capsule())
                    }
                    .animationAccessible(Brand.Animations.snap, value: hasMyHeart)
                    .accessibilityLabel(hasMyHeart ? String(localized: "kalbi geri al") : String(localized: "kalp gönder"))
                    .accessibilityHint(String(localized: "fotoğrafa çift dokunarak da kalp bırakabilirsin"))

                    Menu {
                        Button {
                            showReportSheet = true
                        } label: {
                            Label(String(localized: "fotoğrafı bildir"), systemImage: "exclamationmark.triangle")
                        }
                        Button(role: .destructive) {
                            showBlockAlert = true
                        } label: {
                            Label(String(localized: "göndereni engelle"), systemImage: "hand.raised.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(Brand.scaledFont(size: 16, weight: .bold, relativeTo: .body))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .accessibilityLabel(String(localized: "Daha fazla seçenek"))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        // Subtle scrim so the city/date metadata stays legible over bright
        // photos. Extends into the safe-area top for an edge-to-edge fade.
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color.black.opacity(0.45), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Receive Reveal (duygusal-4)

    /// Sender-name overlay shown while the received moment is still covered.
    private var revealOverlay: some View {
        VStack(spacing: 6) {
            if let name = revealSenderName {
                Text(name)
                    .font(Brand.scaledFont(size: 24, weight: .bold, relativeTo: .title2))
                    .foregroundStyle(.white)
                Text(String(localized: "bir an gönderdi."))
                    .font(Brand.scaledFont(size: 14, weight: .medium, relativeTo: .footnote))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .transition(.opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Resolves the sender's name (bounded wait), holds a short beat so the
    /// covered state registers, then dissolves the photo in with one light
    /// haptic. Reduce Motion runs the same sequence as a simple fade.
    private func runReceiveReveal() async {
        // Name lookup races a 600ms cap — the reveal never stalls on network.
        let name: String? = await withTaskGroup(of: String?.self) { group in
            group.addTask {
                let profile = try? await deps.userRepository.fetchProfile(for: photo.senderId)
                return profile?.displayName ?? profile?.username
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(600))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        revealSenderName = name

        // A brief beat with the name visible before the dissolve.
        try? await Task.sleep(for: .milliseconds(name == nil ? 100 : 300))

        HapticsManager.playImpact(style: .light)
        withAnimation(reduceMotion ? Brand.Animations.fadeLong : .easeOut(duration: 0.4)) {
            isRevealing = false
        }
        // Let the dissolve finish before the chat slides up over the photo.
        try? await Task.sleep(for: .milliseconds(400))
    }

    // MARK: - Memory Ribbon (duygusal-11)

    private var memoryRibbon: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(Brand.scaledFont(size: 11, weight: .semibold, relativeTo: .caption))
            Text(String(localized: "geçen yıldan bir anı."))
                .font(Brand.scaledFont(size: 12, weight: .semibold, relativeTo: .caption))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Retention Tag (guven-3)

    /// Honest lifespan tag: "kalıcı an." for the -1 sentinel, or the remaining
    /// days for an explicit retention. Missing field = default 30-day story
    /// told in the FAQ, so no tag is shown.
    private var retentionTag: String? {
        guard let days = retentionDays else { return nil }
        if days < 0 { return String(localized: "kalıcı an.") }
        let expiry = Calendar.current.date(byAdding: .day, value: days, to: photo.timestamp) ?? photo.timestamp
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        if remaining < 1 { return String(localized: "son gün.") }
        return String(localized: "\(remaining) gün kaldı.")
    }

    // MARK: - Sender Bottom Content

    @ViewBuilder
    private var senderBottomContent: some View {
        VStack(spacing: 0) {
            // Seen-by + received-hearts indicators for sender
            if seenByCount > 0 || heartCount > 0 {
                HStack(spacing: 8) {
                    if seenByCount > 0 {
                        seenByIndicator
                    }
                    if heartCount > 0 {
                        reactionIndicator
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }

            if let receiverId = selectedReceiverId {
                ChatView(stripId: photo.id, chatPartnerId: receiverId)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if otherReceiverIds.count > 1 {
                // Multiple receivers → show horizontal receiver list
                receiverListBar
            }
        }
    }

    // MARK: - Seen By Indicator

    private var seenByIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye.fill")
                .font(Brand.scaledFont(size: 11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.5))

            if seenByNames.isEmpty {
                Text(String(localized: "\(seenByCount) kişi gördü"))
                    .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                let displayText = seenByNames.prefix(3).joined(separator: ", ")
                let suffix = seenByCount > 3 ? " +\(seenByCount - 3)" : ""
                Text(String(localized: "görüldü: \(displayText)\(suffix)"))
                    .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Reaction Indicator (sender)

    /// Subtle capsule showing how many hearts the strip has collected.
    private var reactionIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(Brand.scaledFont(size: 11, weight: .semibold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.5))
            Text("\(heartCount)")
                .font(Brand.scaledFont(size: 12, weight: .medium, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "\(heartCount) kalp aldı"))
    }

    // MARK: - Receiver Bottom Content

    @ViewBuilder
    private var receiverBottomContent: some View {
        if showReceiverChat, let uid = currentUserId {
            ChatView(stripId: photo.id, chatPartnerId: uid)
        }
    }

    // MARK: - Receiver Horizontal List (Sender only)

    private var receiverListBar: some View {
        VStack(spacing: 8) {
            Text(String(localized: "yanıtlar"))
                .font(Brand.scaledFont(size: 11, weight: .bold, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.3))
                .textCase(.uppercase)
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    if isLoadingProfiles {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 52, height: 52)
                                .shimmer()
                        }
                    } else {
                        ForEach(sortedReceiverProfiles, id: \.id) { profile in
                            Button {
                                withAnimation(Brand.Animations.fadeOutStandard) {
                                    selectedReceiverId = profile.id
                                }
                                markChatOpened(receiverId: profile.id)
                                HapticsManager.playImpact(style: .light)
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .topTrailing) {
                                        Group {
                                            if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                                                CachedAsyncImage(url: url) { image in
                                                    image.resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 52, height: 52)
                                                        .clipShape(Circle())
                                                } placeholder: {
                                                    profilePlaceholder(for: profile)
                                                }
                                            } else {
                                                profilePlaceholder(for: profile)
                                            }
                                        }

                                        if hasUnread(receiverId: profile.id) {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 12, height: 12)
                                                .overlay(
                                                    Circle().stroke(Color.black, lineWidth: 2)
                                                )
                                                .offset(x: 2, y: -2)
                                        }
                                    }

                                    Text(profile.displayName ?? profile.username ?? "?")
                                        .font(Brand.scaledFont(size: 11, weight: .medium, relativeTo: .caption))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .lineLimit(1)
                                        .frame(maxWidth: 60)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 80)
        }
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.7), .black.opacity(0.9)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Helpers

    private func profilePlaceholder(for profile: UserProfile) -> some View {
        Circle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 52, height: 52)
            .overlay(
                Text(String((profile.displayName ?? profile.username ?? "?").prefix(1)))
                    .font(Brand.scaledFont(size: 20, weight: .bold, relativeTo: .title3))
                    .foregroundColor(.white.opacity(0.6))
            )
    }

    private func loadReceiverProfiles() async {
        isLoadingProfiles = true
        // receiverIds includes the sender themselves, so filter them out
        let otherReceiverIds = photo.receiverIds.filter { $0 != photo.senderId }

        // Parallel fetch — sequential fetch made the receiver bar feel sluggish
        // when a strip went to many people. TaskGroup runs them concurrently.
        var fetched: [(Int, UserProfile)] = []
        await withTaskGroup(of: (Int, UserProfile?).self) { group in
            for (idx, id) in otherReceiverIds.enumerated() {
                group.addTask {
                    let profile = try? await deps.userRepository.fetchProfile(for: id)
                    return (idx, profile)
                }
            }
            for await (idx, profile) in group {
                if let profile { fetched.append((idx, profile)) }
            }
        }
        // Preserve original receiverIds order (TaskGroup completion order is non-deterministic).
        receiverProfiles = fetched.sorted { $0.0 < $1.0 }.map { $0.1 }
        isLoadingProfiles = false

        // Hydrate last-opened timestamps from UserDefaults so the unread badge
        // survives across detail-view re-opens.
        var openedMap: [String: Date] = [:]
        let defaults = UserDefaults.standard
        for id in otherReceiverIds {
            if let ts = defaults.object(forKey: lastOpenedKey(receiverId: id)) as? Date {
                openedMap[id] = ts
            }
        }
        lastOpenedAt = openedMap

        // Fetch the latest message in each chat to drive sort + badge.
        await loadChatActivity(for: otherReceiverIds)
    }

    /// One-shot fetch of the most recent message in each receiver's strip-chat.
    /// Path: strips/{stripId}/chats/{chatPartnerId}/messages
    private func loadChatActivity(for receiverIds: [String]) async {
        let stripId = photo.id
        await withTaskGroup(of: (String, Date?, String?).self) { group in
            for receiverId in receiverIds {
                group.addTask {
                    do {
                        let snapshot = try await Firestore.firestore()
                            .collection("strips").document(stripId)
                            .collection("chats").document(receiverId)
                            .collection("messages")
                            .order(by: "timestamp", descending: true)
                            .limit(to: 1)
                            .getDocuments()
                        if let doc = snapshot.documents.first {
                            let ts = (doc.data()["timestamp"] as? Timestamp)?.dateValue()
                            let sid = doc.data()["senderId"] as? String
                            return (receiverId, ts, sid)
                        }
                    } catch {
                        // Silent — receiver bar still works without activity data.
                    }
                    return (receiverId, nil, nil)
                }
            }
            for await (id, ts, sid) in group {
                if let ts { chatLatestAt[id] = ts }
                if let sid { chatLatestSenderId[id] = sid }
            }
        }
    }

    /// Persist that the sender just opened this receiver's chat — clears the badge.
    private func markChatOpened(receiverId: String) {
        let now = Date()
        lastOpenedAt[receiverId] = now
        UserDefaults.standard.set(now, forKey: lastOpenedKey(receiverId: receiverId))
    }

    // MARK: - Export / Share

    private func prepareAndShare() {
        isPreparingShare = true
        Task {
            guard let url = URL(string: photo.imageUrl) else {
                isPreparingShare = false
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let original = UIImage(data: data) else {
                    isPreparingShare = false
                    return
                }
                let watermarked = addWatermark(to: original)
                shareImage = watermarked
                isPreparingShare = false
                showShareSheet = true
            } catch {
                isPreparingShare = false
                HapticsManager.playNotification(type: .error)
            }
        }
    }

    private func addWatermark(to image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            image.draw(at: .zero)

            // Semi-transparent gradient bar at bottom
            let barHeight: CGFloat = size.height * 0.06
            let barRect = CGRect(x: 0, y: size.height - barHeight, width: size.width, height: barHeight)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.5).cgColor] as CFArray,
                locations: [0, 1]
            )!
            context.cgContext.saveGState()
            context.cgContext.addRect(barRect)
            context.cgContext.clip()
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height - barHeight),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
            context.cgContext.restoreGState()

            // Brand text
            let brandText = Brand.name as NSString
            let fontSize = size.width * 0.035
            let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            let textSize = brandText.size(withAttributes: attributes)
            let textX = (size.width - textSize.width) / 2
            let textY = size.height - barHeight + (barHeight - textSize.height) / 2
            brandText.draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
        }
    }

    // MARK: - Reactions

    /// One-shot fetch of the strip's reactions map. Read directly from
    /// Firestore (like `loadChatActivity`) because `PhotoMetadata.from` does
    /// not carry the reactions field. Also hydrates the reshared-memory marker
    /// (duygusal-11) and the retention setting (guven-3) from the same read.
    private func loadReactions() async {
        guard let doc = try? await Firestore.firestore()
            .collection("strips").document(photo.id).getDocument(),
              let data = doc.data() else { return }
        let reactions = data["reactions"] as? [String: [String]] ?? [:]
        heartUserIds = reactions[Self.heartValue] ?? []
        withAnimation(Brand.Animations.fade) {
            isResharedMemory = (data["resharedFrom"] as? String) != nil
        }
        retentionDays = data["retentionDays"] as? Int
    }

    // MARK: - Safety Actions (guven-6)

    /// Verified report: success feedback only after the write lands. On
    /// failure the sheet stays open and an error alert offers a retry.
    private func reportPhoto(reason: String) async {
        do {
            try await deps.userRepository.reportContent(
                contentType: "photo",
                contentId: photo.id,
                contentOwnerId: photo.senderId,
                reason: reason
            )
            showReportSheet = false
            HapticsManager.playNotification(type: .success)
        } catch {
            HapticsManager.playNotification(type: .error)
            showReportError = true
        }
    }

    /// Verified block: the success haptic and dismiss fire only when the
    /// repository call actually succeeded — a silent failure here would leave
    /// the user believing they are protected when they are not.
    private func blockSender() async {
        guard !isBlocking else { return }
        isBlocking = true
        defer { isBlocking = false }
        do {
            try await deps.userRepository.blockUser(photo.senderId)
            HapticsManager.playNotification(type: .success)
            dismiss()
        } catch {
            HapticsManager.playNotification(type: .error)
            showBlockError = true
        }
    }

    /// Toggle the current user's heart on this photo (receiver only).
    /// Optimistic local update; reverts to server truth if the write fails.
    private func toggleHeart() {
        guard !isSentByMe, let uid = currentUserId, uid != photo.senderId else { return }
        let hadHeart = heartUserIds.contains(uid)

        if hadHeart {
            heartUserIds.removeAll { $0 == uid }
            HapticsManager.playImpact(style: .light)
        } else {
            heartUserIds.append(uid)
            HapticsManager.playImpact(style: .medium)
            withAnimation(reduceMotion ? nil : Brand.Animations.bouncy) {
                showHeartBurst = true
            }
            Task {
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(reduceMotion ? nil : Brand.Animations.fadeOutStandard) {
                    showHeartBurst = false
                }
            }
        }

        Task {
            do {
                try await deps.stripRepository.toggleReaction(on: photo.id, emoji: Self.heartValue)
            } catch {
                await loadReactions()
            }
        }
    }

    // MARK: - Seen By

    private func loadSeenByInfo() async {
        // Fetch seenBy from Firestore for this strip
        guard let metadata = try? await deps.stripRepository.fetchStrip(byId: photo.id) else { return }
        let seenIds = (metadata.seenBy ?? []).filter { $0 != photo.senderId }
        seenByCount = seenIds.count

        // Resolve names
        var names: [String] = []
        for uid in seenIds.prefix(3) {
            if let profile = try? await deps.userRepository.fetchProfile(for: uid) {
                names.append(profile.displayName ?? profile.username ?? "?")
            }
        }
        seenByNames = names
    }
}

// MARK: - Photo Share Sheet

private struct PhotoShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
