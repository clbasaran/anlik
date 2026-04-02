package com.celalbasaran.stripmate.ui.screen.auth

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.util.Constants
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject

data class AuthUiState(
    val email: String = "",
    val password: String = "",
    val confirmPassword: String = "",
    val displayName: String = "",
    val username: String = "",
    val bio: String = "",
    val dateOfBirth: Date? = null,
    val avatarUri: Uri? = null,
    val isLoading: Boolean = false,
    val error: String? = null,
    val isLoggedIn: Boolean = false,
    val needsProfileCompletion: Boolean = false,
    val needsOnboarding: Boolean = false,
    val currentProfile: UserProfile? = null,
    val isUsernameAvailable: Boolean? = null,
    val isCheckingUsername: Boolean = false,
    val friendGatePassed: Boolean = false,
    val inviteCode: String = "",
    val searchCode: String = "",
    val searchedUser: UserProfile? = null,
    val isSearching: Boolean = false,
    val searchError: String? = null,
    val pendingRequests: List<com.celalbasaran.stripmate.data.model.Friend> = emptyList(),
    val requestSent: Boolean = false,
    val codeShared: Boolean = false,
    val showQROverlay: Boolean = false
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val friendshipRepository: FriendshipRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    init {
        checkAuth()
    }

    fun checkAuth() {
        viewModelScope.launch {
            val isLoggedIn = authRepository.isLoggedIn()
            if (isLoggedIn) {
                val uid = authRepository.currentUserId() ?: return@launch
                val profile = authRepository.fetchProfile(uid)
                _uiState.update {
                    it.copy(
                        isLoggedIn = true,
                        currentProfile = profile,
                        needsProfileCompletion = profile?.needsProfileCompletion == true,
                        inviteCode = profile?.inviteCode ?: ""
                    )
                }
            }
        }
    }

    fun updateEmail(email: String) {
        _uiState.update { it.copy(email = email, error = null) }
    }

    fun updatePassword(password: String) {
        _uiState.update { it.copy(password = password, error = null) }
    }

    fun updateConfirmPassword(password: String) {
        _uiState.update { it.copy(confirmPassword = password, error = null) }
    }

    fun updateDisplayName(name: String) {
        if (name.length <= Constants.DISPLAY_NAME_MAX_LENGTH) {
            _uiState.update { it.copy(displayName = name, error = null) }
        }
    }

    fun updateUsername(username: String) {
        if (username.length <= Constants.USERNAME_MAX_LENGTH) {
            val sanitized = username.lowercase().replace(Regex("[^a-z0-9._]"), "")
            _uiState.update { it.copy(username = sanitized, isUsernameAvailable = null, error = null) }
            if (sanitized.length >= Constants.USERNAME_MIN_LENGTH) {
                checkUsernameAvailability(sanitized)
            }
        }
    }

    fun updateBio(bio: String) {
        if (bio.length <= Constants.BIO_MAX_LENGTH) {
            _uiState.update { it.copy(bio = bio) }
        }
    }

    fun updateDateOfBirth(date: Date) {
        _uiState.update { it.copy(dateOfBirth = date) }
    }

    fun updateAvatarUri(uri: Uri?) {
        _uiState.update { it.copy(avatarUri = uri) }
    }

    fun updateSearchCode(code: String) {
        if (code.length <= Constants.INVITE_CODE_LENGTH) {
            _uiState.update { it.copy(searchCode = code.uppercase(), searchError = null) }
        }
    }

    fun login() {
        val state = _uiState.value
        if (state.email.isBlank() || state.password.isBlank()) {
            _uiState.update { it.copy(error = "Email ve sifre gerekli") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            val result = authRepository.login(state.email.trim(), state.password)
            result.fold(
                onSuccess = { profile ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            isLoggedIn = true,
                            currentProfile = profile,
                            needsProfileCompletion = profile.needsProfileCompletion,
                            inviteCode = profile.inviteCode
                        )
                    }
                },
                onFailure = { e ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = e.localizedMessage ?: "Giris basarisiz"
                        )
                    }
                }
            )
        }
    }

    fun signup() {
        val state = _uiState.value
        if (state.email.isBlank() || state.password.isBlank()) {
            _uiState.update { it.copy(error = "E-posta ve şifre gerekli") }
            return
        }
        if (state.displayName.isBlank()) {
            _uiState.update { it.copy(error = "Ad soyad gerekli") }
            return
        }
        if (state.username.length < 3) {
            _uiState.update { it.copy(error = "Kullanıcı adı en az 3 karakter olmalı") }
            return
        }
        if (state.password != state.confirmPassword) {
            _uiState.update { it.copy(error = "Şifreler eşleşmiyor") }
            return
        }
        if (state.password.length < 6) {
            _uiState.update { it.copy(error = "Şifre en az 6 karakter olmalı") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            val result = authRepository.signup(
                email = state.email.trim(),
                password = state.password,
                displayName = state.displayName.trim(),
                username = state.username.trim(),
                dateOfBirth = state.dateOfBirth ?: Date()
            )
            result.fold(
                onSuccess = { profile ->
                    // Upload avatar if selected
                    state.avatarUri?.let { uri ->
                        try {
                            authRepository.uploadAvatar(uri)
                        } catch (e: Exception) {
                            android.util.Log.e("AuthViewModel", "Avatar upload failed", e)
                        }
                    }
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            isLoggedIn = true,
                            currentProfile = profile,
                            needsProfileCompletion = false,
                            inviteCode = profile.inviteCode
                        )
                    }
                },
                onFailure = { e ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = e.localizedMessage ?: "Kayıt başarısız"
                        )
                    }
                }
            )
        }
    }

    fun signInWithGoogle(idToken: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            val result = authRepository.signInWithGoogle(idToken)
            result.fold(
                onSuccess = { profile ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            isLoggedIn = true,
                            currentProfile = profile,
                            needsProfileCompletion = profile.needsProfileCompletion,
                            inviteCode = profile.inviteCode
                        )
                    }
                },
                onFailure = { e ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = e.localizedMessage ?: "Google giris basarisiz"
                        )
                    }
                }
            )
        }
    }

    fun completeProfile() {
        val state = _uiState.value
        if (state.displayName.isBlank()) {
            _uiState.update { it.copy(error = "Isim gerekli") }
            return
        }
        if (state.username.length < Constants.USERNAME_MIN_LENGTH) {
            _uiState.update { it.copy(error = "Kullanici adi en az ${Constants.USERNAME_MIN_LENGTH} karakter olmali") }
            return
        }
        if (state.isUsernameAvailable == false) {
            _uiState.update { it.copy(error = "Bu kullanici adi alinmis") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            try {
                val data = mutableMapOf<String, Any>(
                    "displayName" to state.displayName.trim(),
                    "username" to state.username.trim()
                )
                if (state.bio.isNotBlank()) {
                    data["bio"] = state.bio.trim()
                }
                state.dateOfBirth?.let {
                    data["dateOfBirth"] = com.google.firebase.Timestamp(it)
                }

                state.avatarUri?.let { uri ->
                    val avatarUrl = authRepository.uploadAvatar(uri)
                    data["avatarUrl"] = avatarUrl
                }

                authRepository.updateProfile(data)

                val uid = authRepository.currentUserId() ?: throw Exception("Kullanici bulunamadi")
                val updatedProfile = authRepository.fetchProfile(uid)

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        needsProfileCompletion = false,
                        currentProfile = updatedProfile
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.localizedMessage ?: "Profil tamamlanamadi"
                    )
                }
            }
        }
    }

    private fun checkUsernameAvailability(username: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isCheckingUsername = true) }
            try {
                val existing = authRepository.searchUserByUsername(username)
                _uiState.update {
                    it.copy(
                        isCheckingUsername = false,
                        isUsernameAvailable = existing == null
                    )
                }
            } catch (_: Exception) {
                _uiState.update { it.copy(isCheckingUsername = false) }
            }
        }
    }

    fun searchByInviteCode() {
        val code = _uiState.value.searchCode.trim()
        if (code.length != Constants.INVITE_CODE_LENGTH) {
            _uiState.update { it.copy(searchError = "Davet kodu ${Constants.INVITE_CODE_LENGTH} haneli olmali") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isSearching = true, searchError = null, searchedUser = null) }
            try {
                val user = authRepository.searchUserByCode(code)
                if (user != null) {
                    _uiState.update { it.copy(isSearching = false, searchedUser = user) }
                } else {
                    _uiState.update { it.copy(isSearching = false, searchError = "Kullanici bulunamadi") }
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(isSearching = false, searchError = e.localizedMessage ?: "Arama basarisiz")
                }
            }
        }
    }

    fun sendFriendRequest(toUserId: String) {
        viewModelScope.launch {
            try {
                friendshipRepository.sendFriendRequest(toUserId)
                _uiState.update {
                    it.copy(requestSent = true, searchedUser = null, searchCode = "")
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(searchError = e.localizedMessage ?: "İstek gönderilemedi") }
            }
        }
    }

    fun acceptFriendRequest(fromUserId: String) {
        viewModelScope.launch {
            try {
                friendshipRepository.acceptFriendRequest(fromUserId)
                _uiState.update { it.copy(friendGatePassed = true) }
                fetchPendingRequests()
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.localizedMessage) }
            }
        }
    }

    fun fetchPendingRequests() {
        viewModelScope.launch {
            try {
                val requests = friendshipRepository.fetchPendingIncomingRequests()
                _uiState.update { it.copy(pendingRequests = requests) }
            } catch (_: Exception) { }
        }
    }

    fun markCodeShared() {
        _uiState.update { it.copy(codeShared = true) }
    }

    fun toggleQROverlay() {
        _uiState.update { it.copy(showQROverlay = !it.showQROverlay) }
    }

    fun checkFriendGateStatus() {
        val state = _uiState.value
        if (state.requestSent || state.codeShared || state.friendGatePassed) {
            _uiState.update { it.copy(friendGatePassed = true) }
        }
    }

    fun resetPassword(email: String) {
        if (email.isBlank()) {
            _uiState.update { it.copy(error = "E-posta adresini gir") }
            return
        }
        viewModelScope.launch {
            try {
                authRepository.resetPassword(email)
                _uiState.update { it.copy(error = "Şifre sıfırlama bağlantısı gönderildi") }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = e.localizedMessage ?: "Gönderilemedi") }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun setError(message: String) {
        _uiState.update { it.copy(error = message, isLoading = false) }
    }

    fun setOnboardingComplete() {
        _uiState.update { it.copy(needsOnboarding = false) }
    }

    fun logout() {
        viewModelScope.launch {
            authRepository.logout()
            _uiState.update { AuthUiState() }
        }
    }
}
