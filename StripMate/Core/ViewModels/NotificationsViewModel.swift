import Foundation

@MainActor
@Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var isLoading: Bool = true
    
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
}
