import SwiftUI

public struct InboxView: View {
    @State private var viewModel = InboxViewModel()
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    public init() {}

    /// Conversations filtered by search text (matches friend display name)
    private var filteredConversations: [ConversationItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return viewModel.conversations
        }
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        return viewModel.conversations.filter { $0.displayName.lowercased().contains(query) }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom header
                    HStack {
                        Button {
                            HapticsManager.playImpact(style: .light)
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel(String(localized: "Kapat"))

                        Spacer()

                        Text("gelen kutusu")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()

                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))

                        TextField("isimle ara...", text: $searchText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // Pending Requests Section
                            if !viewModel.pendingRequests.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("arkadaşlık istekleri")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.45))
                                        .textCase(.uppercase)
                                        .tracking(1)
                                        .padding(.horizontal, 24)
                                    
                                    ForEach(viewModel.pendingRequests, id: \.userId) { request in
                                        HStack {
                                            Circle()
                                                .fill(Color.white.opacity(0.08))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Text(String((request.profile?.displayName ?? "U").prefix(1)))
                                                        .font(.system(size: 17, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(request.profile?.displayName ?? "bilinmeyen")
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(.white)
                                                Text("sana istek gönderdi")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.35))
                                            }
                                            
                                            Spacer()
                                            
                                            Button {
                                                HapticsManager.playImpact(style: .medium)
                                                Task { await viewModel.acceptFriend(request.userId) }
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
                                        }
                                        .padding(14)
                                        .background(Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 0.5))
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            // Conversations Section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("mesajlar")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .padding(.horizontal, 24)
                                
                                if viewModel.isLoading {
                                    VStack(spacing: 0) {
                                        ForEach(0..<5, id: \.self) { _ in
                                            SkeletonInboxRow()
                                        }
                                    }
                                } else if viewModel.conversations.isEmpty {
                                    emptyStateTray
                                } else if filteredConversations.isEmpty {
                                    Text("eşleşen sohbet bulunamadı")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 16)
                                } else {
                                    LazyVStack(spacing: 2) {
                                        ForEach(filteredConversations) { conversation in
                                            if let profile = conversation.friendStatus.profile {
                                                NavigationLink {
                                                    DirectMessageView(partner: profile)
                                                } label: {
                                                    conversationRow(for: conversation)
                                                }
                                            } else {
                                                // Profile couldn't be fetched — still show the row
                                                conversationRow(for: conversation)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        HapticsManager.playImpact(style: .light)
                        await viewModel.fetchData(force: true)
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.fetchData()
            }
            .errorToast(Binding(
                get: { viewModel.errorMessage },
                set: { viewModel.errorMessage = $0 }
            ))
        }
    }
    
    private func conversationRow(for conversation: ConversationItem) -> some View {
        let hasUnread = (conversation.summary?.unreadCount ?? 0) > 0
        
        return HStack(spacing: 14) {
            // Avatar
            if let urlStr = conversation.avatarUrl, let url = URL(string: urlStr) {
                CachedAsyncImage(url: url) { image in
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } placeholder: {
                    avatarPlaceholder(initial: conversation.avatarInitial)
                }
            } else {
                avatarPlaceholder(initial: conversation.avatarInitial)
            }
            
            // Name + Last message
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
                        let isMe = summary.lastMessageSenderId == (viewModel.currentUserId ?? "")
                        Text(isMe ? "sen: \(summary.lastMessage)" : summary.lastMessage)
                            .font(.system(size: 13, weight: hasUnread ? .semibold : .regular))
                            .foregroundColor(hasUnread ? .white.opacity(0.7) : .white.opacity(0.35))
                            .lineLimit(1)
                    } else {
                        Text("sohbete başla")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.25))
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
    
    private func avatarPlaceholder(initial: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 48, height: 48)
            .overlay(
                Text(initial)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private func timeAgo(_ date: Date) -> String {
        TurkishDateFormatter.timeAgo(from: date)
    }
    
    private var emptyStateTray: some View {
        EmptyStateView(icon: "tray", title: "henüz mesaj yok", subtitle: "arkadaşlarınla sohbet başlat.")
    }
}
