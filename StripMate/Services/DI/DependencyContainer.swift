import Foundation
import os

/// A simple dependency container for injecting service protocols.
/// For production, wire real repositories; for tests, wire mocks.
/// Thread-safe via OSAllocatedUnfairLock.
public final class DependencyContainer: @unchecked Sendable {
    public static let shared = DependencyContainer()
    
    private let lock = OSAllocatedUnfairLock<State>(initialState: State())
    
    private struct State {
        var stripRepository: StripRepositoryProtocol = StripRepository.shared
        var friendRepository: FriendRepositoryProtocol = FriendRepository.shared
        var userRepository: UserRepositoryProtocol = UserRepository.shared
        var chatRepository: ChatRepositoryProtocol = ChatRepository.shared
        var notificationRepository: NotificationRepositoryProtocol = NotificationRepository.shared
        // Low-level clients (used by services internally for testability)
        var firestoreClient: FirestoreClient = FirebaseFirestoreClient.shared
        var authClient: AuthClient = FirebaseAuthClient.shared
        var storageClient: StorageClient = FirebaseStorageClient.shared
    }
    
    public var stripRepository: StripRepositoryProtocol {
        get { lock.withLock { $0.stripRepository } }
        set { lock.withLock { $0.stripRepository = newValue } }
    }
    
    public var friendRepository: FriendRepositoryProtocol {
        get { lock.withLock { $0.friendRepository } }
        set { lock.withLock { $0.friendRepository = newValue } }
    }
    
    public var userRepository: UserRepositoryProtocol {
        get { lock.withLock { $0.userRepository } }
        set { lock.withLock { $0.userRepository = newValue } }
    }
    
    public var chatRepository: ChatRepositoryProtocol {
        get { lock.withLock { $0.chatRepository } }
        set { lock.withLock { $0.chatRepository = newValue } }
    }
    
    public var notificationRepository: NotificationRepositoryProtocol {
        get { lock.withLock { $0.notificationRepository } }
        set { lock.withLock { $0.notificationRepository = newValue } }
    }

    public var firestoreClient: FirestoreClient {
        get { lock.withLock { $0.firestoreClient } }
        set { lock.withLock { $0.firestoreClient = newValue } }
    }

    public var authClient: AuthClient {
        get { lock.withLock { $0.authClient } }
        set { lock.withLock { $0.authClient = newValue } }
    }

    public var storageClient: StorageClient {
        get { lock.withLock { $0.storageClient } }
        set { lock.withLock { $0.storageClient = newValue } }
    }

    public init() {}
    
    /// Reset to production defaults (useful after tests)
    public func reset() {
        lock.withLock { state in
            state.stripRepository = StripRepository.shared
            state.friendRepository = FriendRepository.shared
            state.userRepository = UserRepository.shared
            state.chatRepository = ChatRepository.shared
            state.notificationRepository = NotificationRepository.shared
            state.firestoreClient = FirebaseFirestoreClient.shared
            state.authClient = FirebaseAuthClient.shared
            state.storageClient = FirebaseStorageClient.shared
        }
    }
}
