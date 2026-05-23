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

    /// Active Firestore listener registrations, keyed so we can deduplicate when
    /// the same logical stream is requested twice (e.g. rapid view re-appear)
    /// and so we can forcibly remove them all on logout.
    /// Keys are like "history:<uid>" or "stripChat:<stripId>:<partnerId>".
    private var activeListeners: [String: ListenerRegistration] = [:]

    /// Registers a Firestore listener under a logical key. If a listener already
    /// exists for the key, it is removed first — guarantees one live listener
    /// per (user, channel) at any time.
    func registerListener(_ reg: ListenerRegistration, key: String) {
        activeListeners[key]?.remove()
        activeListeners[key] = reg
    }

    /// Unregisters a listener by key (called from AsyncStream onTermination).
    /// Idempotent — safe to call multiple times.
    func unregisterListener(key: String) {
        activeListeners[key]?.remove()
        activeListeners[key] = nil
    }

    /// Removes all active listeners. Called on logout.
    public func stopAllListeners() {
        activeListeners.values.forEach { $0.remove() }
        activeListeners.removeAll()
    }

    private init() {}
    
    // MARK: - Photo Broadcast
    
    public func fetchStrip(byId stripId: String) async throws -> PhotoMetadata? {
        let doc = try await db.collection("strips").document(stripId).getDocument()
        guard let data = doc.data() else { return nil }
        return PhotoMetadata.from(data)
    }

    public func sendPhoto(_ image: UIImage, to receiverIds: [String], latitude: Double? = nil, longitude: Double? = nil, cityName: String? = nil, voiceData: Data? = nil, isSecret: Bool = false, videoFileURL: URL? = nil, videoDuration: Double? = nil) async throws -> String {
        CrashReporter.shared.breadcrumb(.camera, "sendPhoto receivers=\(receiverIds.count) hasVoice=\(voiceData != nil) hasVideo=\(videoFileURL != nil) isSecret=\(isSecret)")
        guard let profile = await AuthService.shared.currentUserProfile else { throw FirebaseError.unauthenticated }
        guard !receiverIds.isEmpty else { throw FirebaseError.noReceivers }
        guard receiverIds.count <= 50 else {
            throw AppError.custom("Maksimum 50 arkadaşa gönderilebilir.")
        }

        // Validate that all receivers are accepted friends of the sender
        let friends = try await FriendshipService.shared.fetchFriends()
        let acceptedFriendIds = Set(friends.filter { !$0.isPending }.map(\.userId))
        let nonFriendIds = receiverIds.filter { $0 != profile.id && !acceptedFriendIds.contains($0) }
        guard nonFriendIds.isEmpty else {
            throw AppError.custom("Sadece arkadaşlarına gönderebilirsin.")
        }

        // Normalize orientation to .up before encoding to JPEG
        // This prevents rotated/sideways photos in the feed
        let normalizedImage = image.normalizedOrientation()
        
        // Resize to max 1440p for higher quality uploads (~1.5 MB)
        let resizedImage = normalizedImage.resizedToMax(dimension: 1440)

        let quality = NetworkMonitor.shared.recommendedJPEGQuality
        guard let imageData = resizedImage.jpegData(compressionQuality: quality) else {
            throw FirebaseError.compressionFailed
        }
        
        let photoId = "\(profile.id)_\(UUID().uuidString)"
        let storageRef = storage.child("strips/\(photoId).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // Start Live Activity for Dynamic Island progress
        await LiveActivityManager.shared.startUploadActivity(recipientCount: receiverIds.count)
        await LiveActivityManager.shared.updateProgress(0.2)

        // Saga: track every Storage upload that succeeded so we can roll them
        // back if a later step (voice, video, Firestore write) fails. Without
        // this, a partial send leaves orphan blobs in Storage that the user
        // ends up paying for and that nothing ever references.
        var uploadedRefs: [StorageReference] = []

        do {
            do {
                _ = try await RetryHelper.withRetry(maxAttempts: 2, initialDelay: 1.5) {
                    try await storageRef.putDataAsync(imageData, metadata: metadata)
                }
            } catch {
                CrashReporter.shared.breadcrumb(.camera, "image upload failed: \(error.localizedDescription)")
                throw AppError.custom(String(localized: "fotoğraf yüklenemedi. internet bağlantını kontrol et."))
            }
            uploadedRefs.append(storageRef)
            await LiveActivityManager.shared.updateProgress(0.6)

            let downloadURL = try await storageRef.downloadURL()
            await LiveActivityManager.shared.updateProgress(0.8)

            // Upload voice recording if present
            var voiceURLString: String?
            if let voiceData {
                let voiceRef = storage.child("voices/\(photoId).m4a")
                let voiceMeta = StorageMetadata()
                voiceMeta.contentType = "audio/mp4"
                do {
                    _ = try await RetryHelper.withRetry(maxAttempts: 2, initialDelay: 1.5) {
                        try await voiceRef.putDataAsync(voiceData, metadata: voiceMeta)
                    }
                    uploadedRefs.append(voiceRef)
                    voiceURLString = try await voiceRef.downloadURL().absoluteString
                } catch {
                    CrashReporter.shared.breadcrumb(.camera, "voice upload failed: \(error.localizedDescription)")
                    throw AppError.custom(String(localized: "sesli yorum yüklenemedi. tekrar dene."))
                }
            }

            // Upload video if present (stream from file to avoid loading into memory)
            var videoUrlString: String? = nil
            if let videoFileURL {
                // Verify video file still exists before attempting upload — iOS
                // can clear the temporary directory between sessions, leading
                // to a confusing failure mid-upload.
                guard FileManager.default.fileExists(atPath: videoFileURL.path) else {
                    CrashReporter.shared.breadcrumb(.camera, "video file missing path=\(videoFileURL.lastPathComponent)")
                    throw AppError.custom(String(localized: "video dosyası bulunamadı. lütfen tekrar çek."))
                }
                let videoRef = Storage.storage().reference().child("strips/videos/\(photoId).mp4")
                let videoMeta = StorageMetadata()
                videoMeta.contentType = "video/mp4"
                do {
                    _ = try await RetryHelper.withRetry(maxAttempts: 2, initialDelay: 1.5) {
                        try await videoRef.putFileAsync(from: videoFileURL, metadata: videoMeta)
                    }
                    uploadedRefs.append(videoRef)
                    videoUrlString = try await videoRef.downloadURL().absoluteString
                } catch {
                    CrashReporter.shared.breadcrumb(.camera, "video upload failed: \(error.localizedDescription)")
                    throw AppError.custom(String(localized: "video yüklenemedi. internet bağlantını kontrol et."))
                }
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
            if let videoUrlString {
                documentData["videoUrl"] = videoUrlString
            }
            if let videoDuration {
                documentData["videoDuration"] = videoDuration
            }
            // Per-user retention preference. -1 sentinel = "kalıcı" (never auto-delete);
            // any positive integer = days; missing field = default 30 (cleanup cron's fallback).
            // Read from UserDefaults so users can change it under Settings without
            // a per-send selector cluttering the UI.
            let retention = UserDefaults.standard.object(forKey: "default_retention_days") as? Int
            if let retention, retention != 30 {
                documentData["retentionDays"] = retention
            }
            // The Firestore write is the commit point. Failure here also rolls
            // back the upload(s) above so we don't leave a dangling photo.
            // Atomic batch — strip doc + sender's stripCount counter must rise
            // together so the automation engine never sees a strip whose author
            // hasn't been credited yet.
            let batch = db.batch()
            batch.setData(documentData, forDocument: db.collection("strips").document(photoId))
            batch.updateData(
                ["stripCount": FieldValue.increment(Int64(1))],
                forDocument: db.collection("users").document(profile.id)
            )
            try await batch.commit()

            for receiverId in receiverIds where receiverId != profile.id {
                // Gizli anlarda thumbnail gönderme — bildirimde kilit ikonu gösterilecek
                let thumbUrl = isSecret ? nil : downloadURL.absoluteString
                await AppNotificationService.shared.sendInAppNotification(to: receiverId, type: .photoReceived, relatedId: photoId, thumbnailUrl: thumbUrl)
            }

            // Complete Live Activity
            await LiveActivityManager.shared.completeUpload()
            CrashReporter.shared.setCustomValue("success", forKey: CrashReporter.Key.lastUploadOutcome)

            return photoId
        } catch {
            // Best-effort rollback: delete every Storage object we already
            // uploaded for this photoId. We swallow individual delete errors —
            // re-throwing them would mask the original failure the user cares
            // about. Server-side TTL cleanup is the safety net if delete fails.
            CrashReporter.shared.breadcrumb(.camera, "sendPhoto rollback uploadedRefs=\(uploadedRefs.count)")
            CrashReporter.shared.setCustomValue("failed", forKey: CrashReporter.Key.lastUploadOutcome)
            for ref in uploadedRefs {
                do {
                    try await ref.delete()
                } catch {
                    AppLogger.service.error("orphan storage cleanup failed path=\(ref.fullPath, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            await LiveActivityManager.shared.failUpload()
            throw error
        }
    }
    
    // MARK: - History
    
    public nonisolated func listenToHistory(for userId: String) -> AsyncStream<[PhotoMetadata]> {
        AsyncStream { continuation in
            // Pre-fetch blocked user IDs once; refresh at most every 5 minutes.
            // Fail-closed semantics: if the fetch errors out we fall back to the
            // last known set persisted in App Group UserDefaults instead of an
            // empty set — otherwise a transient network blip would let a freshly
            // blocked user reappear in the feed.
            let blockedLock = NSLock()
            var blockedIds: Set<String> = []
            var lastBlockedRefresh: Date = .distantPast
            Task {
                let ids: Set<String>
                do {
                    ids = try await AuthService.shared.fetchBlockedUserIds()
                } catch {
                    AppLogger.service.error("listenToHistory blocked-list cold fetch failed; using persisted cache: \(error.localizedDescription, privacy: .public)")
                    ids = await AuthService.shared.bestKnownBlockedUserIds()
                }
                blockedLock.lock()
                blockedIds = ids
                lastBlockedRefresh = Date()
                blockedLock.unlock()
            }

            let query = Firestore.firestore().collection("strips")
                .whereField("receiverIds", arrayContains: userId)
                .order(by: "timestamp", descending: true)

            let listener = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    AppLogger.service.error("listenToHistory failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                guard let documents = snapshot?.documents else {
                    return
                }

                // Refresh blocked IDs at most every 5 minutes
                blockedLock.lock()
                let needsRefresh = Date().timeIntervalSince(lastBlockedRefresh) > 300
                let currentBlockedIds = blockedIds
                blockedLock.unlock()

                if needsRefresh {
                    Task {
                        let ids: Set<String>
                        do {
                            ids = try await AuthService.shared.fetchBlockedUserIds()
                        } catch {
                            // Refresh failure: keep using the last known good set.
                            // Don't reset blockedIds — that would temporarily clear
                            // the filter until the next refresh window opens.
                            AppLogger.service.error("listenToHistory blocked-list refresh failed; keeping previous set: \(error.localizedDescription, privacy: .public)")
                            ids = await AuthService.shared.bestKnownBlockedUserIds()
                        }
                        blockedLock.lock()
                        blockedIds = ids
                        lastBlockedRefresh = Date()
                        blockedLock.unlock()
                    }
                }
                
                let photos = documents.compactMap { doc -> PhotoMetadata? in
                    let data = doc.data()
                    // Filter: skip blocked senders and flagged (moderated) strips
                    if let senderId = data["senderId"] as? String, currentBlockedIds.contains(senderId) { return nil }
                    if data["flagged"] as? Bool == true { return nil }
                    return PhotoMetadata.from(data)
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
            
            // Register listener on the actor with a per-user key. If a previous
            // listener exists for this user it gets replaced (idempotent), and
            // logout can forcibly stop everything via stopAllListeners().
            let listenerKey = "history:\(userId)"
            Task { await PhotoService.shared.registerListener(listener, key: listenerKey) }

            continuation.onTermination = { @Sendable _ in
                listener.remove()
                Task { await PhotoService.shared.unregisterListener(key: listenerKey) }
            }
        }
    }

    // MARK: - Load More (Pagination)
    
    /// Last document snapshot from the most recent pagination query, used for gap-free cursor-based pagination.
    private var lastPaginationDocument: DocumentSnapshot?

    /// Resets the pagination cursor. Call on logout or when history needs a full refresh.
    public func resetPagination() {
        lastPaginationDocument = nil
    }

    public func loadMoreHistory(for userId: String, before lastTimestamp: Date) async -> [PhotoMetadata] {
        do {
            // Mirror the fail-closed behaviour from listenToHistory: never fall
            // back to an empty blocked set on fetch failure or a freshly
            // blocked user can leak in via the loadMore page.
            let blockedIds: Set<String>
            do {
                blockedIds = try await AuthService.shared.fetchBlockedUserIds()
            } catch {
                AppLogger.service.error("loadMoreHistory blocked-list fetch failed; using persisted cache: \(error.localizedDescription, privacy: .public)")
                blockedIds = await AuthService.shared.bestKnownBlockedUserIds()
            }

            var query = db.collection("strips")
                .whereField("receiverIds", arrayContains: userId)
                .order(by: "timestamp", descending: true)

            // Use document snapshot cursor for gap-free pagination when available
            if let lastDoc = lastPaginationDocument {
                query = query.start(afterDocument: lastDoc)
            } else {
                query = query.start(after: [Timestamp(date: lastTimestamp)])
            }

            let snapshot = try await query
                .limit(to: 50)
                .getDocuments()

            // Store the last document for the next pagination call
            lastPaginationDocument = snapshot.documents.last
            
            return snapshot.documents.compactMap { doc -> PhotoMetadata? in
                let data = doc.data()
                // Filter: skip blocked senders and flagged (moderated) strips
                if let senderId = data["senderId"] as? String, blockedIds.contains(senderId) { return nil }
                if data["flagged"] as? Bool == true { return nil }
                return PhotoMetadata.from(data)
            }
        } catch {
            AppLogger.service.error("loadMoreHistory failed: \(error.localizedDescription, privacy: .public)")
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
            AppLogger.service.warning("[PhotoService] failed to delete image: \(String(describing: error), privacy: .public)")
        }

        // 3. Delete thumbnails if they exist
        let baseName = (fileName as NSString).deletingPathExtension
        let thumb800 = storage.child("strips/thumbs/\(baseName)_800x800.jpg")
        let thumb200 = storage.child("strips/thumbs/\(baseName)_200x200.jpg")
        do { try await thumb800.delete() } catch {
            AppLogger.service.warning("[PhotoService] failed to delete 800 thumb: \(String(describing: error), privacy: .public)")
        }
        do { try await thumb200.delete() } catch {
            AppLogger.service.warning("[PhotoService] failed to delete 200 thumb: \(String(describing: error), privacy: .public)")
        }

        // 4. Delete video file if it exists
        if photo.isVideo {
            let videoFileName = "\(photo.id).mp4"
            let videoRef = storage.child("strips/videos/\(videoFileName)")
            do { try await videoRef.delete() } catch {
                AppLogger.service.warning("[PhotoService] failed to delete video: \(String(describing: error), privacy: .public)")
            }
        }

        // 5. Delete chats subcollections (strips/{stripId}/chats/{receiverId}/messages)
        do {
            let chatsSnapshot = try await db.collection("strips").document(photo.id).collection("chats").getDocuments()
            for chatDoc in chatsSnapshot.documents {
                do {
                    let messagesSnapshot = try await chatDoc.reference.collection("messages").getDocuments()
                    let batch = db.batch()
                    for doc in messagesSnapshot.documents { batch.deleteDocument(doc.reference) }
                    try await batch.commit()
                } catch {
                    AppLogger.service.warning("[PhotoService] failed to delete chat messages: \(String(describing: error), privacy: .public)")
                }
                do { try await chatDoc.reference.delete() } catch {
                    AppLogger.service.warning("[PhotoService] failed to delete chat doc: \(String(describing: error), privacy: .public)")
                }
            }
        } catch {
            AppLogger.service.warning("[PhotoService] failed to fetch chats: \(String(describing: error), privacy: .public)")
        }
        
        // 6. Delete from local SwiftData
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
        guard let uid = Auth.auth().currentUser?.uid else { throw FirebaseError.unauthenticated }
        let photoId = UUID().uuidString
        let ref = Storage.storage().reference().child("chat_photos/\(uid)_\(stripId)_\(photoId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    public func sendStripChatMessage(text: String, stripId: String, chatPartnerId: String, clientId: String? = nil, replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil, voiceUrl: String? = nil, photoReplyUrl: String? = nil) async throws {
        CrashReporter.shared.breadcrumb(.chat, "sendStripChatMessage len=\(text.count) hasVoice=\(voiceUrl != nil) hasPhoto=\(photoReplyUrl != nil)")
        guard let profile = await AuthService.shared.currentUserProfile else { throw FirebaseError.unauthenticated }

        // Check for banned words
        if let bannedWord = await AppGuardService.shared.containsBannedWord(text) {
            throw AppError.custom("Mesajınız uygunsuz içerik barındırıyor: \"\(bannedWord)\"")
        }

        guard text.count <= 2000 else {
            throw AppError.custom("Mesaj çok uzun. Maksimum 2000 karakter.")
        }

        // Reuse the optimistically-rendered id when the caller provides one so
        // the listener's emission overwrites the placeholder by id.
        let messageId = clientId ?? UUID().uuidString
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
            AppLogger.service.error("sendStripChatMessage strip fetch failed: \(error.localizedDescription, privacy: .public)")
            photoDoc = nil
        }
        if let photoData = photoDoc?.data() {
            let isStripSecret = photoData["isSecret"] as? Bool ?? false
            let thumbnailUrl = isStripSecret ? nil : (photoData["imageUrl"] as? String)
            // Determine the correct notification recipient:
            // If I'm the photo sender → notify chatPartnerId (the receiver)
            // If I'm a receiver → notify the photo sender
            let stripSenderId = photoData["senderId"] as? String
            let notifyUserId: String
            if profile.id == stripSenderId {
                notifyUserId = chatPartnerId
            } else {
                notifyUserId = stripSenderId ?? chatPartnerId
            }
            await AppNotificationService.shared.sendInAppNotification(to: notifyUserId, type: .commentReceived, relatedId: stripId, thumbnailUrl: thumbnailUrl)
        }
    }
    
    /// Listen to an isolated 1-on-1 chat channel under a strip.
    /// Path: strips/{stripId}/chats/{chatPartnerId}/messages
    public nonisolated func listenToStripChat(stripId: String, chatPartnerId: String) -> AsyncStream<[Comment]> {
        AsyncStream { continuation in
            // Strip chats are 1-on-1; if the chatPartnerId is in our blocked
            // set we never attach the Firestore listener at all. Yield empty
            // and finish — the chat sheet shouldn't have been opened anyway,
            // but this stops the data path from leaking content from a blocked
            // peer if the UI guard is missed.
            Task {
                let blockedIds = await AuthService.shared.bestKnownBlockedUserIds()
                if blockedIds.contains(chatPartnerId) {
                    continuation.yield([])
                    continuation.finish()
                    return
                }

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

                // Track this listener so logout cleanup hits it. Key includes both
                // ids so the same user can subscribe to multiple strip chats.
                let listenerKey = "stripChat:\(stripId):\(chatPartnerId)"
                await PhotoService.shared.registerListener(listener, key: listenerKey)

                continuation.onTermination = { @Sendable _ in
                    listener.remove()
                    Task { await PhotoService.shared.unregisterListener(key: listenerKey) }
                }
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
            AppLogger.service.error("strip chat reaction add failed: \(error.localizedDescription, privacy: .public)")
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
            AppLogger.service.error("strip chat reaction remove failed: \(error.localizedDescription, privacy: .public)")
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
            AppLogger.service.error("sticker add failed: \(error.localizedDescription, privacy: .public)")
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
            AppLogger.service.error("sticker remove failed: \(error.localizedDescription, privacy: .public)")
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
            AppLogger.service.error("markStripAsSeen failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Photo Reactions

    /// Toggle an emoji reaction on a strip photo.
    /// If the user already reacted with this emoji, remove it. Otherwise, add it.
    public func toggleReaction(on photoId: String, emoji: String) async throws {
        guard let profile = await AuthService.shared.currentUserProfile else { throw FirebaseError.unauthenticated }
        let stripRef = db.collection("strips").document(photoId)

        // Capture state across the transaction so we can decide whether the
        // toggle was an "add" (notify owner) vs "remove" (silent).
        nonisolated(unsafe) var didAddReaction = false
        nonisolated(unsafe) var stripOwnerId: String? = nil
        nonisolated(unsafe) var stripThumbnailUrl: String? = nil

        _ = try await db.runTransaction { transaction, errorPointer in
            let stripDoc: DocumentSnapshot
            do {
                stripDoc = try transaction.getDocument(stripRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let data = stripDoc.data() else { return nil }
            stripOwnerId = data["senderId"] as? String
            stripThumbnailUrl = (data["smallThumbnailUrl"] as? String)
                ?? (data["thumbnailUrl"] as? String)
                ?? (data["imageUrl"] as? String)
            var reactions = data["reactions"] as? [String: [String]] ?? [:]

            if let existingEmoji = reactions.first(where: { $0.value.contains(profile.id) })?.key {
                reactions[existingEmoji]?.removeAll { $0 == profile.id }
                if reactions[existingEmoji]?.isEmpty == true {
                    reactions.removeValue(forKey: existingEmoji)
                }
                if existingEmoji == emoji {
                    // Pure remove → don't notify
                    transaction.updateData(["reactions": reactions], forDocument: stripRef)
                    return nil
                }
            }

            reactions[emoji, default: []].append(profile.id)
            didAddReaction = true
            transaction.updateData(["reactions": reactions], forDocument: stripRef)
            return nil
        }

        // Drop a notification on the strip owner so reactions show up in their
        // Bildirimler tab (activity feed). Self-react is a no-op inside the
        // service; double-toggle of the same emoji is a remove and skipped above.
        if didAddReaction, let ownerId = stripOwnerId, ownerId != profile.id {
            await AppNotificationService.shared.sendInAppNotification(
                to: ownerId,
                type: .reactionReceived,
                relatedId: photoId,
                thumbnailUrl: stripThumbnailUrl
            )
        }
    }
}
