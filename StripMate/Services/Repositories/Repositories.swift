import Foundation
import UIKit

// MARK: - Network Guard

/// Throws `AppError.networkUnavailable` if the device is offline.
/// Apply before write operations to give immediate user feedback instead of waiting for Firestore timeout.
private func requireNetwork() throws {
    guard NetworkMonitor.shared.isConnected else {
        throw AppError.networkUnavailable
    }
}

// MARK: - Repository Protocols

/// Repository for strip/photo operations.
public protocol StripRepositoryProtocol: Sendable {
    func fetchStrip(byId stripId: String) async throws -> PhotoMetadata?
    @discardableResult
    func sendPhoto(_ image: UIImage, to receiverIds: [String], latitude: Double?, longitude: Double?, cityName: String?, voiceData: Data?, isSecret: Bool, videoData: Data?, videoDuration: Double?) async throws -> String
    func listenToHistory(for userId: String) -> AsyncStream<[PhotoMetadata]>
    func loadMoreHistory(for userId: String, before lastTimestamp: Date) async -> [PhotoMetadata]
    func clearHistory() async throws
    func deleteStrip(_ photo: PhotoMetadata) async throws
    func sendStripChatMessage(text: String, stripId: String, chatPartnerId: String, replyToId: String?, replyToText: String?, replyToSenderId: String?, voiceUrl: String?, photoReplyUrl: String?) async throws
    func listenToStripChat(stripId: String, chatPartnerId: String) -> AsyncStream<[Comment]>
    func toggleReaction(on photoId: String, emoji: String) async throws
    func markStripAsSeen(stripId: String) async
}

// Default parameter extensions — allows calling without optional trailing params
extension StripRepositoryProtocol {
    @discardableResult
    func sendPhoto(_ image: UIImage, to receiverIds: [String], latitude: Double?, longitude: Double?, cityName: String?, voiceData: Data? = nil, isSecret: Bool = false) async throws -> String {
        try await sendPhoto(image, to: receiverIds, latitude: latitude, longitude: longitude, cityName: cityName, voiceData: voiceData, isSecret: isSecret, videoData: nil, videoDuration: nil)
    }

    func sendStripChatMessage(text: String, stripId: String, chatPartnerId: String, replyToId: String?, replyToText: String?, replyToSenderId: String?, voiceUrl: String?) async throws {
        try await sendStripChatMessage(text: text, stripId: stripId, chatPartnerId: chatPartnerId, replyToId: replyToId, replyToText: replyToText, replyToSenderId: replyToSenderId, voiceUrl: voiceUrl, photoReplyUrl: nil)
    }
}

/// Repository for friend operations.
public protocol FriendRepositoryProtocol: Sendable {
    func fetchFriends() async throws -> [FriendStatus]
    func sendRequest(to userId: String) async throws
    func acceptRequest(from userId: String) async throws
    func remove(_ userId: String) async throws
    func fetchPendingCount() async -> Int
}

/// Repository for user/auth operations.
public protocol UserRepositoryProtocol: Sendable {
    func login(email: String, password: String) async throws -> UserProfile
    func signUp(email: String, password: String, displayName: String, username: String, dateOfBirth: Date) async throws -> UserProfile
    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> UserProfile
    func logout() throws
    func fetchProfile(for userId: String) async throws -> UserProfile
    func searchUser(byCode code: String) async throws -> UserProfile
    func uploadAvatar(_ image: UIImage) async throws -> String
    func sendPasswordReset(to email: String) async throws
    func deleteAccount() async throws
    func blockUser(_ userId: String) async throws
    func unblockUser(_ userId: String) async throws
    func reportUser(_ userId: String, reason: String) async throws
    func reportContent(contentType: String, contentId: String, contentOwnerId: String, reason: String) async throws
    func fetchBlockedUserIds() async throws -> Set<String>
    var currentUserProfile: UserProfile? { get async }
}

/// Repository for chat/DM operations.
public protocol ChatRepositoryProtocol: Sendable {
    func sendMessage(to receiverId: String, text: String, replyToId: String?, replyToText: String?, replyToSenderId: String?) async throws
    func listenToMessages(with partnerId: String) -> AsyncStream<[DirectMessage]>
    func loadMoreMessages(with partnerId: String, before lastTimestamp: Date) async -> [DirectMessage]
}

