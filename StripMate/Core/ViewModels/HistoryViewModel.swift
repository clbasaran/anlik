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
    /// guven-11: true while the Firestore listener appears dead and we are
    /// retrying in the background. The view renders this as a quiet banner
    /// ("güncellenemiyor — yeniden bağlanıyor.") so a silently frozen feed
    /// never looks healthy.
    public var isReconnecting = false

    /// Tracks the active listener task to prevent duplicates. The Task is
    /// stored in an `IsolatedRef` so the nonisolated `deinit` can cancel it
    /// without resorting to `nonisolated(unsafe)`.
    private let listenerTask = IsolatedRef<Task<Void, Never>?>(nil)
    /// guven-11: watchdog + backoff re-subscribe task. Same `IsolatedRef`
    /// pattern so `deinit` can cancel it.
    private let recoveryTask = IsolatedRef<Task<Void, Never>?>(nil)
    private var isListening = false
    /// Whether the current subscription has delivered at least one snapshot.
    /// A healthy Firestore listener always fires promptly (from cache even
    /// when offline); prolonged silence means the listener errored out —
    /// PhotoService logs listener errors without signalling the stream, so
    /// this flag is the only client-side health signal we have.
    private var hasReceivedSnapshot = false
    private var reconnectAttempts = 0
    private let deps = DependencyContainer.shared

    public init() {}

    deinit {
        listenerTask.value?.cancel()
        recoveryTask.value?.cancel()
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

            subscribe(profileId: profileId)
        } catch {
            isListening = false
            isLoading = false
            errorMessage = String(localized: "Geçmiş yüklenemedi. Aşağı çekerek tekrar dene.")
            AppLogger.service.error("history sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Opens the history stream and arms the guven-11 watchdog.
    private func subscribe(profileId: String) {
        listenerTask.value?.cancel()
        recoveryTask.value?.cancel()
        isListening = true
        hasReceivedSnapshot = false

        let stream = deps.stripRepository.listenToHistory(for: profileId)
        listenerTask.value = Task { [weak self] in
            for await photos in stream {
                if Task.isCancelled { break }
                guard let self else { break }
                await MainActor.run {
                    if self.isLoading { self.isLoading = false }
                    self.hasReceivedSnapshot = true
                    self.reconnectAttempts = 0
                    if self.isReconnecting { self.isReconnecting = false }
                }
                _ = photos // SwiftData sync is handled inside PhotoService's snapshot handler
            }
            let wasCancelled = Task.isCancelled
            guard let self else { return }
            await MainActor.run {
                self.isListening = false
                // Stream ended without an explicit stop → the listener died;
                // tear down and re-subscribe with backoff.
                if !wasCancelled {
                    self.scheduleReconnect(profileId: profileId)
                }
            }
        }

        // Watchdog: if no snapshot lands shortly after subscribing, the
        // listener errored (PhotoService just logs and returns). Re-subscribe.
        recoveryTask.value = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                guard !self.hasReceivedSnapshot else { return }
                self.scheduleReconnect(profileId: profileId)
            }
        }
    }

    /// Backoff re-subscribe: 2s, 4s, 8s, 16s, then every 30s while the view
    /// lives. The quiet banner only shows when the network is up — the offline
    /// case already has its own banner.
    private func scheduleReconnect(profileId: String) {
        reconnectAttempts += 1
        isReconnecting = NetworkMonitor.shared.isConnected
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30)
        AppLogger.service.error("history listener stalled — retry #\(self.reconnectAttempts, privacy: .public) in \(delay, privacy: .public)s")

        recoveryTask.value?.cancel()
        recoveryTask.value = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                guard !self.hasReceivedSnapshot else { return }
                self.listenerTask.value?.cancel()
                self.isListening = false
                self.subscribe(profileId: profileId)
            }
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
        listenerTask.value?.cancel()
        listenerTask.value = nil
        recoveryTask.value?.cancel()
        recoveryTask.value = nil
        isListening = false
        isReconnecting = false
        reconnectAttempts = 0
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
