package com.celalbasaran.stripmate.ui.screen.friends

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Friend
import com.celalbasaran.stripmate.data.model.Streak
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.service.streak.StreakRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class FriendsUiState(
    val friends: List<Friend> = emptyList(),
    val streaks: Map<String, Streak> = emptyMap(),
    val pendingRequests: List<Friend> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val myInviteCode: String = "",
    val searchCode: String = "",
    val searchedProfile: UserProfile? = null,
    val isSearching: Boolean = false,
    val errorMessage: String? = null,
    val searchError: String? = null
)

@HiltViewModel
class FriendsViewModel @Inject constructor(
    private val friendshipRepository: FriendshipRepository,
    private val streakRepository: StreakRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(FriendsUiState())
    val uiState: StateFlow<FriendsUiState> = _uiState.asStateFlow()

    init {
        loadInitialData()
    }

    private fun loadInitialData() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            // Load invite code
            val uid = authRepository.currentUserId()
            if (uid != null) {
                val profile = authRepository.fetchProfile(uid)
                _uiState.update { it.copy(myInviteCode = profile?.inviteCode ?: "") }
            }

            fetchFriends()
            fetchPendingRequests()
            _uiState.update { it.copy(isLoading = false) }
        }
    }

    fun fetchFriends() {
        viewModelScope.launch {
            try {
                val friends = friendshipRepository.fetchFriends()
                    .filter { !it.isPending }
                _uiState.update { it.copy(friends = friends) }

                // Load streaks for each friend
                loadStreaks(friends)
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.localizedMessage) }
            }
        }
    }

    private fun loadStreaks(friends: List<Friend>) {
        viewModelScope.launch {
            val streaksMap = mutableMapOf<String, Streak>()
            for (friend in friends) {
                try {
                    val streak = streakRepository.getStreak(friend.userId)
                    if (streak != null) {
                        streaksMap[friend.userId] = streak
                    }
                } catch (_: Exception) { }
            }
            _uiState.update { it.copy(streaks = streaksMap) }
        }
    }

    fun fetchPendingRequests() {
        viewModelScope.launch {
            try {
                val requests = friendshipRepository.fetchPendingIncomingRequests()
                _uiState.update { it.copy(pendingRequests = requests) }
            } catch (_: Exception) { }
        }
    }

    fun refresh() {
        viewModelScope.launch {
            _uiState.update { it.copy(isRefreshing = true) }
            fetchFriends()
            fetchPendingRequests()
            _uiState.update { it.copy(isRefreshing = false) }
        }
    }

    fun updateSearchCode(code: String) {
        if (code.length <= 8) {
            _uiState.update { it.copy(searchCode = code.uppercase(), searchError = null) }
        }
    }

    fun searchByCode() {
        val code = _uiState.value.searchCode.trim()
        if (code.length != 8) {
            _uiState.update { it.copy(searchError = "Davet kodu 8 haneli olmali") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isSearching = true, searchError = null, searchedProfile = null) }
            try {
                val user = authRepository.searchUserByCode(code)
                if (user != null) {
                    _uiState.update { it.copy(isSearching = false, searchedProfile = user) }
                } else {
                    _uiState.update { it.copy(isSearching = false, searchError = "Kullanici bulunamadi") }
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(isSearching = false, searchError = e.localizedMessage ?: "Arama basarisiz")
                }
            }
        }
    }

    fun sendRequest(userId: String) {
        viewModelScope.launch {
            try {
                friendshipRepository.sendFriendRequest(userId)
                _uiState.update {
                    it.copy(
                        searchedProfile = null,
                        searchCode = "",
                        errorMessage = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.localizedMessage) }
            }
        }
    }

    fun acceptRequest(userId: String) {
        viewModelScope.launch {
            try {
                friendshipRepository.acceptFriendRequest(userId)
                fetchPendingRequests()
                fetchFriends()
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.localizedMessage) }
            }
        }
    }

    fun declineRequest(userId: String) {
        viewModelScope.launch {
            try {
                friendshipRepository.declineFriendRequest(userId)
                fetchPendingRequests()
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.localizedMessage) }
            }
        }
    }

    fun removeFriend(userId: String) {
        viewModelScope.launch {
            try {
                friendshipRepository.removeFriend(userId)
                fetchFriends()
            } catch (e: Exception) {
                _uiState.update { it.copy(errorMessage = e.localizedMessage) }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(errorMessage = null) }
    }
}
