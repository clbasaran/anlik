import WidgetKit
import SwiftUI

// MARK: - Streak Complication

struct StreakComplicationEntry: TimelineEntry {
    let date: Date
    let topStreakCount: Int
    let topFriendName: String
    /// SF Symbol identifier for the friendship tier (e.g. `leaf.fill`).
    /// Render with `Image(systemName:)`, never `Text`.
    let tierSymbol: String
    let activeStreakCount: Int
    let expiringCount: Int
}

struct StreakComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakComplicationEntry {
        StreakComplicationEntry(date: Date(), topStreakCount: 7, topFriendName: String(localized: "watch.friend.placeholder"), tierSymbol: "heart.fill", activeStreakCount: 3, expiringCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakComplicationEntry) -> ()) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakComplicationEntry>) -> ()) {
        let entry = currentEntry()
        // Refresh every 15 minutes; real updates come via WidgetCenter.reloadAllTimelines()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> StreakComplicationEntry {
        let defaults = WatchAppGroup.defaults
        return StreakComplicationEntry(
            date: Date(),
            topStreakCount: defaults.integer(forKey: "watch_top_streak"),
            topFriendName: defaults.string(forKey: "watch_top_streak_friend") ?? "",
            tierSymbol: defaults.string(forKey: "watch_top_streak_symbol") ?? "leaf.fill",
            activeStreakCount: defaults.integer(forKey: "watch_active_streak_count"),
            expiringCount: defaults.integer(forKey: "watch_expiring_count")
        )
    }
}

struct StreakComplicationView: View {
    var entry: StreakComplicationEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }
    
    // MARK: - Circular

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 1) {
                if entry.topStreakCount > 0 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                    Text("\(entry.topStreakCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                } else {
                    Text("anlık")
                        .font(.system(size: 9, weight: .bold))
                    Text(".")
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "stripmate://watch/streaks"))
    }

    // MARK: - Rectangular

    private var rectangularView: some View {
        HStack(spacing: 6) {
            VStack(spacing: 0) {
                Image(systemName: entry.topStreakCount > 0 ? "flame.fill" : "leaf.fill")
                    .font(.system(size: 16))
                Text("\(entry.topStreakCount)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 2) {
                if !entry.topFriendName.isEmpty {
                    Text(entry.topFriendName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }

                if entry.activeStreakCount > 0 {
                    Text("\(entry.activeStreakCount) \(String(localized: "watch.count.active_suffix")) \(String(localized: "watch.count.streak_suffix"))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if entry.expiringCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 8))
                        Text("\(entry.expiringCount) \(String(localized: "watch.count.expiring_suffix"))")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(WatchBrand.textSecondary)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "stripmate://watch/streaks"))
    }

    // MARK: - Corner

    private var cornerView: some View {
        ZStack {
            Text("\(entry.topStreakCount)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .widgetLabel {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                Text("anlık.")
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: - Inline

    private var inlineView: some View {
        // accessoryInline cannot render Image+Text composite, so use SF Symbol
        // unicode via systemImage Label (WidgetKit handles it on the lockscreen).
        Label(
            "\(entry.topStreakCount) \(String(localized: "watch.count.day_suffix")) · \(entry.activeStreakCount) \(String(localized: "watch.count.streak_suffix"))",
            systemImage: "flame.fill"
        )
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct StreakComplication: Widget {
    let kind = "StreakComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakComplicationProvider()) { entry in
            StreakComplicationView(entry: entry)
        }
        .configurationDisplayName(String(localized: "watch.complication.streak.name"))
        .description(String(localized: "watch.complication.streak.description"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: - Daily Prompt Complication

struct PromptComplicationEntry: TimelineEntry {
    let date: Date
    let promptText: String
    let isCompleted: Bool
}

struct PromptComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptComplicationEntry {
        PromptComplicationEntry(date: Date(), promptText: String(localized: "watch.prompt.fallback"), isCompleted: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (PromptComplicationEntry) -> ()) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PromptComplicationEntry>) -> ()) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> PromptComplicationEntry {
        let defaults = WatchAppGroup.defaults
        return PromptComplicationEntry(
            date: Date(),
            promptText: defaults.string(forKey: "watch_prompt_text") ?? String(localized: "watch.prompt.fallback"),
            isCompleted: defaults.bool(forKey: "watch_prompt_completed")
        )
    }
}

struct PromptComplicationView: View {
    var entry: PromptComplicationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                    if entry.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(WatchBrand.success)
                    } else {
                        Text(String(localized: "watch.complication.prompt.short"))
                            .font(.system(size: 8, weight: .bold))
                    }
                }
            }
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "stripmate://watch/prompt"))

        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "watch.prompt.header"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(entry.promptText)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(2)
                }
            }
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "stripmate://watch/prompt"))

        case .accessoryInline:
            Label(entry.promptText, systemImage: "lightbulb.fill")
                .containerBackground(for: .widget) { Color.clear }

        default:
            Image(systemName: "lightbulb.fill")
                .containerBackground(for: .widget) { Color.clear }
        }
    }
}

