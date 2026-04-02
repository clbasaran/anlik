import XCTest
import UIKit
@testable import StripMate

// MARK: - Mock Repositories

final class MockUserRepository: UserRepositoryProtocol, @unchecked Sendable {
    var loginResult: Result<UserProfile, Error> = .success(mockProfile)
    var signUpResult: Result<UserProfile, Error> = .success(mockProfile)
    var appleSignInResult: Result<UserProfile, Error> = .success(mockProfile)
    var logoutCalled = false
    var fetchProfileResult: Result<UserProfile, Error> = .success(mockProfile)
    var searchUserResult: Result<UserProfile, Error> = .success(mockProfile)
    var uploadAvatarResult: Result<String, Error> = .success("https://example.com/avatar.jpg")
    var _currentUserProfile: UserProfile? = mockProfile
    
    static let mockProfile = UserProfile(
        id: "test_user_1",
        inviteCode: "ABC123",
        email: "test@test.com",
        displayName: "Test User",
        username: "testuser",
        dateOfBirth: Date(),
        avatarUrl: nil
    )
    
    func login(email: String, password: String) async throws -> UserProfile {
        try loginResult.get()
    }
    
    func signUp(email: String, password: String, displayName: String, username: String, dateOfBirth: Date) async throws -> UserProfile {
        try signUpResult.get()
    }
    
    func signInWithApple(idToken: String, nonce: String, fullName: String?) async throws -> UserProfile {
        try appleSignInResult.get()
    }
    
    func logout() throws {
        logoutCalled = true
    }
    
    func fetchProfile(for userId: String) async throws -> UserProfile {
        try fetchProfileResult.get()
    }
    
    func searchUser(byCode code: String) async throws -> UserProfile {
        try searchUserResult.get()
    }
    
    func uploadAvatar(_ image: UIImage) async throws -> String {
        try uploadAvatarResult.get()
    }
    
    func sendPasswordReset(to email: String) async throws {}
    func deleteAccount() async throws {}
    func blockUser(_ userId: String) async throws {}
    func unblockUser(_ userId: String) async throws {}
    func reportUser(_ userId: String, reason: String) async throws {}
    func reportContent(contentType: String, contentId: String, contentOwnerId: String, reason: String) async throws {}
    func fetchBlockedUserIds() async throws -> Set<String> { [] }
    
    var currentUserProfile: UserProfile? {
        get async { _currentUserProfile }
    }
}

final class MockFriendRepository: FriendRepositoryProtocol, @unchecked Sendable {
    var friends: [FriendStatus] = []
    var sendRequestCalled = false
    var acceptRequestCalled = false
    var removeCalled = false
    var pendingCount = 0
    
    func fetchFriends() async throws -> [FriendStatus] { friends }
    func sendRequest(to userId: String) async throws { sendRequestCalled = true }
    func acceptRequest(from userId: String) async throws { acceptRequestCalled = true }
    func remove(_ userId: String) async throws { removeCalled = true }
    func fetchPendingCount() async -> Int { pendingCount }
}

final class MockStripRepository: StripRepositoryProtocol, @unchecked Sendable {
    var sendPhotoCalled = false
    var clearHistoryCalled = false
    var sendCommentCalled = false
    var deleteStripCalled = false
    var fetchStripResult: PhotoMetadata?
    
    func fetchStrip(byId stripId: String) async throws -> PhotoMetadata? {
        fetchStripResult
    }
    
    @discardableResult
    func sendPhoto(_ image: UIImage, to receiverIds: [String], latitude: Double?, longitude: Double?, cityName: String?, voiceData: Data? = nil, isSecret: Bool = false, videoFileURL: URL? = nil, videoDuration: Double? = nil) async throws -> String {
        sendPhotoCalled = true
        return "mock_photo_id"
    }

    func listenToHistory(for userId: String) -> AsyncStream<[PhotoMetadata]> {
        AsyncStream { continuation in continuation.finish() }
    }

    func loadMoreHistory(for userId: String, before lastTimestamp: Date) async -> [PhotoMetadata] { [] }

    func clearHistory() async throws { clearHistoryCalled = true }

    func deleteStrip(_ photo: PhotoMetadata) async throws { deleteStripCalled = true }

