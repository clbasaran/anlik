package com.celalbasaran.stripmate.ui.screen.friends

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.service.streak.StreakRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class LeaderboardViewModel @Inject constructor(
    private val streakRepository: StreakRepository,
    private val friendshipRepository: FriendshipRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _entries = MutableStateFlow<List<LeaderboardEntry>>(emptyList())
    val entries: StateFlow<List<LeaderboardEntry>> = _entries.asStateFlow()

    init {
        loadLeaderboard()
    }

    private fun loadLeaderboard() {
        viewModelScope.launch {
            val currentUserId = authRepository.currentUserId() ?: return@launch
            val friends = friendshipRepository.fetchFriends().filter { !it.isPending }
            val streaks = streakRepository.getAllStreaksByScore()

            val entries = mutableListOf<LeaderboardEntry>()

            for (friend in friends) {
                val profile = friend.profile ?: authRepository.fetchProfile(friend.userId)
                val streak = streaks.firstOrNull { friend.userId in it.userIds }

                if (profile != null) {
                    entries.add(
                        LeaderboardEntry(
                            userId = friend.userId,
                            displayName = profile.displayName ?: profile.username ?: "",
                            avatarUrl = profile.avatarUrl,
                            streakCount = streak?.currentStreak ?: 0,
                            exchangeCount = streak?.totalExchanges ?: 0,
                            friendshipTier = streak?.friendshipTier
                                ?: com.celalbasaran.stripmate.data.model.FriendshipTier.TANIDIK,
                            isCurrentUser = false
                        )
                    )
                }
            }

            // Add current user
            val myProfile = authRepository.fetchProfile(currentUserId)
            if (myProfile != null) {
                val myBestStreak = streaks.filter { currentUserId in it.userIds }
                    .maxByOrNull { it.currentStreak }
                val myTotalExchanges = streaks.filter { currentUserId in it.userIds }
                    .sumOf { it.totalExchanges }

                entries.add(
                    LeaderboardEntry(
                        userId = currentUserId,
                        displayName = myProfile.displayName ?: myProfile.username ?: "",
                        avatarUrl = myProfile.avatarUrl,
                        streakCount = myBestStreak?.currentStreak ?: 0,
                        exchangeCount = myTotalExchanges,
                        friendshipTier = myBestStreak?.friendshipTier
                            ?: com.celalbasaran.stripmate.data.model.FriendshipTier.TANIDIK,
                        isCurrentUser = true
                    )
                )
            }

            _entries.value = entries
        }
    }
}
