import WidgetKit
import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Timeline Entry
struct QRCodeEntry: TimelineEntry {
    let date: Date
    let inviteCode: String?
    let displayName: String?
    let username: String?
}

// MARK: - Timeline Provider
struct QRCodeProvider: TimelineProvider {
    private let sharedDefaults = UserDefaults(suiteName: "group.V99XFMU3L7.com.celalbasaran.stripmate")
    
    func placeholder(in context: Context) -> QRCodeEntry {
        QRCodeEntry(date: Date(), inviteCode: "ABCD1234", displayName: "anlık.", username: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QRCodeEntry) -> ()) {
        let entry = QRCodeEntry(
            date: Date(),
            inviteCode: sharedDefaults?.string(forKey: "user_invite_code") ?? "ABCD1234",
            displayName: sharedDefaults?.string(forKey: "user_display_name"),
            username: sharedDefaults?.string(forKey: "user_username")
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<QRCodeEntry>) -> ()) {
        let code = sharedDefaults?.string(forKey: "user_invite_code")
        let name = sharedDefaults?.string(forKey: "user_display_name")
        let username = sharedDefaults?.string(forKey: "user_username")
        
        let entry = QRCodeEntry(date: Date(), inviteCode: code, displayName: name, username: username)
        // QR code rarely changes — refresh every 30 minutes
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

// MARK: - QR Code Generator
private func generateQRCode(from string: String, size: CGFloat = 200) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    
    guard let output = filter.outputImage else { return nil }
    
    let scale = size / output.extent.width
    let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    
    let context = CIContext(options: [.useSoftwareRenderer: false])
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

// MARK: - Widget View
struct QRCodeWidgetEntryView: View {
    var entry: QRCodeProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        default:
            smallWidget
        }
    }
    
    // MARK: - Small (QR only)
    private var smallWidget: some View {
        ZStack {
            Color.black
            
            if let code = entry.inviteCode, let qrImage = generateQRCode(from: code, size: 200) {
                VStack(spacing: 6) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    Text("anlık.")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(12)
            } else {
                noAccountView
            }
        }
        .containerBackground(for: .widget) { Color.black }
    }
    
    // MARK: - Medium (QR + info)
    private var mediumWidget: some View {
        ZStack {
            Color.black
            
            if let code = entry.inviteCode, let qrImage = generateQRCode(from: code, size: 200) {
                HStack(spacing: 16) {
                    // QR Code
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("anlık.")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        if let name = entry.displayName {
                            Text(name)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        
                        if let username = entry.username {
                            Text("@\(username)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(code)
                            .font(.system(size: 16, design: .monospaced).weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .tracking(2)
                        
                        Text("beni eklemek için tara")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.vertical, 4)
                    
                    Spacer()
                }
                .padding(16)
            } else {
                noAccountView
            }
        }
        .containerBackground(for: .widget) { Color.black }
    }
    
    // MARK: - Large (QR + full info)
    private var largeWidget: some View {
        ZStack {
            Color.black
            
            if let code = entry.inviteCode, let qrImage = generateQRCode(from: code, size: 300) {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("anlık.")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                        Text("qr kodun")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.2))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    
                    Spacer()
                    
                    // QR Code
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Info
                    VStack(spacing: 6) {
                        if let name = entry.displayName {
                            Text(name)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        if let username = entry.username {
                            Text("@\(username)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        Text(code)
                            .font(.system(size: 22, design: .monospaced).weight(.heavy))
                            .foregroundStyle(.white)
                            .tracking(4)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    Text("arkadaşın bu kodu tarayarak seni ekleyebilir")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            } else {
                noAccountView
            }
        }
        .containerBackground(for: .widget) { Color.black }
    }
    
    // MARK: - No Account View
    private var noAccountView: some View {
        VStack(spacing: 8) {
            Image(systemName: "qrcode")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.white.opacity(0.2))
            Text("giriş yap")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

// MARK: - Widget Configuration
struct QRCodeWidget: Widget {
    let kind: String = "QRCodeWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QRCodeProvider()) { entry in
            QRCodeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("qr kodun")
        .description("Arkadaşlarının seni kolayca eklemesi için QR kodunu ana ekranına koy.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    QRCodeWidget()
} timeline: {
    QRCodeEntry(date: .now, inviteCode: "ABCD1234", displayName: "Celal", username: "celal")
}

#Preview(as: .systemMedium) {
    QRCodeWidget()
} timeline: {
    QRCodeEntry(date: .now, inviteCode: "ABCD1234", displayName: "Celal", username: "celal")
}

#Preview(as: .systemLarge) {
    QRCodeWidget()
} timeline: {
    QRCodeEntry(date: .now, inviteCode: "ABCD1234", displayName: "Celal", username: "celal")
}
