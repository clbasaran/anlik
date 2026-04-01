package com.celalbasaran.stripmate.ui.screen.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.Date
import java.util.concurrent.TimeUnit
import javax.inject.Inject

data class MonthGroup(
    val year: Int,
    val month: Int,
    val strips: List<Strip>
)

@HiltViewModel
class SharedMomentsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val photoRepository: PhotoRepository
) : ViewModel() {

    private val _sharedPhotos = MutableStateFlow<List<Strip>>(emptyList())
    val sharedPhotos: StateFlow<List<Strip>> = _sharedPhotos.asStateFlow()

    private val _friendProfile = MutableStateFlow<UserProfile?>(null)
    val friendProfile: StateFlow<UserProfile?> = _friendProfile.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun loadSharedPhotos(friendUserId: String) {
        viewModelScope.launch {
            _isLoading.value = true

            // Load friend profile
            _friendProfile.value = authRepository.fetchProfile(friendUserId)

            val currentUserId = authRepository.currentUserId() ?: return@launch
            photoRepository.listenToHistory(currentUserId).collect { strips ->
                _sharedPhotos.value = strips.filter { strip ->
                    (strip.senderId == currentUserId && friendUserId in strip.receiverIds) ||
                            (strip.senderId == friendUserId && currentUserId in strip.receiverIds)
                }.sortedByDescending { it.timestamp }
                _isLoading.value = false
            }
        }
    }

    /** Group photos by year+month, sorted newest first */
    fun groupedByMonth(): List<MonthGroup> {
        val calendar = Calendar.getInstance()
        val grouped = _sharedPhotos.value.groupBy { strip ->
            calendar.time = strip.timestamp
            val year = calendar.get(Calendar.YEAR)
            val month = calendar.get(Calendar.MONTH)
            year to month
        }

        return grouped.entries
            .sortedByDescending { it.key.first * 100 + it.key.second }
            .map { (key, strips) ->
                MonthGroup(
                    year = key.first,
                    month = key.second,
                    strips = strips.sortedByDescending { it.timestamp }
                )
            }
    }

    /** Friendship duration string from earliest shared photo */
    fun friendshipDuration(): String? {
        val sorted = _sharedPhotos.value.sortedBy { it.timestamp }
        val firstDate = sorted.firstOrNull()?.timestamp ?: return null
        val now = Date()

        val diffMs = now.time - firstDate.time
        val days = TimeUnit.MILLISECONDS.toDays(diffMs)

        return when {
            days >= 365 -> "${days / 365} yil"
            days >= 30 -> "${days / 30} ay"
            else -> "${maxOf(days, 1)} gun"
        }
    }
}
