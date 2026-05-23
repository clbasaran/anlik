import Foundation

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
            return "az once"
        } else if minutes < 60 {
            return "\(minutes) dk"
        } else if hours < 24 {
            return "\(hours) sa"
        } else if days == 1 {
            return "dun"
        } else if days < 7 {
            return "\(days) gün önce"
        } else if weeks == 1 {
            return "1 hf once"
        } else if weeks < 4 {
            return "\(weeks) hf once"
        } else {
            return formatted(date)
        }
    }

    private static func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
