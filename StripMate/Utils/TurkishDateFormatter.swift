import Foundation

/// Compact relative-time strings for chat bubbles, friends list, and inbox.
///
/// Historically hardcoded Turkish (hence the name, kept for call-site
/// stability). The copy now goes through the string catalog: Turkish output is
/// byte-identical to the original voice ("az once", "2 dk", "dun"), while other
/// locales get real translations instead of raw Turkish.
enum TurkishDateFormatter {

    // MARK: - Public API

    /// Short relative time string for chat bubbles (e.g. "az once", "2 dk", "dun").
    static func shortRelative(from date: Date) -> String {
        relativeString(from: date)
    }

    /// Alias used by friends list and inbox views.
    static func timeAgo(from date: Date) -> String {
        relativeString(from: date)
    }

    // MARK: - Private

    private static func relativeString(from date: Date) -> String {
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))

        guard seconds >= 0 else { return formatted(date) }

        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7

        if seconds < 60 {
            return String(localized: "az once")
        } else if minutes < 60 {
            return String(localized: "\(minutes) dk")
        } else if hours < 24 {
            return String(localized: "\(hours) sa")
        } else if days == 1 {
            return String(localized: "dun")
        } else if days < 7 {
            return String(localized: "\(days) gün önce")
        } else if weeks == 1 {
            return String(localized: "1 hf once")
        } else if weeks < 4 {
            return String(localized: "\(weeks) hf once")
        } else {
            return formatted(date)
        }
    }

    private static func formatted(_ date: Date) -> String {
        // Locale-aware "12 Tem" / "Jul 12" style — follows the user's language.
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}
