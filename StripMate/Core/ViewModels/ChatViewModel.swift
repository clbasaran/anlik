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

    /// Prevent duplicate listeners
    nonisolated(unsafe) private var listenerTask: Task<Void, Never>?
    private var isListening = false
    private let deps = DependencyContainer.shared

    /// New initializer: requires stripId and the chat partner's userId.
    public init(stripId: String, chatPartnerId: String) {
        self.stripId = stripId
        self.chatPartnerId = chatPartnerId
    }

    deinit {
        listenerTask?.cancel()
    }

    public func listenToMessages() async {
        guard !isListening else { return }
        isListening = true
        listenerTask?.cancel()

        let stream = deps.stripRepository.listenToStripChat(
            stripId: stripId,
            chatPartnerId: chatPartnerId
        )
        listenerTask = Task { [weak self] in
            for await newMessages in stream {
                if Task.isCancelled { break }
                guard let self else { break }
                await MainActor.run {
                    self.messages = newMessages
                    self.isLoading = false
                }
                if self.currentUserId == nil {
                    self.currentUserId = await self.deps.userRepository.currentUserProfile?.id
                }
            }
            await MainActor.run { self?.isListening = false }
        }
    }

    public func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
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
        let textToSend = text ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else { return }
        guard textToSend.count <= 2000 else {
            self.errorMessage = String(localized: "Mesaj çok uzun. Maksimum 2000 karakter.")
            HapticsManager.playNotification(type: .error)
            return
        }

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

        do {
            try await deps.stripRepository.sendStripChatMessage(
                text: textToSend,
                stripId: stripId,
                chatPartnerId: chatPartnerId,
                replyToId: reply?.id,
                replyToText: reply?.text,
                replyToSenderId: reply?.senderId,
                voiceUrl: nil
            )
        } catch {
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
