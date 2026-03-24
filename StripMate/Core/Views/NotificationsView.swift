import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Destination for notification tap navigation
enum NotificationDestination: Identifiable {
    case strip(PhotoMetadata)
    case friends
    
    var id: String {
        switch self {
        case .strip(let p): return "strip_\(p.id)"
        case .friends: return "friends"
        }
    }
}

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()
    @State private var destination: NotificationDestination?
    @State private var isLoadingStrip = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("kapat")

                    Spacer()

                    Text("bildirimler")
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
                    EmptyStateView(icon: "bell.slash", title: "henüz bildirim yok", subtitle: "arkadaşlarından bir an geldiğinde\nburada göreceksin.")
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.notifications) { notification in
                            NotificationRow(notification: notification)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .contentShape(Rectangle())
                                .onTapGesture {
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
                                            Label("okundu", systemImage: "envelope.open")
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
        case .photoReceived, .commentReceived:
            guard let stripId = notification.relatedId else { return }
            isLoadingStrip = true
            Task {
                do {
                    if let photo = try await DependencyContainer.shared.stripRepository.fetchStrip(byId: stripId) {
                        destination = .strip(photo)
                    }
                } catch {
                    errorMessage = String(localized: "İçerik yüklenemedi.")
                    HapticsManager.playNotification(type: .error)
                }
                isLoadingStrip = false
            }
        case .friendAdded:
            destination = .friends
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    
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
            
            // Thumbnail if available
            if let thumb = notification.thumbnailUrl, let url = URL(string: thumb) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                }
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
        .accessibilityHint(notification.isRead ? "okundu" : "okunmadı, açmak için çift dokun")
        .accessibilityAddTraits(.isButton)
    }
    
    private func iconForType(_ type: NotificationType) -> String {
        switch type {
        case .photoReceived: return "camera.fill"
        case .commentReceived: return "bubble.left.fill"
        case .friendAdded: return "person.badge.plus.fill"
        }
    }
    
    private func messageForNotification(_ notification: AppNotification) -> String {
        switch notification.type {
        case .photoReceived:
            return String(localized: "\(notification.senderName) seninle bir an paylaştı.")
        case .commentReceived:
            return String(localized: "\(notification.senderName) anına yorum yaptı.")
        case .friendAdded:
            return String(localized: "\(notification.senderName) artık arkadaşın.")
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
