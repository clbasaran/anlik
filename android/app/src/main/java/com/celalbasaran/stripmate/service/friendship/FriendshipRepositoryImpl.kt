package com.celalbasaran.stripmate.service.friendship

import android.util.Log
import com.celalbasaran.stripmate.data.model.Friend
import com.celalbasaran.stripmate.data.model.UserProfile
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FieldPath
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Source
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FriendshipRepositoryImpl @Inject constructor(
    private val db: FirebaseFirestore,
    private val authRepository: AuthRepository
) : FriendshipRepository {

    override suspend fun fetchFriends(): List<Friend> {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        val snapshot = db.collection("users").document(uid)
            .collection("friendships").get().await()

        val friendEntries = snapshot.documents.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            val userId = data["userId"] as? String ?: return@mapNotNull null
            val isPending = data["isPending"] as? Boolean ?: false
            val timestamp = (data["timestamp"] as? Timestamp)?.toDate() ?: Date()
            val requesterId = data["requesterId"] as? String
            FriendEntry(userId, isPending, timestamp, requesterId)
        }

        // Batch fetch profiles in chunks of 30
        val allIds = friendEntries.map { it.userId }
        val profileMap = batchFetchProfiles(allIds)

        return friendEntries.map { entry ->
            Friend(
                userId = entry.userId,
                isPending = entry.isPending,
                requesterId = entry.requesterId,
                timestamp = entry.timestamp,
                profile = profileMap[entry.userId]
            )
        }
    }

    override suspend fun sendFriendRequest(toUserId: String) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        if (uid == toUserId) throw Exception("Cannot send friend request to yourself")

        // Friend limit: max 50 active friends
        val existingFriends = db.collection("users").document(uid)
            .collection("friendships")
            .whereEqualTo("isPending", false)
            .get()
            .await()
        if (existingFriends.documents.size >= 50) {
            throw Exception("Maximum 50 friends limit reached")
        }

        val batch = db.batch()

        val outboundRef = db.collection("users").document(uid)
            .collection("friendships").document(toUserId)
        batch.set(outboundRef, mapOf(
            "userId" to toUserId,
            "isPending" to true,
            "requesterId" to uid,
            "timestamp" to FieldValue.serverTimestamp()
        ))

        val inboundRef = db.collection("users").document(toUserId)
            .collection("friendships").document(uid)
        batch.set(inboundRef, mapOf(
            "userId" to uid,
            "isPending" to true,
            "requesterId" to uid,
            "timestamp" to FieldValue.serverTimestamp()
        ))

        batch.commit().await()
    }

    override suspend fun acceptFriendRequest(fromUserId: String) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        val batch = db.batch()

        val outboundRef = db.collection("users").document(uid)
            .collection("friendships").document(fromUserId)
        batch.update(outboundRef, "isPending", false)

        val inboundRef = db.collection("users").document(fromUserId)
            .collection("friendships").document(uid)
        batch.update(inboundRef, "isPending", false)

        batch.commit().await()
    }

    override suspend fun declineFriendRequest(fromUserId: String) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        val batch = db.batch()

        val outboundRef = db.collection("users").document(uid)
            .collection("friendships").document(fromUserId)
        batch.delete(outboundRef)

        val inboundRef = db.collection("users").document(fromUserId)
            .collection("friendships").document(uid)
        batch.delete(inboundRef)

        batch.commit().await()
    }

    override suspend fun removeFriend(userId: String) {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        val batch = db.batch()

        val outboundRef = db.collection("users").document(uid)
            .collection("friendships").document(userId)
        batch.delete(outboundRef)

        val inboundRef = db.collection("users").document(userId)
            .collection("friendships").document(uid)
        batch.delete(inboundRef)

        batch.commit().await()
    }

    override suspend fun fetchPendingIncomingRequests(): List<Friend> {
        val uid = authRepository.currentUserId()
            ?: throw Exception("Not authenticated")

        // Try server first, fall back to cache when offline
        val snapshot = try {
            db.collection("users").document(uid)
                .collection("friendships")
                .whereEqualTo("isPending", true)
                .get(Source.SERVER)
                .await()
        } catch (e: Exception) {
            db.collection("users").document(uid)
                .collection("friendships")
                .whereEqualTo("isPending", true)
                .get(Source.CACHE)
                .await()
        }

        // Filter: only incoming requests (requesterId != currentUid)
        val incoming = snapshot.documents.filter { doc ->
            val data = doc.data ?: return@filter false
            val requesterId = data["requesterId"] as? String
            requesterId != null && requesterId != uid
        }

        if (incoming.isEmpty()) return emptyList()

        val userIds = incoming.mapNotNull { it.data?.get("userId") as? String }
        val profileMap = batchFetchProfiles(userIds)

        return incoming.mapNotNull { doc ->
            val data = doc.data ?: return@mapNotNull null
            Friend(
                userId = data["userId"] as? String ?: doc.id,
                isPending = true,
                requesterId = data["requesterId"] as? String,
                timestamp = (data["timestamp"] as? Timestamp)?.toDate() ?: Date(),
                profile = profileMap[data["userId"] as? String ?: doc.id]
            )
        }
    }

    override suspend fun getPendingCount(): Int {
        val uid = authRepository.currentUserId() ?: return 0

        return try {
            val snapshot = db.collection("users").document(uid)
                .collection("friendships")
                .whereEqualTo("isPending", true)
                .get()
                .await()

            snapshot.documents.count { doc ->
                val data = doc.data ?: return@count false
                val requesterId = data["requesterId"] as? String
                requesterId != uid
            }
        } catch (e: Exception) {
            0
        }
    }

    override suspend fun hasAnyFriendship(): Boolean {
        val uid = authRepository.currentUserId() ?: return false

        return try {
            val snapshot = db.collection("users").document(uid)
                .collection("friendships")
                .limit(1)
                .get()
                .await()
            snapshot.documents.isNotEmpty()
        } catch (e: Exception) {
            false
        }
    }

    override suspend fun hasAcceptedFriends(): Boolean {
        val uid = authRepository.currentUserId() ?: return false

        return try {
            val snapshot = db.collection("users").document(uid)
                .collection("friendships")
                .whereEqualTo("isPending", false)
                .limit(1)
                .get()
                .await()
            snapshot.documents.isNotEmpty()
        } catch (e: Exception) {
            false
        }
    }

    // MARK: - Private Helpers

    private suspend fun batchFetchProfiles(userIds: List<String>): Map<String, UserProfile> {
        if (userIds.isEmpty()) return emptyMap()

        val profileMap = mutableMapOf<String, UserProfile>()
        val chunks = userIds.chunked(30) // Firestore `in` query limit

        for (chunk in chunks) {
            if (chunk.isEmpty()) continue
            try {
                val profileSnapshot = db.collection("users")
                    .whereIn(FieldPath.documentId(), chunk)
                    .get()
                    .await()

                for (doc in profileSnapshot.documents) {
                    val profile = UserProfile.fromDocument(doc) ?: continue
                    profileMap[doc.id] = profile
                }
            } catch (e: Exception) { Log.e("FriendshipRepository", "Failed to batch fetch profiles", e) }
        }

        return profileMap
    }

    private data class FriendEntry(
        val userId: String,
        val isPending: Boolean,
        val timestamp: Date,
        val requesterId: String?
    )
}
