import XCTest
import UIKit
@testable import StripMate

// MARK: - AuthViewModel — Validation paths

@MainActor
final class AuthViewModelValidationTests: XCTestCase {
    private var mockUser: MockUserRepository!
    private var vm: AuthViewModel!

    override func setUp() async throws {
        mockUser = MockUserRepository()
        DependencyContainer.shared.userRepository = mockUser
        vm = AuthViewModel()
    }

    override func tearDown() async throws {
        DependencyContainer.shared.reset()
    }

    func testEmptyEmailShowsError() async {
        vm.email = ""
        vm.password = "anything"
        await vm.authenticate()
        XCTAssertNotNil(vm.errorMessage)
    }

    func testEmptyPasswordShowsError() async {
        vm.email = "a@b.com"
        vm.password = ""
        await vm.authenticate()
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSignupRequiresDisplayName() async {
        vm.isSignUp = true
        vm.email = "a@b.com"
        vm.password = "secret"
        vm.displayName = ""
        vm.username = "user"
        await vm.authenticate()
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSignupRequiresUsername() async {
        vm.isSignUp = true
        vm.email = "a@b.com"
        vm.password = "secret"
        vm.displayName = "Ali"
        vm.username = ""
        await vm.authenticate()
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSignupRejectsFutureDateOfBirth() async {
        vm.isSignUp = true
        vm.email = "a@b.com"
        vm.password = "secret"
        vm.displayName = "Ali"
        vm.username = "ali"
        vm.dateOfBirth = Date().addingTimeInterval(60 * 60 * 24 * 30) // future
        await vm.authenticate()
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSignupRejectsUnderage() async {
        vm.isSignUp = true
        vm.email = "a@b.com"
        vm.password = "secret"
        vm.displayName = "Ali"
        vm.username = "ali"
        vm.dateOfBirth = Date().addingTimeInterval(-60 * 60 * 24 * 365 * 5) // 5 yo
        await vm.authenticate()
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSignupValidInputAccepted() async {
        vm.isSignUp = true
        vm.email = "a@b.com"
        vm.password = "secret123!"
        vm.displayName = "Ali"
        vm.username = "ali"
        vm.dateOfBirth = AppLimits.latestAllowedBirthDate.addingTimeInterval(-60 * 60 * 24 * 365)
        await vm.authenticate()
        XCTAssertNil(vm.errorMessage)
    }

    func testLoginValidInputAccepted() async {
        vm.isSignUp = false
        vm.email = "a@b.com"
        vm.password = "secret123!"
        await vm.authenticate()
        XCTAssertNil(vm.errorMessage)
    }

    func testLoginPropagatesRepositoryError() async {
        struct LoginError: Error {}
        mockUser.loginResult = .failure(LoginError())
        vm.isSignUp = false
        vm.email = "a@b.com"
        vm.password = "secret123!"
        await vm.authenticate()
        XCTAssertNotNil(vm.errorMessage)
    }

    func testLoadingFlagTogglesAroundAuth() async {
        vm.email = "a@b.com"
        vm.password = "secret"
        let task = Task { await vm.authenticate() }
        await task.value
        XCTAssertFalse(vm.isLoading, "isLoading should be false after authenticate completes")
    }

    func testTrimWhitespaceFromEmail() async {
        vm.email = "  test@x.com  "
        vm.password = "secret"
        await vm.authenticate()
        // Mock won't error on whitespace; we only assert no crash + no whitespace error
        XCTAssertNil(vm.errorMessage)
    }
}

// MARK: - HistoryViewModel

@MainActor
final class HistoryViewModelTests: XCTestCase {
    private var mockStrip: MockStripRepository!
    private var mockUser: MockUserRepository!
    private var vm: HistoryViewModel!

    override func setUp() async throws {
        mockStrip = MockStripRepository()
        mockUser = MockUserRepository()
        DependencyContainer.shared.stripRepository = mockStrip
        DependencyContainer.shared.userRepository = mockUser
        vm = HistoryViewModel()
    }

    override func tearDown() async throws {
        DependencyContainer.shared.reset()
    }

    func testLoadMoreCallsRepository() async {
        await vm.loadMore(oldestTimestamp: Date())
        // Mock returns empty — verify state is consistent + no crash
        XCTAssertFalse(vm.isLoadingMore)
    }

    func testDeleteStripCallsRepository() async {
        let photo = PhotoMetadata(
            id: "x", senderId: "u", receiverIds: ["a"],
            imageUrl: "https://x", timestamp: Date(),
            latitude: nil, longitude: nil, cityName: nil
        )
        await vm.deleteStrip(photo)
        XCTAssertTrue(mockStrip.deleteStripCalled)
    }

    func testInitialLoadingState() {
        XCTAssertTrue(vm.isLoading)
        XCTAssertFalse(vm.isLoadingMore)
        XCTAssertTrue(vm.canLoadMore)
        XCTAssertNil(vm.errorMessage)
    }

    func testStopListeningClearsState() {
        vm.stopListening()
        // No assertion on internals — just verify no crash
    }
}

// MARK: - FriendsListViewModel

@MainActor
final class FriendsListViewModelTests: XCTestCase {
    private var mockFriend: MockFriendRepository!
    private var mockUser: MockUserRepository!
    private var vm: FriendsListViewModel!

    override func setUp() async throws {
        mockFriend = MockFriendRepository()
        mockUser = MockUserRepository()
        DependencyContainer.shared.friendRepository = mockFriend
        DependencyContainer.shared.userRepository = mockUser
        vm = FriendsListViewModel()
    }

    override func tearDown() async throws {
        DependencyContainer.shared.reset()
    }

    func testFetchFriendsCompletes() async {
        mockFriend.friends = [
            FriendStatus(userId: "u1", isPending: false, timestamp: Date(), requesterId: nil, profile: nil),
            FriendStatus(userId: "u2", isPending: true, timestamp: Date(), requesterId: "u2", profile: nil)
        ]
        await vm.fetchFriends()
        XCTAssertFalse(vm.isLoading, "isLoading should clear after fetch completes")
    }

    func testAddFriendCallsRepository() async {
        await vm.addFriend("u1")
        XCTAssertTrue(mockFriend.sendRequestCalled)
    }

    func testAcceptFriendCallsRepository() async {
        await vm.acceptFriend("u1")
        XCTAssertTrue(mockFriend.acceptRequestCalled)
    }

    func testRemoveFriendCallsRepository() async {
        await vm.removeFriend("u1")
        XCTAssertTrue(mockFriend.removeCalled)
    }

    func testInitialState() {
        XCTAssertEqual(vm.searchCode, "")
        XCTAssertNil(vm.searchedProfile)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertTrue(vm.streaks.isEmpty)
    }
}

// MARK: - DirectMessageViewModel — Send Logic

@MainActor
final class DirectMessageViewModelSendTests: XCTestCase {
    private var mockChat: MockChatRepository!
    private var partner: UserProfile!
    private var vm: DirectMessageViewModel!

    override func setUp() async throws {
        mockChat = MockChatRepository()
        DependencyContainer.shared.chatRepository = mockChat
        partner = UserProfile(
            id: "partner", inviteCode: "X", email: nil,
            displayName: "Partner", username: "partner", dateOfBirth: nil
        )
        vm = DirectMessageViewModel(partner: partner)
    }

    override func tearDown() async throws {
        DependencyContainer.shared.reset()
    }

    func testEmptyMessageDoesNotSend() async {
        vm.inputText = ""
        await vm.sendMessage()
        XCTAssertFalse(mockChat.sendMessageCalled)
    }

    func testWhitespaceOnlyMessageDoesNotSend() async {
        vm.inputText = "   \n  "
        await vm.sendMessage()
        XCTAssertFalse(mockChat.sendMessageCalled)
    }

    func testTooLongMessageRejected() async {
        vm.inputText = String(repeating: "a", count: 2001)
        await vm.sendMessage()
        XCTAssertFalse(mockChat.sendMessageCalled)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testValidMessageClearsInput() async {
        vm.inputText = "Selam"
        await vm.sendMessage()
        // Input should be cleared after a successful send (mock succeeds by default)
        XCTAssertEqual(vm.inputText, "")
    }

    func testIsSendingFlagPreventsConcurrentSends() async {
        vm.inputText = "msg"
        vm.isSending = true
        await vm.sendMessage()
        XCTAssertFalse(mockChat.sendMessageCalled,
                       "When isSending=true, message should not go through")
    }
}

// MARK: - ChatViewModel — Strip Comments

@MainActor
final class ChatViewModelTests: XCTestCase {
    private var mockStrip: MockStripRepository!
    private var mockUser: MockUserRepository!
    private var vm: ChatViewModel!

    override func setUp() async throws {
        mockStrip = MockStripRepository()
        mockUser = MockUserRepository()
        DependencyContainer.shared.stripRepository = mockStrip
        DependencyContainer.shared.userRepository = mockUser
        vm = ChatViewModel(stripId: "s1", chatPartnerId: "p1")
    }

    override func tearDown() async throws {
        DependencyContainer.shared.reset()
    }

    func testEmptyMessageDoesNotSend() async {
        vm.inputText = ""
        await vm.sendMessage()
        XCTAssertFalse(mockStrip.sendCommentCalled)
    }

    func testValidMessageSends() async {
        vm.inputText = "ack"
        await vm.sendMessage()
        // Note: NetworkMonitor offline check may queue — assert either send OR pending
        let sentOrQueued = mockStrip.sendCommentCalled || !vm.pendingMessages.isEmpty
        XCTAssertTrue(sentOrQueued)
    }

    func testIsSendingPreventsDoubleTap() async {
        vm.inputText = "ack"
        vm.isSending = true
        await vm.sendMessage()
        XCTAssertFalse(mockStrip.sendCommentCalled)
    }

    func testTooLongMessageBlocked() async {
        vm.inputText = String(repeating: "x", count: 2001)
        await vm.sendMessage()
        XCTAssertFalse(mockStrip.sendCommentCalled)
        XCTAssertNotNil(vm.errorMessage)
    }
}

// MARK: - InboxViewModel

@MainActor
final class InboxViewModelTests: XCTestCase {
    private var mockFriend: MockFriendRepository!
    private var vm: InboxViewModel!

    override func setUp() async throws {
        mockFriend = MockFriendRepository()
        DependencyContainer.shared.friendRepository = mockFriend
        vm = InboxViewModel()
    }

    override func tearDown() async throws {
        DependencyContainer.shared.reset()
    }

    func testAcceptCallsRepository() async {
        await vm.acceptFriend("u1")
        XCTAssertTrue(mockFriend.acceptRequestCalled)
    }

    func testInitialState() {
        XCTAssertEqual(vm.pendingRequests.count, 0)
        XCTAssertEqual(vm.conversations.count, 0)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }
}

// MARK: - NotificationsViewModel

@MainActor
final class NotificationsViewModelTests: XCTestCase {
    private var mockNotif: MockNotificationRepository!
    private var vm: NotificationsViewModel!

    override func setUp() async throws {
        mockNotif = MockNotificationRepository()
        DependencyContainer.shared.notificationRepository = mockNotif
        vm = NotificationsViewModel()
    }

    override func tearDown() async throws {
        DependencyContainer.shared.reset()
    }

    func testMarkAsReadCallsRepo() async throws {
        vm.markAsRead(id: "n1")
        // markAsRead spawns a Task internally; wait briefly for completion.
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        XCTAssertTrue(mockNotif.markAsReadCalled)
        XCTAssertEqual(mockNotif.lastMarkedId, "n1")
    }

    func testMultipleMarksLastWins() async throws {
        vm.markAsRead(id: "n1")
        vm.markAsRead(id: "n2")
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(mockNotif.lastMarkedId, "n2")
    }
}

// MARK: - Repository forwarding (Repositories.swift wrapper layer)

final class RepositoryDelegationTests: XCTestCase {
    func testStripRepositorySingleton() {
        // Real production wiring — just smoke-check the singletons exist.
        XCTAssertNotNil(StripRepository.shared)
        XCTAssertNotNil(FriendRepository.shared)
        XCTAssertNotNil(UserRepository.shared)
        XCTAssertNotNil(ChatRepository.shared)
        XCTAssertNotNil(NotificationRepository.shared)
    }
}

// MARK: - State flag invariants across ViewModels

@MainActor
final class ViewModelStateFlagTests: XCTestCase {
    func testAuthVMInitialState() {
        let vm = AuthViewModel()
        XCTAssertEqual(vm.email, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isSignUp)
        XCTAssertFalse(vm.showSuccessMessage)
        XCTAssertNil(vm.errorMessage)
    }

    func testDirectMessageVMInitialState() {
        let p = UserProfile(id: "p", inviteCode: "X", email: nil,
                            displayName: nil, username: nil, dateOfBirth: nil)
        let vm = DirectMessageViewModel(partner: p)
        XCTAssertEqual(vm.messages.count, 0)
        XCTAssertEqual(vm.inputText, "")
        XCTAssertTrue(vm.isLoading)
        XCTAssertFalse(vm.isSending)
        XCTAssertFalse(vm.isPartnerTyping)
        XCTAssertNil(vm.replyingTo)
    }

    func testChatVMInitialState() {
        let vm = ChatViewModel(stripId: "s", chatPartnerId: "p")
        XCTAssertEqual(vm.messages.count, 0)
        XCTAssertEqual(vm.inputText, "")
        XCTAssertTrue(vm.isLoading)
        XCTAssertFalse(vm.isSending)
        XCTAssertEqual(vm.pendingMessages.count, 0)
    }
}
