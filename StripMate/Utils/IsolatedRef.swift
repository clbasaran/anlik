import Foundation

/// Thread-safe reference holder for resources that need to outlive a
/// `@MainActor`-isolated owner — primarily cancellable Tasks and Firestore
/// `ListenerRegistration` instances that must be torn down from a `deinit`
/// (which is nonisolated and cannot synchronously hop to MainActor).
///
/// This is the Swift-6-clean replacement for the `nonisolated(unsafe) private
/// var task: Task?` pattern: drop-in semantics, but the `Sendable`
/// guarantee comes from an actual lock instead of a "trust me" annotation.
///
/// Usage:
/// ```swift
/// @MainActor final class FooViewModel {
///     private let listenerTask = IsolatedRef<Task<Void, Never>?>(nil)
///     deinit {
///         listenerTask.value?.cancel()
///     }
///     func start() {
///         listenerTask.value = Task { ... }
///     }
/// }
/// ```
public final class IsolatedRef<Value>: @unchecked Sendable {
    private var storage: Value
    private let lock = NSLock()

    public init(_ initial: Value) {
        self.storage = initial
    }

    public var value: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storage = newValue
        }
    }

    /// Atomically read-modify-write the value. Useful when the new value
    /// depends on the old one, e.g. swapping a task while cancelling the
    /// previous one in a single critical section.
    public func mutate<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&storage)
    }
}
