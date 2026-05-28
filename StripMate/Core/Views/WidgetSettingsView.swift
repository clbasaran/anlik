import SwiftUI
import WidgetKit

/// Allows the user to select which friend's photo appears on the widget.
struct WidgetSettingsView: View {
    @State private var friends: [FriendStatus] = []
    @State private var selectedFriendId: String?
    @State private var isLoading = true

    private let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
    private let deps = DependencyContainer.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "widget.small")
                        .font(.system(size: 40))
                        .foregroundColor(Brand.textSecondary)

                    Text("widget ayarları")
                        .font(Brand.headline())
                        .foregroundColor(Brand.textPrimary)

                    Text("widget'ta kimin fotoğraflarını görmek istediğini seç")
                        .font(Brand.caption())
                        .foregroundColor(Brand.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // "Everyone" option
                Button {
                    selectFriend(nil)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16))
                            .frame(width: 40, height: 40)
                            .background(Brand.darkGray)
                            .clipShape(Circle())

                        Text("herkes")
                            .font(Brand.body())
                            .foregroundColor(Brand.textPrimary)

                        Spacer()

                        if selectedFriendId == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(selectedFriendId == nil ? Brand.darkGray : Color.clear)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Friend list
                if isLoading {
                    ProgressView()
                        .padding()
                } else if friends.isEmpty {
                    Text("henüz arkadaşın yok")
                        .font(Brand.body())
                        .foregroundColor(Brand.textSecondary)
                        .padding()
                } else {
                    VStack(spacing: 4) {
                        ForEach(friends, id: \.userId) { friend in
                            Button {
                                selectFriend(friend.userId)
                            } label: {
                                HStack(spacing: 12) {
                                    // Avatar
                                    if let avatarUrl = friend.profile?.avatarUrl, let url = URL(string: avatarUrl) {
                                        CachedAsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(Brand.textSecondary)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 16))
                                            .frame(width: 40, height: 40)
                                            .background(Brand.darkGray)
                                            .clipShape(Circle())
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.profile?.displayName ?? friend.userId)
                                            .font(Brand.body())
                                            .foregroundColor(Brand.textPrimary)

                                        if let username = friend.profile?.username {
                                            Text("@\(username)")
                                                .font(Brand.caption())
                                                .foregroundColor(Brand.textSecondary)
                                        }
                                    }

                                    Spacer()

                                    if selectedFriendId == friend.userId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(selectedFriendId == friend.userId ? Brand.darkGray : Color.clear)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .background(Brand.black.ignoresSafeArea())
        .navigationTitle("widget")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            selectedFriendId = sharedDefaults?.string(forKey: "pinned_friend_id")
            do {
                let allFriends = try await deps.friendRepository.fetchFriends()
                friends = allFriends.filter { !$0.isPending }
            } catch {
                AppLogger.ui.error("Friend fetch error: \(error.localizedDescription, privacy: .public)")
            }
            isLoading = false
        }
    }

    private func selectFriend(_ friendId: String?) {
        selectedFriendId = friendId
        HapticsManager.playSelection()

        if let friendId = friendId, !friendId.isEmpty {
            sharedDefaults?.set(friendId, forKey: "pinned_friend_id")
        } else {
            sharedDefaults?.removeObject(forKey: "pinned_friend_id")
        }
        sharedDefaults?.synchronize()

        // Refresh widget and cache
        Task {
            await CacheService.shared.refreshWidgetFromHistory()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
