package com.celalbasaran.stripmate.ui.screen.settings

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.service.guard.AppGuardRepository
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val guardRepository: AppGuardRepository,
    private val friendshipRepository: FriendshipRepository,
    private val db: FirebaseFirestore
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
            guardRepository.clearCache()
            authRepository.logout()
        }
    }

    fun deleteAccount() {
        viewModelScope.launch {
            authRepository.deleteAccount()
        }
    }

    // MARK: - GDPR Data Export

    private val _isExportingData = MutableStateFlow(false)
    val isExportingData: StateFlow<Boolean> = _isExportingData.asStateFlow()

    fun exportUserData(context: Context) {
        viewModelScope.launch {
            _isExportingData.value = true
            try {
                val uid = authRepository.currentUserId() ?: return@launch
                val profile = _currentProfile.value ?: return@launch
                val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", Locale.US)

                fun Timestamp.toIso(): String = isoFormat.format(this.toDate())

                val root = JSONObject()

                // 1. Profile
                val profileDoc = db.collection("users").document(uid).get().await()
                val profileJson = JSONObject()
                profileDoc.data?.forEach { (key, value) ->
                    if (key != "fcmToken") {
                        profileJson.put(key, when (value) {
                            is Timestamp -> value.toIso()
                            is List<*> -> JSONArray(value)
                            is Map<*, *> -> JSONObject(value)
                            else -> value ?: JSONObject.NULL
                        })
                    }
                }
                root.put("profile", profileJson)

                // 2. Strips (sent photos metadata)
                val stripsArray = JSONArray()
                try {
                    val stripsSnapshot = db.collection("strips")
                        .whereEqualTo("senderId", uid)
                        .get().await()
                    for (doc in stripsSnapshot.documents) {
                        val sj = JSONObject()
                        doc.data?.forEach { (key, value) ->
                            sj.put(key, when (value) {
                                is Timestamp -> value.toIso()
                                is List<*> -> JSONArray(value)
                                is Map<*, *> -> JSONObject(value)
                                else -> value ?: JSONObject.NULL
                            })
                        }
                        stripsArray.put(sj)
                    }
                } catch (_: Exception) { }
                root.put("strips", stripsArray)

                // 3. Comments on user's strips
                val commentsArray = JSONArray()
                try {
                    val stripsSnapshot = db.collection("strips")
                        .whereEqualTo("senderId", uid)
                        .get().await()
                    for (stripDoc in stripsSnapshot.documents) {
                        try {
                            val chatsSnapshot = stripDoc.reference.collection("chats").get().await()
                            for (chatDoc in chatsSnapshot.documents) {
                                val msgsSnapshot = chatDoc.reference.collection("messages").get().await()
                                for (msgDoc in msgsSnapshot.documents) {
                                    val mj = JSONObject()
                                    msgDoc.data?.forEach { (key, value) ->
                                        mj.put(key, when (value) {
                                            is Timestamp -> value.toIso()
                                            else -> value ?: JSONObject.NULL
                                        })
                                    }
                                    commentsArray.put(mj)
                                }
                            }
                        } catch (_: Exception) { }
                    }
                } catch (_: Exception) { }
                root.put("strip_comments", commentsArray)

                // 4. Direct messages (metadata only)
                val dmArray = JSONArray()
                try {
                    val dmThreads = db.collection("direct_messages")
                        .whereArrayContains("participants", uid)
                        .get().await()
                    for (dmDoc in dmThreads.documents) {
                        try {
                            val msgsSnapshot = dmDoc.reference.collection("messages")
                                .limit(200).get().await()
                            for (msgDoc in msgsSnapshot.documents) {
                                val data = msgDoc.data ?: continue
                                val meta = JSONObject().apply {
                                    put("id", data["id"] ?: msgDoc.id)
                                    put("senderId", data["senderId"] ?: "")
                                    put("receiverId", data["receiverId"] ?: "")
                                    val ts = data["timestamp"] as? Timestamp
                                    if (ts != null) put("timestamp", ts.toIso())
                                }
                                dmArray.put(meta)
                            }
                        } catch (_: Exception) { }
                    }
                } catch (_: Exception) { }
                root.put("direct_messages_metadata", dmArray)

                // 5. Friendships
                val friendsArray = JSONArray()
                try {
                    val friendDocs = db.collection("users").document(uid)
                        .collection("friendships").get().await()
                    for (doc in friendDocs.documents) {
                        val fj = JSONObject()
                        fj.put("friendId", doc.id)
                        doc.data?.forEach { (key, value) ->
                            fj.put(key, when (value) {
                                is Timestamp -> value.toIso()
                                else -> value ?: JSONObject.NULL
                            })
                        }
                        friendsArray.put(fj)
                    }
                } catch (_: Exception) { }
                root.put("friendships", friendsArray)

                // 6. Achievements
                val achievementsArray = JSONArray()
                try {
                    val achievementDocs = db.collection("users").document(uid)
                        .collection("achievements").get().await()
                    for (doc in achievementDocs.documents) {
                        val aj = JSONObject()
                        doc.data?.forEach { (key, value) ->
                            aj.put(key, when (value) {
                                is Timestamp -> value.toIso()
                                else -> value ?: JSONObject.NULL
                            })
                        }
                        achievementsArray.put(aj)
                    }
                } catch (_: Exception) { }
                root.put("achievements", achievementsArray)

                // 7. Export metadata
                root.put("export_metadata", JSONObject().apply {
                    put("userId", uid)
                    put("exportDate", isoFormat.format(Date()))
                    put("appVersion", try {
                        context.packageManager.getPackageInfo(context.packageName, 0).versionName
                    } catch (_: Exception) { "unknown" })
                })

                // Write file
                val fileName = "stripmate_data_export_$uid.json"
                val file = File(context.cacheDir, fileName)
                file.writeText(root.toString(2))

                // Share via intent
                val uri = FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    file
                )
                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                    type = "application/json"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                context.startActivity(Intent.createChooser(shareIntent, "Verilerini paylas"))
            } catch (e: Exception) {
                Toast.makeText(context, "Veri disa aktarilamadi", Toast.LENGTH_SHORT).show()
            } finally {
                _isExportingData.value = false
            }
        }
    }
}
