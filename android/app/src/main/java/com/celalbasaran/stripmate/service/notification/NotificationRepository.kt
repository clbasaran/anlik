package com.celalbasaran.stripmate.service.notification

import com.celalbasaran.stripmate.data.model.AppNotification
import kotlinx.coroutines.flow.Flow

interface NotificationRepository {

    fun listenToNotifications(): Flow<List<AppNotification>>

    suspend fun markAsRead(notificationId: String)

    fun getUnreadCount(): Flow<Int>
}
