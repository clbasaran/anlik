package com.celalbasaran.stripmate.service.guard

import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import java.util.Date
import java.util.regex.Pattern
import javax.inject.Inject

class AppGuardRepositoryImpl @Inject constructor(
    private val auth: FirebaseAuth,
    private val db: FirebaseFirestore
) : AppGuardRepository {

    // -- User Status Cache --

    private var cachedStatus: AppGuardRepository.UserStatus? = null
    private var statusFetchedAt: Long? = null
    private val statusTTL = 60_000L // 60 seconds

    override suspend fun checkUserStatus(forceRefresh: Boolean): AppGuardRepository.UserStatus {
        if (!forceRefresh) {
            val cached = cachedStatus
            val fetchedAt = statusFetchedAt
            if (cached != null && fetchedAt != null &&
                System.currentTimeMillis() - fetchedAt < statusTTL
            ) {
                return cached
            }
        }

        val uid = auth.currentUser?.uid ?: return AppGuardRepository.UserStatus.Active

        return try {
            val doc = db.collection("users").document(uid).get().await()
            val data = doc.data ?: emptyMap()

            val isBanned = data["isBanned"] as? Boolean ?: false
            if (isBanned) {
                val reason = data["banReason"] as? String ?: ""
                val status = AppGuardRepository.UserStatus.Banned(reason)
                cachedStatus = status
                statusFetchedAt = System.currentTimeMillis()
                return status
            }

            val isSuspended = data["isSuspended"] as? Boolean ?: false
            if (isSuspended) {
                val timestamp = data["suspendedUntil"] as? com.google.firebase.Timestamp
                val until = timestamp?.toDate()
                if (until != null && until.after(Date())) {
                    val reason = data["banReason"] as? String ?: ""
                    val status = AppGuardRepository.UserStatus.Suspended(until, reason)
                    cachedStatus = status
                    statusFetchedAt = System.currentTimeMillis()
                    return status
                }
                // Suspension expired -- clear it silently
                try {
                    db.collection("users").document(uid).update(
                        mapOf(
                            "isSuspended" to false,
                            "suspendedUntil" to FieldValue.delete(),
                            "banReason" to FieldValue.delete(),
                            "bannedBy" to FieldValue.delete(),
                            "bannedAt" to FieldValue.delete()
                        )
                    ).await()
                } catch (e: Exception) { Log.e("AppGuardRepository", "Failed to clear expired suspension", e) }
            }

            val status = AppGuardRepository.UserStatus.Active
            cachedStatus = status
            statusFetchedAt = System.currentTimeMillis()
            status
        } catch (e: Exception) {
            Log.e("AppGuardRepository", "Failed to check user status", e)
            cachedStatus ?: AppGuardRepository.UserStatus.Active
        }
    }

    // -- Maintenance Cache --

    private var maintenanceCache: AppGuardRepository.MaintenanceInfo? = null
    private var maintenanceFetchedAt: Long? = null
    private val maintenanceTTL = 120_000L // 2 minutes

    override suspend fun checkMaintenance(forceRefresh: Boolean): AppGuardRepository.MaintenanceInfo {
        if (!forceRefresh) {
            val cached = maintenanceCache
            val fetchedAt = maintenanceFetchedAt
            if (cached != null && fetchedAt != null &&
                System.currentTimeMillis() - fetchedAt < maintenanceTTL
            ) {
                return cached
            }
        }

        return try {
            val doc = db.collection("app_config").document("settings").get().await()
            val data = doc.data ?: emptyMap()
            val isActive = data["maintenanceMode"] as? Boolean ?: false
            val message = data["maintenanceMessage"] as? String
                ?: "Uygulama bakımda. Lütfen daha sonra tekrar deneyin."
            val info = AppGuardRepository.MaintenanceInfo(isActive, message)
            maintenanceCache = info
            maintenanceFetchedAt = System.currentTimeMillis()
            info
        } catch (e: Exception) {
            Log.e("AppGuardRepository", "Failed to check maintenance status", e)
            maintenanceCache ?: AppGuardRepository.MaintenanceInfo(false, "")
        }
    }

    // -- Word Filter Cache --

    private var wordFilterCache: Set<String>? = null
    private var wordFilterFetchedAt: Long? = null
    private val wordFilterTTL = 300_000L // 5 minutes

    override suspend fun fetchBannedWords(forceRefresh: Boolean): Set<String> {
        if (!forceRefresh) {
            val cached = wordFilterCache
            val fetchedAt = wordFilterFetchedAt
            if (cached != null && fetchedAt != null &&
                System.currentTimeMillis() - fetchedAt < wordFilterTTL
            ) {
                return cached
            }
        }

        return try {
            val snap = db.collection("admin_word_filters").get().await()
            val words = snap.documents.mapNotNull { it.getString("word") }.toSet()
            wordFilterCache = words
            wordFilterFetchedAt = System.currentTimeMillis()
            words
        } catch (e: Exception) {
            Log.e("AppGuardRepository", "Failed to fetch banned words", e)
            wordFilterCache ?: emptySet()
        }
    }

    override suspend fun containsBannedWord(text: String): String? {
        val banned = fetchBannedWords()
        for (word in banned) {
            val pattern = Pattern.compile(
                "\\b${Pattern.quote(word)}\\b",
                Pattern.CASE_INSENSITIVE or Pattern.UNICODE_CASE
            )
            if (pattern.matcher(text).find()) {
                return word
            }
        }
        return null
    }

    override fun clearCache() {
        cachedStatus = null
        statusFetchedAt = null
        maintenanceCache = null
        maintenanceFetchedAt = null
        wordFilterCache = null
        wordFilterFetchedAt = null
    }
}
