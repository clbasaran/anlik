import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseAuth

/// Destination for notification tap navigation
enum NotificationDestination: Identifiable {
    case strip(PhotoMetadata)
    case friends
    case inbox
    case camera
    case history
    case achievements

    var id: String {
        switch self {
        case .strip(let p): return "strip_\(p.id)"
        case .friends: return "friends"
        case .inbox: return "inbox"
        case .camera: return "camera"
        case .history: return "history"
        case .achievements: return "achievements"
        }
    }
}

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()
    @State private var destination: NotificationDestination?
    @State private var isLoadingStrip = false
    @State private var errorMessage: String?
    @AppStorage("show_notifications_empty_warm_note") private var showWarmEmptyNote = true
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Strip.timestamp, order: .reverse) private var localStrips: [Strip]

    /// Pre-computed locked strip IDs — computed once per render, not per notification row
    private var lockedStripIds: Set<String> {
        let myId = Auth.auth().currentUser?.uid ?? ""
        return Set(localStrips.filter { $0.isLockedFor(myId) }.map(\.id))
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Button {
                        HapticsManager.playImpact(style: .light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(String(localized: "kapat"))

                    Spacer()

                    Text(String(localized: "bildirimler"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(0..<6, id: \.self) { _ in
                                SkeletonNotificationRow()
                            }
                        }
                        .padding(.top, 8)
                    }
                } else if viewModel.notifications.isEmpty {
                    VStack(spacing: 18) {
                        if showWarmEmptyNote {
                            WarmNoteCard(
                                eyebrow: String(localized: "küçük not"),
                                title: String(localized: "burası şimdilik sakin"),
                                message: String(localized: "ilk bildirim gelince bu-9++6rada seni bekliyor olacak."),
                                dismissLabel: String(localized: "tamam"),
                                onDismiss: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        showWarmEmptyNote = false
                                    }
                                }
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }

                        EmptyStateView(
                            icon: "bell.slash",
                            title: String(localized: "henüz bildirim yok"),
                            subtitle: String(localized: "bir şeyler olunca burada belirir."),
                            actionLabel: String(localized: "bir an paylaş"),
                            action: {
                                dismiss()
                                TabBarState.shared.selectedTab = .camera
                            }
                        )
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.notifications) { notification in
                            NotificationRow(
                                notification: notification,
                                lockedStripIds: lockedStripIds,
                                viewModel: viewModel,
                                onAction: { handleNotificationTap(notification) }
                            )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    HapticsManager.playImpact(style: .light)
                                    handleNotificationTap(notification)
                                }
                                .onAppear {
                                    if !notification.isRead {
                                        viewModel.markAsRead(id: notification.id)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    if !notification.isRead {
                                        Button {
                                            viewModel.markAsRead(id: notification.id)
                                            HapticsManager.playSelection()
                                        } label: {
                                            Label(String(localized: "okundu"), systemImage: "envelope.open")
                                        }
                                        .tint(Color.white.opacity(0.2))
                                    }
                                }
                        }

                        // Pagination sentinel — appears at the bottom of the
                        // list. When it scrolls into view we ask the VM for
                        // an older page; once `canLoadMore` flips false the
                        // VM is a no-op, so the sentinel becomes a quiet tail.
                        if viewModel.canLoadMore && !viewModel.notifications.isEmpty {
                            Color.clear
                                .frame(height: 1)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .onAppear {
                                    Task { await viewModel.loadMoreNotifications() }
                                }
                        }

                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView().tint(.white.opacity(0.4))
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.vertical, Brand.Spacing.sm)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        HapticsManager.playImpact(style: .light)
                        viewModel.stopListening()
                        await viewModel.listenToNotifications()
                    }
                }
            }
            
            if isLoadingStrip {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView().tint(.white)
            }
        }
        .task {
            await viewModel.listenToNotifications()
        }
        .fullScreenCover(item: $destination) { dest in
            NavigationStack {
                Group {
                    switch dest {
                    case .strip(let photo):
                        let isMine = photo.senderId == Auth.auth().currentUser?.uid
                        PhotoDetailView(photo: photo, isSentByMe: isMine)
                    case .friends:
                        FriendsListView()
                    case .inbox:
                        InboxView()
                    case .camera:
                        // Close and switch to camera tab
                        Color.clear.onAppear {
                            destination = nil
                            dismiss()
                            TabBarState.shared.selectedTab = .camera
                        }
                    case .history:
                        // Close and switch to history tab
                        Color.clear.onAppear {
                            destination = nil
                            dismiss()
                            TabBarState.shared.selectedTab = .history
                        }
                    case .achievements:
                        AchievementView(unlockedIds: AchievementService.shared.unlockedIds)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            destination = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .errorAlert(errorMessage: $errorMessage)
    }

    private func handleNotificationTap(_ notification: AppNotification) {
        // Mark as read
        if !notification.isRead {
            viewModel.markAsRead(id: notification.id)
        }
        
        switch notification.type {
        case .photoReceived, .commentReceived, .stripChat, .reactionReceived:
            guard let stripId = notification.relatedId else { return }
            isLoadingStrip = true
            Task {
                do {
                    if let photo = try await DependencyContainer.shared.stripRepository.fetchStrip(byId: stripId) {
                        // Gizli ve kilitli strip'i açma
                        let myId = Auth.auth().currentUser?.uid ?? ""
                        let isLocked = photo.isSecret == true && !(photo.unlockedBy ?? []).contains(myId) && photo.senderId != myId
                        if isLocked {
                            errorMessage = String(localized: "bu gizli bir an. açmak için sen de bir an paylaş!")
                            HapticsManager.playNotification(type: .warning)
                        } else {
                            destination = .strip(photo)
                        }
                    }
                } catch {
                    errorMessage = String(localized: "İçerik yüklenemedi.")
                    HapticsManager.playNotification(type: .error)
                }
                isLoadingStrip = false
            }
        case .friendAdded:
            destination = .friends
        case .directMessage:
            destination = .inbox
        case .nudge:
            destination = .camera
        case .weeklySummary:
            destination = .history
        case .supportReply:
            destination = .inbox
        case .streakWarning:
            destination = .camera
        case .achievementUnlocked:
            destination = .achievements
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    /// Strip lock lookup cache passed from parent to avoid per-row @Query over all strips
    var lockedStripIds: Set<String>
    var viewModel: NotificationsViewModel
    var onAction: () -> Void

    private let accentOrange = Color(red: 1.0, green: 0.55, blue: 0.0) // #FF8C00

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // MARK: - Top row: avatar + text + timestamp + unread dot
            HStack(alignment: .top, spacing: 12) {
                // Sender avatar
                senderAvatarView

                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.senderName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    +
                    Text(" ")
                    +
                    Text(actionText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(notification.timestamp.timeAgo())
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                if !notification.isRead {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }
            }

            // MARK: - Middle: thumbnail preview (conditional)
            if hasThumbnailPreview,
               let thumb = notification.thumbnailUrl,
               let url = URL(string: thumb) {
                let isLocked = isStripLocked(relatedId: notification.relatedId)
                ZStack {
                    CachedAsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .blur(radius: isLocked ? 12 : 0)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 160)
                    }

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // MARK: - Bottom: inline action buttons
            actionButtons
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(notification.isRead ? Color.white.opacity(0.03) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(messageForNotification(notification))
        .accessibilityHint(notification.isRead ? String(localized: "okundu") : String(localized: "okunmadi, acmak icin cift dokun"))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Sender Avatar

    @ViewBuilder
    private var senderAvatarView: some View {
        if let avatarUrlString = viewModel.senderAvatars[notification.senderId],
           let avatarUrl = URL(string: avatarUrlString) {
            CachedAsyncImage(url: avatarUrl) { image in
                image.resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } placeholder: {
                fallbackAvatarIcon
            }
        } else {
            fallbackAvatarIcon
        }
    }

    private var fallbackAvatarIcon: some View {
        ZStack {
            Circle()
                .fill(notification.isRead ? Color.white.opacity(0.1) : Color.white.opacity(0.15))
                .frame(width: 32, height: 32)

            Image(systemName: iconForType(notification.type))
                .foregroundColor(notification.isRead ? .white.opacity(0.6) : .white)
                .font(.system(size: 14, weight: .bold))
        }
    }

    // MARK: - Thumbnail eligibility

    private var hasThumbnailPreview: Bool {
        switch notification.type {
        case .photoReceived, .commentReceived, .stripChat, .reactionReceived:
            return notification.thumbnailUrl != nil
        default:
            return false
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            switch notification.type {
            case .friendAdded:
                if viewModel.acceptedRequests.contains(notification.senderId) {
                    NotificationPillButton(
                        title: String(localized: "kabul edildi"),
                        style: .accepted
                    )
                    .disabled(true)
                } else {
                    NotificationPillButton(
                        title: String(localized: "kabul et"),
                        style: .primary,
                        isLoading: viewModel.acceptingRequests.contains(notification.senderId)
                    ) {
                        HapticsManager.playImpact(style: .medium)
                        viewModel.markAsRead(id: notification.id)
                        viewModel.acceptFriendRequest(senderId: notification.senderId)
                    }
                }

                NotificationPillButton(
                    title: String(localized: "profile git"),
                    style: .outline
                ) {
                    HapticsManager.playImpact(style: .light)
                    viewModel.markAsRead(id: notification.id)
                    onAction()
                }

            case .photoReceived, .commentReceived, .stripChat, .reactionReceived:
                NotificationPillButton(
                    title: String(localized: "gor"),
                    style: .outline
                ) {
                    HapticsManager.playImpact(style: .light)
                    onAction()
                }

            case .directMessage:
                NotificationPillButton(
                    title: String(localized: "yanitla"),
                    style: .outline
                ) {
                    HapticsManager.playImpact(style: .light)
                    onAction()
                }

            case .nudge, .streakWarning:
                NotificationPillButton(
                    title: String(localized: "fotoğraf çek"),
                    style: .primary
                ) {
                    HapticsManager.playImpact(style: .medium)
                    onAction()
                }

            case .achievementUnlocked:
                NotificationPillButton(
                    title: String(localized: "gor"),
                    style: .outline
                ) {
                    HapticsManager.playImpact(style: .light)
                    onAction()
                }

            case .weeklySummary:
                NotificationPillButton(
                    title: String(localized: "ozeti gor"),
                    style: .outline
                ) {
                    HapticsManager.playImpact(style: .light)
                    onAction()
                }

            case .supportReply:
                NotificationPillButton(
                    title: String(localized: "yaniti gor"),
                    style: .outline
                ) {
                    HapticsManager.playImpact(style: .light)
                    onAction()
                }
            }
        }
    }

    // MARK: - Helpers

    private var actionText: String {
        switch notification.type {
        case .photoReceived:
            return String(localized: "seninle bir an paylaştı.")
        case .commentReceived, .stripChat:
            return String(localized: "anina yorum yapti.")
        case .friendAdded:
            return String(localized: "sana arkadaşlık isteği gönderdi.")
        case .directMessage:
            return String(localized: "sana mesaj gönderdi.")
        case .weeklySummary:
            return String(localized: "Haftalik ozetin hazir!")
        case .supportReply:
            return String(localized: "Destek ekibinden yanit geldi.")
        case .streakWarning:
            return String(localized: "bağın sona yaklaşıyor!")
        case .achievementUnlocked:
            return String(localized: "Yeni bir basarim kazandin!")
        case .nudge:
            return String(localized: "seni durtu!")
        case .reactionReceived:
            return String(localized: "anına tepki verdi.")
        }
    }

    private func isStripLocked(relatedId: String?) -> Bool {
        guard let stripId = relatedId else { return false }
        return lockedStripIds.contains(stripId)
    }

    private func iconForType(_ type: NotificationType) -> String {
        switch type {
        case .photoReceived: return "camera.fill"
        case .commentReceived, .stripChat: return "bubble.left.fill"
        case .friendAdded: return "person.badge.plus.fill"
        case .directMessage: return "envelope.fill"
        case .weeklySummary: return "chart.bar.fill"
        case .supportReply: return "headphones"
        case .streakWarning: return "flame.fill"
        case .achievementUnlocked: return "star.fill"
        case .nudge: return "hand.wave.fill"
        case .reactionReceived: return "heart.fill"
        }
    }

    private func messageForNotification(_ notification: AppNotification) -> String {
        switch notification.type {
        case .photoReceived:
            return String(localized: "\(notification.senderName) seninle bir an paylaştı.")
        case .commentReceived, .stripChat:
            return String(localized: "\(notification.senderName) anina yorum yapti.")
        case .friendAdded:
            return String(localized: "\(notification.senderName) sana arkadaşlık isteği gönderdi.")
        case .directMessage:
            return String(localized: "\(notification.senderName) sana mesaj gönderdi.")
        case .weeklySummary:
            return String(localized: "Haftalik ozetin hazir!")
        case .supportReply:
            return String(localized: "Destek ekibinden yanit geldi.")
        case .streakWarning:
            return String(localized: "\(notification.senderName) ile bağın sona yaklaşıyor!")
        case .achievementUnlocked:
            return String(localized: "Yeni bir basarim kazandin!")
        case .nudge:
            return String(localized: "\(notification.senderName) seni durtu!")
        case .reactionReceived:
            return String(localized: "\(notification.senderName) anına tepki verdi.")
        }
    }
}

// MARK: - Notification Pill Button

private enum NotificationButtonStyle {
    case primary
    case outline
    case accepted
}

private struct NotificationPillButton: View {
    let title: String
    let style: NotificationButtonStyle
    var isLoading: Bool = false
    var action: (() -> Void)? = nil

    private let accentOrange = Color(red: 1.0, green: 0.55, blue: 0.0)

    var body: some View {
        Button {
            action?()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.7)
                } else {
                    Text(title)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(height: 28)
            .padding(.horizontal, 14)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: hasBorder ? 1 : 0)
            )
        }
        .buttonStyle(.plain)
        .disabled(style == .accepted || isLoading)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .outline: return .white
        case .accepted: return .green
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return accentOrange
        case .outline: return .clear
        case .accepted: return .green.opacity(0.15)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return .clear
        case .outline: return .white.opacity(0.2)
        case .accepted: return .green.opacity(0.3)
        }
    }

    private var hasBorder: Bool {
        style != .primary
    }
}

extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
