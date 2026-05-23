import Foundation

@MainActor
@Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var isLoading: Bool = true
    var isLoadingMore: Bool = false
    /// Older-page pagination flag — flips false once we hit the end.
    var canLoadMore: Bool = true

    /// Maps senderId -> avatarUrl for displaying sender avatars
    var senderAvatars: [String: String] = [:]

    /// Friend request IDs that have been accepted
    var acceptedRequests: Set<String> = []

    /// Friend request IDs currently being accepted (loading state)
    var acceptingRequests: Set<String> = []

    /// Tracks the active listener task to prevent duplicates. Stored in an
    /// `IsolatedRef` so the nonisolated `deinit` can cancel without
    /// `nonisolated(unsafe)`.
    private let listenerTask = IsolatedRef<Task<Void, Never>?>(nil)
    private var isListening = false
    private let deps = DependencyContainer.shared

    deinit {
        listenerTask.value?.cancel()
    }

    func listenToNotifications() async {
        // Guard: don't create duplicate listeners
        guard !isListening else { return }
        isListening = true

        // Cancel any previous listener
        listenerTask.value?.cancel()

        let stream = deps.notificationRepository.listenToNotifications()
        listenerTask.value = Task { [weak self] in
            do {
                for try await newNotifications in stream {
                    if Task.isCancelled { break }
                    guard let self else { break }
                    // Filter out notifications from blocked senders. Without this
                    // a freshly blocked user could still nudge / message and
                    // surface in the inbox until the next login.
                    let blockedIds = await AuthService.shared.bestKnownBlockedUserIds()
                    let filtered = blockedIds.isEmpty
                        ? newNotifications
                        : newNotifications.filter { !blockedIds.contains($0.senderId) }
                    await MainActor.run {
                        self.notifications = filtered
                        self.isLoading = false
                    }
                    await self.fetchSenderAvatars()
                }
            } catch {
                AppLogger.service.error("notification stream error: \(error.localizedDescription, privacy: .public)")
            }
            await MainActor.run {
                self?.isLoading = false
                self?.isListening = false
            }
        }
    }

    func stopListening() {
        listenerTask.value?.cancel()
        listenerTask.value = nil
        isListening = false
    }

    /// Append older notifications below the live window. Triggered when the
    /// user scrolls past the last rendered notification. Idempotent — calling
    /// it while a fetch is in flight is a no-op, and once the server returns
    /// nothing we flip `canLoadMore` so the sentinel stops firing.
    func loadMoreNotifications() async {
        guard !isLoadingMore, canLoadMore else { return }
        guard let oldestTimestamp = notifications.last?.timestamp else { return }

        isLoadingMore = true
        let older = await deps.notificationRepository.loadOlderNotifications(before: oldestTimestamp)
        isLoadingMore = false

        if older.isEmpty {
            canLoadMore = false
            return
        }

        // De-duplicate against the live window in case the server-side page
        // boundary overlaps with what's already streaming.
        let existing = Set(notifications.map(\.id))
        let toAppend = older.filter { !existing.contains($0.id) }
        notifications.append(contentsOf: toAppend)
        await fetchSenderAvatars()
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
                AppLogger.ui.error("accept friend request failed: \(error.localizedDescription, privacy: .public)")
            }
            acceptingRequests.remove(senderId)
        }
    }
}
