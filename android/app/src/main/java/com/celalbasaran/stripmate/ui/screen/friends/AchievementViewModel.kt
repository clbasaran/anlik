package com.celalbasaran.stripmate.ui.screen.friends

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.data.model.UserAchievement
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.google.firebase.firestore.FirebaseFirestore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

@HiltViewModel
class AchievementViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val firestore: FirebaseFirestore
) : ViewModel() {

    private val _unlockedAchievements = MutableStateFlow<List<UserAchievement>>(emptyList())
    val unlockedAchievements: StateFlow<List<UserAchievement>> = _unlockedAchievements.asStateFlow()

    private val _progressMap = MutableStateFlow<Map<String, Int>>(emptyMap())
    val progressMap: StateFlow<Map<String, Int>> = _progressMap.asStateFlow()

    init {
        loadAchievements()
    }

    private fun loadAchievements() {
        viewModelScope.launch {
            val userId = authRepository.currentUserId() ?: return@launch

            // Load unlocked achievements
            val snapshot = firestore.collection("users")
                .document(userId)
                .collection("achievements")
                .get()
                .await()

            val unlocked = snapshot.documents.mapNotNull { doc ->
                val achievementId = doc.getString("achievementId") ?: return@mapNotNull null
                val unlockedAt = doc.getTimestamp("unlockedAt")?.toDate() ?: return@mapNotNull null
                UserAchievement(achievementId = achievementId, unlockedAt = unlockedAt)
            }
            _unlockedAchievements.value = unlocked

            // Load progress data
            val progressDoc = firestore.collection("users")
                .document(userId)
                .collection("stats")
                .document("progress")
                .get()
                .await()

            if (progressDoc.exists()) {
                val map = mutableMapOf<String, Int>()
                map["first_photo"] = progressDoc.getLong("photosSent")?.toInt() ?: 0
                map["photos_10"] = progressDoc.getLong("photosSent")?.toInt() ?: 0
                map["photos_50"] = progressDoc.getLong("photosSent")?.toInt() ?: 0
                map["photos_100"] = progressDoc.getLong("photosSent")?.toInt() ?: 0
                map["photos_500"] = progressDoc.getLong("photosSent")?.toInt() ?: 0
                map["streak_7"] = progressDoc.getLong("longestStreak")?.toInt() ?: 0
                map["streak_30"] = progressDoc.getLong("longestStreak")?.toInt() ?: 0
                map["streak_100"] = progressDoc.getLong("longestStreak")?.toInt() ?: 0
                map["streak_365"] = progressDoc.getLong("longestStreak")?.toInt() ?: 0
                map["first_friend"] = progressDoc.getLong("friendCount")?.toInt() ?: 0
                map["friends_5"] = progressDoc.getLong("friendCount")?.toInt() ?: 0
                map["friends_10"] = progressDoc.getLong("friendCount")?.toInt() ?: 0
                map["friends_25"] = progressDoc.getLong("friendCount")?.toInt() ?: 0
                map["first_comment"] = progressDoc.getLong("commentCount")?.toInt() ?: 0
                map["reaction_50"] = progressDoc.getLong("reactionCount")?.toInt() ?: 0
                map["dm_100"] = progressDoc.getLong("dmCount")?.toInt() ?: 0
                map["cities_3"] = progressDoc.getLong("uniqueCities")?.toInt() ?: 0
                map["cities_10"] = progressDoc.getLong("uniqueCities")?.toInt() ?: 0
                map["daily_prompt_7"] = progressDoc.getLong("dailyPromptsCompleted")?.toInt() ?: 0
                map["daily_prompt_30"] = progressDoc.getLong("dailyPromptsCompleted")?.toInt() ?: 0
                map["night_owl"] = if (progressDoc.getBoolean("nightOwl") == true) 1 else 0
                map["early_bird"] = if (progressDoc.getBoolean("earlyBird") == true) 1 else 0
                map["memory_lane"] = if (progressDoc.getBoolean("memoryLane") == true) 1 else 0
                _progressMap.value = map
            }
        }
    }
}
