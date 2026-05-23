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

    private let deps = DependencyContainer.shared
    
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
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Main content — video or zoomable image
            if photo.isVideo, let videoUrlStr = photo.videoUrl, let videoUrl = URL(string: videoUrlStr) {
                VideoPlayerView(url: videoUrl, startMuted: false)
                    .offset(y: dragOffset.height)
                    .ignoresSafeArea(.keyboard)
            } else {
                ZoomableImageView(url: URL(string: photo.imageUrl))
                    .offset(y: dragOffset.height)
                    .ignoresSafeArea(.keyboard)
            }
            
            // Top bar overlay
            VStack {
                topBar
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
                        Text(String(localized: "Siliniyor..."))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white)
                    }
                }
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = .zero }
                        return
                    }
                    // Bumped from 150 → 180; an intentional dismiss is a clear
                    // swipe, not a wobble that grazed the threshold.
                    if value.translation.height > 180 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = .zero }
                    }
                }
        )
        .alert(String(localized: "Anı Sil?"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "Kalıcı Olarak Sil"), role: .destructive) {
                Task {
                    isDeleting = true
                    await onDelete?()
                    isDeleting = false
                    dismiss()
                }
            }
            Button(String(localized: "İptal"), role: .cancel) {}
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
                // Receiver auto-opens chat
                showReceiverChat = true
                // Mark strip as seen by receiver
                await deps.stripRepository.markStripAsSeen(stripId: photo.id)
            }
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
                title: String(localized: "fotoğrafı bildir"),
                subtitle: String(localized: "bu fotoğrafı neden bildiriyorsun?")
            ) { reason in
                Task {
                    try? await DependencyContainer.shared.userRepository.reportContent(
                        contentType: "photo",
                        contentId: photo.id,
                        contentOwnerId: photo.senderId,
                        reason: reason
                    )
                    showReportSheet = false
                    HapticsManager.playNotification(type: .success)
                }
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
                Task {
                    try? await DependencyContainer.shared.userRepository.blockUser(photo.senderId)
                    HapticsManager.playNotification(type: .success)
                    dismiss()
                }
            }
            Button(String(localized: "iptal"), role: .cancel) {}
        } message: {
            Text(String(localized: "bu kullanıcıyı engellemek onu arkadaş listenden kaldırır ve içerikleri gizler."))
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Close / Back button
            Button {
                if selectedReceiverId != nil && otherReceiverIds.count > 1 {
                    // Multiple receivers: go back to receiver list
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedReceiverId = nil
                    }
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: selectedReceiverId != nil && otherReceiverIds.count > 1 ? "chevron.left" : "xmark")
                    .font(.system(size: 16, weight: .bold))
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
                                .font(.system(size: 10))
                            Text(cityName)
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                } else {
                    Text(isSentByMe ? String(localized: "Senin Gönderdiğin") : String(localized: "Alınan"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }
                Text(photo.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .opacity(0.6)
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
                                .font(.system(size: 16, weight: .bold))
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
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.12), in: Circle())
                        }
                        .accessibilityLabel(String(localized: "Anı sil"))
                    }
                }
            } else {
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel(String(localized: "Daha fazla seçenek"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    // MARK: - Sender Bottom Content
    
    @ViewBuilder
    private var senderBottomContent: some View {
        VStack(spacing: 0) {
            // Seen-by indicator for sender
            if seenByCount > 0 {
                seenByIndicator
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            if seenByNames.isEmpty {
                Text(String(localized: "\(seenByCount) kişi gördü"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                let displayText = seenByNames.prefix(3).joined(separator: ", ")
                let suffix = seenByCount > 3 ? " +\(seenByCount - 3)" : ""
                Text(String(localized: "görüldü: \(displayText)\(suffix)"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .padding(.bottom, 8)
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
                .font(.system(size: 11, weight: .bold))
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
                                withAnimation(.easeOut(duration: 0.25)) {
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
                                                .fill(Color.red)
                                                .frame(width: 12, height: 12)
                                                .overlay(
                                                    Circle().stroke(Color.black, lineWidth: 2)
                                                )
                                                .offset(x: 2, y: -2)
                                        }
                                    }

                                    Text(profile.displayName ?? profile.username ?? "?")
                                        .font(.system(size: 11, weight: .medium))
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
                    .font(.system(size: 20, weight: .bold))
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
