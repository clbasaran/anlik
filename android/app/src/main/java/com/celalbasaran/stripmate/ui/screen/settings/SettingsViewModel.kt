package com.celalbasaran.stripmate.ui.screen.settings

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _notificationPrefs = MutableStateFlow<Map<String, Boolean>>(emptyMap())
    val notificationPrefs: StateFlow<Map<String, Boolean>> = _notificationPrefs.asStateFlow()

    private val _inviteCode = MutableStateFlow("")
    val inviteCode: StateFlow<String> = _inviteCode.asStateFlow()

    private val _currentProfile = MutableStateFlow<UserProfile?>(null)
    val currentProfile: StateFlow<UserProfile?> = _currentProfile.asStateFlow()

    init {
        loadSettings()
    }

    private fun loadSettings() {
        viewModelScope.launch {
            val userId = authRepository.currentUserId() ?: return@launch
            val profile = authRepository.fetchProfile(userId) ?: return@launch
            _currentProfile.value = profile
            _inviteCode.value = profile.inviteCode
            _notificationPrefs.value = profile.notificationPreferences ?: mapOf(
                "photo_received" to true,
                "comment_received" to true,
                "friend_added" to true,
                "message_received" to true,
                "streak_warning" to true
            )
        }
    }

    fun toggleNotification(key: String, enabled: Boolean) {
        val updated = _notificationPrefs.value.toMutableMap()
        updated[key] = enabled
        _notificationPrefs.value = updated

        viewModelScope.launch {
            authRepository.updateProfile(mapOf("notificationPreferences" to updated))
        }
    }

    fun copyInviteCode(context: Context) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("Davet Kodu", _inviteCode.value))
        Toast.makeText(context, "Davet kodu kopyalandi", Toast.LENGTH_SHORT).show()
    }

    fun clearCache(context: Context) {
        context.cacheDir.deleteRecursively()
        Toast.makeText(context, "Onbellek temizlendi", Toast.LENGTH_SHORT).show()
    }

    fun logout() {
        viewModelScope.launch {
            authRepository.logout()
        }
    }

    fun deleteAccount() {
        viewModelScope.launch {
            authRepository.deleteAccount()
        }
    }
}
