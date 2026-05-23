import WidgetKit
import SwiftUI
import CoreLocation

struct PhotoEntry: TimelineEntry, Sendable {
    let date: Date
    let image: UIImage?
    let cityName: String?
    let latitude: Double?
    let longitude: Double?
}

// Modern Concurrency Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: Date(), image: nil, cityName: nil, latitude: nil, longitude: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (PhotoEntry) -> ()) {
        let entry = PhotoEntry(date: Date(), image: UIImage(systemName: "photo.fill"), cityName: "Muğla", latitude: nil, longitude: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhotoEntry>) -> ()) {
        Task {
            let (image, cityName, lat, lon) = await fetchLatestPhoto()
            let currentDate = Date()

            let sharedDefaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
            sharedDefaults?.set(currentDate.timeIntervalSince1970, forKey: "widget_last_timeline")
            sharedDefaults?.synchronize()

            // Push-driven widget: the WidgetKit push from Cloud Functions is the
            // primary refresh trigger. The timeline itself only needs a single
            // entry; a short `.after` policy acts as a safety net in case a push
            // is missed (device offline, APNs drop, etc.). 15 min gives enough
            // coverage without wasting iOS widget refresh budget.
            let entry = PhotoEntry(date: currentDate, image: image, cityName: cityName, latitude: lat, longitude: lon)
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
            completion(timeline)
        }
    }
    
    private func fetchLatestPhoto() async -> (UIImage?, String?, Double?, Double?) {
        let groupID = "group.V99XFMU3L7.com.celalbasaran.stripmate"
        let sharedDefaults = UserDefaults(suiteName: groupID)
        let cityName = sharedDefaults?.string(forKey: "latest_photo_city")

        // Read lat/lon — only use if key actually exists (double returns 0 for missing keys)
        let lat: Double? = sharedDefaults?.object(forKey: "latest_photo_lat") as? Double
        let lon: Double? = sharedDefaults?.object(forKey: "latest_photo_lon") as? Double

        // Metadata timestamp from NSE
        let photoTime = sharedDefaults?.double(forKey: "latest_photo_time") ?? 0

        // 1. Try local shared file (cached by NSE or main app)
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            let fileURL = containerURL.appendingPathComponent("latest_widget_image.jpg")
            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileDate = attrs[.modificationDate] as? Date,
               // Only use file if it's recent enough (not stale from old session)
               fileDate.timeIntervalSince1970 >= photoTime - 5,
               let data = try? Data(contentsOf: fileURL),
               let image = UIImage(data: data) {
                return (image.downsampled(maxDimension: 512), cityName, lat, lon)
            }
        }

        // 2. Fallback: download from URL (thumbnail preferred for speed)
        let urlString = sharedDefaults?.string(forKey: "latest_thumbnail_url")
            ?? sharedDefaults?.string(forKey: "latest_photo_url")
        guard let urlStr = urlString, !urlStr.isEmpty,
              let url = URL(string: urlStr) else {
            return (nil, cityName, lat, lon)
        }

        do {
            // Use ephemeral session to avoid cache staleness
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForResource = 15
            let session = URLSession(configuration: config)
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else { return (nil, cityName, lat, lon) }

            // Save downloaded image to shared container for next time
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
                let fileURL = containerURL.appendingPathComponent("latest_widget_image.jpg")
                try? data.write(to: fileURL, options: .atomic)
            }

            return (image.downsampled(maxDimension: 512), cityName, lat, lon)
        } catch {
            return (nil, cityName, lat, lon)
        }
    }
}

