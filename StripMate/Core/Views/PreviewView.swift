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
    @Binding var sendVideoWithSound: Bool
    var onRetake: () -> Void
    var onSend: () -> Void
    var onCollage: (() -> Void)?  // Deprecated — kept for source compat; no longer wired (Faz B).
    var videoURL: URL?
    var videoDuration: Double?

    init(image: UIImage, isUploading: Bool, showSuccess: Bool, availableFriends: [FriendStatus], selectedReceiverIds: Binding<Set<String>>, initialComment: Binding<String>, voiceData: Binding<Data?>, isSecret: Binding<Bool>, sendVideoWithSound: Binding<Bool>, onRetake: @escaping () -> Void, onSend: @escaping () -> Void, onCollage: (() -> Void)? = nil, videoURL: URL? = nil, videoDuration: Double? = nil) {
        self.image = image
        self.isUploading = isUploading
        self.showSuccess = showSuccess
        self.availableFriends = availableFriends
        self._selectedReceiverIds = selectedReceiverIds
        self._initialComment = initialComment
        self._voiceData = voiceData
        self._isSecret = isSecret
        self._sendVideoWithSound = sendVideoWithSound
        self.onRetake = onRetake
        self.onSend = onSend
        self.onCollage = onCollage
        self.videoURL = videoURL
        self.videoDuration = videoDuration
    }

    @State private var showFriendSheet = false
    @State private var controlsVisible = false
    @State private var isSavingToGallery = false
    @State private var showSavedToast = false
    @State private var showAdvancedSendOptions = false
    // Voice recording state moved into PreviewVoiceRecorder.

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
                                        Text(String(localized: "gizli an"))
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

                                if videoURL != nil {
                                    HStack(spacing: 6) {
                                        Image(systemName: sendVideoWithSound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(sendVideoWithSound ? String(localized: "sesli gönderilecek") : String(localized: "sessiz gönderilecek"))
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                    .transition(.scale.combined(with: .opacity))
                                }

                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                        showAdvancedSendOptions.toggle()
                                    }
                                    HapticsManager.playSelection()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: showAdvancedSendOptions ? "chevron.down" : "ellipsis")
                                            .font(.system(size: 12, weight: .bold))
                                        Text(showAdvancedSendOptions ? String(localized: "daha az") : String(localized: "daha fazla"))
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white.opacity(0.75))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .disabled(isUploading || showSuccess)

                                if showAdvancedSendOptions {
                                    HStack(spacing: btnSpacing) {
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

                                        if videoURL != nil {
                                            Button {
                                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                                    sendVideoWithSound.toggle()
                                                }
                                                HapticsManager.playImpact(style: .light)
                                            } label: {
                                                Image(systemName: sendVideoWithSound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                                                    .foregroundColor(sendVideoWithSound ? .black : .white.opacity(0.8))
                                                    .frame(width: btnSize, height: btnSize)
                                                    .background(sendVideoWithSound ? Color.white : Color.white.opacity(0.12))
                                                    .clipShape(Circle())
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                            .disabled(isUploading || showSuccess)
                                            .accessibilityLabel(sendVideoWithSound ? String(localized: "Sesli gönder") : String(localized: "Sessiz gönder"))
                                        }

                                        if videoURL == nil {
                                            voiceRecordButton
                                        }

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
                                        .accessibilityLabel(isSecret ? String(localized: "Gizli an açık") : String(localized: "Gizli an kapalı"))
                                    }
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .task {
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation { controlsVisible = true }
        }
        // Mic permission alert moved into PreviewVoiceRecorder along with the
        // rest of the recording flow.
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

    // Voice recording UI + machinery extracted to PreviewVoiceRecorder.swift.
    private var voiceRecordButton: some View {
        PreviewVoiceRecorder(
            voiceData: $voiceData,
            isUploading: isUploading,
            showSuccess: showSuccess
        )
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
                if let videoURL = self.videoURL {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                } else {
                    PHAssetChangeRequest.creationRequestForAsset(from: self.image)
                }
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

    private var sendButton: some View {
        PreviewSendButton(
            availableFriends: availableFriends,
            isUploading: isUploading,
            showSuccess: showSuccess,
            onSendTap: {
                // Always open the recipient picker. The previous fast-path
                // (auto-send to last-used friends when pre-selected) was
                // silently shipping to potentially stale recipients with no
                // confirmation. Last-used IDs still pre-populate the
                // picker selection so a single confirm tap finishes the send.
                showFriendSheet = true
            },
            onSendLongPress: { showFriendSheet = true },
            onAddFriend: { TabBarState.shared.selectedTab = .friends },
            onRetake: onRetake
        )
    }

    // Success overlay extracted to PreviewSuccessOverlay.swift.
    private var successOverlay: some View {
        PreviewSuccessOverlay(isVisible: showSuccess)
    }
}

// MARK: - Friend Selection Sheet

struct FriendSelectionSheet: View {
    let friends: [FriendStatus]
    @Binding var selectedIds: Set<String>
    @Binding var commentText: String
    let onSend: () -> Void

    @State private var appeared = false
    @State private var searchText: String = ""
    @State private var sendGroups: [SendGroup] = []
    @State private var showCreateGroupAlert = false
    @State private var newGroupName: String = ""
    @State private var groupCreationError: String?
    @FocusState private var isSearchFocused: Bool

    /// Friends matching the current search query. Empty query → all friends.
    private var filteredFriends: [FriendStatus] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return friends }
        let q = searchText.lowercased()
        return friends.filter { friend in
            let name = (friend.profile?.displayName ?? "").lowercased()
            let username = (friend.profile?.username ?? "").lowercased()
            return name.contains(q) || username.contains(q)
        }
    }

    private var favoriteFriends: [FriendStatus] {
        filteredFriends.filter { $0.isFavorite }
    }
    private var nonFavoriteFriends: [FriendStatus] {
        filteredFriends.filter { !$0.isFavorite }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Handle + Header ──
            VStack(spacing: 6) {
                Text(String(localized: "arkadaş seç"))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)

            // ── Search bar ──
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.4))
                    .font(.system(size: 14, weight: .medium))
                TextField("", text: $searchText, prompt: Text(String(localized: "ara")).foregroundColor(.white.opacity(0.4)))
                    .focused($isSearchFocused)
                    .foregroundColor(.white)
                    .font(.system(size: 15))
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.4))
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            // ── Scrollable friend list ──
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    // Send groups — only show when no active search
                    if searchText.isEmpty && !sendGroups.isEmpty {
                        sectionHeader(String(localized: "gruplar"))
                        ForEach(sendGroups) { group in
                            let memberSet = Set(group.memberIds)
                            // Group is "selected" when every member is currently selected.
                            let allSelected = !memberSet.isEmpty && memberSet.isSubset(of: selectedIds)
                            friendRow(
                                label: group.name,
                                subtitle: String(localized: "\(group.memberIds.count) kişi"),
                                isSelected: allSelected,
                                avatarUrl: nil,
                                icon: "person.2.crop.square.stack.fill",
                                iconSize: 16
                            ) {
                                HapticsManager.playSelection()
                                if allSelected {
                                    selectedIds.subtract(memberSet)
                                } else {
                                    selectedIds.formUnion(memberSet)
                                }
                            }
                        }
                    }

                    // Favorites — always shown when present (search-respecting)
                    if !favoriteFriends.isEmpty {
                        if !sendGroups.isEmpty || !searchText.isEmpty {
                            sectionHeader(String(localized: "favoriler"))
                        } else {
                            sectionHeader(String(localized: "favoriler"))
                        }
                        ForEach(favoriteFriends, id: \.userId) { friend in
                            friendSelectionRow(for: friend)
                        }
                    }

                    // Regular friends
                    if !nonFavoriteFriends.isEmpty {
                        if !favoriteFriends.isEmpty || !sendGroups.isEmpty {
                            sectionHeader(String(localized: "tüm arkadaşlar"))
                        }
                        ForEach(nonFavoriteFriends, id: \.userId) { friend in
                            friendSelectionRow(for: friend)
                        }
                    }

                    if filteredFriends.isEmpty && !searchText.isEmpty {
                        Text(String(localized: "bu aramayla kimse çıkmadı"))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.vertical, 24)
                    }

                    // Save current selection as a new group (>=2 selected)
                    if searchText.isEmpty && selectedIds.count >= 2 {
                        Button {
                            HapticsManager.playSelection()
                            newGroupName = ""
                            showCreateGroupAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(String(localized: "seçimi grup olarak kaydet"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }

                    // Select All row — only when search is empty
                    if searchText.isEmpty && friends.count > 1 {
                        friendRow(
                            label: String(localized: "herkese gönder"),
                            subtitle: String(localized: "\(friends.count) arkadaş"),
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
        .task {
            do {
                sendGroups = try await SendGroupService.shared.fetchGroups()
            } catch {
                // Silent — empty groups list is fine
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: SendGroupService.groupsChangedNotification)) { _ in
            Task { sendGroups = (try? await SendGroupService.shared.fetchGroups()) ?? [] }
        }
        .alert(String(localized: "grubu adlandır"), isPresented: $showCreateGroupAlert) {
            TextField(String(localized: "grup adı"), text: $newGroupName)
                .textInputAutocapitalization(.never)
            Button(String(localized: "kaydet")) {
                let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                let members = Array(selectedIds)
                Task {
                    do {
                        _ = try await SendGroupService.shared.createGroup(name: name, memberIds: members)
                    } catch {
                        groupCreationError = error.localizedDescription
                    }
                }
            }
            Button(String(localized: "iptal"), role: .cancel) {}
        } message: {
            Text(String(localized: "seçili \(selectedIds.count) kişi bu grup adıyla bir arada saklanır."))
        }
        .alert(String(localized: "grup oluşturulamadı"),
               isPresented: Binding(get: { groupCreationError != nil }, set: { if !$0 { groupCreationError = nil } })) {
            Button("tamam", role: .cancel) {}
        } message: {
            Text(groupCreationError ?? "")
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
            let suffix = turkishDativeSuffix(for: name)
            return String(localized: "\(name)'\(suffix) gönder")
        } else {
            return String(localized: "\(selectedIds.count) kişiye gönder")
        }
    }

    private func turkishDativeSuffix(for name: String) -> String {
        let lastChar = name.lowercased().last ?? "a"
        let backVowels: Set<Character> = ["a", "ı", "o", "u"]
        let frontVowels: Set<Character> = ["e", "i", "ö", "ü"]
        let vowels = backVowels.union(frontVowels)

        // Find the last vowel in the name to determine harmony
        let lastVowel = name.lowercased().last(where: { vowels.contains($0) }) ?? "e"

        // If name ends with a vowel, add buffer 'y'
        let needsBuffer = vowels.contains(lastChar)
        let isBack = backVowels.contains(lastVowel)

        if needsBuffer {
            return isBack ? "ya" : "ye"
        } else {
            return isBack ? "a" : "e"
        }
    }


    private var sendNowButton: some View {
        Button {
            HapticsManager.playImpact(style: .heavy)
            onSend()
        } label: {
            Text(sendButtonLabel)
                .font(.system(size: 17, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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

    // MARK: - Section helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func friendSelectionRow(for friend: FriendStatus) -> some View {
        let name = friend.profile?.displayName ?? friend.profile?.username ?? String(localized: "bilinmeyen")
        let avatarUrl = friend.profile?.avatarUrl
        friendRow(
            label: name,
            subtitle: friend.isFavorite ? "★" : nil,
            isSelected: selectedIds.contains(friend.userId),
            avatarUrl: avatarUrl,
            icon: "person.fill",
            iconSize: 16
        ) {
            HapticsManager.playSelection()
            if selectedIds.contains(friend.userId) {
                selectedIds.remove(friend.userId)
            } else {
                selectedIds.insert(friend.userId)
            }
        }
        .contextMenu {
            Button {
                Task {
                    try? await FriendshipService.shared.setFavorite(
                        friendId: friend.userId,
                        isFavorite: !friend.isFavorite
                    )
                }
            } label: {
                if friend.isFavorite {
                    Label(String(localized: "favorilerden çıkar"), systemImage: "star.slash")
                } else {
                    Label(String(localized: "favorilere ekle"), systemImage: "star.fill")
                }
            }
        }
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
