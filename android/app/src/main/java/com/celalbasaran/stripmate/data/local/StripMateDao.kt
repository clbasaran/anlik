package com.celalbasaran.stripmate.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface StripMateDao {

    // Users
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertUsers(users: List<UserEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertUser(user: UserEntity)

    @Query("SELECT * FROM users")
    fun getAllUsers(): Flow<List<UserEntity>>

    @Query("SELECT * FROM users WHERE id = :userId LIMIT 1")
    suspend fun getUserById(userId: String): UserEntity?

    @Query("SELECT * FROM users WHERE id = :userId LIMIT 1")
    fun observeUserById(userId: String): Flow<UserEntity?>

    @Query("DELETE FROM users")
    suspend fun deleteAllUsers()

    @Query("DELETE FROM users WHERE id = :userId")
    suspend fun deleteUser(userId: String)

    // Friends
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertFriends(friends: List<FriendEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertFriend(friend: FriendEntity)

    @Query("SELECT * FROM friends")
    fun getAllFriends(): Flow<List<FriendEntity>>

    @Query("SELECT * FROM friends WHERE isPending = 0")
    fun getAcceptedFriends(): Flow<List<FriendEntity>>

    @Query("SELECT * FROM friends WHERE isPending = 1")
    fun getPendingFriends(): Flow<List<FriendEntity>>

    @Query("SELECT * FROM friends WHERE userId = :userId LIMIT 1")
    suspend fun getFriendById(userId: String): FriendEntity?

    @Query("DELETE FROM friends")
    suspend fun deleteAllFriends()

    @Query("DELETE FROM friends WHERE userId = :userId")
    suspend fun deleteFriend(userId: String)

    // Strips
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertStrips(strips: List<StripEntity>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertStrip(strip: StripEntity)

    @Query("SELECT * FROM strips ORDER BY timestamp DESC")
    fun getAllStrips(): Flow<List<StripEntity>>

    @Query("SELECT * FROM strips WHERE senderId = :senderId ORDER BY timestamp DESC")
    fun getStripsBySender(senderId: String): Flow<List<StripEntity>>

    @Query("SELECT * FROM strips WHERE receiverIds LIKE '%' || :userId || '%' ORDER BY timestamp DESC")
    fun getStripsForReceiver(userId: String): Flow<List<StripEntity>>

    @Query("SELECT * FROM strips WHERE id = :stripId LIMIT 1")
    suspend fun getStripById(stripId: String): StripEntity?

    @Query("DELETE FROM strips")
    suspend fun deleteAllStrips()

    @Query("DELETE FROM strips WHERE id = :stripId")
    suspend fun deleteStrip(stripId: String)

    // Clear all tables
    @Query("DELETE FROM users")
    suspend fun clearUsers()

    @Query("DELETE FROM friends")
    suspend fun clearFriends()

    @Query("DELETE FROM strips")
    suspend fun clearStrips()
}
