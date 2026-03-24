import Foundation
import ActivityKit

/// Attributes for the photo upload Live Activity (Dynamic Island)
struct PhotoUploadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var progress: Double  // 0.0 ... 1.0
        var status: UploadStatus
        
        enum UploadStatus: String, Codable, Hashable {
            case uploading = "yükleniyor"
            case processing = "işleniyor"
            case completed = "gönderildi"
            case failed = "başarısız"
        }
    }
    
    var recipientCount: Int
    var photoTimestamp: Date
}
