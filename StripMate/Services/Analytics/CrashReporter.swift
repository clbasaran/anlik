import Foundation
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Centralized crash reporting wrapper.
/// Add FirebaseCrashlytics SPM product from firebase-ios-sdk to enable.
public final class CrashReporter {
    public static let shared = CrashReporter()
    
    private init() {}
    
    /// Set the current user ID for crash attribution
    public func setUserId(_ userId: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setUserID(userId)
        #endif
    }
    
    /// Log a non-fatal error
    public func recordError(_ error: Error, userInfo: [String: Any]? = nil) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
        #endif
        #if DEBUG
 print(" CrashReporter: \(error.localizedDescription)")
        #endif
    }
    
    /// Log a custom message to the crash log
    public func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif
    }
    
    /// Set a custom key-value pair for crash context
    public func setCustomValue(_ value: Any, forKey key: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
        #endif
    }
}
