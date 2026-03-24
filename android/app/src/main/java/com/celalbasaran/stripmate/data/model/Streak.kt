package com.celalbasaran.stripmate.data.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import java.util.Calendar
import java.util.Date

data class Streak(
    val id: String = "",
    val userIds: List<String> = emptyList(),
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val totalExchanges: Int = 0,
    val lastExchangeDate: Date = Date(),
    val lastSenderId: String = "",
    val friendshipScore: Int = 0
) {
    val isExpiringSoon: Boolean
        get() {
            if (currentStreak <= 0) return false
            val calendar = Calendar.getInstance()
            val today = calendar.apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis

            calendar.time = lastExchangeDate
            val lastDay = calendar.apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis

            val daysSince = ((today - lastDay) / (1000 * 60 * 60 * 24)).toInt()
            return daysSince >= 1
        }

    val friendshipTier: FriendshipTier
        get() = when {
            friendshipScore < 50 -> FriendshipTier.TANIDIK
            friendshipScore < 150 -> FriendshipTier.MUHABBET
            friendshipScore < 350 -> FriendshipTier.YAKIN
            friendshipScore < 700 -> FriendshipTier.SIRDAS
            else -> FriendshipTier.KADIM
        }

    val nextTierThreshold: Int
        get() = when (friendshipTier) {
            FriendshipTier.TANIDIK -> 50
            FriendshipTier.MUHABBET -> 150
            FriendshipTier.YAKIN -> 350
            FriendshipTier.SIRDAS -> 700
            FriendshipTier.KADIM -> 1000
        }

    val tierProgress: Double
        get() {
            val current = friendshipScore.toDouble()
            val thresholds = listOf(0 to 50, 50 to 150, 150 to 350, 350 to 700, 700 to 1000)
            for ((low, high) in thresholds) {
                if (friendshipScore < high) {
                    return (current - low) / (high - low)
                }
            }
            return 1.0
        }

    fun toMap(): Map<String, Any?> = buildMap {
        put("id", id)
        put("userIds", userIds)
        put("currentStreak", currentStreak)
        put("longestStreak", longestStreak)
        put("totalExchanges", totalExchanges)
        put("lastExchangeDate", Timestamp(lastExchangeDate))
        put("lastSenderId", lastSenderId)
        put("friendshipScore", friendshipScore)
    }

    companion object {
        fun streakId(uid1: String, uid2: String): String {
            return listOf(uid1, uid2).sorted().joinToString("_")
        }

        @Suppress("UNCHECKED_CAST")
        fun fromDocument(doc: DocumentSnapshot): Streak? {
            if (!doc.exists()) return null
            return Streak(
                id = doc.id,
                userIds = doc.get("userIds") as? List<String> ?: emptyList(),
                currentStreak = doc.getLong("currentStreak")?.toInt() ?: 0,
                longestStreak = doc.getLong("longestStreak")?.toInt() ?: 0,
                totalExchanges = doc.getLong("totalExchanges")?.toInt() ?: 0,
                lastExchangeDate = doc.getTimestamp("lastExchangeDate")?.toDate() ?: Date(),
                lastSenderId = doc.getString("lastSenderId") ?: "",
                friendshipScore = doc.getLong("friendshipScore")?.toInt() ?: 0
            )
        }
    }
}

enum class FriendshipTier(val tierName: String, val tierIcon: String) {
    TANIDIK("Tanıdık", "circle_dotted"),
    MUHABBET("Muhabbet", "cup_and_saucer"),
    YAKIN("Yakın", "link"),
    SIRDAS("Sırdaş", "key"),
    KADIM("Kadim", "infinity")
}
