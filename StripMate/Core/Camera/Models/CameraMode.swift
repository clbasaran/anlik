import Foundation

/// Top-level capture mode picked by the user via the bottom mode picker.
/// Video lives inside `.foto` as a long-press affordance — there is no
/// separate "video" mode (matches the existing finger-on-shutter ritual).
public enum CameraMode: String, CaseIterable, Identifiable, Sendable {
    case foto
    case kolaj

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .foto:  return "foto"
        case .kolaj: return "kolaj"
        }
    }
}

/// Self-timer setting for the shutter. 0 = off.
public enum CameraTimer: Int, CaseIterable, Identifiable, Sendable {
    case off = 0
    case three = 3
    case ten = 10

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .off:   return "kapalı"
        case .three: return "3sn"
        case .ten:   return "10sn"
        }
    }

    /// SF Symbol shown in the tool cluster.
    public var icon: String {
        switch self {
        case .off:   return "timer"
        case .three: return "3.circle.fill"
        case .ten:   return "10.circle.fill"
        }
    }

    public func next() -> CameraTimer {
        switch self {
        case .off:   return .three
        case .three: return .ten
        case .ten:   return .off
        }
    }
}
