package com.celalbasaran.stripmate.ui.screen.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.Friend
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.camera.CameraRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.service.location.LocationRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.File
import javax.inject.Inject

data class CameraUiState(
    val capturedBitmap: Bitmap? = null,
    val isUploading: Boolean = false,
    val showSuccess: Boolean = false,
    val selectedReceiverIds: Set<String> = emptySet(),
    val availableFriends: List<Friend> = emptyList(),
    val initialComment: String = "",
    val voiceData: ByteArray? = null,
    val isRecording: Boolean = false,
    val recordingDuration: Long = 0L,
    val error: String? = null,
    val showFriendSheet: Boolean = false,
    val profileAvatarUrl: String? = null,
    val profileDisplayName: String? = null
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is CameraUiState) return false
        return capturedBitmap == other.capturedBitmap &&
                isUploading == other.isUploading &&
                showSuccess == other.showSuccess &&
                selectedReceiverIds == other.selectedReceiverIds &&
                availableFriends == other.availableFriends &&
                initialComment == other.initialComment &&
                voiceData.contentEquals(other.voiceData) &&
                isRecording == other.isRecording &&
                recordingDuration == other.recordingDuration &&
                error == other.error &&
                showFriendSheet == other.showFriendSheet &&
                profileAvatarUrl == other.profileAvatarUrl &&
                profileDisplayName == other.profileDisplayName
    }

    override fun hashCode(): Int {
        var result = capturedBitmap?.hashCode() ?: 0
        result = 31 * result + isUploading.hashCode()
        result = 31 * result + showSuccess.hashCode()
        result = 31 * result + selectedReceiverIds.hashCode()
        result = 31 * result + availableFriends.hashCode()
        result = 31 * result + initialComment.hashCode()
        result = 31 * result + (voiceData?.contentHashCode() ?: 0)
        result = 31 * result + isRecording.hashCode()
        result = 31 * result + recordingDuration.hashCode()
        result = 31 * result + (error?.hashCode() ?: 0)
        result = 31 * result + showFriendSheet.hashCode()
        result = 31 * result + (profileAvatarUrl?.hashCode() ?: 0)
        result = 31 * result + (profileDisplayName?.hashCode() ?: 0)
        return result
    }
}

@HiltViewModel
class CameraViewModel @Inject constructor(
    private val photoRepository: PhotoRepository,
    private val friendshipRepository: FriendshipRepository,
    private val locationRepository: LocationRepository,
    private val cameraRepository: CameraRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(CameraUiState())
    val uiState: StateFlow<CameraUiState> = _uiState.asStateFlow()

    private var mediaRecorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var recordingJob: Job? = null

    init {
        fetchFriends()
        loadProfile()
    }

    private fun loadProfile() {
        viewModelScope.launch {
            try {
                val userId = authRepository.currentUserId() ?: return@launch
                val profile = authRepository.fetchProfile(userId) ?: return@launch
                _uiState.update {
                    it.copy(
                        profileAvatarUrl = profile.avatarUrl,
                        profileDisplayName = profile.displayName
                    )
                }
            } catch (_: Exception) { }
        }
    }

    fun fetchFriends() {
        viewModelScope.launch {
            try {
                val friends = friendshipRepository.fetchFriends()
                    .filter { !it.isPending }
                _uiState.update { it.copy(availableFriends = friends) }
            } catch (_: Exception) { }
        }
    }

    fun captureFromUri(uri: Uri, context: Context) {
        viewModelScope.launch {
            try {
                val inputStream = context.contentResolver.openInputStream(uri)
                val bitmap = BitmapFactory.decodeStream(inputStream)
                inputStream?.close()
                if (bitmap != null) {
                    val fixed = cameraRepository.fixOrientation(bitmap, uri)
                    _uiState.update { it.copy(capturedBitmap = fixed) }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = "Fotoğraf alınamadı: ${e.localizedMessage}") }
            }
        }
    }

    fun captureFromBitmap(bitmap: Bitmap) {
        _uiState.update { it.copy(capturedBitmap = bitmap) }
    }

    fun sendPhoto() {
        val state = _uiState.value
        val bitmap = state.capturedBitmap ?: return
        val receiverIds = state.selectedReceiverIds.toList()
        if (receiverIds.isEmpty()) {
            _uiState.update { it.copy(error = "En az bir arkadaş seç") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isUploading = true, error = null) }
            try {
                val location = locationRepository.fetchLocation()
                val cityName = location?.let { (lat, lng) ->
                    locationRepository.reverseGeocode(lat, lng)
                }

                photoRepository.sendPhoto(
                    bitmap = bitmap,
                    receiverIds = receiverIds,
                    latitude = location?.first,
                    longitude = location?.second,
                    cityName = cityName,
                    voiceData = state.voiceData
                )

                _uiState.update {
                    it.copy(
                        isUploading = false,
                        showSuccess = true,
                        showFriendSheet = false
                    )
                }

                delay(1500)
                retakePhoto()
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isUploading = false,
                        error = e.localizedMessage ?: "Gonderme basarisiz"
                    )
                }
            }
        }
    }

    fun retakePhoto() {
        _uiState.update {
            CameraUiState(availableFriends = it.availableFriends)
        }
    }

    fun toggleFriendSelection(friendId: String) {
        _uiState.update { state ->
            val newSet = state.selectedReceiverIds.toMutableSet()
            if (newSet.contains(friendId)) {
                newSet.remove(friendId)
            } else {
                newSet.add(friendId)
            }
            state.copy(selectedReceiverIds = newSet)
        }
    }

    fun updateComment(comment: String) {
        _uiState.update { it.copy(initialComment = comment) }
    }

    fun showFriendSheet() {
        _uiState.update { it.copy(showFriendSheet = true) }
    }

    fun hideFriendSheet() {
        _uiState.update { it.copy(showFriendSheet = false) }
    }

    @Suppress("DEPRECATION")
    fun startRecording(context: Context) {
        try {
            val file = File(context.cacheDir, "voice_${System.currentTimeMillis()}.m4a")
            recordingFile = file

            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(44100)
                setOutputFile(file.absolutePath)
                prepare()
                start()
            }

            _uiState.update { it.copy(isRecording = true, recordingDuration = 0L) }

            recordingJob = viewModelScope.launch {
                while (true) {
                    delay(100)
                    _uiState.update { it.copy(recordingDuration = it.recordingDuration + 100) }
                    if (_uiState.value.recordingDuration >= 15000L) {
                        stopRecording()
                        break
                    }
                }
            }
        } catch (e: Exception) {
            _uiState.update { it.copy(error = "Kayit baslatilamadi") }
        }
    }

    fun stopRecording() {
        recordingJob?.cancel()
        try {
            mediaRecorder?.apply {
                stop()
                release()
            }
            mediaRecorder = null

            val file = recordingFile
            if (file != null && file.exists()) {
                val bytes = file.readBytes()
                _uiState.update {
                    it.copy(
                        isRecording = false,
                        voiceData = bytes
                    )
                }
                file.delete()
            } else {
                _uiState.update { it.copy(isRecording = false) }
            }
        } catch (e: Exception) {
            _uiState.update { it.copy(isRecording = false, error = "Kayit durdurulamadi") }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    override fun onCleared() {
        super.onCleared()
        recordingJob?.cancel()
        mediaRecorder?.release()
        recordingFile?.delete()
    }
}
