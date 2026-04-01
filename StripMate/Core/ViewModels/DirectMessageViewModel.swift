import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
public final class DirectMessageViewModel {
    public let partner: UserProfile
    public var messages: [DirectMessage] = []
    public var inputText: String = ""
    public var isLoading = true
    public var errorMessage: String?
    public var currentUserId: String?
    
    // Reply state
    public var replyingTo: DirectMessage?
    
    // Typing indicator state
    public var isPartnerTyping = false
    
    // Pagination state
    public var canLoadMore = true
    public var isLoadingMore = false
    
    /// Prevent duplicate listeners
    nonisolated(unsafe) private var listenerTask: Task<Void, Never>?
    nonisolated(unsafe) private var typingListenerRegistration: ListenerRegistration?
    private var isListening = false
    private let deps = DependencyContainer.shared

    // Typing debounce
    nonisolated(unsafe) private var typingTimeoutTask: Task<Void, Never>?
    private var isCurrentlyTyping = false
    
    public init(partner: UserProfile) {
        self.partner = partner
        loadPendingMessages()
    }

    deinit {
        listenerTask?.cancel()
        typingListenerRegistration?.remove()
        typingTimeoutTask?.cancel()
    }

    // MARK: - Messages
    
    public func listenToMessages() async {
        guard !isListening else { return }
        isListening = true
        listenerTask?.cancel()
        
        // Fetch current user ID first
        if self.currentUserId == nil {
            self.currentUserId = await self.deps.userRepository.currentUserProfile?.id
        }
        
        // Start listening for partner typing status
        listenToPartnerTyping()
        
        let stream = deps.chatRepository.listenToMessages(with: partner.id)
        listenerTask = Task { [weak self] in
            for await newMessages in stream {
                if Task.isCancelled { break }
                guard let self else { break }
                await MainActor.run {
                    self.messages = newMessages
                    self.isLoading = false
                }
                // Mark incoming messages as read
                await self.markAsRead()
            }
            await MainActor.run { self?.isListening = false }
        }
    }
    
    public func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
        isListening = false
        
        // Stop typing listener
        typingListenerRegistration?.remove()
        typingListenerRegistration = nil
        
