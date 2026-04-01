import SwiftUI
import SwiftData
import FirebaseAuth

// MARK: - Section Enum



// MARK: - FriendsListView

public struct FriendsListView: View {
    @State private var viewModel = FriendsListViewModel()
    @State private var inboxVM = InboxViewModel()
    @Query(sort: \Friend.timestamp, order: .reverse) private var localFriends: [Friend]
    
    @AppStorage("pinned_friend_id", store: UserDefaults(suiteName: AppConstants.appGroupID))
    private var pinnedFriendId: String = ""
    
        @State private var showBlockAlert = false
    @State private var showReportSheet = false
    @State private var qrInviteCode: String?
    @State private var targetUserId: String?
    @State private var targetUserName: String?
    @State private var actionMessage: String?
    @State private var friendToRemove: String?
    @State private var friendToRemoveName: String?
    @State private var selectedDMPartner: UserProfile?
    @State private var selectedFriendForProfile: FriendStatus?
    @State private var friendFilter: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ── Header ──
                    header
                    
                    // ── Content ──
                    friendsTab
                }
            }
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedDMPartner) { partner in
                DirectMessageView(partner: partner)
            }
        }
        .task {
            // Register callback to auto-refresh streaks when Firestore snapshot arrives
            await StreakService.shared.setOnUpdate { [weak viewModel] in
                guard let viewModel else { return }
                Task { @MainActor in
                    await viewModel.refreshStreaks()
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchFriends()
                await inboxVM.fetchData()
            }
        }
        .errorAlert(errorMessage: Binding(
            get: { viewModel.errorMessage ?? inboxVM.errorMessage },
            set: { viewModel.errorMessage = $0; inboxVM.errorMessage = $0 }
        ))
        .alert("kullanıcıyı engelle", isPresented: $showBlockAlert) {
            Button("iptal", role: .cancel) {}
            Button("engelle", role: .destructive) {
                guard let userId = targetUserId else { return }
                Task {
                    do {
                        try await DependencyContainer.shared.userRepository.blockUser(userId)
                        await viewModel.fetchFriends()
                        await inboxVM.fetchData()
                        actionMessage = "kullanıcı engellendi."
                        HapticsManager.playNotification(type: .success)
                    } catch {
                        viewModel.errorMessage = "kullanıcı engellenemedi."
                        HapticsManager.playNotification(type: .error)
                    }
                }
            }
        } message: {
            Text("bu kullanıcıyı engellemek onu arkadaş listenden kaldırır ve gelecekteki etkileşimleri engeller.")
        }
        .confirmationDialog(
            "\(friendToRemoveName ?? "bu kişiyi") arkadaş listenden kaldırmak istediğine emin misin?",
            isPresented: Binding(
                get: { friendToRemove != nil },
                set: { if !$0 { friendToRemove = nil; friendToRemoveName = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("kaldır", role: .destructive) {
                if let uid = friendToRemove {
                    Task { await viewModel.removeFriend(uid) }
                }
                friendToRemove = nil
                friendToRemoveName = nil
            }
            Button("vazgeç", role: .cancel) {
                friendToRemove = nil
                friendToRemoveName = nil
            }
        }
        .sheet(isPresented: $showReportSheet) {
            ReportUserSheet(
                userName: targetUserName ?? "Kullanıcı",
                onReport: { reason in
                    guard let userId = targetUserId else { return }
                    Task {
                        do {
                            try await DependencyContainer.shared.userRepository.reportUser(userId, reason: reason)
                            actionMessage = "kullanıcı şikâyet edildi. teşekkürler."
                            HapticsManager.playNotification(type: .success)
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                            HapticsManager.playNotification(type: .error)
                        }
                    }
                    showReportSheet = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.black)
        }
        .sheet(isPresented: Binding(
            get: { qrInviteCode != nil },
            set: { if !$0 { qrInviteCode = nil } }
        )) {
            if let code = qrInviteCode {
                QRCodeView(inviteCode: code)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.black)
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedFriendForProfile != nil },
            set: { if !$0 { selectedFriendForProfile = nil } }
        )) {
            if let friendStatus = selectedFriendForProfile {
                NavigationStack {
                    FriendProfileView(friend: friendStatus)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.black)
            }
        }
        .overlay(alignment: .top) {
            if let message = actionMessage {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2.5))
                            withAnimation { actionMessage = nil }
                        }
                    }
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Profile Hero + Header

    @State private var showSettings = false
    @State private var showSupportChat = false
    @State private var showContactSync = false

    private var header: some View {
        VStack(spacing: 12) {
            // Profile Hero — always visible, shows placeholder while loading
            Button {
                HapticsManager.playImpact(style: .light)
                if viewModel.currentProfile != nil {
                    showSettings = true
                }
            } label: {
                HStack(spacing: 14) {
                    // Avatar
                    if let avatarUrl = viewModel.currentProfile?.avatarUrl, let url = URL(string: avatarUrl) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Circle().fill(Color.white.opacity(0.1))
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                    }

                    // Name + username
                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.currentProfile?.displayName ?? "yükleniyor...")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if let username = viewModel.currentProfile?.username, !username.isEmpty {
                            Text("@\(username)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Stats
                    HStack(spacing: 16) {
                        let activeFriendCount = localFriends.filter { !$0.isPending }.count
                        let activeStreakCount = viewModel.streaks.values.filter { $0.currentStreak > 0 }.count

                        statPill(value: "\(activeFriendCount)", label: "arkadaş")
                        statPill(value: "\(activeStreakCount)", label: "seri")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showSettings) {
                if let profile = viewModel.currentProfile {
                    SettingsView(profile: profile, onLogout: {
                        // Logout handled inside SettingsView
                    })
                    .preferredColorScheme(.dark)
                }
            }

            // Action row: share code + QR
            HStack(spacing: 10) {
                if let code = viewModel.currentProfile?.inviteCode {
                    Button {
                        HapticsManager.playImpact(style: .light)
                        let shareText = "anlık.'ta beni ekle!\n\nDavet kodum: \(code)\n\nhttps://apps.apple.com/tr/app/anlik/id6759793761?l=tr"
                        let av = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = windowScene.windows.first?.rootViewController {
                            root.present(av, animated: true)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .bold))
                            Text(code)
                                .font(.system(size: 13, design: .monospaced).weight(.bold))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    }
                    .accessibilityLabel("Davet kodunu paylaş: \(code)")
                }

                Button {
                    HapticsManager.playImpact(style: .light)
                    if let code = viewModel.currentProfile?.inviteCode, !code.isEmpty {
                        qrInviteCode = code
                    } else {
                        Task {
                            await viewModel.fetchFriends()
                            if let code = viewModel.currentProfile?.inviteCode, !code.isEmpty {
                                qrInviteCode = code
                            }
                        }
                    }
                } label: {
                    Image(systemName: "qrcode")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .accessibilityLabel("QR kodunu göster")

                // Support chat button
                Button {
                    HapticsManager.playImpact(style: .light)
                    showSupportChat = true
                } label: {
                    Image(systemName: "questionmark.bubble")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Canlı destek")

                // Contact sync button
                Button {
                    HapticsManager.playImpact(style: .light)
                    showContactSync = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Rehberden bul")

            }
            .sheet(isPresented: $showSupportChat) {
                NavigationStack {
                    SupportChatView()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showContactSync) {
                ContactSyncView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.black)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func statPill(value: String, label: String) -> some View {
        FriendStatPill(value: value, label: label)
    }
    
    
    // MARK: - Friends Tab
    
    private var friendsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("arkadaş ekle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1)
                        .padding(.horizontal, 8)
                    
                    HStack {
                        TextField("kod veya kullanıcı adı", text: $viewModel.searchCode)
                            .font(.system(.body, weight: .semibold))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit {
                                Task { await viewModel.searchPartner() }
                            }
                            .onChange(of: viewModel.searchCode) { _, newValue in
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.count == 8 {
                                    Task { await viewModel.searchPartner() }
                                } else if trimmed.isEmpty {
                                    viewModel.searchedProfile = nil
                                    viewModel.searchErrorMessage = nil
                                }
                            }
                        
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                    
                    if let error = viewModel.searchErrorMessage {
                        Text(error)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                    }
                    
                    if let profile = viewModel.searchedProfile {
                        searchResultCard(for: profile)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.horizontal, 40)
                
                // Incoming Requests
                let incomingRequests = localFriends.filter {
                    $0.isPending && $0.requesterId != nil && $0.requesterId != FirebaseAuth.Auth.auth().currentUser?.uid
                }
                if !incomingRequests.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("gelen istekler · \(incomingRequests.count)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 28)
                        
                        ForEach(incomingRequests, id: \.userId) { friend in
                            friendCard(for: friend)
                        }
                    }
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.horizontal, 40)
                }
                
                // Active Friends + Outgoing
                VStack(alignment: .leading, spacing: 14) {
                    let activeFriends = localFriends.filter { !$0.isPending }
                    let outgoing = localFriends.filter {
                        $0.isPending && ($0.requesterId == nil || $0.requesterId == FirebaseAuth.Auth.auth().currentUser?.uid)
                    }

                    // Filter active friends by name
                    let filteredActive: [Friend] = {
                        let query = friendFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        guard !query.isEmpty else { return activeFriends }
                        return activeFriends.filter {
                            let name = ($0.profile?.displayName ?? $0.profile?.username ?? "").lowercased()
                            return name.contains(query)
                        }
                    }()

                    HStack {
                        Text("arkadaşların · \(activeFriends.count)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1)
                        Spacer()
                    }
                    .padding(.horizontal, 28)

                    // Name filter — show only when 3+ friends
                    if activeFriends.count >= 3 {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                            TextField("isimle ara...", text: $friendFilter)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 20)
                    }

                    if viewModel.isLoading && localFriends.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonFriendRow()
                            }
                        }
                    } else if activeFriends.isEmpty && outgoing.isEmpty {
                        EmptyStateView(
                            icon: "person.2",
                            title: "henüz arkadaşın yok",
                            subtitle: "yukarıdaki alana 8 haneli\nkodu girerek arkadaş ekle."
                        )
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredActive, id: \.userId) { friend in
                                friendCard(for: friend)
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                            ForEach(outgoing, id: \.userId) { friend in
                                friendCard(for: friend)
                                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                            }
                        }

                        if !friendFilter.isEmpty && filteredActive.isEmpty {
                            Text("eşleşen arkadaş bulunamadı")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 16)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .refreshable {
            HapticsManager.playImpact(style: .light)
            await viewModel.fetchFriends()
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    
    // MARK: - Search Result Card

    private func searchResultCard(for profile: UserProfile) -> some View {
        FriendSearchResultCard(profile: profile) {
            Task { await viewModel.addFriend(profile.id) }
        }
    }
    
    // MARK: - Pending Request Row

    private func pendingRequestRow(for request: FriendStatus) -> some View {
        FriendPendingRequestRow(
            request: request,
            onAccept: {
                Task {
                    await inboxVM.acceptFriend(request.userId)
                    await viewModel.fetchFriends()
                }
            },
            onReject: {
                Task {
                    await viewModel.removeFriend(request.userId)
                    await inboxVM.fetchData()
                }
            }
        )
    }
    
    // MARK: - Conversation Row

    private func conversationRow(for conversation: ConversationItem) -> some View {
        FriendConversationRow(conversation: conversation, currentUserId: inboxVM.currentUserId)
    }
    
    // MARK: - Friend Card

    @ViewBuilder
    private func friendCard(for friend: Friend) -> some View {
        let streak = viewModel.streak(for: friend.userId)
        VStack(spacing: 0) {
            FriendCardHeaderView(friend: friend, onTapProfile: {
                var userProfile: UserProfile? = nil
                if let p = friend.profile {
                    userProfile = UserProfile(
                        id: p.id,
                        inviteCode: p.inviteCode,
                        email: p.email,
                        displayName: p.displayName,
                        username: p.username,
                        dateOfBirth: p.dateOfBirth,
                        avatarUrl: p.avatarUrl,
                        bio: p.bio
                    )
                }
                selectedFriendForProfile = FriendStatus(
                    userId: friend.userId,
                    isPending: false,
                    timestamp: friend.timestamp,
                    requesterId: nil,
                    profile: userProfile
                )
            })
            FriendCardStreakView(friend: friend, streak: streak)
            FriendCardTierProgressView(friend: friend, streak: streak)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 20)
        .contextMenu {
            if !friend.isPending {
                let name = friend.profile?.displayName ?? friend.profile?.username ?? "bilinmeyen"

                if let profileContext = friend.profile {
                    Button {
                        selectedDMPartner = UserProfile(
                            id: profileContext.id,
                            inviteCode: profileContext.inviteCode,
                            email: profileContext.email,
                            displayName: profileContext.displayName,
                            username: profileContext.username,
                            dateOfBirth: profileContext.dateOfBirth,
                            avatarUrl: profileContext.avatarUrl,
                            bio: profileContext.bio
                        )
                    } label: {
                        Label(String(localized: "mesaj gönder"), systemImage: "bubble.right.fill")
                    }
                }

                Button(role: .destructive) {
                    friendToRemove = friend.userId
                    friendToRemoveName = name
                } label: {
                    Label(String(localized: "arkadaşlıktan çıkar"), systemImage: "person.badge.minus")
                }

                Button(role: .destructive) {
                    targetUserId = friend.userId
                    targetUserName = name
                    showBlockAlert = true
                } label: {
                    Label(String(localized: "kullanıcıyı engelle"), systemImage: "hand.raised.fill")
                }

                Button {
                    targetUserId = friend.userId
                    targetUserName = name
                    showReportSheet = true
                } label: {
                    Label(String(localized: "kullanıcıyı şikâyet et"), systemImage: "exclamationmark.triangle.fill")
                }
            }
        }
    }
    
}
