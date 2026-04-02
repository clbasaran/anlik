package com.celalbasaran.stripmate.ui.screen.history

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.notification.NotificationRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HistoryViewModel @Inject constructor(
    private val photoRepository: PhotoRepository,
    private val authRepository: AuthRepository,
    private val notificationRepository: NotificationRepository
) : ViewModel() {

    private val _photos = MutableStateFlow<List<Strip>>(emptyList())
    val photos: StateFlow<List<Strip>> = _photos.asStateFlow()

    private val _isLoading = MutableStateFlow(true)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isLoadingMore = MutableStateFlow(false)
    val isLoadingMore: StateFlow<Boolean> = _isLoadingMore.asStateFlow()

    private val _isRefreshing = MutableStateFlow(false)
    val isRefreshing: StateFlow<Boolean> = _isRefreshing.asStateFlow()

    val notificationCount: StateFlow<Int> = notificationRepository.getUnreadCount()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 0)

    private var hasMorePages = true
    private var listenerJob: Job? = null

    init {
        listenToPhotos()
    }

    private fun listenToPhotos() {
        listenerJob?.cancel()
        val userId = authRepository.currentUserId() ?: return
        listenerJob = viewModelScope.launch {
            photoRepository.listenToHistory(userId).collect { strips ->
                _photos.value = strips.sortedByDescending { it.timestamp }
                _isLoading.value = false
                _isRefreshing.value = false
            }
        }
    }

    fun refresh() {
        _isRefreshing.value = true
        listenToPhotos()
    }

    fun loadMore() {
        if (_isLoadingMore.value || !hasMorePages) return
        val userId = authRepository.currentUserId() ?: return
        val lastPhoto = _photos.value.lastOrNull() ?: return

        viewModelScope.launch {
            _isLoadingMore.value = true
            val moreStrips = photoRepository.loadMoreHistory(userId, lastPhoto.timestamp)
            if (moreStrips.isEmpty()) {
                hasMorePages = false
            } else {
                _photos.value = _photos.value + moreStrips.sortedByDescending { it.timestamp }
            }
            _isLoadingMore.value = false
        }
    }

    val currentUserId: String?
        get() = authRepository.currentUserId()

    private val _isDeleting = MutableStateFlow(false)
    val isDeleting: StateFlow<Boolean> = _isDeleting.asStateFlow()

    fun deleteStrip(strip: Strip) {
        viewModelScope.launch {
            photoRepository.deleteStrip(strip)
            _photos.value = _photos.value.filter { it.id != strip.id }
        }
    }

    fun clearHistory() {
        viewModelScope.launch {
            _isDeleting.value = true
            try {
                photoRepository.clearHistory()
                _photos.value = emptyList()
            } catch (e: Exception) {
                Log.e("HistoryViewModel", "Failed to clear history", e)
            }
            _isDeleting.value = false
        }
    }

    fun toggleReaction(photoId: String, emoji: String) {
        viewModelScope.launch {
            photoRepository.toggleReaction(photoId, emoji)
        }
    }

    fun reportContent(contentType: String, contentId: String, contentOwnerId: String, reason: String) {
        viewModelScope.launch {
            try {
                authRepository.reportContent(contentType, contentId, contentOwnerId, reason)
            } catch (e: Exception) {
                Log.e("HistoryVM", "Failed to report content", e)
            }
        }
    }
}
