package com.celalbasaran.stripmate.ui.screen.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.isActive
import com.celalbasaran.stripmate.data.model.CollageAspectRatio
import com.celalbasaran.stripmate.data.model.CollageBackground
import com.celalbasaran.stripmate.data.model.PhotoTransform
import com.celalbasaran.stripmate.data.model.CollageCornerStyle
import com.celalbasaran.stripmate.data.model.CollageLayout
import com.celalbasaran.stripmate.data.model.Friend

import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.camera.CameraRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.service.location.LocationRepository
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
    val profileDisplayName: String? = null,
    val isSecret: Boolean = false,
    val isSavingToGallery: Boolean = false,
    val showSavedToast: Boolean = false,
    val isCollageMode: Boolean = false,
    val collagePhotos: List<Bitmap> = emptyList(),
    val collageLayout: CollageLayout = CollageLayout.TWO_HORIZONTAL,
    val showCollageView: Boolean = false,
    val collageGap: Float = 4f,
    val collageBackground: CollageBackground = CollageBackground.BLACK,
    val collageCornerStyle: CollageCornerStyle = CollageCornerStyle.ROUNDED,
    val collageAspectRatio: CollageAspectRatio = CollageAspectRatio.PORTRAIT,
    val collageTransforms: Map<Int, PhotoTransform> = emptyMap(),
    val collageReplaceIndex: Int? = null,
    // Video recording
    val capturedVideoUri: Uri? = null,
    val videoDuration: Double = 0.0,
    val isRecordingVideo: Boolean = false,
    val videoRecordingProgress: Float = 0f
) {
    val isVideoMode: Boolean get() = capturedVideoUri != null
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
                profileDisplayName == other.profileDisplayName &&
                isSecret == other.isSecret &&
                isSavingToGallery == other.isSavingToGallery &&
                showSavedToast == other.showSavedToast &&
                isCollageMode == other.isCollageMode &&
                collagePhotos == other.collagePhotos &&
                collageLayout == other.collageLayout &&
                showCollageView == other.showCollageView &&
                collageGap == other.collageGap &&
                collageBackground == other.collageBackground &&
                collageCornerStyle == other.collageCornerStyle &&
                collageAspectRatio == other.collageAspectRatio &&
                collageTransforms == other.collageTransforms &&
                collageReplaceIndex == other.collageReplaceIndex &&
                capturedVideoUri == other.capturedVideoUri &&
                videoDuration == other.videoDuration &&
                isRecordingVideo == other.isRecordingVideo &&
                videoRecordingProgress == other.videoRecordingProgress
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
        result = 31 * result + isSecret.hashCode()
        result = 31 * result + isSavingToGallery.hashCode()
        result = 31 * result + showSavedToast.hashCode()
        result = 31 * result + isCollageMode.hashCode()
        result = 31 * result + collagePhotos.hashCode()
        result = 31 * result + collageLayout.hashCode()
        result = 31 * result + showCollageView.hashCode()
        result = 31 * result + collageGap.hashCode()
        result = 31 * result + collageBackground.hashCode()
        result = 31 * result + collageCornerStyle.hashCode()
        result = 31 * result + collageAspectRatio.hashCode()
        result = 31 * result + collageTransforms.hashCode()
        result = 31 * result + (collageReplaceIndex?.hashCode() ?: 0)
        result = 31 * result + (capturedVideoUri?.hashCode() ?: 0)
        result = 31 * result + videoDuration.hashCode()
        result = 31 * result + isRecordingVideo.hashCode()
        result = 31 * result + videoRecordingProgress.hashCode()
        return result
    }
}

