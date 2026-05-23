import Foundation

/// Lightweight remote config service using UserDefaults as local store.
/// When Firebase Remote Config is added to the project, swap the implementation.
///
/// Usage:
///   await RemoteConfigService.shared.fetchConfig()
///   if RemoteConfigService.shared.friendGateEnabled { ... }
final class RemoteConfigService {

    static let shared = RemoteConfigService()

    private let defaults = UserDefaults.standard
    private let prefix = "rc_"

    private init() {}

    // MARK: - Fetch (stub — replace with real remote fetch later)

    /// Placeholder: in production, fetch values from a remote source.
    /// For now this is a no-op; values come from local defaults.
    func fetchConfig() async {
        // TODO: Replace with Firebase Remote Config or custom backend fetch
        // let url = URL(string: "https://your-api.com/config")!
        // let (data, _) = try await URLSession.shared.data(from: url)
        // parse and store values via setValue(...)
    }

    // MARK: - Accessors

    /// Returns a boolean value for the given config key. Defaults to `false` if not set.
    func boolValue(forKey key: String) -> Bool {
        defaults.bool(forKey: prefix + key)
    }

    /// Sets a config value locally (useful for testing or server-side override).
    func setValue(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: prefix + key)
    }

    /// Whether the friend-gate feature is enabled. Defaults to `true`.
    var friendGateEnabled: Bool {
        // Key not yet set in UserDefaults → default to true
        if defaults.object(forKey: prefix + "friend_gate_enabled") == nil {
            return true
        }
        return defaults.bool(forKey: prefix + "friend_gate_enabled")
    }
}
