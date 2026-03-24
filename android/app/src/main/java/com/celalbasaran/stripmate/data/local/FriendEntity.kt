package com.celalbasaran.stripmate.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.celalbasaran.stripmate.data.model.Friend
import java.util.Date

@Entity(tableName = "friends")
data class FriendEntity(
    @PrimaryKey
    val userId: String,
    val isPending: Boolean = false,
    val requesterId: String? = null,
    val timestamp: Long = System.currentTimeMillis()
) {
    fun toFriend(): Friend = Friend(
        userId = userId,
        isPending = isPending,
        requesterId = requesterId,
        timestamp = Date(timestamp)
    )

    companion object {
        fun fromFriend(friend: Friend): FriendEntity = FriendEntity(
            userId = friend.userId,
            isPending = friend.isPending,
            requesterId = friend.requesterId,
            timestamp = friend.timestamp.time
        )
    }
}
