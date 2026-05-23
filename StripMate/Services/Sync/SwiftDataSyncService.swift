import Foundation
import SwiftData

/// Handles all SwiftData local persistence and synchronization.
public actor SwiftDataSyncService {
    public static let shared = SwiftDataSyncService()
    
    public var modelContainer: ModelContainer?
    
    /// Single reusable ModelContext. Safe to cache because all access is serialized
    /// through this actor — the context is only ever touched from actor-isolated
    /// functions, never concurrently. Do NOT expose the context outside this actor.
    private var _cachedContext: ModelContext?
    
    // MARK: - Dedup & Debounce State
    /// Track hashes of last synced data to avoid redundant writes
    private var lastHistoryHash: Int = 0
    private var lastFriendsHash: Int = 0
    /// Minimum interval between syncs (seconds)
    private let debounceInterval: TimeInterval = 2.0
    private var lastHistorySyncTime: Date = .distantPast
    private var lastFriendsSyncTime: Date = .distantPast
    
    private init() {}
    
    public func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container
        self._cachedContext = ModelContext(container)
    }
    
    private var localContext: ModelContext? {
        return _cachedContext
    }
    
    // MARK: - Strip Sync
    
    public func syncHistoryToLocal(_ photos: [PhotoMetadata]) async {
        // Dedup: compute hash from IDs + timestamps to catch content changes
        let incomingHash = photos.map { "\($0.id)_\($0.timestamp.timeIntervalSince1970)_\($0.flagged)_\($0.isSecret)_\($0.unlockedBy?.count ?? 0)" }.sorted().hashValue
        let now = Date()
        
        // Skip if same data and within debounce window
        if incomingHash == lastHistoryHash && now.timeIntervalSince(lastHistorySyncTime) < debounceInterval {
            return
        }
        
        guard let context = localContext else { return }
        
        // SAFETY: If Firestore returned an empty array, do NOT wipe local cache.
        // This prevents accidental data loss from permission errors or network issues.
        // Only allow full wipe via explicit clearHistory action.
        guard !photos.isEmpty else {
            lastHistoryHash = incomingHash
            lastHistorySyncTime = now
            return
        }
        
        do {
            let descriptor = FetchDescriptor<Strip>()
            let localStrips = try context.fetch(descriptor)
            let localIds = Set(localStrips.map { $0.id })
            let remoteIds = Set(photos.map { $0.id })
            
            // Remove what's no longer on server
            let idsToRemove = localIds.subtracting(remoteIds)
            for id in idsToRemove {
                let toDelete = FetchDescriptor<Strip>(predicate: #Predicate { $0.id == id })
                if let strip = try context.fetch(toDelete).first {
                    context.delete(strip)
                }
            }
            
            // Upsert what's new
            for metadata in photos {
                if let existing = localStrips.first(where: { $0.id == metadata.id }) {
                    existing.senderId = metadata.senderId
                    existing.receiverIds = metadata.receiverIds
                    existing.imageUrl = metadata.imageUrl
                    existing.timestamp = metadata.timestamp
                    existing.latitude = metadata.latitude
                    existing.longitude = metadata.longitude
                    existing.cityName = metadata.cityName
                    existing.thumbnailUrl = metadata.thumbnailUrl
                    existing.smallThumbnailUrl = metadata.smallThumbnailUrl
                    existing.flagged = metadata.flagged
                    existing.flagReason = metadata.flagReason
                    existing.isSecret = metadata.isSecret
                    existing.unlockedBy = metadata.unlockedBy ?? []
                    existing.seenBy = metadata.seenBy ?? []
                    existing.videoUrl = metadata.videoUrl
                    existing.videoDuration = metadata.videoDuration
                } else {
                    let strip = Strip(
                        id: metadata.id,
                        senderId: metadata.senderId,
                        receiverIds: metadata.receiverIds,
                        imageUrl: metadata.imageUrl,
                        timestamp: metadata.timestamp,
                        latitude: metadata.latitude,
                        longitude: metadata.longitude,
                        cityName: metadata.cityName,
                        thumbnailUrl: metadata.thumbnailUrl,
                        smallThumbnailUrl: metadata.smallThumbnailUrl,
                        flagged: metadata.flagged,
                        flagReason: metadata.flagReason,
                        isSecret: metadata.isSecret,
                        unlockedBy: metadata.unlockedBy ?? [],
                        seenBy: metadata.seenBy ?? [],
                        videoUrl: metadata.videoUrl,
                        videoDuration: metadata.videoDuration
                    )
                    context.insert(strip)
                }
            }
            
            try context.save()
            lastHistoryHash = incomingHash
            lastHistorySyncTime = now
            #if DEBUG
            print("DEBUG: Synchronized \(photos.count) Strips to SwiftData")
            #endif
        } catch {
            #if DEBUG
            print("DEBUG: Failed to sync history: \(error)")
            #endif
        }
    }
    
    // MARK: - Friend Sync
    
    public func syncFriendsToLocal(_ friends: [FriendStatus]) async {
        // Dedup: compute a lightweight hash of incoming data
        let incomingHash = friends.map { "\($0.userId)_\($0.isPending)_\($0.requesterId ?? "")" }.sorted().hashValue
        let now = Date()
        
        // Skip if same data and within debounce window
        if incomingHash == lastFriendsHash && now.timeIntervalSince(lastFriendsSyncTime) < debounceInterval {
            return
        }
        
        guard let context = localContext else { return }
        
        do {
            let descriptor = FetchDescriptor<Friend>()
            let localFriends = try context.fetch(descriptor)
            let localIds = Set(localFriends.map { $0.userId })
            let remoteIds = Set(friends.map { $0.userId })
            
            // Remove what's no longer on server
            let idsToRemove = localIds.subtracting(remoteIds)
            for id in idsToRemove {
                let toDelete = FetchDescriptor<Friend>(predicate: #Predicate { $0.userId == id })
                if let friend = try context.fetch(toDelete).first {
                    context.delete(friend)
                }
            }
            
            // Upsert what's new
            for friend in friends {
                var localProfile: User? = nil
                if let profile = friend.profile {
                    await syncUserToLocal(profile)
                    let profDescriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == profile.id })
                    localProfile = try context.fetch(profDescriptor).first
                }
                
                if let existing = localFriends.first(where: { $0.userId == friend.userId }) {
                    existing.isPending = friend.isPending
                    existing.timestamp = friend.timestamp
                    existing.requesterId = friend.requesterId
                    existing.profile = localProfile
                    existing.isFavorite = friend.isFavorite
                } else {
                    let newFriend = Friend(
                        userId: friend.userId,
                        isPending: friend.isPending,
                        timestamp: friend.timestamp,
                        requesterId: friend.requesterId,
                        profile: localProfile,
                        isFavorite: friend.isFavorite
                    )
                    context.insert(newFriend)
                }
            }
            
            try context.save()
            lastFriendsHash = incomingHash
            lastFriendsSyncTime = now
            #if DEBUG
            print("DEBUG: Synchronized \(friends.count) Friends to SwiftData")
            #endif
        } catch {
            #if DEBUG
            print("DEBUG: Failed to sync friends: \(error)")
            #endif
        }
    }
    
    // MARK: - User Sync
    
    public func syncUserToLocal(_ profile: UserProfile) async {
        guard let context = localContext else { return }
        
        do {
            let id = profile.id
            let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.inviteCode = profile.inviteCode
                existing.email = profile.email
                existing.displayName = profile.displayName
                existing.username = profile.username
                existing.dateOfBirth = profile.dateOfBirth
                existing.avatarUrl = profile.avatarUrl
                existing.bio = profile.bio
                existing.statusEmoji = profile.statusEmoji
            } else {
                let newUser = User(
                    id: profile.id,
                    inviteCode: profile.inviteCode,
                    email: profile.email,
                    displayName: profile.displayName,
                    username: profile.username,
                    dateOfBirth: profile.dateOfBirth,
                    avatarUrl: profile.avatarUrl,
                    bio: profile.bio,
                    statusEmoji: profile.statusEmoji
                )
                context.insert(newUser)
            }
            try context.save()
        } catch {
            #if DEBUG
            print("DEBUG: Failed to sync user to local DB: \(error)")
            #endif
        }
    }
    
    // MARK: - Clear
    
    public nonisolated func deleteStrip(id: String) {
        Task {
            await _deleteStrip(id: id)
        }
    }
    
    private func _deleteStrip(id stripId: String) {
        guard let context = localContext else { return }
        do {
            let predicate = #Predicate<Strip> { $0.id == stripId }
            try context.delete(model: Strip.self, where: predicate)
            try context.save()
        } catch {
            #if DEBUG
            print("DEBUG: Failed to delete strip \(stripId): \(error)")
            #endif
        }
    }
    
    public nonisolated func clearAllStrips() {
        Task {
            await _clearAllStrips()
        }
    }
    
    private func _clearAllStrips() {
        guard let context = localContext else { return }
        do {
            try context.delete(model: Strip.self)
            try context.save()
            lastHistoryHash = 0
            lastHistorySyncTime = .distantPast
        } catch {
            #if DEBUG
            print("DEBUG: Failed to clear strips: \(error)")
            #endif
        }
    }
}
