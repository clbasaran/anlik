package com.celalbasaran.stripmate.ui.screen.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Streak
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import com.celalbasaran.stripmate.service.streak.StreakRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FriendProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val friendshipRepository: FriendshipRepository,
    private val streakRepository: StreakRepository,
    private val photoRepository: PhotoRepository
) : ViewModel() {

    private val _profile = MutableStateFlow<UserProfile?>(null)
    val profile: StateFlow<UserProfile?> = _profile.asStateFlow()

    private val _streak = MutableStateFlow<Streak?>(null)
    val streak: StateFlow<Streak?> = _streak.asStateFlow()

    private val _sharedPhotos = MutableStateFlow<List<Strip>>(emptyList())
    val sharedPhotos: StateFlow<List<Strip>> = _sharedPhotos.asStateFlow()

    fun loadProfile(userId: String) {
        viewModelScope.launch {
            _profile.value = authRepository.fetchProfile(userId)
            _streak.value = streakRepository.getStreak(userId)

            val currentUserId = authRepository.currentUserId() ?: return@launch
            photoRepository.listenToHistory(currentUserId).collect { strips ->
                _sharedPhotos.value = strips.filter { strip ->
                    (strip.senderId == currentUserId && userId in strip.receiverIds) ||
                            (strip.senderId == userId && currentUserId in strip.receiverIds)
                }.sortedByDescending { it.timestamp }
            }
        }
    }

    fun removeFriend(userId: String) {
        viewModelScope.launch {
            friendshipRepository.removeFriend(userId)
        }
    }

    fun blockUser(userId: String) {
        viewModelScope.launch {
            authRepository.blockUser(userId)
        }
    }

    fun reportUser(userId: String) {
        viewModelScope.launch {
            authRepository.reportUser(userId, "Kullanici tarafindan raporlandi")
        }
    }
}
