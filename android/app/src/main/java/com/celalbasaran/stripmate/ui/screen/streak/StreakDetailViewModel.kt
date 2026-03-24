package com.celalbasaran.stripmate.ui.screen.streak

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Streak
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.streak.StreakRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class StreakDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val streakRepository: StreakRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val userId: String = savedStateHandle["userId"] ?: ""

    private val _streak = MutableStateFlow<Streak?>(null)
    val streak = _streak.asStateFlow()

    private val _friendProfile = MutableStateFlow<UserProfile?>(null)
    val friendProfile = _friendProfile.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading = _isLoading.asStateFlow()

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            try {
                _friendProfile.value = authRepository.fetchProfile(userId)
                _streak.value = streakRepository.getStreak(userId)
            } catch (_: Exception) {
            } finally {
                _isLoading.value = false
            }
        }
    }
}
