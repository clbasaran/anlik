import Foundation

@MainActor
@Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var isLoading: Bool = true

    /// Maps senderId -> avatarUrl for displaying sender avatars
    var senderAvatars: [String: String] = [:]

    /// Friend request IDs that have been accepted
    var acceptedRequests: Set<String> = []

    /// Friend request IDs currently being accepted (loading state)
    var acceptingRequests: Set<String> = []

    /// Tracks the active listener task to prevent duplicates
    nonisolated(unsafe) private var listenerTask: Task<Void, Never>?
    private var isListening = false
    private let deps = DependencyContainer.shared

    deinit {
        listenerTask?.cancel()
    }

    func listenToNotifications() async {
        // Guard: don't create duplicate listeners
        guard !isListening else { return }
        isListening = true

        // Cancel any previous listener
        listenerTask?.cancel()

        let stream = deps.notificationRepository.listenToNotifications()
        listenerTask = Task { [weak self] in
            do {
                for try await newNotifications in stream {
                    if Task.isCancelled { break }
                    guard let self else { break }
                    await MainActor.run {
                        self.notifications = newNotifications
                        self.isLoading = false
                    }
                    await self.fetchSenderAvatars()
                }
            } catch {
                // Stream failed — ensure loading state resets
                #if DEBUG
                print("Notification stream error: \(error)")
                #endif
            }
            await MainActor.run {
                self?.isLoading = false
                self?.isListening = false
            }
        }
    }

    func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
        isListening = false
    }

    func markAsRead(id: String) {
        Task {
            await deps.notificationRepository.markAsRead(id: id)
        }
    }

    // MARK: - Sender Avatars

    func fetchSenderAvatars() async {
        let senderIds = Set(notifications.map(\.senderId)).subtracting(senderAvatars.keys)
        guard !senderIds.isEmpty else { return }

        await withTaskGroup(of: (String, String?).self) { group in
            for senderId in senderIds {
                group.addTask { [deps] in
                    do {
                        let profile = try await deps.userRepository.fetchProfile(for: senderId)
                        return (senderId, profile.avatarUrl)
                    } catch {
                        return (senderId, nil)
                    }
                }
            }

            for await (senderId, avatarUrl) in group {
                if let avatarUrl {
                    senderAvatars[senderId] = avatarUrl
                }
            }
        }
    }

    // MARK: - Friend Request Actions

    func acceptFriendRequest(senderId: String) {
        guard !acceptedRequests.contains(senderId),
              !acceptingRequests.contains(senderId) else { return }

        acceptingRequests.insert(senderId)

        Task {
            do {
                try await deps.friendRepository.acceptRequest(from: senderId)
                acceptedRequests.insert(senderId)
            } catch {
                #if DEBUG
                print("Accept friend request error: \(error)")
                #endif
            }
            acceptingRequests.remove(senderId)
        }
    }
}
