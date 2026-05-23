package com.celalbasaran.stripmate.service.update

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.util.Log
import androidx.core.content.FileProvider
import com.celalbasaran.stripmate.BuildConfig
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Self-hosted APK update service for anlık. (not on Play Store).
 *
 * Workflow:
 * 1. On app foreground, read `app_config/settings` from Firestore:
 *    - `androidLatestVersionCode: Int` — newest available
 *    - `androidLatestVersionName: String` — human-readable, shown in banner
 *    - `androidApkUrl: String` — direct HTTPS URL to the signed APK
 *    - `androidMinRequiredVersionCode: Int` — versions below are forced to update
 *    - `androidUpdateNotes: String` — optional release notes (Turkish)
 * 2. Compare against [BuildConfig.VERSION_CODE]:
 *    - newer available + below min → emit ForceUpdate (UI blocks the app)
 *    - newer available → emit UpdateAvailable (UI shows soft banner)
 * 3. User taps "güncelle" → start a DownloadManager request to a local file
 *    in cacheDir, observe progress, and on completion launch the system
 *    installer via FileProvider.
 *
 * Requires:
 * - Manifest: `REQUEST_INSTALL_PACKAGES` permission, FileProvider entry
 * - User must allow "install unknown apps" once (system handles the prompt)
 * - APK must be signed with the same keystore as the running build, otherwise
 *   the installer rejects the upgrade.
 */
@Singleton
class AppUpdateService @Inject constructor(
    @ApplicationContext private val appContext: Context
) {
    sealed class State {
        object Idle : State()
        /** A newer version is available. */
        data class UpdateAvailable(val info: VersionInfo) : State()
        /** Hard block — current version is below the configured minimum. */
        data class ForceUpdate(val info: VersionInfo) : State()
        /** Download in progress. */
        data class Downloading(val info: VersionInfo, val progress: Float) : State()
        /** Download complete; installer will launch. */
        data class ReadyToInstall(val info: VersionInfo, val file: File) : State()
        /** Download failed. */
        data class Failed(val message: String) : State()
    }

    data class VersionInfo(
        val versionCode: Int,
        val versionName: String,
        val apkUrl: String,
        val notes: String,
        val isForce: Boolean
    )

    private val _state = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = _state.asStateFlow()

    private val _events = MutableSharedFlow<Event>(replay = 0, extraBufferCapacity = 4)
    val events: SharedFlow<Event> = _events.asSharedFlow()

    sealed class Event {
        /** Emitted when the installer is about to be launched. UI can show a "açılıyor" toast. */
        object LaunchingInstaller : Event()
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var currentDownloadId: Long = -1L

    /** Run the update check. Safe to call repeatedly; debounce handled by state. */
    suspend fun checkForUpdates() {
        // Don't re-check while a download is active.
        if (_state.value is State.Downloading || _state.value is State.ReadyToInstall) return

        try {
            val doc = Firebase.firestore.collection("app_config").document("settings").get().await()
            val latest = (doc.getLong("androidLatestVersionCode") ?: 0L).toInt()
            val minRequired = (doc.getLong("androidMinRequiredVersionCode") ?: 0L).toInt()
            val versionName = doc.getString("androidLatestVersionName") ?: ""
            val apkUrl = doc.getString("androidApkUrl") ?: ""
            val notes = doc.getString("androidUpdateNotes") ?: ""
            val current = BuildConfig.VERSION_CODE

            if (apkUrl.isEmpty() || latest <= current) {
                _state.value = State.Idle
                return
            }

            val info = VersionInfo(
                versionCode = latest,
                versionName = versionName.ifEmpty { "yeni sürüm" },
                apkUrl = apkUrl,
                notes = notes,
                isForce = minRequired > current
            )
            _state.value = if (info.isForce) State.ForceUpdate(info) else State.UpdateAvailable(info)
        } catch (e: Exception) {
            Log.w("AppUpdateService", "checkForUpdates failed", e)
        }
    }

    /** User accepted the update prompt — start downloading the APK. */
    fun startDownload(info: VersionInfo) {
        if (_state.value is State.Downloading) return
        _state.value = State.Downloading(info, 0f)

        val dm = appContext.getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
        if (dm == null) {
            _state.value = State.Failed("İndirme servisi bulunamadı")
            return
        }

        // Use external cache dir so DownloadManager can write without extra perms,
        // and the file is auto-cleaned when the app is uninstalled.
        val targetDir = appContext.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: appContext.cacheDir
        if (!targetDir.exists()) targetDir.mkdirs()
        val file = File(targetDir, "anlik-${info.versionCode}.apk")
        // If we already have it cached (re-attempt after interruption), skip download.
        if (file.exists() && file.length() > 0) {
            _state.value = State.ReadyToInstall(info, file)
            launchInstaller(file)
            return
        }

        try {
            val request = DownloadManager.Request(Uri.parse(info.apkUrl))
                .setTitle("anlık. güncelleme")
                .setDescription("yeni sürüm indiriliyor")
                .setMimeType("application/vnd.android.package-archive")
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                .setDestinationUri(Uri.fromFile(file))
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)
            currentDownloadId = dm.enqueue(request)
            observeDownload(dm, currentDownloadId, info, file)
        } catch (e: Exception) {
            Log.w("AppUpdateService", "startDownload failed", e)
            _state.value = State.Failed("İndirme başlatılamadı: ${e.message}")
        }
    }

    private fun observeDownload(dm: DownloadManager, id: Long, info: VersionInfo, file: File) {
        scope.launch {
            while (true) {
                val query = DownloadManager.Query().setFilterById(id)
                val cursor = dm.query(query) ?: break
                if (!cursor.moveToFirst()) {
                    cursor.close()
                    _state.value = State.Failed("İndirme bulunamadı")
                    return@launch
                }
                val statusIdx = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
                val totalIdx = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
                val soFarIdx = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
                val status = if (statusIdx >= 0) cursor.getInt(statusIdx) else 0
                val total = if (totalIdx >= 0) cursor.getLong(totalIdx) else 0L
                val soFar = if (soFarIdx >= 0) cursor.getLong(soFarIdx) else 0L
                cursor.close()

                when (status) {
                    DownloadManager.STATUS_SUCCESSFUL -> {
                        _state.value = State.ReadyToInstall(info, file)
                        _events.tryEmit(Event.LaunchingInstaller)
                        launchInstaller(file)
                        return@launch
                    }
                    DownloadManager.STATUS_FAILED -> {
                        _state.value = State.Failed("İndirme başarısız")
                        return@launch
                    }
                    else -> {
                        if (total > 0) {
                            _state.value = State.Downloading(info, (soFar.toFloat() / total.toFloat()).coerceIn(0f, 1f))
                        }
                        delay(500)
                    }
                }
            }
        }
    }

    /**
     * Launches the system package installer for [apkFile]. Requires
     * REQUEST_INSTALL_PACKAGES permission + the user enabling "install unknown
     * apps" for anlık. (the system shows a one-time settings prompt).
     */
    private fun launchInstaller(apkFile: File) {
        try {
            val authority = "${appContext.packageName}.fileprovider"
            val uri: Uri = FileProvider.getUriForFile(appContext, authority, apkFile)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            appContext.startActivity(intent)
        } catch (e: Exception) {
            Log.w("AppUpdateService", "launchInstaller failed", e)
            _state.value = State.Failed("Yükleyici açılamadı: ${e.message}")
        }
    }

    /** User dismissed a soft update prompt. Hides the banner until next foreground. */
    fun dismiss() {
        if (_state.value is State.UpdateAvailable) {
            _state.value = State.Idle
        }
    }
}
