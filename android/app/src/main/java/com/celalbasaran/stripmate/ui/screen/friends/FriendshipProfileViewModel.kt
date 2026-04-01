package com.celalbasaran.stripmate.ui.screen.friends

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
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import javax.inject.Inject

data class FriendshipStats(
    val firstPhotoDate: Date? = null,
    val totalPhotos: Int = 0,
    val sentPhotos: Int = 0,
    val receivedPhotos: Int = 0,
    val mostActiveDay: String = "-",
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val monthlyActivity: List<MonthlyCount> = emptyList()
)

data class MonthlyCount(
    val monthLabel: String,
    val count: Int
)

data class FriendshipProfileUiState(
    val myProfile: UserProfile? = null,
    val friendProfile: UserProfile? = null,
    val stats: FriendshipStats = FriendshipStats(),
    val sharedPhotos: List<Strip> = emptyList(),
    val displayedPhotos: List<Strip> = emptyList(),
    val hasMorePhotos: Boolean = false,
    val isLoadingMore: Boolean = false,
    val isLoading: Boolean = true
)

@HiltViewModel
class FriendshipProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val photoRepository: PhotoRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(FriendshipProfileUiState())
    val uiState: StateFlow<FriendshipProfileUiState> = _uiState.asStateFlow()

    private val pageSize = 30
    private val turkishDays = listOf("pazartesi", "sali", "carsamba", "persembe", "cuma", "cumartesi", "pazar")
    private val turkishMonths = listOf("oca", "sub", "mar", "nis", "may", "haz", "tem", "agu", "eyl", "eki", "kas", "ara")

    fun loadFriendship(friendId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                val currentUserId = authRepository.currentUserId() ?: return@launch
                val myProfile = authRepository.fetchProfile(currentUserId)
                val friendProfile = authRepository.fetchProfile(friendId)

                _uiState.update { it.copy(myProfile = myProfile, friendProfile = friendProfile) }

                photoRepository.listenToHistory(currentUserId).collect { allStrips ->
                    val shared = allStrips.filter { strip ->
                        (strip.senderId == currentUserId && friendId in strip.receiverIds) ||
                                (strip.senderId == friendId && currentUserId in strip.receiverIds)
                    }.sortedByDescending { it.timestamp }

                    val stats = computeStats(shared, currentUserId)
                    val displayed = shared.take(pageSize)

                    _uiState.update {
                        it.copy(
                            sharedPhotos = shared,
                            displayedPhotos = displayed,
                            hasMorePhotos = shared.size > pageSize,
                            stats = stats,
                            isLoading = false
                        )
                    }
                }
            } catch (_: Exception) {
                _uiState.update { it.copy(isLoading = false) }
            }
        }
    }

    fun loadMorePhotos() {
        val state = _uiState.value
        if (state.isLoadingMore || !state.hasMorePhotos) return

        _uiState.update { it.copy(isLoadingMore = true) }

        val currentCount = state.displayedPhotos.size
        val endIndex = minOf(currentCount + pageSize, state.sharedPhotos.size)
        val next = state.sharedPhotos.subList(currentCount, endIndex)

        _uiState.update {
            val newDisplayed = it.displayedPhotos + next
            it.copy(
                displayedPhotos = newDisplayed,
                hasMorePhotos = newDisplayed.size < it.sharedPhotos.size,
                isLoadingMore = false
            )
        }
    }

    private fun computeStats(strips: List<Strip>, currentUserId: String): FriendshipStats {
        if (strips.isEmpty()) return FriendshipStats()

        val sorted = strips.sortedBy { it.timestamp }
        val firstDate = sorted.firstOrNull()?.timestamp

        val sentPhotos = strips.count { it.senderId == currentUserId }
        val receivedPhotos = strips.size - sentPhotos

        // Most active day of week
        val dayCounter = IntArray(7)
        val calendar = Calendar.getInstance()
        for (strip in strips) {
            calendar.time = strip.timestamp
            val dayOfWeek = (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Monday = 0
            dayCounter[dayOfWeek]++
        }
        val mostActiveDayIndex = dayCounter.indices.maxByOrNull { dayCounter[it] } ?: 0
        val mostActiveDay = turkishDays[mostActiveDayIndex]

        // Streaks: consecutive days with at least one photo
        val daySet = strips.map { strip ->
            val cal = Calendar.getInstance()
            cal.time = strip.timestamp
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            cal.timeInMillis
        }.toSortedSet()

        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 0
        var previousDay: Long? = null
        val oneDayMs = 86400000L

        for (day in daySet) {
            if (previousDay != null && day - previousDay == oneDayMs) {
                tempStreak++
            } else {
                tempStreak = 1
            }
            if (tempStreak > longestStreak) longestStreak = tempStreak
            previousDay = day
        }

        // Check if current streak is active (today or yesterday)
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        if (daySet.contains(today) || daySet.contains(today - oneDayMs)) {
            var streak = 0
            var checkDay = if (daySet.contains(today)) today else today - oneDayMs
            while (daySet.contains(checkDay)) {
                streak++
                checkDay -= oneDayMs
            }
            currentStreak = streak
        }

        // Monthly activity (last 6 months)
        val monthlyActivity = mutableListOf<MonthlyCount>()
        val now = Calendar.getInstance()
        for (i in 5 downTo 0) {
            val cal = Calendar.getInstance()
            cal.time = now.time
            cal.add(Calendar.MONTH, -i)
            val month = cal.get(Calendar.MONTH)
            val year = cal.get(Calendar.YEAR)
            val count = strips.count { strip ->
                val sCal = Calendar.getInstance()
                sCal.time = strip.timestamp
                sCal.get(Calendar.MONTH) == month && sCal.get(Calendar.YEAR) == year
            }
            monthlyActivity.add(MonthlyCount(turkishMonths[month], count))
        }

        return FriendshipStats(
            firstPhotoDate = firstDate,
            totalPhotos = strips.size,
            sentPhotos = sentPhotos,
            receivedPhotos = receivedPhotos,
            mostActiveDay = mostActiveDay,
            currentStreak = currentStreak,
            longestStreak = longestStreak,
            monthlyActivity = monthlyActivity
        )
    }

    fun formatDate(date: Date): String {
        val formatter = SimpleDateFormat("d MMM yyyy", Locale("tr"))
        return formatter.format(date)
    }
}
