package com.celalbasaran.stripmate.service.contacts

interface ContactSyncRepository {
    suspend fun matchContacts(phoneHashes: List<String>): List<MatchedContact>
}

data class MatchedContact(
    val userId: String,
    val displayName: String,
    val username: String,
    val avatarUrl: String,
    val hash: String
)
