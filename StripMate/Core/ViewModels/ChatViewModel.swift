import Foundation
import SwiftUI

@MainActor
@Observable
public final class ChatViewModel {
    public let stripId: String
    public let chatPartnerId: String
    public var messages: [Comment] = []
    public var inputText: String = ""
    public var isLoading = true
    public var errorMessage: String?
    public var currentUserId: String?

    // Reply state
    public var replyingTo: Comment?

    // Offline queue for strip chat messages
    public struct PendingMessage: Identifiable {
        public let id = UUID().uuidString
        let text: String
        let replyToId: String?
        let replyToText: String?
        let replyToSenderId: String?
    }
    public var pendingMessages: [PendingMessage] = []

    /// Prevents duplicate send taps while a message is in flight
    public var isSending = false

    /// Prevent duplicate listeners. The generation counter guards against an
    /// older listener's late yields or its exit handler overwriting newer state
    /// when the view rapidly disappears and reappears. Task lives in an
    /// `IsolatedRef` so the nonisolated `deinit` can cancel without
    /// `nonisolated(unsafe)`.
    private let listenerTask = IsolatedRef<Task<Void, Never>?>(nil)
    private var isListening = false
    private var listeningGeneration: Int = 0
    private let deps = DependencyContainer.shared

    /// New initializer: requires stripId and the chat partner's userId.
    public init(stripId: String, chatPartnerId: String) {
        self.stripId = stripId
        self.chatPartnerId = chatPartnerId
    }

    deinit {
        listenerTask.value?.cancel()
    }

    public func listenToMessages() async {
        // Always cancel-and-replace rather than gating on isListening. The old
        // task may still be unwinding (its exit handler hasn't run yet), so a
        // bare guard !isListening can let two listeners coexist briefly.
        listenerTask.value?.cancel()
        listeningGeneration += 1
        let myGen = listeningGeneration
        isListening = true

        // Initialize currentUserId early so it's available before first message arrives
        if currentUserId == nil {
            currentUserId = await deps.userRepository.currentUserProfile?.id
        }

        let stream = deps.stripRepository.listenToStripChat(
            stripId: stripId,
            chatPartnerId: chatPartnerId
        )
        listenerTask.value = Task { [weak self] in
            for await newMessages in stream {
                if Task.isCancelled { break }
                guard let self else { break }
                await MainActor.run {
                    // Drop stale yields from a prior listener generation.
                    guard self.listeningGeneration == myGen else { return }
                    self.messages = newMessages
                    self.isLoading = false
                }
                if self.currentUserId == nil {
                    self.currentUserId = await self.deps.userRepository.currentUserProfile?.id
                }
            }
            await MainActor.run {
                // Only flip isListening back if a newer generation hasn't taken over.
                guard let self, self.listeningGeneration == myGen else { return }
                self.isListening = false
            }
        }
    }

    public func stopListening() {
        listenerTask.value?.cancel()
        listenerTask.value = nil
        // Bumping the generation here invalidates any in-flight task so its late
        // updates won't leak into the next session.
        listeningGeneration += 1
        isListening = false
    }

    private static let heartReaction = "\u{2764}\u{FE0F}" // red heart emoji stored in Firestore

    /// Toggle heart reaction on a strip chat message (double-tap gesture).
    public func toggleHeart(on message: Comment) {
        guard let uid = currentUserId else { return }
        let hasHeart = message.reactions?[uid] == Self.heartReaction
        HapticsManager.playImpact(style: .light)
        Task {
            if hasHeart {
                await PhotoService.shared.removeStripChatReaction(
                    stripId: stripId, chatPartnerId: chatPartnerId, messageId: message.id
                )
            } else {
                await PhotoService.shared.addStripChatReaction(
                    stripId: stripId, chatPartnerId: chatPartnerId, messageId: message.id, emoji: Self.heartReaction
                )
            }
        }
    }

    /// Add a GIPHY sticker to a message.
    public func addSticker(to message: Comment, url: String, mediaId: String) {
        HapticsManager.playImpact(style: .light)
        Task {
            await PhotoService.shared.addStickerToMessage(
                stripId: stripId, chatPartnerId: chatPartnerId,
                messageId: message.id, url: url, mediaId: mediaId
            )
        }
    }

