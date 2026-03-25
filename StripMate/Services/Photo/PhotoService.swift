import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

/// Handles photo sending, history listening, comments, and history clearing.
public actor PhotoService {
    public static let shared = PhotoService()
    
    private var auth: Auth { Auth.auth() }
    private var db: Firestore { Firestore.firestore() }
    private var storage: StorageReference { Storage.storage().reference() }
    
    private init() {}
    
    // MARK: - Photo Broadcast
    
    public func fetchStrip(byId stripId: String) async throws -> PhotoMetadata? {
        let doc = try await db.collection("strips").document(stripId).getDocument()
        guard let data = doc.data(),
              let id = data["id"] as? String,
              let senderId = data["senderId"] as? String,
              let receiverIds = data["receiverIds"] as? [String],
              let imageUrl = data["imageUrl"] as? String else { return nil }
        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        return PhotoMetadata(
            id: id,
            senderId: senderId,
            receiverIds: receiverIds,
            imageUrl: imageUrl,
            timestamp: timestamp,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            cityName: data["cityName"] as? String,
                    thumbnailUrl: data["thumbnailUrl"] as? String,
                    smallThumbnailUrl: data["smallThumbnailUrl"] as? String,
            flagged: data["flagged"] as? Bool ?? false,
            flagReason: data["flagReason"] as? String,
            voiceUrl: data["voiceUrl"] as? String,
            isSecret: data["isSecret"] as? Bool ?? false,
            unlockedBy: data["unlockedBy"] as? [String],
            seenBy: data["seenBy"] as? [String]
        )
    }

    public func sendPhoto(_ image: UIImage, to receiverIds: [String], latitude: Double? = nil, longitude: Double? = nil, cityName: String? = nil, voiceData: Data? = nil, isSecret: Bool = false) async throws -> String {
        guard let profile = await AuthService.shared.currentUserProfile else { throw FirebaseError.unauthenticated }
        guard !receiverIds.isEmpty else { throw FirebaseError.compressionFailed }
        guard receiverIds.count <= 50 else {
            throw AppError.custom("Maksimum 50 arkadaşa gönderilebilir.")
        }

        // Normalize orientation to .up before encoding to JPEG
        // This prevents rotated/sideways photos in the feed
        let normalizedImage = image.normalizedOrientation()
        
        // Resize to max 1080p to reduce upload size (~80% smaller)
        let resizedImage = normalizedImage.resizedToMax(dimension: 1080)
        
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.75) else {
            throw FirebaseError.compressionFailed
        }
        
        let photoId = UUID().uuidString
        let storageRef = storage.child("strips/\(photoId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        // Start Live Activity for Dynamic Island progress
        await LiveActivityManager.shared.startUploadActivity(recipientCount: receiverIds.count)
        await LiveActivityManager.shared.updateProgress(0.2)
        
        _ = try await RetryHelper.withRetry(maxAttempts: 2, initialDelay: 1.5) {
            try await storageRef.putDataAsync(imageData, metadata: metadata)
        }
        await LiveActivityManager.shared.updateProgress(0.6)
        
        let downloadURL = try await storageRef.downloadURL()
        await LiveActivityManager.shared.updateProgress(0.8)
        
        // Upload voice recording if present
        var voiceURLString: String?
        if let voiceData {
            let voiceRef = storage.child("voices/\(photoId).m4a")
            let voiceMeta = StorageMetadata()
            voiceMeta.contentType = "audio/mp4"
            _ = try await RetryHelper.withRetry(maxAttempts: 2, initialDelay: 1.5) {
                try await voiceRef.putDataAsync(voiceData, metadata: voiceMeta)
            }
            voiceURLString = try await voiceRef.downloadURL().absoluteString
        }

        var finalReceivers = receiverIds
        if !finalReceivers.contains(profile.id) {
            finalReceivers.append(profile.id)
        }

        var documentData: [String: Any] = [
            "id": photoId,
            "senderId": profile.id,
            "receiverIds": finalReceivers,
            "imageUrl": downloadURL.absoluteString,
            "timestamp": FieldValue.serverTimestamp(),
            "latitude": latitude as Any,
            "longitude": longitude as Any,
            "cityName": cityName as Any
        ]
        if let voiceURLString {
            documentData["voiceUrl"] = voiceURLString
        }
        if isSecret {
            documentData["isSecret"] = true
            documentData["unlockedBy"] = [String]()
        }

        try await db.collection("strips").document(photoId).setData(documentData)
        
        for receiverId in receiverIds where receiverId != profile.id {
            // Gizli anlarda thumbnail gönderme — bildirimde kilit ikonu gösterilecek
            let thumbUrl = isSecret ? nil : downloadURL.absoluteString
            await AppNotificationService.shared.sendInAppNotification(to: receiverId, type: .photoReceived, relatedId: photoId, thumbnailUrl: thumbUrl)
        }
        
        // Complete Live Activity
        await LiveActivityManager.shared.completeUpload()
        
        return photoId
    }
    
    // MARK: - History
    
    public nonisolated func listenToHistory(for userId: String) -> AsyncStream<[PhotoMetadata]> {
        AsyncStream { continuation in
            // Pre-fetch blocked user IDs once; refresh at most every 5 minutes
            var blockedIds: Set<String> = []
            var lastBlockedRefresh: Date = .distantPast
            Task {
                blockedIds = (try? await AuthService.shared.fetchBlockedUserIds()) ?? []
                lastBlockedRefresh = Date()
            }

            let query = Firestore.firestore().collection("strips")
                .whereField("receiverIds", arrayContains: userId)
                .order(by: "timestamp", descending: true)
                .limit(to: 200)

            let listener = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("⚠️ PhotoService.listenToHistory error: \(error.localizedDescription)")
                    #endif
                    return
                }
                guard let documents = snapshot?.documents else {
                    return
                }

                // Refresh blocked IDs at most every 5 minutes
                if Date().timeIntervalSince(lastBlockedRefresh) > 300 {
                    Task {
                        blockedIds = (try? await AuthService.shared.fetchBlockedUserIds()) ?? []
                        lastBlockedRefresh = Date()
                    }
                }
                
                let photos = documents.compactMap { doc -> PhotoMetadata? in
                    let data = doc.data()
                    guard let id = data["id"] as? String,
                          let senderId = data["senderId"] as? String,
                          let receiverIds = data["receiverIds"] as? [String],
                          let imageUrl = data["imageUrl"] as? String else { return nil }
                    // Filter: skip blocked senders and flagged (moderated) strips
                    if blockedIds.contains(senderId) { return nil }
                    if data["flagged"] as? Bool == true { return nil }
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    return PhotoMetadata(
                        id: id,
                        senderId: senderId,
                        receiverIds: receiverIds,
                        imageUrl: imageUrl,
                        timestamp: timestamp,
                        latitude: data["latitude"] as? Double,
                        longitude: data["longitude"] as? Double,
                        cityName: data["cityName"] as? String,
                    thumbnailUrl: data["thumbnailUrl"] as? String,
                    smallThumbnailUrl: data["smallThumbnailUrl"] as? String,
                    flagged: data["flagged"] as? Bool ?? false,
                    flagReason: data["flagReason"] as? String,
                    voiceUrl: data["voiceUrl"] as? String,
                    isSecret: data["isSecret"] as? Bool ?? false,
                    unlockedBy: data["unlockedBy"] as? [String],
                    seenBy: data["seenBy"] as? [String]
                    )
                }.sorted(by: { $0.timestamp > $1.timestamp })
                
                // Determine widget-relevant photo
                let pinnedId = UserDefaults(suiteName: AppConstants.appGroupID)?.string(forKey: "pinned_friend_id")
                let targetPhoto: PhotoMetadata?
                if let pid = pinnedId, !pid.isEmpty {
                    targetPhoto = photos.first(where: { $0.senderId == pid })
                } else {
                    targetPhoto = photos.first(where: { $0.senderId != userId })
                }
                
                // Consolidate all side-effects in a single ordered Task
                let relevantPhoto = targetPhoto
                Task {
                    await CacheService.shared.saveHistoryToCache(photos)
                    if let relevant = relevantPhoto {
                        await CacheService.shared.saveLatestPhotoForWidget(relevant)
                    }
                    await SwiftDataSyncService.shared.syncHistoryToLocal(photos)
                }
                
                continuation.yield(photos)
            }
            
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    // MARK: - Load More (Pagination)
    
    public func loadMoreHistory(for userId: String, before lastTimestamp: Date) async -> [PhotoMetadata] {
        do {
            let blockedIds = (try? await AuthService.shared.fetchBlockedUserIds()) ?? []
            
            let snapshot = try await db.collection("strips")
                .whereField("receiverIds", arrayContains: userId)
                .order(by: "timestamp", descending: true)
                // Note: Using Timestamp cursor; prefer document snapshot cursor for gap-free pagination
                .start(after: [Timestamp(date: lastTimestamp)])
                .limit(to: 30)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> PhotoMetadata? in
                let data = doc.data()
                guard let id = data["id"] as? String,
                      let senderId = data["senderId"] as? String,
                      let receiverIds = data["receiverIds"] as? [String],
                      let imageUrl = data["imageUrl"] as? String else { return nil }
                // Filter: skip blocked senders and flagged (moderated) strips
                if blockedIds.contains(senderId) { return nil }
                if data["flagged"] as? Bool == true { return nil }
                let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                return PhotoMetadata(
                    id: id, senderId: senderId, receiverIds: receiverIds,
                    imageUrl: imageUrl, timestamp: timestamp,
                    latitude: data["latitude"] as? Double,
                    longitude: data["longitude"] as? Double,
                    cityName: data["cityName"] as? String,
                    thumbnailUrl: data["thumbnailUrl"] as? String,
                    smallThumbnailUrl: data["smallThumbnailUrl"] as? String,
                    flagged: data["flagged"] as? Bool ?? false,
                    flagReason: data["flagReason"] as? String,
                    voiceUrl: data["voiceUrl"] as? String,
                    isSecret: data["isSecret"] as? Bool ?? false,
                    unlockedBy: data["unlockedBy"] as? [String],
                    seenBy: data["seenBy"] as? [String]
                )
            }
        } catch {
            #if DEBUG
            print("DEBUG: Failed to load more history: \(error)")
            #endif
            return []
        }
    }
    
    // MARK: - Clear History
    
    /// Permanently deletes a strip (Firestore doc + Storage image + thumbnails).
    /// Only the sender can delete their own strip.
    public func deleteStrip(_ photo: PhotoMetadata) async throws {
        guard let uid = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }
        guard photo.senderId == uid else { throw FirebaseError.unauthenticated }
        
        // 1. Delete Firestore document
        try await db.collection("strips").document(photo.id).delete()
        
        // 2. Delete from Storage (original image)
        let fileName = URL(string: photo.imageUrl)?.lastPathComponent ?? "\(photo.id).jpg"
        let imageRef = storage.child("strips/\(fileName)")
        do { try await imageRef.delete() } catch {
            #if DEBUG
            print("DEBUG: ⚠️ deleteStrip — failed to delete image: \(error.localizedDescription)")
            #endif
        }

        // 3. Delete thumbnails if they exist
        let baseName = (fileName as NSString).deletingPathExtension
        let thumb800 = storage.child("strips/thumbs/\(baseName)_800x800.jpg")
        let thumb200 = storage.child("strips/thumbs/\(baseName)_200x200.jpg")
        do { try await thumb800.delete() } catch {
            #if DEBUG
            print("DEBUG: ⚠️ deleteStrip — failed to delete 800 thumb: \(error.localizedDescription)")
            #endif
        }
        do { try await thumb200.delete() } catch {
            #if DEBUG
            print("DEBUG: ⚠️ deleteStrip — failed to delete 200 thumb: \(error.localizedDescription)")
            #endif
        }

        // 4. Delete chats subcollections (strips/{stripId}/chats/{receiverId}/messages)
        do {
            let chatsSnapshot = try await db.collection("strips").document(photo.id).collection("chats").getDocuments()
            for chatDoc in chatsSnapshot.documents {
                do {
                    let messagesSnapshot = try await chatDoc.reference.collection("messages").getDocuments()
                    let batch = db.batch()
                    for doc in messagesSnapshot.documents { batch.deleteDocument(doc.reference) }
                    try await batch.commit()
                } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ deleteStrip — failed to delete chat messages: \(error.localizedDescription)")
                    #endif
                }
                do { try await chatDoc.reference.delete() } catch {
                    #if DEBUG
                    print("DEBUG: ⚠️ deleteStrip — failed to delete chat doc: \(error.localizedDescription)")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ deleteStrip — failed to fetch chats: \(error.localizedDescription)")
            #endif
        }
        
        // 5. Delete from local SwiftData
        SwiftDataSyncService.shared.deleteStrip(id: photo.id)
    }
    
    public func clearUserHistory() async throws {
        guard let userId = auth.currentUser?.uid else { throw FirebaseError.unauthenticated }

        let snapshot = try await db.collection("strips")
            .whereField("receiverIds", arrayContains: userId)
            .getDocuments()

        // Firestore batch limiti 500 — chunk'lara böl
        let chunks = stride(from: 0, to: snapshot.documents.count, by: 450)
        for chunkStart in chunks {
            let chunkEnd = min(chunkStart + 450, snapshot.documents.count)
            let batch = db.batch()
            for i in chunkStart..<chunkEnd {
                let doc = snapshot.documents[i]
                var receiverIds = doc.data()["receiverIds"] as? [String] ?? []
                receiverIds.removeAll { $0 == userId }

                if receiverIds.isEmpty {
                    batch.deleteDocument(doc.reference)
                } else {
                    batch.updateData(["receiverIds": receiverIds], forDocument: doc.reference)
                }
            }
            try await batch.commit()
        }

        SwiftDataSyncService.shared.clearAllStrips()
    }
    
    // MARK: - Strip Chat (1-on-1 per receiver)
    
    /// Send a chat message under a strip's isolated 1-on-1 channel.
    /// Path: strips/{stripId}/chats/{chatPartnerId}/messages/{messageId}
    /// Upload a chat photo reply to Storage and return the download URL.
    public func uploadChatPhoto(image: UIImage, stripId: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.7) else { throw FirebaseError.compressionFailed }
        let photoId = UUID().uuidString
        let ref = Storage.storage().reference().child("chat_photos/\(stripId)_\(photoId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    public func sendStripChatMessage(text: String, stripId: String, chatPartnerId: String, replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil, voiceUrl: String? = nil, photoReplyUrl: String? = nil) async throws {
        guard let profile = await AuthService.shared.currentUserProfile else { throw FirebaseError.unauthenticated }

        let messageId = UUID().uuidString
        let messageRef = db.collection("strips").document(stripId)
            .collection("chats").document(chatPartnerId)
            .collection("messages").document(messageId)

        var documentData: [String: Any] = [
            "id": messageId,
            "photoId": stripId,
            "senderId": profile.id,
            "text": text,
            "timestamp": FieldValue.serverTimestamp()
        ]

        if let replyToId = replyToId {
            documentData["replyToId"] = replyToId
        }
        if let replyToText = replyToText {
            documentData["replyToText"] = replyToText
        }
        if let replyToSenderId = replyToSenderId {
            documentData["replyToSenderId"] = replyToSenderId
        }
        if let voiceUrl {
            documentData["voiceUrl"] = voiceUrl
        }
        if let photoReplyUrl {
            documentData["photoReplyUrl"] = photoReplyUrl
        }

        try await messageRef.setData(documentData)
        
        // Send in-app notification to the chat partner
        let photoDoc: DocumentSnapshot?
        do {
            photoDoc = try await db.collection("strips").document(stripId).getDocument()
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ sendStripChatMessage — failed to fetch strip for notification: \(error.localizedDescription)")
            #endif
            photoDoc = nil
        }
        if let photoData = photoDoc?.data() {
            let isStripSecret = photoData["isSecret"] as? Bool ?? false
            let thumbnailUrl = isStripSecret ? nil : (photoData["imageUrl"] as? String)
            await AppNotificationService.shared.sendInAppNotification(to: chatPartnerId, type: .commentReceived, relatedId: stripId, thumbnailUrl: thumbnailUrl)
        }
    }
    
    /// Listen to an isolated 1-on-1 chat channel under a strip.
    /// Path: strips/{stripId}/chats/{chatPartnerId}/messages
    public nonisolated func listenToStripChat(stripId: String, chatPartnerId: String) -> AsyncStream<[Comment]> {
        AsyncStream { continuation in
            let query = Firestore.firestore()
                .collection("strips").document(stripId)
                .collection("chats").document(chatPartnerId)
                .collection("messages")
                .order(by: "timestamp", descending: false)
            
            let listener = query.addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    continuation.yield([])
                    return
                }
                
                let messages = documents.compactMap { doc -> Comment? in
                    let data = doc.data()
                    guard let id = data["id"] as? String,
                          let pid = data["photoId"] as? String,
                          let senderId = data["senderId"] as? String,
                          let text = data["text"] as? String else { return nil }
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let reactions = data["reactions"] as? [String: String]

                    // Parse stickers: { userId: { url: "...", mediaId: "..." } }
                    var stickers: [String: StickerAttachment]?
                    if let rawStickers = data["stickers"] as? [String: [String: String]] {
                        var parsed: [String: StickerAttachment] = [:]
                        for (userId, stickerData) in rawStickers {
                            if let url = stickerData["url"], let mediaId = stickerData["mediaId"] {
                                parsed[userId] = StickerAttachment(url: url, mediaId: mediaId)
                            }
                        }
                        if !parsed.isEmpty { stickers = parsed }
                    }

                    return Comment(
                        id: id, photoId: pid, senderId: senderId, text: text, timestamp: timestamp,
                        replyToId: data["replyToId"] as? String,
                        replyToText: data["replyToText"] as? String,
                        replyToSenderId: data["replyToSenderId"] as? String,
                        reactions: reactions,
                        voiceUrl: data["voiceUrl"] as? String,
                        stickers: stickers,
                        photoReplyUrl: data["photoReplyUrl"] as? String
                    )
                }
                
                continuation.yield(messages)
            }
            
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    // MARK: - Strip Chat Reactions

    /// Add an emoji reaction to a strip chat message.
    public func addStripChatReaction(stripId: String, chatPartnerId: String, messageId: String, emoji: String) async {
        guard let profile = await AuthService.shared.currentUserProfile else { return }
        let ref = db.collection("strips").document(stripId)
            .collection("chats").document(chatPartnerId)
            .collection("messages").document(messageId)
        do {
            try await ref.updateData(["reactions.\(profile.id)": emoji])
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ Failed to add strip chat reaction: \(error.localizedDescription)")
            #endif
        }
    }

    /// Remove an emoji reaction from a strip chat message.
    public func removeStripChatReaction(stripId: String, chatPartnerId: String, messageId: String) async {
        guard let profile = await AuthService.shared.currentUserProfile else { return }
        let ref = db.collection("strips").document(stripId)
            .collection("chats").document(chatPartnerId)
            .collection("messages").document(messageId)
        do {
            try await ref.updateData(["reactions.\(profile.id)": FieldValue.delete()])
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ Failed to remove strip chat reaction: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Strip Chat Stickers

    /// Add an animated sticker to a strip chat message (GIPHY).
    public func addStickerToMessage(stripId: String, chatPartnerId: String, messageId: String, url: String, mediaId: String) async {
        guard let profile = await AuthService.shared.currentUserProfile else { return }
        let ref = db.collection("strips").document(stripId)
            .collection("chats").document(chatPartnerId)
            .collection("messages").document(messageId)
        do {
            try await ref.updateData([
                "stickers.\(profile.id)": ["url": url, "mediaId": mediaId]
            ])
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ Failed to add sticker: \(error.localizedDescription)")
            #endif
        }
    }

    /// Remove a sticker from a strip chat message.
    public func removeStickerFromMessage(stripId: String, chatPartnerId: String, messageId: String) async {
        guard let profile = await AuthService.shared.currentUserProfile else { return }
        let ref = db.collection("strips").document(stripId)
            .collection("chats").document(chatPartnerId)
            .collection("messages").document(messageId)
        do {
            try await ref.updateData(["stickers.\(profile.id)": FieldValue.delete()])
        } catch {
            #if DEBUG
            print("DEBUG: ⚠️ Failed to remove sticker: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Seen By

    /// Mark a strip as "seen" by the current user using Firestore arrayUnion.
    public func markStripAsSeen(stripId: String) async {
        guard let profile = await AuthService.shared.currentUserProfile else { return }
        let ref = db.collection("strips").document(stripId)
        do {
            try await ref.updateData([
                "seenBy": FieldValue.arrayUnion([profile.id])
            ])
        } catch {
            #if DEBUG
            print("DEBUG: Failed to mark strip as seen: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Photo Reactions

    /// Toggle an emoji reaction on a strip photo.
    /// If the user already reacted with this emoji, remove it. Otherwise, add it.
    public func toggleReaction(on photoId: String, emoji: String) async throws {
        guard let profile = await AuthService.shared.currentUserProfile else { throw FirebaseError.unauthenticated }
        let stripRef = db.collection("strips").document(photoId)
        
        _ = try await db.runTransaction { transaction, errorPointer in
            let stripDoc: DocumentSnapshot
            do {
                stripDoc = try transaction.getDocument(stripRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let data = stripDoc.data() else { return nil }
            var reactions = data["reactions"] as? [String: [String]] ?? [:]

            if let existingEmoji = reactions.first(where: { $0.value.contains(profile.id) })?.key {
                reactions[existingEmoji]?.removeAll { $0 == profile.id }
                if reactions[existingEmoji]?.isEmpty == true {
                    reactions.removeValue(forKey: existingEmoji)
                }
                if existingEmoji == emoji {
                    transaction.updateData(["reactions": reactions], forDocument: stripRef)
                    return nil
                }
            }

            reactions[emoji, default: []].append(profile.id)
            transaction.updateData(["reactions": reactions], forDocument: stripRef)
            return nil
        }
    }
}
