package com.celalbasaran.stripmate.ui.screen.recap

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.data.model.recap.MonthlySummary
import com.celalbasaran.stripmate.data.model.recap.RecapComputer
import com.celalbasaran.stripmate.data.model.recap.WeeklySummary
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SummariesViewModel @Inject constructor(
    private val photoRepository: PhotoRepository,
    private val authRepository: AuthRepository,
    private val friendshipRepository: FriendshipRepository
) : ViewModel() {

    private val _weeklySummaries = MutableStateFlow<List<WeeklySummary>>(emptyList())
    val weeklySummaries: StateFlow<List<WeeklySummary>> = _weeklySummaries.asStateFlow()

    private val _monthlySummaries = MutableStateFlow<List<MonthlySummary>>(emptyList())
    val monthlySummaries: StateFlow<List<MonthlySummary>> = _monthlySummaries.asStateFlow()

    private val _allStrips = MutableStateFlow<List<Strip>>(emptyList())
    val allStrips: StateFlow<List<Strip>> = _allStrips.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    val currentUserId: String?
        get() = authRepository.currentUserId()

    init {
        loadSummaries()
    }

    private fun loadSummaries() {
        val userId = authRepository.currentUserId() ?: return
        viewModelScope.launch {
            // Arkadaş isim cache'i oluştur
            val friendNameCache = mutableMapOf<String, String>()
            try {
                val friends = friendshipRepository.fetchFriends()
                friends.forEach { friend ->
                    val name = friend.profile?.displayName ?: friend.profile?.username
                    if (name != null) {
                        friendNameCache[friend.userId] = name
                    }
                }
            } catch (_: Exception) { }

            // Fotoğraf geçmişini dinle
            photoRepository.listenToHistory(userId).collect { strips ->
                _allStrips.value = strips

                val weekly = RecapComputer.computeWeeklySummaries(
                    strips = strips,
                    currentUserId = userId,
                    friendNameCache = friendNameCache
                )
                _weeklySummaries.value = weekly

                _monthlySummaries.value = RecapComputer.computeMonthlySummaries(
                    strips = strips,
                    currentUserId = userId,
                    weeklySummaries = weekly,
                    friendNameCache = friendNameCache
                )

                _isLoading.value = false
            }
        }
    }

    /**
     * Belirli bir haftaya ait strip'leri filtrele.
     */
    fun stripsForWeek(summary: WeeklySummary): List<Strip> {
        val calendar = java.util.Calendar.getInstance()
        return _allStrips.value.filter { strip ->
            calendar.time = strip.timestamp
            val year = calendar.get(java.util.Calendar.YEAR)
            val week = calendar.get(java.util.Calendar.WEEK_OF_YEAR)
            year == summary.year && week == summary.weekNumber
        }
    }

    /**
     * Belirli bir aya ait strip'leri filtrele.
     */
    fun stripsForMonth(summary: MonthlySummary): List<Strip> {
        val calendar = java.util.Calendar.getInstance()
        return _allStrips.value.filter { strip ->
            calendar.time = strip.timestamp
            val year = calendar.get(java.util.Calendar.YEAR)
            val month = calendar.get(java.util.Calendar.MONTH) + 1
            year == summary.year && month == summary.month
        }
    }
}
