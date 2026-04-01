import Foundation
import UIKit
import FirebaseAuth

@MainActor
@Observable
public final class HistoryViewModel {
    public var currentUserId: String?
    public var isLoading = true
    public var isLoadingMore = false
    public var canLoadMore = true
    public var errorMessage: String?
    
    /// Tracks the active listener task to prevent duplicates
    nonisolated(unsafe) private var listenerTask: Task<Void, Never>?
    private var isListening = false
    private let deps = DependencyContainer.shared
    
    public init() {}

    deinit {
        listenerTask?.cancel()
    }

    public func listenToPhotos() async {
        // ...existing code...
        guard !isListening else { return }
        
        do {
            // Try getting profile from repository first
            var profileId = await deps.userRepository.currentUserProfile?.id
            
            // Fallback: if profile not loaded yet, use Firebase Auth UID directly
            if profileId == nil {
                profileId = Auth.auth().currentUser?.uid
            }
            
            // If still nil, retry briefly (no long blocking)
            if profileId == nil {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                profileId = Auth.auth().currentUser?.uid
            }
            
            guard let profileId else {
                throw FirebaseError.unauthenticated
            }
            self.currentUserId = profileId
            
            listenerTask?.cancel()
            isListening = true

            let stream = deps.stripRepository.listenToHistory(for: profileId)
            listenerTask = Task { [weak self] in
                for await photos in stream {
                    if Task.isCancelled { break }
                    guard let self else { break }
                    await MainActor.run {
                        if self.isLoading { self.isLoading = false }
                    }
                    _ = photos // SwiftData sync is handled inside PhotoService's snapshot handler
                }
                await MainActor.run { self?.isListening = false }
            }
        } catch {
            isListening = false
            isLoading = false
            errorMessage = String(localized: "Geçmiş yüklenemedi. Aşağı çekerek tekrar dene.")
            #if DEBUG
            print("Failed to sync history from Firebase: \(error)")
            #endif
        }
    }
    
    /// Load older history items when scrolling to the bottom
    public func loadMore(oldestTimestamp: Date) async {
        guard !isLoadingMore, canLoadMore, let userId = currentUserId else { return }
        isLoadingMore = true
        
        let olderPhotos = await deps.stripRepository.loadMoreHistory(for: userId, before: oldestTimestamp)
        
        if olderPhotos.isEmpty {
            canLoadMore = false
        }
        // SwiftData sync handles insertion automatically via PhotoService
        
        isLoadingMore = false
    }
    
    /// Force refresh: cancel existing listener and re-subscribe
    public func refresh() async {
        canLoadMore = true
        stopListening()
        await listenToPhotos()
    }
    
    public func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
        isListening = false
    }
    
    /// Permanently delete a strip (sender only)
    public func deleteStrip(_ photo: PhotoMetadata) async {
        do {
            try await deps.stripRepository.deleteStrip(photo)
            HapticsManager.playNotification(type: .success)
        } catch {
            HapticsManager.playNotification(type: .error)
            self.errorMessage = String(localized: "Silme işlemi başarısız oldu.")
        }
    }
}
