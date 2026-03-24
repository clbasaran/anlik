package com.celalbasaran.stripmate.service.streak

import com.celalbasaran.stripmate.data.model.Streak
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class StreakRepositoryImpl @Inject constructor(
    private val db: FirebaseFirestore,
    private val authRepository: AuthRepository
) : StreakRepository {

    // In-memory cache keyed by friendId
    @Volatile
    private var streakCache: Map<String, Streak> = emptyMap()

    override fun listenToStreaks(userId: String): Flow<List<Streak>> = callbackFlow {
        val query = db.collection("streaks")
            .whereArrayContains("userIds", userId)

        val listener: ListenerRegistration = query.addSnapshotListener { snapshot, error ->
            if (error != null || snapshot == null) return@addSnapshotListener

            val newCache = mutableMapOf<String, Streak>()
            val streaks = snapshot.documents.mapNotNull { doc ->
                val streak = parseStreak(doc.data ?: return@mapNotNull null)
                    ?: return@mapNotNull null
                val friendId = streak.userIds.firstOrNull { it != userId } ?: ""
                if (friendId.isNotEmpty()) {
                    newCache[friendId] = streak
                }
                streak
            }

            streakCache = newCache
            trySend(streaks)
        }

        awaitClose { listener.remove() }
    }

    override suspend fun getStreak(friendId: String): Streak? {
        // Return from in-memory cache first
        streakCache[friendId]?.let { return it }

        // Fallback: fetch from Firestore
        val uid = authRepository.currentUserId() ?: return null
        val streakId = Streak.streakId(uid, friendId)

        return try {
            val doc = db.collection("streaks").document(streakId).get().await()
            if (!doc.exists()) return null
            val data = doc.data ?: return null
            parseStreak(data)
        } catch (e: Exception) {
            null
        }
    }

    override suspend fun getAllStreaksByScore(): List<Streak> {
        if (streakCache.isNotEmpty()) {
            return streakCache.values.sortedByDescending { it.friendshipScore }
        }

        // Fallback: fetch from Firestore
        val uid = authRepository.currentUserId() ?: return emptyList()

        return try {
            val snapshot = db.collection("streaks")
                .whereArrayContains("userIds", uid)
                .get()
                .await()

            snapshot.documents.mapNotNull { doc ->
                val data = doc.data ?: return@mapNotNull null
                parseStreak(data)
            }.sortedByDescending { it.friendshipScore }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun parseStreak(data: Map<String, Any?>): Streak? {
        val id = data["id"] as? String ?: return null
        @Suppress("UNCHECKED_CAST")
        val userIds = data["userIds"] as? List<String> ?: return null
        val lastDate = (data["lastExchangeDate"] as? Timestamp)?.toDate() ?: Date()

        return Streak(
            id = id,
            userIds = userIds,
            currentStreak = (data["currentStreak"] as? Number)?.toInt() ?: 0,
            longestStreak = (data["longestStreak"] as? Number)?.toInt() ?: 0,
            totalExchanges = (data["totalExchanges"] as? Number)?.toInt() ?: 0,
            lastExchangeDate = lastDate,
            lastSenderId = data["lastSenderId"] as? String ?: "",
            friendshipScore = (data["friendshipScore"] as? Number)?.toInt() ?: 0
        )
    }

}