        // Send stop typing
        if isCurrentlyTyping {
            isCurrentlyTyping = false
            Task { await ChatService.shared.setTyping(partnerId: partner.id, isTyping: false) }
        }
        typingTimeoutTask?.cancel()
        typingTimeoutTask = nil
    }
    
    // MARK: - Pagination
    
    /// Load messages older than the earliest currently displayed message.
    public func loadMoreMessages() async {
        guard canLoadMore, !isLoadingMore, !messages.isEmpty else { return }
        guard let oldestTimestamp = messages.first?.timestamp else { return }
        
        isLoadingMore = true
        let older = await deps.chatRepository.loadMoreMessages(with: partner.id, before: oldestTimestamp)
        isLoadingMore = false
        
        if older.isEmpty {
            canLoadMore = false
        } else {
            // Prepend older messages, avoid duplicates
            let existingIds = Set(messages.map(\.id))
            let newOnes = older.filter { !existingIds.contains($0.id) }
            messages = newOnes + messages
        }
    }
    
    // MARK: - Read Receipts
    
    public func markAsRead() async {
        await ChatService.shared.markMessagesAsRead(partnerId: partner.id)
    }
    
    // MARK: - Typing Indicator
    
    public func handleTypingChange() {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasText && !isCurrentlyTyping {
            isCurrentlyTyping = true
            Task { await ChatService.shared.setTyping(partnerId: partner.id, isTyping: true) }
        }

        // Cancel any pending timeout and schedule a fresh one
        typingTimeoutTask?.cancel()
        typingTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                if self.isCurrentlyTyping {
                    self.isCurrentlyTyping = false
                    Task { await ChatService.shared.setTyping(partnerId: self.partner.id, isTyping: false) }
                }
            }
        }

        if !hasText && isCurrentlyTyping {
            isCurrentlyTyping = false
            typingTimeoutTask?.cancel()
            typingTimeoutTask = nil
            Task { await ChatService.shared.setTyping(partnerId: partner.id, isTyping: false) }
        }
    }
    
    /// Listen to partner's typing status from Firestore thread document
    private func listenToPartnerTyping() {
        guard let myId = currentUserId else { return }
        let threadId = myId < partner.id ? "\(myId)_\(partner.id)" : "\(partner.id)_\(myId)"
        
        let docRef = Firestore.firestore().collection("direct_messages").document(threadId)
        
        typingListenerRegistration = docRef.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let data = snapshot?.data() else { return }
            let partnerTypingKey = "typing_\(self.partner.id)"
            let partnerTypingAtKey = "typing_\(self.partner.id)_at"
            
            let isTyping = data[partnerTypingKey] as? Bool ?? false
            
            var isRecent = true
            if let typingAt = data[partnerTypingAtKey] as? Timestamp {
                isRecent = Date().timeIntervalSince(typingAt.dateValue()) < 10
            }
            
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isPartnerTyping = isTyping && isRecent
                }
            }
        }
    }
    
    // MARK: - Send Message
    
    /// Pending messages waiting to be sent when network returns.
    /// Persisted to UserDefaults so they survive app restarts.
    public var pendingMessages: [(text: String, replyToId: String?, replyToText: String?, replyToSenderId: String?)] = [] {
        didSet { savePendingMessages() }
    }

    private var pendingStorageKey: String { "pending_dm_\(partner.id)" }

    private func savePendingMessages() {
        let encoded = pendingMessages.map { msg -> [String: String] in
            var dict: [String: String] = ["text": msg.text]
            if let r = msg.replyToId { dict["replyToId"] = r }
            if let t = msg.replyToText { dict["replyToText"] = t }
            if let s = msg.replyToSenderId { dict["replyToSenderId"] = s }
            return dict
        }
        UserDefaults.standard.set(encoded, forKey: pendingStorageKey)
    }

    private func loadPendingMessages() {
        guard let saved = UserDefaults.standard.array(forKey: pendingStorageKey) as? [[String: String]] else { return }
        pendingMessages = saved.compactMap { dict in
            guard let text = dict["text"] else { return nil }
            return (text: text, replyToId: dict["replyToId"], replyToText: dict["replyToText"], replyToSenderId: dict["replyToSenderId"])
        }
    }

    private static let heartReaction = "\u{2764}\u{FE0F}" // red heart emoji stored in Firestore

    /// Toggle heart reaction on a DM message (double-tap gesture).
    public func toggleHeart(on message: DirectMessage) {
        guard let uid = currentUserId else { return }
        let hasHeart = message.reactions?[uid] == Self.heartReaction
        let threadId = [uid, partner.id].sorted().joined(separator: "_")
        HapticsManager.playImpact(style: .light)
        Task {
            if hasHeart {
                await ChatService.shared.removeReaction(threadId: threadId, messageId: message.id)
            } else {
                await ChatService.shared.addReaction(threadId: threadId, messageId: message.id, emoji: Self.heartReaction)
            }
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

        if isCurrentlyTyping {
            isCurrentlyTyping = false
            typingTimeoutTask?.cancel()
            typingTimeoutTask = nil
            await ChatService.shared.setTyping(partnerId: partner.id, isTyping: false)
        }

        HapticsManager.playImpact(style: .light)

        // If offline, queue the message for later
        if !NetworkMonitor.shared.isConnected {
            pendingMessages.append((
                text: textToSend,
                replyToId: reply?.id,
                replyToText: reply?.text,
                replyToSenderId: reply?.senderId
            ))
            self.errorMessage = String(localized: "Çevrimdışısın. Mesaj bağlantı gelince gönderilecek.")
            HapticsManager.playNotification(type: .warning)
            return
        }

        do {
            try await deps.chatRepository.sendMessage(
                to: partner.id,
                text: textToSend,
                replyToId: reply?.id,
                replyToText: reply?.text,
                replyToSenderId: reply?.senderId
            )
        } catch {
            // Queue for retry instead of losing the message
            pendingMessages.append((
                text: textToSend,
                replyToId: reply?.id,
                replyToText: reply?.text,
                replyToSenderId: reply?.senderId
            ))
            self.errorMessage = String(localized: "Mesaj gönderilemedi. Otomatik tekrar denenecek.")
            HapticsManager.playNotification(type: .error)
        }
    }

    /// Flush pending messages when network is back
    public func flushPendingMessages() async {
        guard NetworkMonitor.shared.isConnected, !pendingMessages.isEmpty else { return }
        let queue = pendingMessages
        pendingMessages.removeAll()

        for msg in queue {
            do {
                try await deps.chatRepository.sendMessage(
                    to: partner.id,
                    text: msg.text,
                    replyToId: msg.replyToId,
                    replyToText: msg.replyToText,
                    replyToSenderId: msg.replyToSenderId
                )
            } catch {
                // Re-queue if still failing
                pendingMessages.append(msg)
            }
        }

        if !pendingMessages.isEmpty {
            self.errorMessage = String(localized: "\(pendingMessages.count) mesaj hâlâ gönderilemedi.")
        }
    }
}
