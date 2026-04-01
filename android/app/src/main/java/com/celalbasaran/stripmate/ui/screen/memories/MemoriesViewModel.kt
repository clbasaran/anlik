package com.celalbasaran.stripmate.ui.screen.memories

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
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

enum class MemoryPeriod(val label: String) {
    THIS_WEEK("bu hafta"),
    THIS_MONTH("bu ay"),
    ALL_TIME("tum zamanlar")
}

enum class PlaybackSpeed(val label: String, val intervalMs: Long) {
    FAST("2sn", 2000L),
    NORMAL("3sn", 3000L),
    SLOW("5sn", 5000L)
}

data class MemoriesUiState(
    val strips: List<Strip> = emptyList(),
    val filteredStrips: List<Strip> = emptyList(),
    val currentIndex: Int = 0,
    val selectedPeriod: MemoryPeriod = MemoryPeriod.ALL_TIME,
    val playbackSpeed: PlaybackSpeed = PlaybackSpeed.NORMAL,
    val isPlaying: Boolean = true,
    val isLoading: Boolean = true,
    val senderNames: Map<String, String> = emptyMap(),
    val segmentProgress: Float = 0f
)

@HiltViewModel
class MemoriesViewModel @Inject constructor(
    private val photoRepository: PhotoRepository,
    private val authRepository: AuthRepository,
    @ApplicationContext private val appContext: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(MemoriesUiState())
    val uiState: StateFlow<MemoriesUiState> = _uiState.asStateFlow()

    private var autoAdvanceJob: Job? = null
    val currentUserId: String? get() = _currentUserId
    private var _currentUserId: String? = null

    companion object {
        private const val TICK_INTERVAL_MS = 16L // ~60fps
    }

    init {
        loadMemories()
    }

    private fun loadMemories() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            try {
                _currentUserId = authRepository.currentUserId()
                val userId = _currentUserId ?: return@launch

                photoRepository.listenToHistory(userId).collect { strips ->
                    val sorted = strips.sortedByDescending { it.timestamp }
                    val names = mutableMapOf<String, String>()
                    sorted.map { it.senderId }.distinct().forEach { senderId ->
                        try {
                            val profile = authRepository.fetchProfile(senderId)
                            if (profile != null) {
                                names[senderId] = profile.displayName ?: profile.username ?: senderId
                            }
                        } catch (_: Exception) {}
                    }

                    _uiState.update { state ->
                        val filtered = filterStrips(sorted, state.selectedPeriod)
                        state.copy(
                            strips = sorted,
                            filteredStrips = filtered,
                            isLoading = false,
                            senderNames = names,
                            currentIndex = 0,
                            segmentProgress = 0f
                        )
                    }
                    startAutoAdvance()
                }
            } catch (_: Exception) {
                _uiState.update { it.copy(isLoading = false) }
            }
        }
    }

    fun selectPeriod(period: MemoryPeriod) {
        _uiState.update { state ->
            val filtered = filterStrips(state.strips, period)
            state.copy(
                selectedPeriod = period,
                filteredStrips = filtered,
                currentIndex = 0,
                segmentProgress = 0f
            )
        }
        if (_uiState.value.isPlaying) startAutoAdvance()
    }

    fun setPlaybackSpeed(speed: PlaybackSpeed) {
        _uiState.update { it.copy(playbackSpeed = speed, segmentProgress = 0f) }
        if (_uiState.value.isPlaying) startAutoAdvance()
    }

    fun goToIndex(index: Int) {
        val max = _uiState.value.filteredStrips.size
        if (max == 0) return
        _uiState.update { it.copy(currentIndex = index.coerceIn(0, max - 1), segmentProgress = 0f) }
        if (_uiState.value.isPlaying) startAutoAdvance()
    }

    fun nextStrip() {
        val state = _uiState.value
        if (state.filteredStrips.isEmpty()) return
        val next = (state.currentIndex + 1) % state.filteredStrips.size
        _uiState.update { it.copy(currentIndex = next, segmentProgress = 0f) }
    }

    fun previousStrip() {
        val state = _uiState.value
        if (state.filteredStrips.isEmpty()) return
        val prev = if (state.currentIndex > 0) state.currentIndex - 1 else 0
        _uiState.update { it.copy(currentIndex = prev, segmentProgress = 0f) }
    }

    fun togglePlayPause() {
        val playing = !_uiState.value.isPlaying
        _uiState.update { it.copy(isPlaying = playing) }
        if (playing) startAutoAdvance() else stopAutoAdvance()
    }

    private fun startAutoAdvance() {
        autoAdvanceJob?.cancel()
        autoAdvanceJob = viewModelScope.launch {
            val startTime = System.currentTimeMillis()
            val startProgress = _uiState.value.segmentProgress

            while (_uiState.value.isPlaying) {
                delay(TICK_INTERVAL_MS)
                val state = _uiState.value
                if (!state.isPlaying || state.filteredStrips.isEmpty()) break

                val elapsed = System.currentTimeMillis() - startTime
                val remainingDuration = state.playbackSpeed.intervalMs * (1f - startProgress)
                val progress = startProgress + (elapsed.toFloat() / state.playbackSpeed.intervalMs.toFloat()) * (1f - startProgress)

                if (progress >= 1f) {
                    // Advance to next
                    val next = (state.currentIndex + 1) % state.filteredStrips.size
                    _uiState.update { it.copy(currentIndex = next, segmentProgress = 0f) }
                    // Restart the loop with fresh timing
                    startAutoAdvance()
                    return@launch
                } else {
                    _uiState.update { it.copy(segmentProgress = progress.coerceIn(0f, 1f)) }
                }
            }
        }
    }

    private fun stopAutoAdvance() {
        autoAdvanceJob?.cancel()
    }

    fun generateShareImage(strips: List<Strip>): Bitmap {
        val size = 1080
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        canvas.drawColor(android.graphics.Color.BLACK)

        // Draw watermark
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.WHITE
            textSize = 48f
            typeface = Typeface.DEFAULT_BOLD
            textAlign = Paint.Align.CENTER
        }
        canvas.drawText("anlik.", (size / 2).toFloat(), (size - 40).toFloat(), paint)

        return output
    }

    private fun filterStrips(strips: List<Strip>, period: MemoryPeriod): List<Strip> {
        val calendar = Calendar.getInstance()
        return when (period) {
            MemoryPeriod.THIS_WEEK -> {
                calendar.add(Calendar.DAY_OF_YEAR, -7)
                val weekAgo = calendar.time
                strips.filter { it.timestamp.after(weekAgo) }
            }
            MemoryPeriod.THIS_MONTH -> {
                calendar.add(Calendar.MONTH, -1)
                val monthAgo = calendar.time
                strips.filter { it.timestamp.after(monthAgo) }
            }
            MemoryPeriod.ALL_TIME -> strips
        }
    }

    fun formatDate(date: Date): String {
        val formatter = SimpleDateFormat("d MMM yyyy", Locale("tr"))
        return formatter.format(date)
    }

    override fun onCleared() {
        super.onCleared()
        autoAdvanceJob?.cancel()
    }
}