/// Repository for notification operations.
public protocol NotificationRepositoryProtocol: Sendable {
    func listenToNotifications() -> AsyncStream<[AppNotification]>
    func markAsRead(id: String) async
    func sendInAppNotification(to userId: String, type: NotificationType, relatedId: String?, thumbnailUrl: String?) async
}

// MARK: - Default Implementations (Firebase-backed)

/// Default StripRepository backed by PhotoService + SwiftDataSyncService.
public final class StripRepository: StripRepositoryProtocol, @unchecked Sendable {
    public static let shared = StripRepository()
    private init() {}
    
    public func fetchStrip(byId stripId: String) async throws -> PhotoMetadata? {
        try await PhotoService.shared.fetchStrip(byId: stripId)
    }
    
    @discardableResult
    public func sendPhoto(_ image: UIImage, to receiverIds: [String], latitude: Double?, longitude: Double?, cityName: String?, voiceData: Data? = nil, isSecret: Bool = false, videoData: Data? = nil, videoDuration: Double? = nil) async throws -> String {
        try requireNetwork()
        let photoId = try await PhotoService.shared.sendPhoto(image, to: receiverIds, latitude: latitude, longitude: longitude, cityName: cityName, voiceData: voiceData, isSecret: isSecret, videoData: videoData, videoDuration: videoDuration)
        
        // Mark daily prompt as completed (fire-and-forget)
        if let senderId = await AuthService.shared.currentUserProfile?.id {
            await DailyPromptService.shared.markCompleted(userId: senderId)
        }
        
        return photoId
    }
    
    public func listenToHistory(for userId: String) -> AsyncStream<[PhotoMetadata]> {
        PhotoService.shared.listenToHistory(for: userId)
    }
    
    public func loadMoreHistory(for userId: String, before lastTimestamp: Date) async -> [PhotoMetadata] {
        await PhotoService.shared.loadMoreHistory(for: userId, before: lastTimestamp)
    }
    
    public func clearHistory() async throws {
        try requireNetwork()
        try await PhotoService.shared.clearUserHistory()
    }
    
    public func deleteStrip(_ photo: PhotoMetadata) async throws {
        try requireNetwork()
        try await PhotoService.shared.deleteStrip(photo)
    }
    
    public func sendStripChatMessage(text: String, stripId: String, chatPartnerId: String, replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil, voiceUrl: String? = nil, photoReplyUrl: String? = nil) async throws {
        try requireNetwork()
        try await PhotoService.shared.sendStripChatMessage(text: text, stripId: stripId, chatPartnerId: chatPartnerId, replyToId: replyToId, replyToText: replyToText, replyToSenderId: replyToSenderId, voiceUrl: voiceUrl, photoReplyUrl: photoReplyUrl)
    }
    
    public func listenToStripChat(stripId: String, chatPartnerId: String) -> AsyncStream<[Comment]> {
        PhotoService.shared.listenToStripChat(stripId: stripId, chatPartnerId: chatPartnerId)
    }
    
    public func toggleReaction(on photoId: String, emoji: String) async throws {
        try requireNetwork()
        try await PhotoService.shared.toggleReaction(on: photoId, emoji: emoji)
    }

    public func markStripAsSeen(stripId: String) async {
        await PhotoService.shared.markStripAsSeen(stripId: stripId)
    }
}

/// Default FriendRepository backed by FriendshipService + SwiftDataSyncService.
public final class FriendRepository: FriendRepositoryProtocol, @unchecked Sendable {
    public static let shared = FriendRepository()
    private init() {}
    
    public func fetchFriends() async throws -> [FriendStatus] {
        try await FriendshipService.shared.fetchFriends()
    }
    
    public func sendRequest(to userId: String) async throws {
        try requireNetwork()
        try await FriendshipService.shared.sendFriendRequest(to: userId)
    }
    
    public func acceptRequest(from userId: String) async throws {
        try requireNetwork()
        try await FriendshipService.shared.acceptFriendRequest(from: userId)
    }
    
