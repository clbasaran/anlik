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
                    EmptyStateView(icon: "bell.slash", title: String(localized: "henüz bildirim yok"), subtitle: String(localized: "arkadaşlarından bir an geldiğinde\nburada göreceksin."))
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.notifications) { notification in
                            NotificationRow(notification: notification, lockedStripIds: lockedStripIds)
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
                    }
                    .listStyle(.plain)
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
        case .photoReceived, .commentReceived, .stripChat:
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

    var body: some View {
        HStack(spacing: 16) {
            // Icon / Avatar
            ZStack {
                Circle()
                    .fill(notification.isRead ? Color.white.opacity(0.1) : Color.white.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconForType(notification.type))
                    .foregroundColor(notification.isRead ? .white.opacity(0.6) : Color.white)
                    .font(.system(size: 20, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(messageForNotification(notification))
                    .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(notification.timestamp.timeAgo())
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Spacer()
            
            // Thumbnail if available — gizli anlar blur + kilit
            if let thumb = notification.thumbnailUrl, let url = URL(string: thumb) {
                let isLocked = isStripLocked(relatedId: notification.relatedId)
                ZStack {
                    CachedAsyncImage(url: url) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .blur(radius: isLocked ? 8 : 0)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 44, height: 44)
                    }

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if !notification.isRead {
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(notification.isRead ? Color.white.opacity(0.03) : Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(messageForNotification(notification))
        .accessibilityHint(notification.isRead ? String(localized: "okundu") : String(localized: "okunmadı, açmak için çift dokun"))
        .accessibilityAddTraits(.isButton)
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
        }
    }
    
    private func messageForNotification(_ notification: AppNotification) -> String {
        switch notification.type {
        case .photoReceived:
            return String(localized: "\(notification.senderName) seninle bir an paylaştı.")
        case .commentReceived, .stripChat:
            return String(localized: "\(notification.senderName) anına yorum yaptı.")
        case .friendAdded:
            return String(localized: "\(notification.senderName) artık arkadaşın.")
        case .directMessage:
            return String(localized: "\(notification.senderName) sana mesaj gönderdi.")
        case .weeklySummary:
            return String(localized: "Haftalık özetin hazır!")
        case .supportReply:
            return String(localized: "Destek ekibinden yanıt geldi.")
        case .streakWarning:
            return String(localized: "\(notification.senderName) ile serin sona yaklaşıyor!")
        case .achievementUnlocked:
            return String(localized: "Yeni bir başarım kazandın!")
        case .nudge:
            return String(localized: "\(notification.senderName) seni durtu!")
        }
    }
}

extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
