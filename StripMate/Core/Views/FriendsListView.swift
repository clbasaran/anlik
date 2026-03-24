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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { actionMessage = nil }
                        }
                    }
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .center) {
            if let code = viewModel.currentProfile?.inviteCode {
                Text(code)
                    .font(.system(size: 13, design: .monospaced).weight(.bold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .accessibilityLabel("Davet kodun: \(code)")
            }
            
            Spacer()
            
            Button {
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
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .accessibilityLabel("QR kodunu göster")
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 8)
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
                        TextField("8 haneli kodu gir", text: $viewModel.searchCode)
                            .font(.system(.body, design: .monospaced).weight(.bold))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: viewModel.searchCode) { _, newValue in
                                if newValue.count == 8 {
                                    Task { await viewModel.searchPartner() }
                                } else {
                                    viewModel.searchedProfile = nil
                                    viewModel.errorMessage = nil
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
                    
                    if let error = viewModel.errorMessage {
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
        HStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 44, height: 44)
                .overlay(Text(String(profile.displayName?.prefix(1) ?? "?")).font(.system(size: 17, weight: .bold)).foregroundColor(.white))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.displayName ?? "Kullanıcı")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(profile.inviteCode)
                    .font(.system(size: 12, design: .monospaced).weight(.medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            Button {
                Task { await viewModel.addFriend(profile.id) }
            } label: {
                Text("ekle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
    
    // MARK: - Pending Request Row
    
    private func pendingRequestRow(for request: FriendStatus) -> some View {
        HStack(spacing: 12) {
            if let urlStr = request.profile?.avatarUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } placeholder: {
                    avatarPlaceholder(initial: String((request.profile?.displayName ?? "U").prefix(1)))
                }
            } else {
                avatarPlaceholder(initial: String((request.profile?.displayName ?? "U").prefix(1)))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(request.profile?.displayName ?? "bilinmeyen")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text("arkadaş olmak istiyor")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    Task {
                        await inboxVM.acceptFriend(request.userId)
                        await viewModel.fetchFriends()
                    }
                } label: {
                    Text("kabul et")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                
                Button {
                    Task {
                        await viewModel.removeFriend(request.userId)
                        await inboxVM.fetchData()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 16)
    }
    
    // MARK: - Conversation Row
    
    private func conversationRow(for conversation: ConversationItem) -> some View {
        let hasUnread = (conversation.summary?.unreadCount ?? 0) > 0
        
        return HStack(spacing: 14) {
            if let urlStr = conversation.avatarUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } placeholder: {
                    avatarPlaceholder(initial: conversation.avatarInitial, size: 48)
                }
            } else {
                avatarPlaceholder(initial: conversation.avatarInitial, size: 48)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(conversation.displayName)
                        .font(.system(size: 16, weight: hasUnread ? .bold : .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let summary = conversation.summary {
                        Text(timeAgo(summary.lastMessageTimestamp))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(hasUnread ? .white : .white.opacity(0.3))
                    }
                }
                
                HStack {
                    if let summary = conversation.summary {
                        let isMe = summary.lastMessageSenderId == (inboxVM.currentUserId ?? "")
                        Text(isMe ? "sen: \(summary.lastMessage)" : summary.lastMessage)
                            .font(.system(size: 13, weight: hasUnread ? .semibold : .regular))
                            .foregroundColor(hasUnread ? .white.opacity(0.7) : .white.opacity(0.35))
                            .lineLimit(1)
                    } else {
                        Text("sohbete başla")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                    
                    if hasUnread, let unreadCount = conversation.summary?.unreadCount {
                        Text("\(unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(hasUnread ? Color.white.opacity(0.07) : Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
    
    // MARK: - Friend Card
    
    @ViewBuilder
    private func friendCard(for friend: Friend) -> some View {
        VStack(spacing: 0) {
            friendCardHeader(for: friend)
            friendCardStreak(for: friend)
            friendCardTierProgress(for: friend)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5))
        .padding(.horizontal, 20)
        .contextMenu {
            if !friend.isPending {
                let name = friend.profile?.displayName ?? friend.profile?.username ?? "bilinmeyen"

                // DM shortcut
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
    
    @ViewBuilder
    private func friendCardHeader(for friend: Friend) -> some View {
        HStack(spacing: 12) {
            if let avatarUrl = friend.profile?.avatarUrl,
               let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } placeholder: {
                    friendAvatarPlaceholder(for: friend)
                }
            } else {
                friendAvatarPlaceholder(for: friend)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.profile?.displayName ?? friend.profile?.username ?? "bilinmeyen")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                if friend.isPending {
                    let isIncoming = friend.requesterId != nil && friend.requesterId != FirebaseAuth.Auth.auth().currentUser?.uid
                    Text(isIncoming ? "sana istek gönderdi" : "istek gönderildi")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if !friend.isPending {
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
                }
            }
            
            Spacer(minLength: 4)
            
            if friend.isPending {
                friendCardPendingActions(for: friend)
            } else {
                friendCardActiveActions(for: friend)
            }
        }
    }
    
    @ViewBuilder
    private func friendCardPendingActions(for friend: Friend) -> some View {
        let isIncoming = friend.requesterId != nil && friend.requesterId != FirebaseAuth.Auth.auth().currentUser?.uid
        if isIncoming {
            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.acceptFriend(friend.userId) }
                } label: {
                    Text("kabul et")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("Arkadaşlık isteğini kabul et")
                
                Button {
                    Task { await viewModel.removeFriend(friend.userId) }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .accessibilityLabel("İsteği reddet")
            }
        } else {
            Button {
                Task { await viewModel.removeFriend(friend.userId) }
            } label: {
                Text("iptal")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    @ViewBuilder
    private func friendCardActiveActions(for friend: Friend) -> some View {
        HStack(spacing: 8) {
            if let profileContext = friend.profile {
                let metadataProfile = UserProfile(
                    id: profileContext.id,
                    inviteCode: profileContext.inviteCode,
                    email: profileContext.email,
                    displayName: profileContext.displayName,
                    username: profileContext.username,
                    dateOfBirth: profileContext.dateOfBirth,
                    avatarUrl: profileContext.avatarUrl,
                    bio: profileContext.bio
                )
                NavigationLink {
                    DirectMessageView(partner: metadataProfile)
                } label: {
                    Image(systemName: "bubble.right.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Mesaj gönder")
            }
        }
    }
    
    @ViewBuilder
    private func friendCardStreak(for friend: Friend) -> some View {
        if !friend.isPending, let streak = viewModel.streak(for: friend.userId) {
            HStack(spacing: 16) {
                // Seri gösterimi
                if streak.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(streak.currentStreak)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                }
                
                // Seviye gösterimi
                HStack(spacing: 4) {
                    Image(systemName: streak.tier.tierIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.gray)
                    Text(streak.tier.tierName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.gray)
                }
                
                // Sıra göstergesi
                if let currentId = FirebaseAuth.Auth.auth().currentUser?.uid,
                   streak.lastSenderId != currentId,
                   streak.currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .medium))
                        Text("senin sıran")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                
                // Süre dolmak üzere göstergesi
                if streak.isExpiringSoon {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.gray)
                }
                
                Spacer()
            }
            .padding(.top, 10)
            .padding(.leading, 56)
        }
    }
    
    @ViewBuilder
    private func friendCardTierProgress(for friend: Friend) -> some View {
        if !friend.isPending, let streak = viewModel.streak(for: friend.userId), streak.friendshipScore > 0 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 2)
                    Capsule()
                        .fill(LinearGradient(colors: tierGradient(for: streak.tier), startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * streak.tierProgress, height: 2)
                        .animation(.easeInOut(duration: 0.6), value: streak.tierProgress)
                }
            }
            .frame(height: 2)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Helpers
    
    private func friendAvatarPlaceholder(for friend: Friend) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String((friend.profile?.displayName ?? friend.profile?.username ?? "?").prefix(1)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.white)
            )
    }
    
    private func avatarPlaceholder(initial: String, size: CGFloat = 44) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: size, height: size)
            .overlay(
                Text(initial)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private func tierGradient(for tier: Streak.FriendshipTier) -> [Color] {
        switch tier {
        case .tanidik:  return [.white.opacity(0.2), .white.opacity(0.3)]
        case .muhabbet: return [.white.opacity(0.3), .white.opacity(0.4)]
        case .yakin:    return [.white.opacity(0.4), .white.opacity(0.6)]
        case .sirdas:   return [.white.opacity(0.6), .white.opacity(0.8)]
        case .kadim:    return [.white.opacity(0.8), .white]
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "şimdi" }
        if interval < 3600 { return "\(Int(interval / 60))dk" }
        if interval < 86400 { return "\(Int(interval / 3600))sa" }
        if interval < 604800 { return "\(Int(interval / 86400))g" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: date)
    }
}

// MARK: - Skeleton Conversation Row

private struct SkeletonConversationRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 180, height: 12)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .shimmer()
    }
}

// MARK: - Report User Sheet

struct ReportUserSheet: View {
    let userName: String
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let reasons = [
        "Inappropriate Content",
        "Harassment or Bullying",
        "Spam or Fake Account",
        "Other"
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("kullanıcıyı şikâyet et")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("bu kullanıcıyı neden şikâyet ediyorsun?")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                
                VStack(spacing: 12) {
                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            onReport(reason)
                        } label: {
                            Text(String(localized: String.LocalizationValue(reason)))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("iptal")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 32)
        }
    }
}
