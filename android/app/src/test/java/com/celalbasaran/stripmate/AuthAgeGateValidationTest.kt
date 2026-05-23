package com.celalbasaran.stripmate

import android.net.Uri
import com.celalbasaran.stripmate.data.model.Friend
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.ui.screen.auth.AuthViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import java.util.Calendar
import java.util.Date

@OptIn(ExperimentalCoroutinesApi::class)
class AuthAgeGateValidationTest {
    private val testDispatcher = UnconfinedTestDispatcher()

    @Before
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun signupRejectsUsersYoungerThan16() = runTest {
        val viewModel = AuthViewModel(
            authRepository = FakeAuthRepository(),
            friendshipRepository = FakeFriendshipRepository()
        )
        val under16 = Calendar.getInstance().apply { add(Calendar.YEAR, -15) }.time

        viewModel.updateEmail("test@example.com")
        viewModel.updatePassword("123456")
        viewModel.updateConfirmPassword("123456")
        viewModel.updateDisplayName("Test")
        viewModel.updateUsername("testuser")
        viewModel.updateDateOfBirth(under16)
        viewModel.signup()

        assertEquals(
            "kayıt için en az 16 yaşında olmalısın",
            viewModel.uiState.value.error
        )
    }
}

private class FakeAuthRepository : AuthRepository {
    override suspend fun login(email: String, password: String): Result<UserProfile> = Result.failure(Exception("unused"))
    override suspend fun signup(
        email: String,
        password: String,
        displayName: String,
        username: String,
        dateOfBirth: Date
    ): Result<UserProfile> = Result.success(UserProfile(id = "1", inviteCode = "ABCDEFGH"))
    override suspend fun signInWithGoogle(idToken: String): Result<UserProfile> = Result.failure(Exception("unused"))
    override suspend fun fetchProfile(uid: String): UserProfile? = null
    override suspend fun updateProfile(data: Map<String, Any>) {}
    override suspend fun uploadAvatar(uri: Uri): String = ""
    override suspend fun logout() {}
    override suspend fun deleteAccount() {}
    override suspend fun generateInviteCode(): String = "ABCDEFGH"
    override suspend fun searchUserByCode(code: String): UserProfile? = null
    override suspend fun searchUserByUsername(username: String): UserProfile? = null
    override fun isLoggedIn(): Boolean = false
    override fun currentUserId(): String? = null
    override suspend fun persistFCMToken() {}
    override suspend fun fetchBlockedUserIds(): Set<String> = emptySet()
    override suspend fun blockUser(userId: String) {}
    override suspend fun unblockUser(userId: String) {}
    override suspend fun reportUser(userId: String, reason: String) {}
    override suspend fun reportContent(contentType: String, contentId: String, contentOwnerId: String, reason: String) {}
    override fun needsProfileCompletion(): Boolean = false
    override suspend fun resetPassword(email: String) {}
}

private class FakeFriendshipRepository : FriendshipRepository {
    override suspend fun fetchFriends(): List<Friend> = emptyList()
    override suspend fun sendFriendRequest(toUserId: String) {}
    override suspend fun acceptFriendRequest(fromUserId: String) {}
    override suspend fun declineFriendRequest(fromUserId: String) {}
    override suspend fun removeFriend(userId: String) {}
    override suspend fun fetchPendingIncomingRequests(): List<Friend> = emptyList()
    override suspend fun getPendingCount(): Int = 0
    override suspend fun hasAnyFriendship(): Boolean = false
    override suspend fun hasAcceptedFriends(): Boolean = false
}
