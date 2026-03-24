import WidgetKit
import SwiftUI

// MARK: - Streak Complication

struct StreakComplicationEntry: TimelineEntry {
    let date: Date
    let topStreakCount: Int
    let topFriendName: String
    let tierEmoji: String
    let activeStreakCount: Int
    let expiringCount: Int
}

struct StreakComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakComplicationEntry {
        StreakComplicationEntry(date: Date(), topStreakCount: 7, topFriendName: "Arkadaş", tierEmoji: "💜", activeStreakCount: 3, expiringCount: 0)
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
        let defaults = UserDefaults.standard
        return StreakComplicationEntry(
            date: Date(),
            topStreakCount: defaults.integer(forKey: "watch_top_streak"),
            topFriendName: defaults.string(forKey: "watch_top_streak_friend") ?? "",
            tierEmoji: defaults.string(forKey: "watch_top_streak_emoji") ?? "🌱",
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
                    Text("🔥")
                        .font(.system(size: 14))
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
                Text(entry.topStreakCount > 0 ? "🔥" : "🌱")
                    .font(.system(size: 18))
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
                    Text("\(entry.activeStreakCount) aktif seri")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                if entry.expiringCount > 0 {
                    HStack(spacing: 2) {
                        Text("⏳")
                            .font(.system(size: 8))
                        Text("\(entry.expiringCount) bitiyor")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.orange)
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
            Text("🔥 anlık.")
        }
        .containerBackground(for: .widget) { Color.clear }
    }
    
    // MARK: - Inline
    
    private var inlineView: some View {
        Text("🔥 \(entry.topStreakCount) gün · \(entry.activeStreakCount) seri")
            .containerBackground(for: .widget) { Color.clear }
    }
}

struct StreakComplication: Widget {
    let kind = "StreakComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakComplicationProvider()) { entry in
            StreakComplicationView(entry: entry)
        }
        .configurationDisplayName("Seri Takibi")
        .description("En yüksek serini ve aktif seri sayını göster.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

// MARK: - Daily Prompt Complication

struct PromptComplicationEntry: TimelineEntry {
    let date: Date
    let promptText: String
    let emoji: String
    let isCompleted: Bool
}

struct PromptComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> PromptComplicationEntry {
        PromptComplicationEntry(date: Date(), promptText: "anını yakala", emoji: "📸", isCompleted: false)
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
        let defaults = UserDefaults.standard
        return PromptComplicationEntry(
            date: Date(),
            promptText: defaults.string(forKey: "watch_prompt_text") ?? "anını yakala",
            emoji: defaults.string(forKey: "watch_prompt_emoji") ?? "📸",
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
                    Text(entry.emoji)
                        .font(.system(size: 16))
                    if entry.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                    } else {
                        Text("görev")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
            }
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(URL(string: "stripmate://watch/prompt"))
            
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Text(entry.emoji)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("günün görevi")
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
            Text("\(entry.emoji) \(entry.promptText)")
                .containerBackground(for: .widget) { Color.clear }
            
        default:
            Text(entry.emoji)
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
        .configurationDisplayName("Günün Görevi")
        .description("Günlük fotoğraf görevini saat yüzeyinde gör.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
