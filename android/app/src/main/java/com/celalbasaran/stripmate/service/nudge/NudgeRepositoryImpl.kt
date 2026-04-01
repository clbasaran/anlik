package com.celalbasaran.stripmate.service.nudge

import android.util.Log
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import java.util.Calendar
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class NudgeRepositoryImpl @Inject constructor(
    private val db: FirebaseFirestore,
    private val authRepository: AuthRepository
) : NudgeRepository {

    override suspend fun sendNudge(friendId: String) {
        val uid = authRepository.currentUserId()
            ?: throw IllegalStateException("Unauthenticated")

        val nudgeRef = db.collection("users").document(friendId)
            .collection("nudges").document()

        nudgeRef.set(
            mapOf(
                "id" to nudgeRef.id,
                "senderId" to uid,
                "receiverId" to friendId,
                "timestamp" to FieldValue.serverTimestamp()
            )
        ).await()
    }

    override suspend fun nudgesRemainingToday(friendId: String): Int {
        val uid = authRepository.currentUserId() ?: return 0

        val startOfDay = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        return try {
            val snapshot = db.collection("users").document(friendId)
                .collection("nudges")
                .whereEqualTo("senderId", uid)
                .whereGreaterThan("timestamp", Timestamp(startOfDay.time))
                .get()
                .await()
            maxOf(0, 3 - snapshot.size())
        } catch (e: Exception) {
            Log.e("NudgeRepository", "nudgesRemainingToday failed", e)
            3 // Default to 3 (allow nudging) when query fails
        }
    }
}
