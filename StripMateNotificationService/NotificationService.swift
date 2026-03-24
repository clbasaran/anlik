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

        // Save metadata immediately so widget can use URL fallback
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

        // Reload widget immediately with metadata (URL fallback available)
        WidgetCenter.shared.reloadTimelines(ofKind: "StripMateWidget")

        // Try to download image for local cache + notification attachment
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
