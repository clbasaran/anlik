package com.celalbasaran.stripmate.service.friendship

import com.celalbasaran.stripmate.data.model.SendGroup
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.util.AppEventBus
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import kotlinx.coroutines.tasks.await
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

/**
 * CRUD for user-defined recipient groups stored at
 * users/{uid}/send_groups/{groupId}. Mirrors the iOS SendGroupService.
 */
@Singleton
class SendGroupRepository @Inject constructor(
    private val db: FirebaseFirestore,
    private val authRepository: AuthRepository
) {

    suspend fun fetchGroups(): List<SendGroup> {
        val uid = authRepository.currentUserId() ?: return emptyList()
        val snap = db.collection("users").document(uid)
            .collection("send_groups")
            .orderBy("createdAt", Query.Direction.ASCENDING)
            .get()
            .await()
        return snap.documents.mapNotNull { SendGroup.fromDocument(it) }
    }

    suspend fun createGroup(name: String, memberIds: List<String>): SendGroup {
        val uid = authRepository.currentUserId() ?: throw Exception("Not authenticated")
        val trimmed = name.trim()
        require(trimmed.isNotEmpty() && trimmed.length <= 40) { "İsim 1-40 karakter olmalı" }
        require(memberIds.isNotEmpty()) { "En az bir kişi seç" }
        val group = SendGroup(name = trimmed, memberIds = memberIds, createdAt = Date())
        db.collection("users").document(uid)
            .collection("send_groups").document(group.id)
            .set(mapOf(
                "name" to group.name,
                "memberIds" to group.memberIds,
                "createdAt" to Timestamp(group.createdAt)
            ))
            .await()
        AppEventBus.post(AppEventBus.Event.SendGroupsChanged)
        return group
    }

    suspend fun updateGroup(id: String, name: String, memberIds: List<String>) {
        val uid = authRepository.currentUserId() ?: throw Exception("Not authenticated")
        val trimmed = name.trim()
        require(trimmed.isNotEmpty() && trimmed.length <= 40) { "İsim 1-40 karakter olmalı" }
        db.collection("users").document(uid)
            .collection("send_groups").document(id)
            .update(mapOf(
                "name" to trimmed,
                "memberIds" to memberIds
            ))
            .await()
        AppEventBus.post(AppEventBus.Event.SendGroupsChanged)
    }

    suspend fun deleteGroup(id: String) {
        val uid = authRepository.currentUserId() ?: throw Exception("Not authenticated")
        db.collection("users").document(uid)
            .collection("send_groups").document(id).delete().await()
        AppEventBus.post(AppEventBus.Event.SendGroupsChanged)
    }
}
