package com.celalbasaran.stripmate.service.friendship

import com.celalbasaran.stripmate.data.model.Friend

interface FriendshipRepository {

    suspend fun fetchFriends(): List<Friend>

    /** Toggle the sender-side favorite flag stored at users/{uid}/friendships/{friendId}.isFavorite. */
    suspend fun setFavorite(friendId: String, isFavorite: Boolean)

    suspend fun sendFriendRequest(toUserId: String)

    suspend fun acceptFriendRequest(fromUserId: String)

    suspend fun declineFriendRequest(fromUserId: String)

    suspend fun removeFriend(userId: String)

    suspend fun fetchPendingIncomingRequests(): List<Friend>

    suspend fun getPendingCount(): Int

    suspend fun hasAnyFriendship(): Boolean

    suspend fun hasAcceptedFriends(): Boolean
}
