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

    /// Prevents duplicate send taps while a message is in flight
    public var isSending = false

    /// Prevent duplicate listeners. The generation counter guards against an
    /// older listener's late yields or its exit handler overwriting newer state
    /// when the view rapidly disappears and reappears. Three resources held
    /// in `IsolatedRef` so the nonisolated `deinit` can tear them down without
    /// `nonisolated(unsafe)`.
    private let listenerTask = IsolatedRef<Task<Void, Never>?>(nil)
    private let typingListenerRegistration = IsolatedRef<ListenerRegistration?>(nil)
    private var isListening = false
    private var listeningGeneration: Int = 0
    private let deps = DependencyContainer.shared

    // Typing debounce
    private let typingTimeoutTask = IsolatedRef<Task<Void, Never>?>(nil)
    private var isCurrentlyTyping = false

    public init(partner: UserProfile) {
        self.partner = partner
        loadPendingMessages()
    }

    deinit {
        listenerTask.value?.cancel()
        typingListenerRegistration.value?.remove()
        typingTimeoutTask.value?.cancel()
    }

    // MARK: - Messages

    public func listenToMessages() async {
        // Always cancel-and-replace rather than gating on isListening. The old
        // task may still be unwinding (its exit handler hasn't run yet), so a
        // bare guard !isListening can let two listeners coexist briefly.
        listenerTask.value?.cancel()
        listeningGeneration += 1
        let myGen = listeningGeneration
        isListening = true

        // Fetch current user ID first
        if self.currentUserId == nil {
            self.currentUserId = await self.deps.userRepository.currentUserProfile?.id
        }

        // Start listening for partner typing status
        listenToPartnerTyping()

        let stream = deps.chatRepository.listenToMessages(with: partner.id)
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
                // Mark incoming messages as read
                await self.markAsRead()
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

        // Stop typing listener
        typingListenerRegistration.value?.remove()
        typingListenerRegistration.value = nil

        // Send stop typing
        if isCurrentlyTyping {
            isCurrentlyTyping = false
            Task { await ChatService.shared.setTyping(partnerId: partner.id, isTyping: false) }
        }
        typingTimeoutTask.value?.cancel()
        typingTimeoutTask.value = nil
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
        typingTimeoutTask.value?.cancel()
        typingTimeoutTask.value = Task { [weak self] in
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
            typingTimeoutTask.value?.cancel()
            typingTimeoutTask.value = nil
            Task { await ChatService.shared.setTyping(partnerId: partner.id, isTyping: false) }
        }
    }

    /// Listen to partner's typing status from Firestore thread document
    private func listenToPartnerTyping() {
        guard let myId = currentUserId else { return }
        let threadId = myId < partner.id ? "\(myId)_\(partner.id)" : "\(partner.id)_\(myId)"

        let docRef = Firestore.firestore().collection("direct_messages").document(threadId)

        // Remove any previously-registered typing listener before assigning a new
        // one. Without this, a second listenToMessages() call (e.g. after the
        // stream errors and isListening flips back) would orphan the old
        // registration — it'd keep firing until logout or app death.
        typingListenerRegistration.value?.remove()

        typingListenerRegistration.value = docRef.addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let data = snapshot?.data() else { return }
            let partnerTypingKey = "typing_\(self.partner.id)"
            let partnerTypingAtKey = "typing_\(self.partner.id)_at"

            let isTyping = data[partnerTypingKey] as? Bool ?? false

            var isRecent = true
            if let typingAt = data[partnerTypingAtKey] as? Timestamp {
                isRecent = Date().timeIntervalSince(typingAt.dateValue()) < 10
            }

            Task { @MainActor in
                withAnimation(Brand.Animations.fadeQuick) {
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
        // Prevent duplicate submissions if a send is already in flight
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

        if isCurrentlyTyping {
            isCurrentlyTyping = false
            typingTimeoutTask.value?.cancel()
            typingTimeoutTask.value = nil
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

        // Optimistic insertion: render the message instantly with the id we'll
        // ask the server to use. The Firestore listener emits the real doc with
        // the same id, so the next stream update overwrites this placeholder
        // with the server's authoritative copy (timestamp/readAt/etc.).
        let clientId = UUID().uuidString
        let senderUid = currentUserId ?? ""
        let optimistic = DirectMessage(
            id: clientId,
            senderId: senderUid,
            receiverId: partner.id,
            text: textToSend,
            timestamp: Date(),
            replyToId: reply?.id,
            replyToText: reply?.text,
            replyToSenderId: reply?.senderId
        )
        messages.append(optimistic)

        do {
            try await deps.chatRepository.sendMessage(
                to: partner.id,
                text: textToSend,
                clientId: clientId,
                replyToId: reply?.id,
                replyToText: reply?.text,
                replyToSenderId: reply?.senderId
            )
        } catch {
            // Roll back the optimistic placeholder so the user doesn't see a
            // ghost message that never made it. Then queue for retry.
            messages.removeAll { $0.id == clientId }
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
                    clientId: nil,
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
