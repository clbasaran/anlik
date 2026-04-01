package com.celalbasaran.stripmate.service.contacts

import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

class ContactSyncRepositoryImpl @Inject constructor(
    private val functions: FirebaseFunctions
) : ContactSyncRepository {

    override suspend fun matchContacts(phoneHashes: List<String>): List<MatchedContact> {
        val result = functions
            .getHttpsCallable("matchContacts")
            .call(mapOf("phoneHashes" to phoneHashes))
            .await()

        @Suppress("UNCHECKED_CAST")
        val data = result.data as? Map<String, Any> ?: return emptyList()
        val matches = data["matches"] as? List<Map<String, Any>> ?: return emptyList()

        return matches.map { m ->
            MatchedContact(
                userId = m["userId"] as? String ?: "",
                displayName = m["displayName"] as? String ?: "",
                username = m["username"] as? String ?: "",
                avatarUrl = m["avatarUrl"] as? String ?: "",
                hash = m["hash"] as? String ?: ""
            )
        }
    }
}
