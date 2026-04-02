import Foundation
import UIKit

public struct ConversationItem: Identifiable {
    public var id: String { friendStatus.userId }
    public let friendStatus: FriendStatus
    public var summary: ThreadSummary?

    public var displayName: String {
        friendStatus.profile?.displayName ?? friendStatus.profile?.username ?? "bilinmeyen"
    }

    public var avatarInitial: String {
        String((friendStatus.profile?.displayName ?? friendStatus.profile?.username ?? "U").prefix(1))
    }

    public var avatarUrl: String? {
        friendStatus.profile?.avatarUrl
    }
}

@MainActor
@Observable
public final class InboxViewModel {
    public var pendingRequests: [FriendStatus] = []
    public var conversations: [ConversationItem] = []
    public var isLoading = false
    public var errorMessage: String?

    public private(set) var currentUserId: String?
    private let deps = DependencyContainer.shared

    /// Debounce: prevent rapid duplicate fetches
    private var isFetching = false
    /// Debounce: prevent rapid duplicate accept taps
    private var acceptingIds: Set<String> = []

    /// Cache: timestamp of last successful fetch
    private var lastFetchTime: Date?
    /// Cache staleness threshold (30 seconds)
    private let stalenessInterval: TimeInterval = 30
    /// Thread summary cache — avoids refetching unchanged threads
    private var summaryCache: [String: ThreadSummary] = [:]

    public init() {}

    public func fetchData(force: Bool = false) async {
        guard !isFetching else { return }

        // Staleness check: skip re-fetch if data is fresh (unless forced)
        if !force, let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < stalenessInterval,
           !conversations.isEmpty {
            return
        }

        isFetching = true
        isLoading = conversations.isEmpty // Only show full loading on first load
        self.currentUserId = await deps.userRepository.currentUserProfile?.id

        do {
            let allFriends = try await deps.friendRepository.fetchFriends()
            let blockedIds = (try? await deps.userRepository.fetchBlockedUserIds()) ?? []

            // Filter out blocked users
            let unblockedFriends = allFriends.filter { !blockedIds.contains($0.userId) }

            self.pendingRequests = unblockedFriends.filter {
                $0.isPending && $0.requesterId != currentUserId
            }

            let activeChats = unblockedFriends.filter { !$0.isPending }

            // Fetch thread summaries in parallel with concurrency limit to avoid N+1 explosion
            let batchSize = 10
            var allItems: [ConversationItem] = []

            for batchStart in stride(from: 0, to: activeChats.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, activeChats.count)
                let batch = Array(activeChats[batchStart..<batchEnd])

                let batchItems = await withTaskGroup(of: ConversationItem.self, returning: [ConversationItem].self) { group in
                    for chat in batch {
                        group.addTask { [summaryCache] in
                            // Use cached summary if available and this isn't a forced refresh
                            if !force, let cached = summaryCache[chat.userId] {
                                return ConversationItem(friendStatus: chat, summary: cached)
                            }
                            let summary = await ChatService.shared.fetchThreadSummary(partnerId: chat.userId)
                            return ConversationItem(friendStatus: chat, summary: summary)
                        }
                    }
                    var results: [ConversationItem] = []
                    for await item in group {
                        results.append(item)
                    }
                    return results
                }
                allItems.append(contentsOf: batchItems)
            }

            // Update summary cache
            for item in allItems {
                if let summary = item.summary {
                    self.summaryCache[item.id] = summary
                }
            }

            // Sort: conversations with messages first (by most recent), then those without messages
            self.conversations = allItems.sorted { a, b in
                let aTime = a.summary?.lastMessageTimestamp ?? .distantPast
                let bTime = b.summary?.lastMessageTimestamp ?? .distantPast
                return aTime > bTime
            }

            self.lastFetchTime = Date()
        } catch {
            self.errorMessage = String(localized: "Gelen kutusu yüklenemedi.")
        }
        isLoading = false
        isFetching = false
    }

    public func acceptFriend(_ userId: String) async {
        guard !acceptingIds.contains(userId) else { return }
        acceptingIds.insert(userId)
        HapticsManager.playImpact(style: .medium)
        do {
            try await deps.friendRepository.acceptRequest(from: userId)
            HapticsManager.playNotification(type: .success)
            await fetchData(force: true)
        } catch {
            self.errorMessage = String(localized: "Kabul edilemedi.")
        }
        acceptingIds.remove(userId)
    }
}