struct PromptComplication: Widget {
    let kind = "PromptComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PromptComplicationProvider()) { entry in
            PromptComplicationView(entry: entry)
        }
        .configurationDisplayName(String(localized: "watch.complication.prompt.name"))
        .description(String(localized: "watch.complication.prompt.description"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Latest Photo Complication

/// Surfaces the most recent received photo on the watch face. The image bytes
/// live at `WatchAppGroup.latestPhotoURL` (written by PhoneSessionManager when
/// iPhone pushes a thumbnail). Metadata (sender name, city, timestamp) is
/// mirrored into the shared UserDefaults by `WatchDataStore`.
struct PhotoComplicationEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
    let senderName: String
    let cityName: String
    let photoDate: Date?
}

struct PhotoComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> PhotoComplicationEntry {
        PhotoComplicationEntry(
            date: Date(),
            image: nil,
            senderName: String(localized: "watch.friend.placeholder"),
            cityName: "",
            photoDate: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PhotoComplicationEntry) -> ()) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhotoComplicationEntry>) -> ()) {
        // Push refresh comes from WidgetCenter.reloadAllTimelines() in
        // WatchDataStore; the 30-min safety net just keeps the watch face
        // alive if no new photo arrives.
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> PhotoComplicationEntry {
        let defaults = WatchAppGroup.defaults
        var image: UIImage? = nil
        if let url = WatchAppGroup.latestPhotoURL,
           FileManager.default.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
        return PhotoComplicationEntry(
            date: Date(),
            image: image,
            senderName: defaults.string(forKey: "watch_latest_photo_sender") ?? "",
            cityName: defaults.string(forKey: "watch_latest_photo_city") ?? "",
            photoDate: defaults.object(forKey: "watch_latest_photo_time") as? Date
        )
    }
}

struct PhotoComplicationView: View {
    var entry: PhotoComplicationEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    // MARK: - Circular (small round slot — fits a thumbnail only)

    private var circularView: some View {
        ZStack {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                AccessoryWidgetBackground()
                Image(systemName: "camera.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "stripmate://watch/photo"))
    }

    // MARK: - Rectangular (thumbnail + sender + timestamp)

    private var rectangularView: some View {
        HStack(spacing: 6) {
            // Square thumbnail
            Group {
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.white.opacity(0.1)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 1) {
                if !entry.senderName.isEmpty {
                    Text(entry.senderName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                } else {
                    Text("anlık.")
                        .font(.system(size: 12, weight: .bold))
                }

                if let photoDate = entry.photoDate {
                    Text(photoDate, style: .relative)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !entry.cityName.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "mappin")
                            .font(.system(size: 8))
                        Text(entry.cityName)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "stripmate://watch/photo"))
    }

    // MARK: - Inline (single line of text on watch face)

    private var inlineView: some View {
        // accessoryInline can't render images — fall back to a brand + sender line.
        Label(
            entry.senderName.isEmpty ? "anlık." : entry.senderName,
            systemImage: "camera.fill"
        )
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct PhotoComplication: Widget {
    let kind = "PhotoComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhotoComplicationProvider()) { entry in
            PhotoComplicationView(entry: entry)
        }
        .configurationDisplayName(String(localized: "watch.complication.photo.name"))
        .description(String(localized: "watch.complication.photo.description"))
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
