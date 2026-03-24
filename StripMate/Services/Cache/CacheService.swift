import Foundation
import FirebaseAuth
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Handles all caching: JSON history cache, widget data sharing via App Group.
public actor CacheService {
    public static let shared = CacheService()
    
    private let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupID)
    public var lastHistory: [PhotoMetadata] = []
    
    private init() {}
    
    // MARK: - JSON History Cache
    
    private var cacheURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)?
            .appendingPathComponent("history_cache.json")
    }
    
    public func saveHistoryToCache(_ photos: [PhotoMetadata]) {
        self.lastHistory = photos
        guard let url = cacheURL else { return }
        do {
            let data = try JSONEncoder().encode(photos)
            try data.write(to: url)
        } catch {
            #if DEBUG
            print("DEBUG: Failed to save history cache: \(error)")
            #endif
        }
    }
    
    public func loadHistoryFromCache() -> [PhotoMetadata] {
        guard let url = cacheURL, FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([PhotoMetadata].self, from: data)
        } catch {
            #if DEBUG
            print("DEBUG: Failed to load history cache: \(error)")
            #endif
            return []
        }
    }
    
    // MARK: - Widget Data Sharing
    
    public func downloadAndSaveForWidget(urlString: String, stripId: String, cityName: String?, lat: Double?, lon: Double?, thumbnailUrl: String? = nil) async {
        // Prefer thumbnail for widget (smaller file = faster load + less memory)
        let downloadUrlString = thumbnailUrl ?? urlString
        guard let url = URL(string: downloadUrlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID) {
                let fileURL = containerURL.appendingPathComponent("latest_widget_image.jpg")
                try? data.write(to: fileURL, options: .atomic)
            }
            
            sharedDefaults?.set(urlString, forKey: "latest_photo_url")
            sharedDefaults?.set(thumbnailUrl, forKey: "latest_thumbnail_url")
            sharedDefaults?.set(stripId, forKey: "latest_photo_id")
            sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "latest_photo_time")
            
            // Konum bilgisi: nil ise key'i temizle, var ise kaydet
            if let lat = lat, lat != 0 {
                sharedDefaults?.set(lat, forKey: "latest_photo_lat")
            } else {
                sharedDefaults?.removeObject(forKey: "latest_photo_lat")
            }
            
            if let lon = lon, lon != 0 {
                sharedDefaults?.set(lon, forKey: "latest_photo_lon")
            } else {
                sharedDefaults?.removeObject(forKey: "latest_photo_lon")
            }
            
            if let cityName = cityName, !cityName.isEmpty {
                sharedDefaults?.set(cityName, forKey: "latest_photo_city")
            } else {
                sharedDefaults?.removeObject(forKey: "latest_photo_city")
            }
            
            // Force sync to disk before widget reads
            sharedDefaults?.synchronize()
            
            #if !WIDGET
            WidgetCenter.shared.reloadAllTimelines()
            WidgetReloadThrottle.shared.recordDirectReload()
            #endif
            
            #if DEBUG
            print("DEBUG: Successfully saved photo to App Group for widget.")
            #endif
        } catch {
            #if DEBUG
            print("DEBUG: Failed to download and save for widget: \(error.localizedDescription)")
            #endif
        }
    }
    
    public func refreshWidgetFromHistory() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        let pinnedId = sharedDefaults?.string(forKey: "pinned_friend_id")
        let targetPhoto: PhotoMetadata?
        
        if let pid = pinnedId, !pid.isEmpty {
            targetPhoto = lastHistory.first(where: { $0.senderId == pid })
        } else {
            targetPhoto = lastHistory.first(where: { $0.senderId != currentUid })
        }
        
        if let relevant = targetPhoto {
            saveLatestPhotoForWidget(relevant)
        }
    }
    
    public func saveLatestPhotoForWidget(_ photo: PhotoMetadata) {
        let pinnedId = sharedDefaults?.string(forKey: "pinned_friend_id")
        
        if let pinnedId = pinnedId, !pinnedId.isEmpty {
            guard photo.senderId == pinnedId else { return }
        }
        
        if let currentUid = Auth.auth().currentUser?.uid {
            guard photo.senderId != currentUid else { return }
        }
        
        Task {
            await downloadAndSaveForWidget(
                urlString: photo.imageUrl,
                stripId: photo.id,
                cityName: photo.cityName,
                lat: photo.latitude,
                lon: photo.longitude,
                thumbnailUrl: photo.thumbnailUrl
            )
            
            // Also send thumbnail to Apple Watch
            await sendPhotoToWatch(photo)
        }
    }
    
    /// Downloads a small thumbnail and sends it to the Apple Watch.
    private func sendPhotoToWatch(_ photo: PhotoMetadata) async {
        let urlString = photo.smallThumbnailUrl ?? photo.thumbnailUrl ?? photo.imageUrl
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            WatchSessionManager.shared.sendPhotoThumbnail(data, photoId: photo.id)
        } catch {
            #if DEBUG
            print("DEBUG: Failed to send photo to watch: \(error)")
            #endif
        }
    }
}
