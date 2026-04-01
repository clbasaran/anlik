package com.celalbasaran.stripmate.service.nudge

interface NudgeRepository {

    /** Send a nudge to a friend. Creates a document under the receiver's nudges subcollection. */
    suspend fun sendNudge(friendId: String)

    /** Returns how many nudges remain today for the current user toward a specific friend (max 3). */
    suspend fun nudgesRemainingToday(friendId: String): Int
}
