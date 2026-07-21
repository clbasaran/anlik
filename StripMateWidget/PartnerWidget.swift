import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Partner Widget ("1:1 modu")
//
// A widget pinned to ONE chosen friend: it always shows that friend's latest
// moment, unaffected by photos arriving from anyone else. This is the app's
// answer to sparse friend graphs — with a single close person (partner, best
// friend, family) the home screen still stays alive.
//
// Data contract (App Group):
// - "widget_friends" (Data, JSON [[id,name]]): accepted friends, written by
//   SwiftDataSyncService on every friends sync — feeds the picker.
// - "partner_<id>.jpg" (file): that friend's latest photo, written by the NSE
//   on each new_strip push from them.
// - "partner_<id>_ts" (Double) / "partner_<id>_name" (String): freshness + name.

private let partnerAppGroupID = "group.V99XFMU3L7.com.celalbasaran.stripmate"

// MARK: - Friend entity for the configuration picker

struct WidgetFriendEntity: AppEntity, Identifiable, Hashable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "arkadaş")
    static let defaultQuery = WidgetFriendQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static func loadAll() -> [WidgetFriendEntity] {
        guard let defaults = UserDefaults(suiteName: partnerAppGroupID),
              let data = defaults.data(forKey: "widget_friends"),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            return []
        }
        return list.compactMap { dict in
            guard let id = dict["id"], let name = dict["name"] else { return nil }
            return WidgetFriendEntity(id: id, name: name)
        }
    }
}

struct WidgetFriendQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetFriendEntity] {
        WidgetFriendEntity.loadAll().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WidgetFriendEntity] {
        WidgetFriendEntity.loadAll()
    }

    func defaultResult() async -> WidgetFriendEntity? {
        WidgetFriendEntity.loadAll().first
    }
}

// MARK: - Configuration intent

struct SelectPartnerIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "arkadaş seç"
    static let description = IntentDescription("bu widget'ın takip edeceği kişi.")

    @Parameter(title: "arkadaş")
    var friend: WidgetFriendEntity?
}

// MARK: - Timeline

struct PartnerEntry: TimelineEntry {
    let date: Date
    let friendName: String?
    let image: UIImage?
    let photoDate: Date?
}

struct PartnerProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PartnerEntry {
        PartnerEntry(date: Date(), friendName: nil, image: nil, photoDate: nil)
    }

    func snapshot(for configuration: SelectPartnerIntent, in context: Context) async -> PartnerEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectPartnerIntent, in context: Context) async -> Timeline<PartnerEntry> {
        let e = entry(for: configuration)
        // Push-driven via NSE reloads; 30 min is only the safety net.
        return Timeline(entries: [e], policy: .after(Date().addingTimeInterval(30 * 60)))
    }

    private func entry(for configuration: SelectPartnerIntent) -> PartnerEntry {
        guard let friend = configuration.friend else {
            return PartnerEntry(date: Date(), friendName: nil, image: nil, photoDate: nil)
        }
        var image: UIImage?
        var photoDate: Date?
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: partnerAppGroupID) {
            let fileURL = containerURL.appendingPathComponent("partner_\(friend.id).jpg")
            if let data = try? Data(contentsOf: fileURL) {
                image = UIImage(data: data)
            }
        }
        if let defaults = UserDefaults(suiteName: partnerAppGroupID) {
            let ts = defaults.double(forKey: "partner_\(friend.id)_ts")
            if ts > 0 { photoDate = Date(timeIntervalSince1970: ts) }
        }
        return PartnerEntry(date: Date(), friendName: friend.name, image: image, photoDate: photoDate)
    }
}

// MARK: - View

struct PartnerWidgetEntryView: View {
    var entry: PartnerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)

                // Legibility scrim + name/time footer
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        if let name = entry.friendName {
                            Text(name.lowercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let photoDate = entry.photoDate, family != .systemSmall {
                            Text(photoDate, style: .relative)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
            } else {
                // Monochrome placeholder — same language as the main widget.
                VStack(spacing: 6) {
                    Image(systemName: entry.friendName == nil ? "person.crop.circle.badge.questionmark" : "camera")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(entry.friendName.map { "\($0.lowercased()) henüz an göndermedi" } ?? "bir arkadaş seç")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(8)
            }
        }
        .containerBackground(for: .widget) { Color.black }
    }
}

// MARK: - Widget

struct PartnerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "PartnerWidget",
            intent: SelectPartnerIntent.self,
            provider: PartnerProvider()
        ) { entry in
            PartnerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("bir kişi")
        .description("seçtiğin arkadaşın son anı — sadece o.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
