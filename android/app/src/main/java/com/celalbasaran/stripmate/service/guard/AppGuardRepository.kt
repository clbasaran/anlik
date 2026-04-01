package com.celalbasaran.stripmate.service.guard

import java.util.Date

/**
 * Centralized guard service for ban/suspend checks, maintenance mode, and word filtering.
 * Mirrors the iOS AppGuardService.
 */
interface AppGuardRepository {

    // -- User Status --

    sealed class UserStatus {
        data object Active : UserStatus()
        data class Banned(val reason: String) : UserStatus()
        data class Suspended(val until: Date, val reason: String) : UserStatus()
    }

    suspend fun checkUserStatus(forceRefresh: Boolean = false): UserStatus

    // -- Maintenance Mode --

    data class MaintenanceInfo(
        val isActive: Boolean,
        val message: String
    )

    suspend fun checkMaintenance(forceRefresh: Boolean = false): MaintenanceInfo

    // -- Word Filter --

    suspend fun fetchBannedWords(forceRefresh: Boolean = false): Set<String>

    /**
     * Checks if the text contains any banned words using word-boundary regex.
     * Returns the first matched word or null.
     */
    suspend fun containsBannedWord(text: String): String?

    /**
     * Clears all local caches (call on logout).
     */
    fun clearCache()
}
