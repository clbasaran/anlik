import Foundation
import FirebaseFirestore

/// Retry wrapper with exponential backoff for network operations.
public enum RetryHelper {
    /// Whether an error is worth retrying. Permission/argument/authentication
    /// failures are deterministic — retrying only burns the backoff budget and
    /// delays the user-facing error, so we fail fast on those and retry only
    /// transient network conditions.
    static func isRetryable(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: ns.code) {
            switch code {
            case .unavailable, .deadlineExceeded, .aborted, .internal, .resourceExhausted:
                return true
            default:
                return false
            }
        }
        if ns.domain == NSURLErrorDomain {
            return true // timeouts, connection lost, cannot-connect, etc.
        }
        // Unknown error types: retry once via the backoff loop rather than assume fatal.
        return true
    }
    /// Execute an async operation with retry and exponential backoff.
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default: 3)
    ///   - initialDelay: Initial delay between retries in seconds (default: 1.0)
    ///   - maxDelay: Maximum delay cap in seconds (default: 8.0)
    ///   - operation: The async throwing operation to retry
    /// - Returns: The result of the successful operation
    public static func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 8.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = initialDelay

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                AppLogger.service.debug("Retry attempt \(attempt, privacy: .public)/\(maxAttempts, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")

                // Fail fast on deterministic errors — no point backing off.
                if !isRetryable(error) { throw error }

                // Don't sleep after the last attempt
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay = min(currentDelay * 2, maxDelay)
                }
            }
        }

        throw lastError ?? AppError.unknown(NSError(domain: "RetryHelper", code: -1))
    }

    /// Execute an async operation with a timeout.
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: The async throwing operation
    /// - Returns: The result of the operation
    public static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AppError.timeout
            }

            guard let result = try await group.next() else {
                throw AppError.timeout
            }
            group.cancelAll()
            return result
        }
    }
}