@HiltViewModel
class CameraViewModel @Inject constructor(
    private val photoRepository: PhotoRepository,
    private val friendshipRepository: FriendshipRepository,
    private val locationRepository: LocationRepository,
    private val cameraRepository: CameraRepository,
    private val authRepository: AuthRepository,
    @ApplicationContext private val appContext: Context
) : ViewModel() {

    private val prefs = appContext.getSharedPreferences("stripmate_camera", Context.MODE_PRIVATE)

    private val _uiState = MutableStateFlow(CameraUiState())
    val uiState: StateFlow<CameraUiState> = _uiState.asStateFlow()

    private var mediaRecorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var recordingJob: Job? = null

    // Video recording state
    private var videoRecorder: MediaRecorder? = null
    private var videoOutputFile: File? = null
    private var videoRecordingJob: Job? = null
    private var videoRecordingStartTime: Long = 0L

    /** Returns the saved lens facing preference (default: back camera). */
    fun getSavedLensFacing(): Int {
        return if (prefs.getBoolean("last_camera_front", false))
            androidx.camera.core.CameraSelector.LENS_FACING_FRONT
        else
            androidx.camera.core.CameraSelector.LENS_FACING_BACK
    }

    /** Save current lens facing preference. */
    fun saveLensFacing(isFront: Boolean) {
        prefs.edit().putBoolean("last_camera_front", isFront).apply()
    }

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
                _uiState.update { state ->
                    var newSelectedIds = state.selectedReceiverIds
                    // Pre-populate with last selected friends if none selected yet
                    if (newSelectedIds.isEmpty()) {
                        val lastIds = prefs.getStringSet("last_selected_receiver_ids", emptySet()) ?: emptySet()
                        val friendIds = friends.map { it.userId }.toSet()
                        val validIds = lastIds.intersect(friendIds)
                        if (validIds.isNotEmpty()) {
                            newSelectedIds = validIds
                        }
                    }
                    state.copy(availableFriends = friends, selectedReceiverIds = newSelectedIds)
                }
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
                    voiceData = state.voiceData,
                    isSecret = state.isSecret
                )

                // Save selected receivers for next session
                prefs.edit().putStringSet("last_selected_receiver_ids", state.selectedReceiverIds).apply()

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
        videoOutputFile?.delete()
        _uiState.update {
            CameraUiState(availableFriends = it.availableFriends)
        }
    }

    // ── Video Recording ─────────────────────────────────────────────────────

    @Suppress("DEPRECATION")
    fun startVideoRecording(context: Context) {
        if (_uiState.value.isRecordingVideo) return

        val outputFile = File(context.cacheDir, "anlik_clip_${System.currentTimeMillis()}.mp4")
        videoOutputFile = outputFile

        try {
            val recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                MediaRecorder()
            }
            recorder.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setVideoSize(1080, 1920)
                setVideoFrameRate(30)
                setVideoEncodingBitRate(4_000_000)
                setAudioEncodingBitRate(128_000)
                setAudioSamplingRate(44100)
                setMaxDuration(5000)
                setOutputFile(outputFile.absolutePath)
                setOnInfoListener { _, what, _ ->
                    if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                        stopVideoRecording()
                    }
                }
                prepare()
                start()
            }
            videoRecorder = recorder
            videoRecordingStartTime = System.currentTimeMillis()
            _uiState.update { it.copy(isRecordingVideo = true, videoRecordingProgress = 0f) }

            videoRecordingJob = viewModelScope.launch {
                while (isActive && _uiState.value.isRecordingVideo) {
                    delay(50)
                    val elapsed = (System.currentTimeMillis() - videoRecordingStartTime) / 1000.0
                    _uiState.update {
                        it.copy(
                            videoRecordingProgress = (elapsed / 5.0).toFloat().coerceAtMost(1f),
                            videoDuration = elapsed.coerceAtMost(5.0)
                        )
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("CameraViewModel", "Failed to start video recording", e)
            _uiState.update { it.copy(error = "Video kaydedilemedi") }
            outputFile.delete()
        }
    }

    fun stopVideoRecording() {
        val elapsed = (System.currentTimeMillis() - videoRecordingStartTime) / 1000.0
        videoRecordingJob?.cancel()
        videoRecordingJob = null

        try {
            videoRecorder?.stop()
        } catch (_: Exception) { }
        try {
            videoRecorder?.release()
        } catch (_: Exception) { }
        videoRecorder = null

        if (elapsed < 2.0) {
            videoOutputFile?.delete()
            _uiState.update {
                it.copy(
                    isRecordingVideo = false,
                    videoRecordingProgress = 0f,
                    capturedVideoUri = null,
                    error = "En az 2 saniye kaydet"
                )
            }
        } else {
            val uri = Uri.fromFile(videoOutputFile)
            _uiState.update {
                it.copy(
                    isRecordingVideo = false,
                    capturedVideoUri = uri,
                    videoDuration = elapsed.coerceAtMost(5.0)
                )
            }
            viewModelScope.launch { fetchFriends() }
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

    fun toggleSecret() {
        _uiState.update { it.copy(isSecret = !it.isSecret) }
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

    fun saveToGallery(context: Context) {
        val bitmap = _uiState.value.capturedBitmap ?: return
        viewModelScope.launch {
            _uiState.update { it.copy(isSavingToGallery = true) }
            try {
                val contentValues = android.content.ContentValues().apply {
                    put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, "StripMate_${System.currentTimeMillis()}.jpg")
                    put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        put(android.provider.MediaStore.Images.Media.RELATIVE_PATH, "Pictures/StripMate")
                    }
                }
                val uri = context.contentResolver.insert(
                    android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    contentValues
                )
                if (uri != null) {
                    context.contentResolver.openOutputStream(uri)?.use { out ->
                        bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 95, out)
                    }
                    _uiState.update { it.copy(isSavingToGallery = false, showSavedToast = true) }
                    delay(2000)
                    _uiState.update { it.copy(showSavedToast = false) }
                } else {
                    _uiState.update { it.copy(isSavingToGallery = false, error = "Galeriye kaydedilemedi") }
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(isSavingToGallery = false, error = "Galeriye kaydedilemedi") }
            }
        }
    }

    // ── Collage ──────────────────────────────────────────────────────────────

    fun startCollage() {
        val bitmap = _uiState.value.capturedBitmap
        val initialPhotos = if (bitmap != null) listOf(bitmap) else emptyList()
        _uiState.update {
            it.copy(
                isCollageMode = true,
                showCollageView = true,
                collagePhotos = initialPhotos,
                collageLayout = CollageLayout.TWO_HORIZONTAL
            )
        }
    }

    fun addToCollage(bitmap: Bitmap) {
        _uiState.update { state ->
            val replaceIdx = state.collageReplaceIndex
            val updated = if (replaceIdx != null && replaceIdx < state.collagePhotos.size) {
                state.collagePhotos.toMutableList().also { it[replaceIdx] = bitmap }
            } else {
                if (state.collagePhotos.size >= 4) return@update state
                state.collagePhotos + bitmap
            }
            // Auto-select best layout for current count
            val bestLayout = CollageLayout.layoutsFor(updated.size)
                .firstOrNull { it.photoCount == updated.size }
                ?: state.collageLayout
            state.copy(
                collagePhotos = updated,
                collageLayout = bestLayout,
                collageReplaceIndex = null
            )
        }
    }

    fun selectCollageLayout(layout: CollageLayout) {
        _uiState.update { it.copy(collageLayout = layout, collageTransforms = emptyMap()) }
    }

    fun finalizeCollage() {
        val state = _uiState.value
        if (state.collagePhotos.size < state.collageLayout.photoCount) return

        viewModelScope.launch {
            try {
                val collage = com.celalbasaran.stripmate.util.CollageBuilder.build(
                    state.collagePhotos,
                    state.collageLayout,
                    gap = state.collageGap,
                    background = state.collageBackground,
                    cornerStyle = state.collageCornerStyle,
                    aspectRatio = state.collageAspectRatio,
                    transforms = state.collageTransforms
                )
                _uiState.update {
                    it.copy(
                        capturedBitmap = collage,
                        isCollageMode = false,
                        showCollageView = false,
                        collagePhotos = emptyList(),
                        collageReplaceIndex = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update { it.copy(error = "Kolaj olusturulamadi") }
            }
        }
    }

    fun cancelCollage() {
        _uiState.update {
            it.copy(
                isCollageMode = false,
                showCollageView = false,
                collagePhotos = emptyList(),
                collageReplaceIndex = null
            )
        }
    }

    fun setCollageGap(gap: Float) {
        _uiState.update { it.copy(collageGap = gap) }
    }

    fun setCollageBackground(background: CollageBackground) {
        _uiState.update { it.copy(collageBackground = background) }
    }

    fun setCollageCornerStyle(style: CollageCornerStyle) {
        _uiState.update { it.copy(collageCornerStyle = style) }
    }

    fun setCollageAspectRatio(ratio: CollageAspectRatio) {
        _uiState.update { it.copy(collageAspectRatio = ratio, collageTransforms = emptyMap()) }
    }

    fun setCollageTransform(index: Int, transform: PhotoTransform) {
        _uiState.update { state ->
            val updated = state.collageTransforms.toMutableMap()
            updated[index] = transform
            state.copy(collageTransforms = updated)
        }
    }

    fun clearCollageTransforms() {
        _uiState.update { it.copy(collageTransforms = emptyMap()) }
    }

    fun removeFromCollage(index: Int) {
        _uiState.update { state ->
            if (index >= state.collagePhotos.size) return@update state
            val updated = state.collagePhotos.toMutableList().also { it.removeAt(index) }
            if (updated.size < 2) {
                state.copy(collagePhotos = updated, showCollageView = false)
            } else {
                state.copy(collagePhotos = updated)
            }
        }
    }

    fun swapCollagePhotos(fromIndex: Int, toIndex: Int) {
        _uiState.update { state ->
            if (fromIndex >= state.collagePhotos.size || toIndex >= state.collagePhotos.size) return@update state
            val updated = state.collagePhotos.toMutableList()
            val temp = updated[fromIndex]
            updated[fromIndex] = updated[toIndex]
            updated[toIndex] = temp
            state.copy(collagePhotos = updated)
        }
    }

    fun setCollageReplaceIndex(index: Int) {
        _uiState.update { it.copy(collageReplaceIndex = index) }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    override fun onCleared() {
        super.onCleared()
        recordingJob?.cancel()
        mediaRecorder?.release()
        recordingFile?.delete()
        videoRecordingJob?.cancel()
        videoRecorder?.release()
        videoOutputFile?.delete()
    }
}
