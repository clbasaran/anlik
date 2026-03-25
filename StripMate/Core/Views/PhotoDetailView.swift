import SwiftUI
import FirebaseAuth
import Photos

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
    @State private var isSavingPhoto = false
    @State private var showSaveSuccess = false

    // Sender flow: which receiver's chat is open
    @State private var selectedReceiverId: String?
    // Receiver flow: auto-open chat
    @State private var showReceiverChat = false
    
    // Receiver profiles cache (for sender's horizontal list)
    @State private var receiverProfiles: [UserProfile] = []
    @State private var isLoadingProfiles = false

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
    
    init(photo: PhotoMetadata, isSentByMe: Bool, onDelete: (() async -> Void)? = nil, preSelectedReceiverId: String? = nil) {
        self.photo = photo
        self.isSentByMe = isSentByMe
        self.onDelete = onDelete
        self.preSelectedReceiverId = preSelectedReceiverId
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Zoomable Image — fixed size, unaffected by keyboard
            ZoomableImageView(url: URL(string: photo.imageUrl))
                .offset(y: dragOffset.height)
                .ignoresSafeArea(.keyboard)
            
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

            // Save success toast
            if showSaveSuccess {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(String(localized: "galeriye kaydedildi"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 120)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .opacity(1.0 - min(abs(dragOffset.height) / CGFloat(400), 0.5))
        // Drag-to-dismiss on ZStack level so it works both on photo AND chat overlay.
        // Using .simultaneousGesture so the chat ScrollView can still scroll independently.
        // Only downward vertical drags move the photo; upward scrolling (translation.height < 0)
        // is ignored so the photo doesn't jump when the user scrolls chat up.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if isDragVertical == nil {
                        let h = abs(value.translation.width)
                        let v = abs(value.translation.height)
                        guard h + v > 10 else { return }
                        isDragVertical = v > h
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
                    if value.translation.height > 150 {
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
                    if otherReceiverIds.count > 1 {
                        await loadReceiverProfiles()
                    }
                } else if otherReceiverIds.count == 1 {
                    // Single receiver → auto-open chat directly
                    selectedReceiverId = otherReceiverIds.first
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
            .accessibilityLabel(selectedReceiverId != nil ? "Geri" : "Kapat")
            
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

            // Save to gallery button
            Button {
                Task { await savePhotoToGallery() }
            } label: {
                Image(systemName: isSavingPhoto ? "arrow.down.circle" : "square.and.arrow.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .disabled(isSavingPhoto)
            .accessibilityLabel(String(localized: "Galeriye kaydet"))

            if isSentByMe && onDelete != nil {
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
                .accessibilityLabel("Daha fazla seçenek")
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
                // Sender selected a receiver (or single receiver auto-selected) → show their 1-on-1 chat overlay
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
                Text("\(seenByCount) kişi gördü")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                let displayText = seenByNames.prefix(3).joined(separator: ", ")
                let suffix = seenByCount > 3 ? " +\(seenByCount - 3)" : ""
                Text("görüldü: \(displayText)\(suffix)")
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
            // Receiver's own chat with the sender
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
                        ForEach(receiverProfiles, id: \.id) { profile in
                            Button {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    selectedReceiverId = profile.id
                                }
                                HapticsManager.playImpact(style: .light)
                            } label: {
                                VStack(spacing: 6) {
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
        
        var profiles: [UserProfile] = []
        for receiverId in otherReceiverIds {
            if let profile = try? await deps.userRepository.fetchProfile(for: receiverId) {
                profiles.append(profile)
            }
        }
        receiverProfiles = profiles
        isLoadingProfiles = false
    }

    // MARK: - Save Photo to Gallery

    private func savePhotoToGallery() async {
        guard !isSavingPhoto else { return }
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        // Request photo library permission
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            HapticsManager.playNotification(type: .error)
            return
        }

        // Download the image
        guard let url = URL(string: photo.imageUrl) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }

            // Save to photo library
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }

            HapticsManager.playNotification(type: .success)
            withAnimation(.easeInOut(duration: 0.3)) {
                showSaveSuccess = true
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                showSaveSuccess = false
            }
        } catch {
            HapticsManager.playNotification(type: .error)
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
