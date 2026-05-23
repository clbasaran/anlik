import Foundation
import os

/// Unified logger for StripMate services. Uses os.Logger for structured logs on device
/// and no-ops in release builds for anything that would leak sensitive info.
///
/// Prefer `AppLogger.service.debug(...)` over `print(...)` so console noise is disabled
/// in production and searchable via Console.app / Xcode on debug.
public enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.celalbasaran.stripmate"

    public static let service = Logger(subsystem: subsystem, category: "service")
    public static let auth = Logger(subsystem: subsystem, category: "auth")
    public static let camera = Logger(subsystem: subsystem, category: "camera")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
    public static let push = Logger(subsystem: subsystem, category: "push")
    public static let app = Logger(subsystem: subsystem, category: "app")
}
