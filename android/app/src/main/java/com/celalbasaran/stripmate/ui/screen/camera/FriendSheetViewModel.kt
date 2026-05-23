package com.celalbasaran.stripmate.ui.screen.camera

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.SendGroup
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.service.friendship.SendGroupRepository
import com.celalbasaran.stripmate.util.AppEventBus
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Sheet-scoped ViewModel that owns the data needed by the recipient picker:
 * search text, send groups, favorite toggle, and inline group creation.
 *
 * Friends list itself comes from CameraViewModel (already loaded for the
 * camera screen) so this VM doesn't refetch friends.
 */
@HiltViewModel
class FriendSheetViewModel @Inject constructor(
    private val friendshipRepository: FriendshipRepository,
    private val sendGroupRepository: SendGroupRepository
) : ViewModel() {

    private val _searchText = MutableStateFlow("")
    val searchText: StateFlow<String> = _searchText.asStateFlow()

    private val _sendGroups = MutableStateFlow<List<SendGroup>>(emptyList())
    val sendGroups: StateFlow<List<SendGroup>> = _sendGroups.asStateFlow()

    private val _showCreateDialog = MutableStateFlow(false)
    val showCreateDialog: StateFlow<Boolean> = _showCreateDialog.asStateFlow()

    private val _newGroupName = MutableStateFlow("")
    val newGroupName: StateFlow<String> = _newGroupName.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    init {
        refreshGroups()
        // Listen for group changes so the sheet stays in sync after create/delete.
        viewModelScope.launch {
            AppEventBus.events.collect { event ->
                if (event is AppEventBus.Event.SendGroupsChanged) refreshGroups()
            }
        }
    }

    fun setSearchText(value: String) { _searchText.value = value }

    fun openCreateGroupDialog() {
        _newGroupName.value = ""
        _showCreateDialog.value = true
    }

    fun closeCreateGroupDialog() {
        _showCreateDialog.value = false
    }

    fun setNewGroupName(value: String) {
        _newGroupName.value = value.take(40)
    }

    fun createGroupFromSelection(memberIds: List<String>) {
        val name = _newGroupName.value.trim()
        if (name.isEmpty()) {
            _errorMessage.value = "isim gerekli"
            return
        }
        if (memberIds.isEmpty()) {
            _errorMessage.value = "en az bir kişi seç"
            return
        }
        viewModelScope.launch {
            try {
                sendGroupRepository.createGroup(name, memberIds)
                _showCreateDialog.value = false
            } catch (e: Exception) {
                _errorMessage.value = e.message ?: "grup oluşturulamadı"
            }
        }
    }

    fun toggleFavorite(friendId: String, currentlyFavorite: Boolean) {
        viewModelScope.launch {
            try {
                friendshipRepository.setFavorite(friendId, !currentlyFavorite)
            } catch (_: Exception) { /* no-op — UI re-fetch will reconcile */ }
        }
    }

    fun clearError() { _errorMessage.value = null }

    private fun refreshGroups() {
        viewModelScope.launch {
            _sendGroups.value = try { sendGroupRepository.fetchGroups() } catch (_: Exception) { emptyList() }
        }
    }
}