// Sub-zero minimalist, edge-to-edge UI
struct StripMateWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall, .systemLarge, .systemExtraLarge:
            photoWidget
        case .systemMedium:
            mediumWidget
        case .accessoryRectangular:
            lockScreenRectangular
        case .accessoryCircular:
            lockScreenCircular
        default:
            photoWidget
        }
    }
    
    // MARK: - Photo Widget (Small/Large/ExtraLarge)
    
    private var photoWidget: some View {
        ZStack {
            if let image = entry.image {
                // Edge-to-edge photo — frameless
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                
                // Subtle gradient vignette at top for legibility
                VStack {
                    LinearGradient(
                        colors: [.black.opacity(0.35), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 50)
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
                
                // Brand watermark — top right
                VStack {
                    HStack {
                        Spacer()
                        Text("anlık.")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 10)
                        .padding(.trailing, 12)
                    }
                    Spacer()
                }
                
                // Location info — bottom left, minimal
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if let city = entry.cityName {
                                Text(city)
                                    .font(.system(size: 10, weight: .semibold, design: .default))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            if let lat = entry.latitude, let lon = entry.longitude {
                                let dist = calculateDistance(toLat: lat, toLon: lon)
                                if !dist.isEmpty {
                                    Text(dist)
                                        .font(.system(size: 9, weight: .medium, design: .default))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }
                        .padding(.leading, 12)
                        .padding(.bottom, 10)
                        Spacer()
                    }
                }
            } else {
                // Premium Empty State
                ZStack {
                    Color.black
                    VStack(spacing: 6) {
                        Text("anlık.")
                            .font(.system(size: 24, weight: .bold, design: .default))
                            .foregroundColor(.white.opacity(0.2))
                        Text("bir fotoğraf bekleniyor")
                            .font(.system(size: 10, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.12))
                            .tracking(1)
                    }
                }
            }
        }
        // Modern iOS 17+ requirement to rip out default widget margins
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "stripmate://camera"))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.image != nil ? "anlık — \(entry.cityName ?? "bir arkadaştan fotoğraf")" : "anlık — bir fotoğraf bekleniyor")
    }
    
    // MARK: - Medium Widget (Photo + Info side by side)
    
    private var mediumWidget: some View {
        ZStack {
            if let image = entry.image {
                HStack(spacing: 0) {
                    // Left: photo
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                    
                    // Right: info panel
                    VStack(alignment: .leading, spacing: 8) {
                        Text("anlık.")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        if let city = entry.cityName {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 10))
                                Text(city)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if let lat = entry.latitude, let lon = entry.longitude {
                            let dist = calculateDistance(toLat: lat, toLon: lon)
                            if !dist.isEmpty {
                                Text(dist)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        
                        Text(entry.date, style: .relative)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .padding(14)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .leading)
                    .background(Color.black)
                }
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Text("anlık.")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white.opacity(0.2))
                        Text("bir fotoğraf bekleniyor")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.12))
                            .tracking(1)
                    }
                    Spacer()
                }
                .background(Color.black)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "stripmate://camera"))
    }
    
    // MARK: - Lock Screen Rectangular
    
    private var lockScreenRectangular: some View {
        HStack(spacing: 8) {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(Image(systemName: "camera").font(.system(size: 14)).foregroundStyle(.white.opacity(0.5)))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("anlık.")
                    .font(.system(size: 13, weight: .bold))
                if let city = entry.cityName {
                    Text(city)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "stripmate://camera"))
    }
    
    // MARK: - Lock Screen Circular
    
    private var lockScreenCircular: some View {
        ZStack {
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(.white.opacity(0.15))
                    .overlay(
                        Text("a.")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    )
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(URL(string: "stripmate://camera"))
    }
    
    private func calculateDistance(toLat: Double, toLon: Double) -> String {
        // Must match AppConstants.appGroupID in main app target
        let sharedDefaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
        guard let userLat = sharedDefaults?.object(forKey: "user_last_lat") as? Double,
              let userLon = sharedDefaults?.object(forKey: "user_last_lon") as? Double,
              userLat != 0, userLon != 0,
              toLat != 0, toLon != 0 else {
            return ""
        }
        
        let userLocation = CLLocation(latitude: userLat, longitude: userLon)
        let photoLocation = CLLocation(latitude: toLat, longitude: toLon)
        let distanceMeters = userLocation.distance(from: photoLocation)
        
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters))m uzakta"
        } else {
            let km = distanceMeters / 1000.0
            return String(format: "%.0f km uzakta", km)
        }
    }
}

// Custom Ext to downsample the high resolution iOS camera output
extension UIImage {
    func downsampled(maxDimension: CGFloat) -> UIImage? {
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        
        let scaleRate = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scaleRate, height: size.height * scaleRate)
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0 // Render physically at precise pixels requested
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Widget Push Handler

struct StripMatePushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        // Convert raw APNs token to hex string
        let tokenString = pushInfo.token.map { String(format: "%02x", $0) }.joined()

        // Save to shared UserDefaults so main app can upload to Firestore
        let sharedDefaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
        sharedDefaults?.set(tokenString, forKey: "widget_push_token")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "widget_push_token_time")
        sharedDefaults?.set(tokenString.count, forKey: "widget_push_token_len")
        sharedDefaults?.synchronize()
    }
}

// Widget Configuration
struct StripMateWidget: Widget {
    let kind: String = "StripMateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StripMateWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("anlık.")
        .description("Arkadaşlarından gelen en son fotoğrafı ana ekranında gör.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
        .pushHandler(StripMatePushHandler.self)
    }
}