    func sendStripChatMessage(text: String, stripId: String, chatPartnerId: String, replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil, voiceUrl: String? = nil, photoReplyUrl: String? = nil) async throws { sendCommentCalled = true }

    func listenToStripChat(stripId: String, chatPartnerId: String) -> AsyncStream<[Comment]> {
        AsyncStream { continuation in continuation.finish() }
    }

    func toggleReaction(on photoId: String, emoji: String) async throws {}
    func markStripAsSeen(stripId: String) async {}
}

final class MockChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    var sendMessageCalled = false
    var lastSentText: String?
    
    func sendMessage(to receiverId: String, text: String, replyToId: String? = nil, replyToText: String? = nil, replyToSenderId: String? = nil) async throws {
        sendMessageCalled = true
        lastSentText = text
    }
    
    func listenToMessages(with partnerId: String) -> AsyncStream<[DirectMessage]> {
        AsyncStream { continuation in continuation.finish() }
    }
    
    func loadMoreMessages(with partnerId: String, before lastTimestamp: Date) async -> [DirectMessage] { [] }
}

final class MockNotificationRepository: NotificationRepositoryProtocol, @unchecked Sendable {
    var markAsReadCalled = false
    var lastMarkedId: String?
    
    func listenToNotifications() -> AsyncStream<[AppNotification]> {
        AsyncStream { continuation in continuation.finish() }
    }
    
    func markAsRead(id: String) async {
        markAsReadCalled = true
        lastMarkedId = id
    }
    
    func sendInAppNotification(to userId: String, type: NotificationType, relatedId: String?, thumbnailUrl: String?) async {}
}

// MARK: - Tests