    /// Remove the current user's sticker from a message.
    public func removeSticker(from message: Comment) {
        HapticsManager.playImpact(style: .light)
        Task {
            await PhotoService.shared.removeStickerFromMessage(
                stripId: stripId, chatPartnerId: chatPartnerId,
                messageId: message.id
            )
        }
    }

    public func sendMessage(text: String? = nil) async {
        guard !isSending else { return }
        let textToSend = text ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else { return }
        guard textToSend.count <= 2000 else {
            self.errorMessage = String(localized: "Mesaj çok uzun. Maksimum 2000 karakter.")
            HapticsManager.playNotification(type: .error)
            return
        }
        isSending = true
        defer { isSending = false }

        let reply = self.replyingTo

        if text == nil {
            self.inputText = ""
        }
        self.replyingTo = nil

        HapticsManager.playImpact(style: .light)

        // Queue message if offline
        if !NetworkMonitor.shared.isConnected {
            pendingMessages.append(PendingMessage(
                text: textToSend,
                replyToId: reply?.id,
                replyToText: reply?.text,
                replyToSenderId: reply?.senderId
            ))
            return
        }

        // Optimistic append: drop the message into the list immediately under
        // the same id we'll write server-side. The Firestore listener replaces
        // the placeholder with the server doc on next emission (matched by id).
        let clientId = UUID().uuidString
        let senderUid = currentUserId ?? ""
        let optimistic = Comment(
            id: clientId,
            photoId: stripId,
            senderId: senderUid,
            text: textToSend,
            timestamp: Date(),
            replyToId: reply?.id,
            replyToText: reply?.text,
            replyToSenderId: reply?.senderId
        )
        messages.append(optimistic)

        do {
            try await deps.stripRepository.sendStripChatMessage(
                text: textToSend,
                stripId: stripId,
                chatPartnerId: chatPartnerId,
                clientId: clientId,
                replyToId: reply?.id,
                replyToText: reply?.text,
                replyToSenderId: reply?.senderId,
                voiceUrl: nil,
                photoReplyUrl: nil
            )
        } catch {
            // Pull the placeholder back so the user sees the failure cleanly.
            messages.removeAll { $0.id == clientId }
            // Queue for retry instead of just restoring text
            pendingMessages.append(PendingMessage(
                text: textToSend,
                replyToId: reply?.id,
                replyToText: reply?.text,
                replyToSenderId: reply?.senderId
            ))
            self.errorMessage = String(localized: "Mesaj kuyruğa eklendi. Bağlantı gelince gönderilecek.")
            HapticsManager.playNotification(type: .error)
        }
    }

    /// Flush queued messages when network is restored
    public func flushPendingMessages() async {
        let queued = pendingMessages
        pendingMessages.removeAll()
        for msg in queued {
            do {
                try await deps.stripRepository.sendStripChatMessage(
                    text: msg.text,
                    stripId: stripId,
                    chatPartnerId: chatPartnerId,
                    replyToId: msg.replyToId,
                    replyToText: msg.replyToText,
                    replyToSenderId: msg.replyToSenderId,
                    voiceUrl: nil
                )
            } catch {
                pendingMessages.append(msg)
            }
        }
    }

    /// Send a photo reply (selfie reaction) as a chat message.
    public func sendPhotoReply(image: UIImage) async {
        HapticsManager.playImpact(style: .medium)
        do {
            // Step 1: Upload photo to Storage
            let photoUrl = try await PhotoService.shared.uploadChatPhoto(image: image, stripId: stripId)

            // Step 2: Send message with photo URL
            try await PhotoService.shared.sendStripChatMessage(
                text: "",
                stripId: stripId,
                chatPartnerId: chatPartnerId,
                replyToId: nil,
                replyToText: nil,
                replyToSenderId: nil,
                voiceUrl: nil,
                photoReplyUrl: photoUrl
            )
            HapticsManager.playNotification(type: .success)
        } catch {
            #if DEBUG
            print("Photo reply error: \(error)")
            #endif
            self.errorMessage = String(localized: "Fotoğraf yanıt gönderilemedi.")
            HapticsManager.playNotification(type: .error)
        }
    }
}