    public func remove(_ userId: String) async throws {
        try requireNetwork()
        try await FriendshipService.shared.removeFriend(userId)
    }
    
    public func fetchPendingCount() async -> Int {
        await FriendshipService.shared.fetchPendingRequestsCount()
    }
}

/// Default UserRepository backed by AuthService.
public final class UserRepository: UserRepositoryProtocol, @unchecked Sendable {
    public static let shared = UserRepository()
    private init() {}
    
    public func login(email: String, password: String) async throws -> UserProfile {
        try await AuthService.shared.login(email: email, password: password)
    }
    
    public func signUp(email: String, password: String, displayName: String, username: String, dateOfBirth: Date) async throws -> UserProfile {
        try await AuthService.shared.signUp(email: email, password: password, displayName: displayName, username: username, dateOfBirth: dateOfBirth)
    }
    
    public func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> UserProfile {
        try await AuthService.shared.signInWithApple(idToken: idToken, nonce: nonce, fullName: fullName)
    }
    
    public func logout() throws {
        try AuthService.shared.logout()
    }
    
    public func fetchProfile(for userId: String) async throws -> UserProfile {
        try await AuthService.shared.fetchProfile(for: userId)
    }
    
    public func searchUser(byCode code: String) async throws -> UserProfile {
        try await AuthService.shared.searchUser(byCode: code)
    }
    
    public func uploadAvatar(_ image: UIImage) async throws -> String {
        try await AuthService.shared.uploadAvatar(image)
    }
    
    public func sendPasswordReset(to email: String) async throws {
        try await AuthService.shared.sendPasswordReset(to: email)
    }
    
    public func deleteAccount() async throws {
        try await AuthService.shared.deleteAccount()
    }
    
    public func blockUser(_ userId: String) async throws {
        try await AuthService.shared.blockUser(userId)
    }
    
    public func unblockUser(_ userId: String) async throws {
        try await AuthService.shared.unblockUser(userId)
    }
    
    public func reportUser(_ userId: String, reason: String) async throws {
        try await AuthService.shared.reportUser(userId, reason: reason)
    }

    public func reportContent(contentType: String, contentId: String, contentOwnerId: String, reason: String) async throws {
        try await AuthService.shared.reportContent(contentType: contentType, contentId: contentId, contentOwnerId: contentOwnerId, reason: reason)
    }
    
    public func fetchBlockedUserIds() async throws -> Set<String> {
        try await AuthService.shared.fetchBlockedUserIds()
    }
    
    public var currentUserProfile: UserProfile? {
        get async { await AuthService.shared.currentUserProfile }
    }
}

/// Default ChatRepository backed by ChatService.
public final class ChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    public static let shared = ChatRepository()
    private init() {}
    
    public func sendMessage(to receiverId: String, text: String, replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil) async throws {
        try requireNetwork()
        try await ChatService.shared.sendDirectMessage(to: receiverId, text: text, replyToId: replyToId, replyToText: replyToText, replyToSenderId: replyToSenderId)
    }
    
    public func listenToMessages(with partnerId: String) -> AsyncStream<[DirectMessage]> {
        ChatService.shared.listenToDirectMessages(with: partnerId)
    }
    
    public func loadMoreMessages(with partnerId: String, before lastTimestamp: Date) async -> [DirectMessage] {
        await ChatService.shared.loadMoreMessages(partnerId: partnerId, before: lastTimestamp)
    }
}

/// Default NotificationRepository backed by AppNotificationService.
public final class NotificationRepository: NotificationRepositoryProtocol, @unchecked Sendable {
    public static let shared = NotificationRepository()
    private init() {}
    
    public func listenToNotifications() -> AsyncStream<[AppNotification]> {
        AppNotificationService.shared.listenToNotifications()
    }
    
    public func markAsRead(id: String) async {
        await AppNotificationService.shared.markNotificationAsRead(id: id)
    }
    
    public func sendInAppNotification(to userId: String, type: NotificationType, relatedId: String?, thumbnailUrl: String?) async {
        await AppNotificationService.shared.sendInAppNotification(to: userId, type: type, relatedId: relatedId, thumbnailUrl: thumbnailUrl)
    }
}
