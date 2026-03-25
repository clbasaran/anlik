import UserNotifications
import WidgetKit
import SwiftUI

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private let appGroupID = "group.V99XFMU3L7.com.celalbasaran.stripmate"

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = bestAttemptContent.userInfo
        let type = userInfo["type"] as? String ?? ""

        // Set category for inline reply action
        switch type {
        case "new_strip", "new_strip_chat":
            bestAttemptContent.categoryIdentifier = "strip_chat"
        case "direct_message":
            bestAttemptContent.categoryIdentifier = "direct_message"
        default:
            break
        }

        // Only process image download for new_strip
        guard type == "new_strip" else {
            contentHandler(bestAttemptContent)
            return
        }

        let isSecret = (userInfo["isSecret"] as? String) == "true"

        // Collect all image URLs from payload
        let smallThumbnailUrl = userInfo["smallThumbnailUrl"] as? String ?? ""
        let thumbnailUrl = userInfo["thumbnailUrl"] as? String ?? ""
        let fullImageUrl = userInfo["imageUrl"] as? String ?? ""

        // Pick best URL for download (smallest first for speed)
        let imageUrl: String = {
            for url in [smallThumbnailUrl, thumbnailUrl, fullImageUrl] {
                if !url.isEmpty { return url }
            }
            return ""
        }()

        let stripId = userInfo["stripId"] as? String ?? ""
        let cityName = userInfo["cityName"] as? String
        let lat = Double(userInfo["latitude"] as? String ?? "")
        let lon = Double(userInfo["longitude"] as? String ?? "")

        // Gizli anlarda widget'a görsel kaydetme
        if !isSecret {
            let sharedDefaults = UserDefaults(suiteName: appGroupID)
            saveMetadata(
                to: sharedDefaults,
                urlString: fullImageUrl,
                thumbnailUrlString: thumbnailUrl.isEmpty ? smallThumbnailUrl : thumbnailUrl,
                stripId: stripId,
                cityName: cityName,
                lat: lat,
                lon: lon
            )
        }

        // Reload widget
        WidgetCenter.shared.reloadTimelines(ofKind: "StripMateWidget")

        // Gizli an → kilit ikonlu placeholder görsel oluştur
        if isSecret {
            if let lockImage = generateSecretLockImage() {
                attachImage(data: lockImage, to: bestAttemptContent)
            }
            contentHandler(bestAttemptContent)
            return
        }

        // Normal an → fotoğrafı indir ve ekle
        guard !imageUrl.isEmpty, let url = URL(string: imageUrl) else {
            contentHandler(bestAttemptContent)
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config)

        Task {
            do {
                let (data, _) = try await session.data(from: url)

                // Save to shared container for widget
                if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                    let fileURL = containerURL.appendingPathComponent("latest_widget_image.jpg")
                    try? data.write(to: fileURL, options: .atomic)
                }

                // Reload widget again with local image available
                WidgetCenter.shared.reloadTimelines(ofKind: "StripMateWidget")

                // Attach image to notification for rich preview
                attachImage(data: data, to: bestAttemptContent)
            } catch {}

            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        WidgetCenter.shared.reloadTimelines(ofKind: "StripMateWidget")
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - Helpers

    private func saveMetadata(to defaults: UserDefaults?, urlString: String, thumbnailUrlString: String = "", stripId: String, cityName: String?, lat: Double?, lon: Double?) {
        guard let defaults = defaults else { return }

        if !urlString.isEmpty {
            defaults.set(urlString, forKey: "latest_photo_url")
        }
        if !thumbnailUrlString.isEmpty {
            defaults.set(thumbnailUrlString, forKey: "latest_thumbnail_url")
        } else if !urlString.isEmpty {
            defaults.set(urlString, forKey: "latest_thumbnail_url")
        }
        defaults.set(stripId, forKey: "latest_photo_id")
        defaults.set(Date().timeIntervalSince1970, forKey: "latest_photo_time")

        if let lat = lat, lat != 0 {
            defaults.set(lat, forKey: "latest_photo_lat")
        } else {
            defaults.removeObject(forKey: "latest_photo_lat")
        }

        if let lon = lon, lon != 0 {
            defaults.set(lon, forKey: "latest_photo_lon")
        } else {
            defaults.removeObject(forKey: "latest_photo_lon")
        }

        if let cityName = cityName, !cityName.isEmpty {
            defaults.set(cityName, forKey: "latest_photo_city")
        } else {
            defaults.removeObject(forKey: "latest_photo_city")
        }

        defaults.synchronize()
    }

    /// Gizli an bildirimi için kilit ikonlu placeholder görsel oluşturur
    private func generateSecretLockImage() -> Data? {
        let size = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Koyu gradient arka plan
            let colors = [UIColor(white: 0.08, alpha: 1).cgColor, UIColor(white: 0.15, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])

            // Kilit ikonu (SF Symbol)
            let lockConfig = UIImage.SymbolConfiguration(pointSize: 60, weight: .medium)
            if let lockSymbol = UIImage(systemName: "lock.fill", withConfiguration: lockConfig) {
                let tinted = lockSymbol.withTintColor(UIColor(white: 0.4, alpha: 1), renderingMode: .alwaysOriginal)
                let iconSize = tinted.size
                let iconOrigin = CGPoint(x: (size.width - iconSize.width) / 2, y: (size.height - iconSize.height) / 2 - 20)
                tinted.draw(at: iconOrigin)
            }

            // "gizli an" yazısı
            let text = "gizli an"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor(white: 0.5, alpha: 1)
            ]
            let textSize = (text as NSString).size(withAttributes: attrs)
            let textOrigin = CGPoint(x: (size.width - textSize.width) / 2, y: size.height / 2 + 30)
            (text as NSString).draw(at: textOrigin, withAttributes: attrs)
        }
        return image.jpegData(compressionQuality: 0.8)
    }

    @discardableResult
    private func attachImage(data: Data, to content: UNMutableNotificationContent) -> Bool {
        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent("\(UUID().uuidString).jpg")
        do {
            try data.write(to: fileURL)
            let attachment = try UNNotificationAttachment(identifier: "image", url: fileURL)
            content.attachments = [attachment]
            return true
        } catch {
            return false
        }
    }
}