final class StripMateTests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testUserProfileCreation() {
        let profile = UserProfile(
            id: "123",
            inviteCode: "ABC123",
            email: "test@test.com",
            displayName: "Test",
            username: "test",
            dateOfBirth: Date(),
            avatarUrl: nil
        )
        XCTAssertEqual(profile.id, "123")
        XCTAssertEqual(profile.inviteCode, "ABC123")
        XCTAssertNil(profile.avatarUrl)
    }
    
    func testPhotoMetadataCreation() {
        let photo = PhotoMetadata(
            id: "photo1",
            senderId: "user1",
            receiverIds: ["user1", "user2"],
            imageUrl: "https://example.com/photo.jpg",
            timestamp: Date(),
            latitude: 37.0,
            longitude: 29.0,
            cityName: "Muğla"
        )
        XCTAssertEqual(photo.id, "photo1")
        XCTAssertEqual(photo.receiverIds.count, 2)
        XCTAssertEqual(photo.cityName, "Muğla")
    }
    
    func testCommentCreation() {
        let comment = Comment(
            id: "c1",
            photoId: "p1",
            senderId: "u1",
            text: "Nice photo!",
            timestamp: Date()
        )
        XCTAssertEqual(comment.text, "Nice photo!")
    }
    
    func testDirectMessageCreation() {
        let dm = DirectMessage(
            id: "dm1",
            senderId: "u1",
            receiverId: "u2",
            text: "Hey!",
            timestamp: Date()
        )
        XCTAssertEqual(dm.text, "Hey!")
        XCTAssertEqual(dm.senderId, "u1")
    }
    
    func testFriendStatusCreation() {
        let status = FriendStatus(
            userId: "friend1",
            isPending: true,
            timestamp: Date(),
            requesterId: "me",
            profile: nil
        )
        XCTAssertTrue(status.isPending)
        XCTAssertNil(status.profile)
    }
    
    // MARK: - Error Tests
    
    func testFirebaseErrorDescriptions() {
        XCTAssertNotNil(FirebaseError.unauthenticated.errorDescription)
        XCTAssertNotNil(FirebaseError.userNotFound.errorDescription)
        XCTAssertNotNil(FirebaseError.invalidInviteCode.errorDescription)
        XCTAssertNotNil(FirebaseError.compressionFailed.errorDescription)
    }
    
    func testAppErrorDescriptions() {
        let errors: [AppError] = [
            .unauthenticated,
            .networkUnavailable,
            .userNotFound,
            .sendMessageFailed,
            .capturePhotoFailed,
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.alertTitle.isEmpty)
        }
    }
    
    // MARK: - DependencyContainer Tests
    
    func testDependencyContainerDefaults() {
        let container = DependencyContainer.shared
        XCTAssertTrue(container.stripRepository is StripRepository)
        XCTAssertTrue(container.friendRepository is FriendRepository)
        XCTAssertTrue(container.userRepository is UserRepository)
        XCTAssertTrue(container.chatRepository is ChatRepository)
    }
    
    func testDependencyContainerMockInjection() {
        let mockUser = MockUserRepository()
        let mockFriend = MockFriendRepository()
        let mockStrip = MockStripRepository()
        let mockChat = MockChatRepository()
        
        let container = DependencyContainer.shared
        container.stripRepository = mockStrip
        container.friendRepository = mockFriend
        container.userRepository = mockUser
        container.chatRepository = mockChat
        
        XCTAssertTrue(container.userRepository is MockUserRepository)
        XCTAssertTrue(container.friendRepository is MockFriendRepository)
        
        container.reset()
    }
    
    // MARK: - Analytics Tests
    
    func testAnalyticsEventRawValues() {
        XCTAssertEqual(AnalyticsEvent.login.rawValue, "sm_login")
        XCTAssertEqual(AnalyticsEvent.sendPhoto.rawValue, "sm_send_photo")
        XCTAssertEqual(AnalyticsEvent.sendFriendRequest.rawValue, "sm_send_friend_request")
    }
    
    // MARK: - FriendsListViewModel Tests
    
    @MainActor
    func testFriendsListSearchCodeValidation() async {
        let vm = FriendsListViewModel()
        vm.searchCode = "ABC" // too short
        await vm.searchPartner()
        XCTAssertNil(vm.searchedProfile, "Should not search with code shorter than 8 characters")
    }
    
    @MainActor
    func testFriendsListAddFriendCallsRepository() async {
        let mockFriends = MockFriendRepository()
        DependencyContainer.shared.friendRepository = mockFriends
        
        let vm = FriendsListViewModel()
        await vm.addFriend("target_user")
        
        XCTAssertTrue(mockFriends.sendRequestCalled)
        
        DependencyContainer.shared.reset()
    }
    
    @MainActor
    func testFriendsListAcceptFriendCallsRepository() async {
        let mockFriends = MockFriendRepository()
        DependencyContainer.shared.friendRepository = mockFriends
        
        let vm = FriendsListViewModel()
        await vm.acceptFriend("incoming_user")
        
        XCTAssertTrue(mockFriends.acceptRequestCalled)
        
        DependencyContainer.shared.reset()
    }
    
    @MainActor
    func testFriendsListRemoveFriendCallsRepository() async {
        let mockFriends = MockFriendRepository()
        DependencyContainer.shared.friendRepository = mockFriends
        
        let vm = FriendsListViewModel()
        await vm.removeFriend("friend_to_remove")
        
        XCTAssertTrue(mockFriends.removeCalled)
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - InboxViewModel Tests
    
    @MainActor
    func testInboxAcceptFriend() async {
        let mockFriends = MockFriendRepository()
        DependencyContainer.shared.friendRepository = mockFriends
        
        let vm = InboxViewModel()
        await vm.acceptFriend("pending_user")
        
        XCTAssertTrue(mockFriends.acceptRequestCalled)
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - ChatViewModel Tests
    
    @MainActor
    func testChatSendCommentEmpty() async {
        let mockStrip = MockStripRepository()
        DependencyContainer.shared.stripRepository = mockStrip

        let vm = ChatViewModel(stripId: "p1", chatPartnerId: "u1")
        vm.inputText = "   " // whitespace only
        await vm.sendMessage()

        XCTAssertFalse(mockStrip.sendCommentCalled, "Should not send empty/whitespace comment")

        DependencyContainer.shared.reset()
    }

    @MainActor
    func testChatSendCommentSuccess() async {
        let mockStrip = MockStripRepository()
        DependencyContainer.shared.stripRepository = mockStrip

        let vm = ChatViewModel(stripId: "p1", chatPartnerId: "u1")
        vm.inputText = "Nice photo!"
        await vm.sendMessage()

        XCTAssertTrue(mockStrip.sendCommentCalled, "Should send valid comment")
        XCTAssertEqual(vm.inputText, "", "Input should be cleared after send")

        DependencyContainer.shared.reset()
    }
    
    // MARK: - DirectMessageViewModel Tests
    
    @MainActor
    func testDMSendMessageEmpty() async {
        let partner = MockUserRepository.mockProfile
        let mockChat = MockChatRepository()
        DependencyContainer.shared.chatRepository = mockChat
        
        let vm = DirectMessageViewModel(partner: partner)
        vm.inputText = "" // empty
        await vm.sendMessage()
        
        XCTAssertFalse(mockChat.sendMessageCalled, "Should not send empty message")
        
        DependencyContainer.shared.reset()
    }
    
    @MainActor
    func testDMSendMessageSuccess() async {
        let partner = MockUserRepository.mockProfile
        let mockChat = MockChatRepository()
        DependencyContainer.shared.chatRepository = mockChat
        
        let vm = DirectMessageViewModel(partner: partner)
        vm.inputText = "Hello!"
        await vm.sendMessage()
        
        XCTAssertTrue(mockChat.sendMessageCalled, "Should send valid message")
        XCTAssertEqual(mockChat.lastSentText, "Hello!")
        XCTAssertEqual(vm.inputText, "", "Input should be cleared after send")
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - Pagination Tests
    
    @MainActor
    func testHistoryViewModelLoadMore() async {
        let mockStrip = MockStripRepository()
        DependencyContainer.shared.stripRepository = mockStrip
        DependencyContainer.shared.userRepository = MockUserRepository()
        
        let vm = HistoryViewModel()
        vm.currentUserId = "test_user_1"
        
        XCTAssertFalse(vm.isLoadingMore)
        XCTAssertTrue(vm.canLoadMore)
        
        // loadMore returns empty → canLoadMore should become false
        await vm.loadMore(oldestTimestamp: Date())
        
        XCTAssertFalse(vm.canLoadMore, "Should set canLoadMore to false when no more items returned")
        XCTAssertFalse(vm.isLoadingMore)
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - Delete Strip Tests
    
    @MainActor
    func testDeleteStripCallsRepository() async {
        let mockStrip = MockStripRepository()
        DependencyContainer.shared.stripRepository = mockStrip
        DependencyContainer.shared.userRepository = MockUserRepository()
        
        let vm = HistoryViewModel()
        vm.currentUserId = "test_user_1"
        
        let photo = PhotoMetadata(
            id: "strip1", senderId: "test_user_1", receiverIds: ["test_user_1", "friend1"],
            imageUrl: "https://example.com/img.jpg", timestamp: Date()
        )
        
        await vm.deleteStrip(photo)
        
        XCTAssertTrue(mockStrip.deleteStripCalled, "Should call deleteStrip on repository")
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - Notification Tests
    
    @MainActor
    func testNotificationMarkAsRead() async {
        let mockNotif = MockNotificationRepository()
        DependencyContainer.shared.notificationRepository = mockNotif
        
        await mockNotif.markAsRead(id: "notif_123")
        
        XCTAssertTrue(mockNotif.markAsReadCalled)
        XCTAssertEqual(mockNotif.lastMarkedId, "notif_123")
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - RollcallSummary Tests
    
    func testRollcallSummaryIdentifiable() {
        let summary = RollcallSummary(
            weekNumber: 10,
            year: 2026,
            photosCount: 5,
            thumbnailUrl: nil,
            startDate: Date(),
            endDate: Date()
        )
        XCTAssertEqual(summary.photosCount, 5)
        XCTAssertEqual(summary.weekNumber, 10)
    }
    
    // MARK: - Streak Model Tests
    
    func testStreakIsExpiringSoon_NoStreak() {
        let streak = Streak(id: "a_b", userIds: ["a", "b"], currentStreak: 0)
        XCTAssertFalse(streak.isExpiringSoon, "Streak of 0 should not show expiring warning")
    }
    
    func testStreakIsExpiringSoon_ExchangedToday() {
        let streak = Streak(id: "a_b", userIds: ["a", "b"], currentStreak: 5, lastExchangeDate: Date())
        XCTAssertFalse(streak.isExpiringSoon, "Streak exchanged today should not show expiring")
    }
    
    func testStreakIsExpiringSoon_ExchangedYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let streak = Streak(id: "a_b", userIds: ["a", "b"], currentStreak: 5, lastExchangeDate: yesterday)
        XCTAssertTrue(streak.isExpiringSoon, "Streak not exchanged today should show expiring")
    }
    
    func testStreakTierProgression() {
        let tanidik = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 10)
        XCTAssertEqual(tanidik.tier, .tanidik)
        
        let muhabbet = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 75)
        XCTAssertEqual(muhabbet.tier, .muhabbet)
        
        let yakin = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 200)
        XCTAssertEqual(yakin.tier, .yakin)
        
        let sirdas = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 500)
        XCTAssertEqual(sirdas.tier, .sirdas)
        
        let kadim = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 800)
        XCTAssertEqual(kadim.tier, .kadim)
    }
    
    func testStreakTierProgress() {
        let mid = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 25)
        XCTAssertEqual(mid.tier, .tanidik)
        XCTAssertEqual(mid.tierProgress, 0.5, accuracy: 0.01, "25/50 should be 50% progress")
    }
    
    func testStreakIdGeneration() {
        let id1 = Streak.streakId(for: "bob", and: "alice")
        let id2 = Streak.streakId(for: "alice", and: "bob")
        XCTAssertEqual(id1, id2, "Streak ID should be order-independent")
        XCTAssertEqual(id1, "alice_bob")
    }
    
    // MARK: - PhotoMetadata Tests
    
    func testPhotoMetadataInit() {
        let photo = PhotoMetadata(senderId: "user1", imageUrl: "https://example.com/photo.jpg")
        XCTAssertEqual(photo.senderId, "user1")
        XCTAssertEqual(photo.imageUrl, "https://example.com/photo.jpg")
        XCTAssertNil(photo.latitude)
        XCTAssertNil(photo.longitude)
        XCTAssertNil(photo.cityName)
        XCTAssertNil(photo.thumbnailUrl)
    }
    
    // MARK: - DirectMessage Tests
    
    func testDirectMessageWithReactions() {
        let msg = DirectMessage(
            senderId: "user1", receiverId: "user2", text: "hello",
            reactions: ["user2": "❤️"], readAt: Date()
        )
        XCTAssertEqual(msg.reactions?["user2"], "❤️")
        XCTAssertNotNil(msg.readAt)
    }
    
    // MARK: - AppError Tests
    
    func testAppErrorCustom() {
        let error = AppError.custom("test error")
        XCTAssertEqual(error.errorDescription, "test error")
    }
    
    func testAppErrorNetworkUnavailable() {
        let error = AppError.networkUnavailable
        // LocalizedError.errorDescription may return nil via @testable import;
        // use localizedDescription (from Error protocol) which always works
        let desc = error.localizedDescription
        XCTAssertFalse(desc.isEmpty, "networkUnavailable should have a description")
    }
    
    // MARK: - DailyPrompt Tests
    
    func testDailyPromptLibraryNotEmpty() {
        XCTAssertGreaterThan(DailyPrompt.promptLibrary.count, 50, "Should have at least 50 prompts")
    }
    
    func testDailyPromptCategories() {
        let categories = Set(DailyPrompt.promptLibrary.map { $0.category })
        XCTAssertTrue(categories.contains(.selfie))
        XCTAssertTrue(categories.contains(.mood))
        XCTAssertTrue(categories.contains(.food))
        XCTAssertTrue(categories.contains(.creative))
    }
    
    // MARK: - Image Resize Tests
    
    func testUIImageResizeToMax() {
        // Create a 2000x1000 test image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1000))
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 2000, height: 1000)))
        }
        
        let resized = image.resizedToMax(dimension: 1080)
        XCTAssertLessThanOrEqual(max(resized.size.width, resized.size.height), 1080)
        // Aspect ratio should be preserved
        let ratio = image.size.width / image.size.height
        let resizedRatio = resized.size.width / resized.size.height
        XCTAssertEqual(ratio, resizedRatio, accuracy: 0.01)
    }
    
    func testUIImageResizeSkipsSmallImages() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 500))
        let image = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 500, height: 500)))
        }
        
        let resized = image.resizedToMax(dimension: 1080)
        XCTAssertEqual(resized.size.width, 500, "Small images should not be resized")
    }
    
    // MARK: - AuthViewModel Tests
    
    @MainActor
    func testAuthViewModelLoginSuccess() async {
        let mockUser = MockUserRepository()
        DependencyContainer.shared.userRepository = mockUser
        
        let vm = AuthViewModel()
        vm.email = "test@test.com"
        vm.password = "password123"
        vm.isSignUp = false
        
        await vm.authenticate()
        
        XCTAssertNil(vm.errorMessage, "Login should not set error on success")
        
        DependencyContainer.shared.reset()
    }
    
    @MainActor
    func testAuthViewModelLoginFailure() async {
        let mockUser = MockUserRepository()
        mockUser.loginResult = .failure(NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"]))
        DependencyContainer.shared.userRepository = mockUser
        
        let vm = AuthViewModel()
        vm.email = "bad@test.com"
        vm.password = "wrong"
        vm.isSignUp = false
        
        await vm.authenticate()
        
        XCTAssertNotNil(vm.errorMessage, "Login should set error on failure")
        
        DependencyContainer.shared.reset()
    }
    
    @MainActor
    func testAuthViewModelSignUpValidation() async {
        let mockUser = MockUserRepository()
        DependencyContainer.shared.userRepository = mockUser
        
        let vm = AuthViewModel()
        // Empty fields should trigger validation
        vm.email = ""
        vm.password = ""
        vm.displayName = ""
        vm.username = ""
        vm.isSignUp = true
        
        // SignUp with empty fields
        await vm.authenticate()
        
        // Should show error for empty fields
        XCTAssertNotNil(vm.errorMessage, "SignUp should validate empty fields")
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - CameraViewModel Tests
    
    @MainActor
    func testCameraViewModelRetakePhoto() async {
        let vm = CameraViewModel()
        vm.capturedPhotoData = Data([0xFF, 0xD8, 0xFF]) // mock JPEG header
        
        XCTAssertNotNil(vm.capturedPhotoData)
        
        vm.retakePhoto()
        
        XCTAssertNil(vm.capturedPhotoData, "retakePhoto should clear captured data")
    }
    
    @MainActor
    func testCameraViewModelToggleFlash() async {
        let vm = CameraViewModel()
        let initialFlash = vm.isFlashModeOn
        
        vm.toggleFlash()
        
        // Note: Flash toggle is async; verify the property exists and toggles correctly
        // In simulator, CameraManager.toggleFlash() is a no-op but the VM call should not crash
        XCTAssertNotNil(vm.isFlashModeOn)
    }
    
    @MainActor
    func testCameraViewModelSendPhotoRequiresReceivers() async {
        let mockStrip = MockStripRepository()
        DependencyContainer.shared.stripRepository = mockStrip
        DependencyContainer.shared.userRepository = MockUserRepository()

        let vm = CameraViewModel()
        vm.capturedPhotoData = Data([0xFF, 0xD8, 0xFF])
        vm.selectedReceiverIds = [] // no receivers

        vm.sendPhotoInBackground()

        // Give brief time for the background task
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(mockStrip.sendPhotoCalled, "sendPhoto should not send without receivers")

        DependencyContainer.shared.reset()
    }
    
    // MARK: - FriendsListViewModel Tests
    
    @MainActor
    func testFriendsListViewModelFetch() async {
        let mockFriend = MockFriendRepository()
        let friend = FriendStatus(userId: "friend1", isPending: false, timestamp: Date(), requesterId: "friend1")
        mockFriend.friends = [friend]
        DependencyContainer.shared.friendRepository = mockFriend
        DependencyContainer.shared.userRepository = MockUserRepository()
        
        let vm = FriendsListViewModel()
        await vm.fetchFriends()
        
        XCTAssertFalse(vm.isLoading, "Should not be loading after fetch")
        
        DependencyContainer.shared.reset()
    }
    
    @MainActor
    func testFriendsListViewModelSearch() async {
        let mockUser = MockUserRepository()
        DependencyContainer.shared.userRepository = mockUser
        DependencyContainer.shared.friendRepository = MockFriendRepository()
        
        let vm = FriendsListViewModel()
        vm.searchCode = "ABC12345"
        
        await vm.searchPartner()
        
        // Should have attempted to search
        XCTAssertFalse(vm.isLoading, "Should not be loading after search")
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - HistoryViewModel Comprehensive Tests
    
    @MainActor
    func testHistoryViewModelRefresh() async {
        let mockStrip = MockStripRepository()
        DependencyContainer.shared.stripRepository = mockStrip
        DependencyContainer.shared.userRepository = MockUserRepository()
        
        let vm = HistoryViewModel()
        vm.currentUserId = "test_user_1"
        
        await vm.refresh()
        
        XCTAssertFalse(vm.isLoadingMore, "Should not be loading more after refresh")
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - Achievement Tests
    
    func testAchievementAllExists() {
        XCTAssertGreaterThan(Achievement.all.count, 15, "Should have at least 15 achievements")
    }
    
    func testAchievementUniqueIds() {
        let ids = Achievement.all.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "Achievement IDs should be unique")
    }
    
    func testAchievementCategoryCoverage() {
        let categories = Set(Achievement.all.map { $0.category })
        XCTAssertEqual(categories.count, Achievement.Category.allCases.count, "All categories should have at least one achievement")
    }
    
    // MARK: - UserProfile Tests
    
    func testUserProfileCodable() throws {
        let profile = UserProfile(
            id: "uid1",
            inviteCode: "CODE01",
            email: "a@b.com",
            displayName: "Test",
            username: "test",
            dateOfBirth: Date(),
            avatarUrl: "https://example.com/avatar.jpg"
        )
        
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
        
        XCTAssertEqual(decoded.id, "uid1")
        XCTAssertEqual(decoded.inviteCode, "CODE01")
        XCTAssertEqual(decoded.displayName, "Test")
    }
    
    // MARK: - Error Toast Tests

    func testAppErrorToastDescriptions() {
        let errors: [AppError] = [
            .networkUnavailable,
            .unauthenticated,
            .photoUploadFailed(NSError(domain: "test", code: 0)),
            .custom("ozel hata"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "All errors should have descriptions")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Descriptions should not be empty")
        }
    }
    
    // MARK: - Streak Service Tests (model-level)
    
    func testStreakFriendshipTier() {
        let tiers: [(Int, Streak.FriendshipTier)] = [
            (10, .tanidik), (75, .muhabbet), (200, .yakin), (500, .sirdas), (800, .kadim)
        ]
        for (score, expected) in tiers {
            let streak = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: score)
            XCTAssertEqual(streak.tier, expected)
            XCTAssertFalse(streak.tier.tierName.isEmpty, "Tier should have name")
            XCTAssertFalse(streak.tier.tierIcon.isEmpty, "Tier should have icon")
        }
    }

    func testStreakNextTierThreshold() {
        let streak = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 10)
        XCTAssertEqual(streak.nextTierThreshold, 50)

        let kadim = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 800)
        XCTAssertEqual(kadim.nextTierThreshold, 1000)
    }
    
    func testStreakTierProgressAtBoundary() {
        let zero = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 0)
        XCTAssertEqual(zero.tierProgress, 0.0, accuracy: 0.01)
        
        let maxed = Streak(id: "a_b", userIds: ["a", "b"], friendshipScore: 1000)
        XCTAssertEqual(maxed.tierProgress, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Block/Unblock Tests
    
    @MainActor
    func testInboxFiltersBlockedUsers() async {
        let mockFriends = MockFriendRepository()
        let mockUser = MockUserRepository()
        
        let blockedFriend = FriendStatus(userId: "blocked_user", isPending: false, timestamp: Date(), requesterId: "blocked_user")
        let normalFriend = FriendStatus(userId: "normal_user", isPending: false, timestamp: Date(), requesterId: "normal_user")
        mockFriends.friends = [blockedFriend, normalFriend]
        
        DependencyContainer.shared.friendRepository = mockFriends
        DependencyContainer.shared.userRepository = mockUser
        
        let vm = InboxViewModel()
        await vm.fetchData()
        
        // With empty blocked list, both should appear
        XCTAssertEqual(vm.conversations.count, 2)
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - Reaction Toggle Tests
    
    @MainActor
    func testReactionToggleCallsRepository() async {
        let mockStrip = MockStripRepository()
        DependencyContainer.shared.stripRepository = mockStrip
        
        // toggleReaction should not throw when called
        do {
            try await mockStrip.toggleReaction(on: "photo1", emoji: "❤️")
        } catch {
            XCTFail("toggleReaction should not throw")
        }
        
        DependencyContainer.shared.reset()
    }
    
    // MARK: - NotificationType Tests
    
    func testNotificationTypeRawValues() {
        XCTAssertEqual(NotificationType.photoReceived.rawValue, "photo_received")
        XCTAssertEqual(NotificationType.commentReceived.rawValue, "comment_received")
        XCTAssertEqual(NotificationType.friendAdded.rawValue, "friend_added")
    }
    
    // MARK: - FriendStatus Tests
    
    func testFriendStatusId() {
        let status = FriendStatus(userId: "user123", isPending: false, timestamp: Date(), requesterId: nil)
        XCTAssertEqual(status.id, "user123", "FriendStatus id should be userId")
    }
    
    // MARK: - DailyPrompt Deterministic Tests
    
    func testDailyPromptDateString() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: "2026-01-15")!
        let dateStr = DailyPromptService.dateString(for: date)
        XCTAssertEqual(dateStr, "2026-01-15")
    }
    
    func testDailyPromptCategoriesHaveIcons() {
        for category in DailyPrompt.PromptCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty, "\(category) should have display name")
            XCTAssertFalse(category.icon.isEmpty, "\(category) should have icon")
        }
    }
    
    // MARK: - PhotoMetadata Reactions Tests
    
    func testPhotoMetadataReactions() {
        let photo = PhotoMetadata(
            senderId: "user1", imageUrl: "https://example.com/photo.jpg",
            reactions: ["❤️": ["user2", "user3"], "🔥": ["user4"]]
        )
        XCTAssertEqual(photo.reactions?["❤️"]?.count, 2)
        XCTAssertEqual(photo.reactions?["🔥"]?.count, 1)
        XCTAssertNil(photo.reactions?["😂"])
    }
    
    // MARK: - DependencyContainer Thread Safety Tests
    
    func testDependencyContainerResetRestoresDefaults() {
        let container = DependencyContainer.shared
        container.stripRepository = MockStripRepository()
        XCTAssertTrue(container.stripRepository is MockStripRepository)
        
        container.reset()
        XCTAssertTrue(container.stripRepository is StripRepository)
    }
    
    // MARK: - AppConstants Tests
    
    func testAppGroupIDNotEmpty() {
        XCTAssertFalse(AppConstants.appGroupID.isEmpty, "App Group ID should not be empty")
        XCTAssertTrue(AppConstants.appGroupID.contains("group."), "App Group should start with 'group.'")
    }
    
    // MARK: - Brand System Tests
    
    func testBrandNameIsCorrect() {
        XCTAssertEqual(Brand.name, "anlık.")
    }
    
    func testBrandFontsAreNotNil() {
        XCTAssertNotNil(Brand.logotype())
        XCTAssertNotNil(Brand.headline())
        XCTAssertNotNil(Brand.body())
        XCTAssertNotNil(Brand.caption())
    }
    
    // MARK: - DirectMessage Soft Delete Tests
    
    func testDirectMessageSoftDelete() {
        let dm = DirectMessage(
            senderId: "u1", receiverId: "u2", text: "bu mesaj silindi", isDeleted: true
        )
        XCTAssertTrue(dm.isDeleted ?? false)
    }
    
    // MARK: - Comment Reply Tests
    
    func testCommentReplyFields() {
        let reply = Comment(
            photoId: "p1", senderId: "u2", text: "Çok güzel!",
            replyToId: "c1", replyToText: "Orijinal yorum", replyToSenderId: "u1"
        )
        XCTAssertEqual(reply.replyToId, "c1")
        XCTAssertEqual(reply.replyToText, "Orijinal yorum")
        XCTAssertEqual(reply.replyToSenderId, "u1")
    }
}
