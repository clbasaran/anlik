package com.celalbasaran.stripmate.ui.screen.profile

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.service.auth.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject

@HiltViewModel
class EditProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _displayName = MutableStateFlow("")
    val displayName: StateFlow<String> = _displayName.asStateFlow()

    private val _username = MutableStateFlow("")
    val username: StateFlow<String> = _username.asStateFlow()

    private val _bio = MutableStateFlow("")
    val bio: StateFlow<String> = _bio.asStateFlow()

    private val _avatarUrl = MutableStateFlow<String?>(null)
    val avatarUrl: StateFlow<String?> = _avatarUrl.asStateFlow()

    private val _dateOfBirth = MutableStateFlow<Date?>(null)
    val dateOfBirth: StateFlow<Date?> = _dateOfBirth.asStateFlow()

    private val _statusEmoji = MutableStateFlow<String?>(null)
    val statusEmoji: StateFlow<String?> = _statusEmoji.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _usernameAvailable = MutableStateFlow<Boolean?>(null)
    val usernameAvailable: StateFlow<Boolean?> = _usernameAvailable.asStateFlow()

    private val _saveSuccess = MutableStateFlow(false)
    val saveSuccess: StateFlow<Boolean> = _saveSuccess.asStateFlow()

    private val _email = MutableStateFlow<String?>(null)
    val email: StateFlow<String?> = _email.asStateFlow()

    private val _inviteCode = MutableStateFlow("")
    val inviteCode: StateFlow<String> = _inviteCode.asStateFlow()

    private var usernameCheckJob: Job? = null
    private var originalUsername: String = ""

    init {
        loadCurrentProfile()
    }

    private fun loadCurrentProfile() {
        viewModelScope.launch {
            val userId = authRepository.currentUserId() ?: return@launch
            val profile = authRepository.fetchProfile(userId) ?: return@launch
            _displayName.value = profile.displayName ?: ""
            _username.value = profile.username ?: ""
            _bio.value = profile.bio ?: ""
            _avatarUrl.value = profile.avatarUrl
            _dateOfBirth.value = profile.dateOfBirth
            _statusEmoji.value = profile.statusEmoji
            _email.value = profile.email
            _inviteCode.value = profile.inviteCode
            originalUsername = profile.username ?: ""
        }
    }

    fun updateDisplayName(name: String) {
        if (name.length <= 30) {
            _displayName.value = name
        }
    }

    fun updateUsername(name: String) {
        val sanitized = name.lowercase().filter { it.isLetterOrDigit() || it == '_' }
        if (sanitized.length <= 20) {
            _username.value = sanitized
            checkUsernameAvailability(sanitized)
        }
    }

    private fun checkUsernameAvailability(username: String) {
        usernameCheckJob?.cancel()
        if (username == originalUsername) {
            _usernameAvailable.value = true
            return
        }
        if (username.length < 3) {
            _usernameAvailable.value = null
            return
        }
        usernameCheckJob = viewModelScope.launch {
            delay(500) // debounce
            val existingUser = authRepository.searchUserByCode(username)
            _usernameAvailable.value = existingUser == null
        }
    }

    fun updateBio(text: String) {
        _bio.value = text
    }

    fun updateDateOfBirth(date: Date) {
        _dateOfBirth.value = date
    }

    fun updateStatusEmoji(emoji: String) {
        _statusEmoji.value = emoji
    }

    fun uploadAvatar(uri: Uri) {
        viewModelScope.launch {
            val url = authRepository.uploadAvatar(uri)
            _avatarUrl.value = url
        }
    }

    fun save() {
        viewModelScope.launch {
            _isSaving.value = true
            val data = buildMap<String, Any> {
                put("displayName", _displayName.value)
                put("username", _username.value)
                put("bio", _bio.value)
                _dateOfBirth.value?.let { put("dateOfBirth", com.google.firebase.Timestamp(it)) }
                _statusEmoji.value?.let { put("statusEmoji", it) }
                _avatarUrl.value?.let { put("avatarUrl", it) }
            }
            authRepository.updateProfile(data)
            _isSaving.value = false
            _saveSuccess.value = true
        }
    }

    fun deleteAccount() {
        viewModelScope.launch {
            authRepository.deleteAccount()
        }
    }
}
