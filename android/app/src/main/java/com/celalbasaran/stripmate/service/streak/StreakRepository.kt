package com.celalbasaran.stripmate.service.streak

import com.celalbasaran.stripmate.data.model.Streak
import kotlinx.coroutines.flow.Flow

interface StreakRepository {

    fun listenToStreaks(userId: String): Flow<List<Streak>>

    suspend fun getStreak(friendId: String): Streak?

    suspend fun getAllStreaksByScore(): List<Streak>
}
