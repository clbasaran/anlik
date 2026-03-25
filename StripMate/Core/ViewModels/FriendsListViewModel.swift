import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
@Observable
public final class FriendsListViewModel {
    public var searchCode: String = ""
    public var searchedProfile: UserProfile?
    public var isLoading = false
    public var errorMessage: String?
    public var searchErrorMessage: String?
    public var currentProfile: UserProfile?
    
    /// Streak data keyed by friendId for quick lookup in the UI
    public var streaks: [String: Streak] = [:]
    
    private let deps = DependencyContainer.shared

    /// Debounce flags to prevent duplicate taps
    private var isAddingFriend = false
    private var isAcceptingIds: Set<String> = []
    private var isRemoving = false

    public init() {}
    
    public func fetchFriends() async {
        self.currentProfile = await deps.userRepository.currentUserProfile

        // If profile not cached, actively fetch it
        if currentProfile == nil, let uid = Auth.auth().currentUser?.uid {
            self.currentProfile = try? await deps.userRepository.fetchProfile(for: uid)
        }

        // Get userId — fallback to Firebase Auth if profile not loaded yet
        let userId = currentProfile?.id ?? Auth.auth().currentUser?.uid

        #if DEBUG
        print("🔥 fetchFriends: starting, userId=\(userId ?? "nil"), profileLoaded=\(currentProfile != nil)")
        #endif

        // Start streak listener and register for real-time updates
        if let uid = userId {
            await StreakService.shared.startListening(for: uid)
            await StreakService.shared.setOnUpdate { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.refreshStreaks()
                }
            }
        }
        
        guard NetworkMonitor.shared.isConnected else {
            self.errorMessage = nil
            return
        }
        do {
            _ = try await deps.friendRepository.fetchFriends()
        } catch {
            self.errorMessage = String(localized: "Arkadaşlar senkronize edilemedi.")
        }
        
        // Refresh streak cache immediately (may be empty on first call)
        await refreshStreaks()
        
        #if DEBUG
        print("🔥 fetchFriends: first refreshStreaks done, got \(streaks.count) streaks")
        #endif
        
        // Streak verisi listener ile gelecek, bloklama yapma
        // StreakService listener otomatik olarak UI'i guncelleyecek
    }
    
    /// Refresh local streak data from the StreakService cache
    public func refreshStreaks() async {
        let all = await StreakService.shared.allStreaksByScore()
        let newMap = Dictionary(uniqueKeysWithValues: all.map { ($0.friendId, $0.streak) })
        self.streaks = newMap
    }
    
    /// Get streak for a specific friend
    public func streak(for friendId: String) -> Streak? {
        streaks[friendId]
    }
    
    public func searchPartner() async {
        let trimmed = searchCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return }
        isLoading = true
        searchErrorMessage = nil
        do {
            HapticsManager.playImpact(style: .light)
            self.searchedProfile = try await deps.userRepository.searchUser(byCode: trimmed)
            self.searchErrorMessage = nil
        } catch {
            HapticsManager.playNotification(type: .error)
            self.searchErrorMessage = String(localized: "kullanıcı bulunamadı.")
            self.searchedProfile = nil
        }
        isLoading = false
    }
    
    public func addFriend(_ userId: String) async {
        guard !isAddingFriend else { return }
        isAddingFriend = true
        defer { isAddingFriend = false }

        HapticsManager.playImpact(style: .medium)
        do {
            try await deps.friendRepository.sendRequest(to: userId)
            AnalyticsService.shared.log(.sendFriendRequest)
            HapticsManager.playNotification(type: .success)
            self.searchCode = ""
            self.searchedProfile = nil
            await fetchFriends()
        } catch {
            HapticsManager.playNotification(type: .error)
            self.errorMessage = String(localized: "İstek gönderilemedi.")
        }
    }

    public func acceptFriend(_ userId: String) async {
        guard !isAcceptingIds.contains(userId) else { return }
        isAcceptingIds.insert(userId)
        defer { isAcceptingIds.remove(userId) }

        HapticsManager.playImpact(style: .medium)
        do {
            try await deps.friendRepository.acceptRequest(from: userId)
            AnalyticsService.shared.log(.acceptFriendRequest)
            HapticsManager.playNotification(type: .success)
            await fetchFriends()
        } catch {
            self.errorMessage = String(localized: "Kabul edilemedi.")
        }
    }

    public func removeFriend(_ userId: String) async {
        guard !isRemoving else { return }
        isRemoving = true
        defer { isRemoving = false }

        do {
            try await deps.friendRepository.remove(userId)
            AnalyticsService.shared.log(.removeFriend)
            await fetchFriends()
        } catch {
            self.errorMessage = String(localized: "Kaldırılamadı.")
        }
    }
}
