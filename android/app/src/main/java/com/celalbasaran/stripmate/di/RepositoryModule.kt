package com.celalbasaran.stripmate.di

import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.auth.AuthRepositoryImpl
import com.celalbasaran.stripmate.service.contacts.ContactSyncRepository
import com.celalbasaran.stripmate.service.contacts.ContactSyncRepositoryImpl
import com.celalbasaran.stripmate.service.camera.CameraRepository
import com.celalbasaran.stripmate.service.camera.CameraRepositoryImpl
import com.celalbasaran.stripmate.service.chat.ChatRepository
import com.celalbasaran.stripmate.service.chat.ChatRepositoryImpl
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.celalbasaran.stripmate.service.friendship.FriendshipRepositoryImpl
import com.celalbasaran.stripmate.service.guard.AppGuardRepository
import com.celalbasaran.stripmate.service.guard.AppGuardRepositoryImpl
import com.celalbasaran.stripmate.service.location.LocationRepository
import com.celalbasaran.stripmate.service.nudge.NudgeRepository
import com.celalbasaran.stripmate.service.nudge.NudgeRepositoryImpl
import com.celalbasaran.stripmate.service.location.LocationRepositoryImpl
import com.celalbasaran.stripmate.service.notification.NotificationRepository
import com.celalbasaran.stripmate.service.notification.NotificationRepositoryImpl
import com.celalbasaran.stripmate.service.photo.PhotoRepository
import com.celalbasaran.stripmate.service.photo.PhotoRepositoryImpl
import com.celalbasaran.stripmate.service.streak.StreakRepository
import com.celalbasaran.stripmate.service.streak.StreakRepositoryImpl
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindAuthRepository(impl: AuthRepositoryImpl): AuthRepository

    @Binds
    @Singleton
    abstract fun bindPhotoRepository(impl: PhotoRepositoryImpl): PhotoRepository

    @Binds
    @Singleton
    abstract fun bindChatRepository(impl: ChatRepositoryImpl): ChatRepository

    @Binds
    @Singleton
    abstract fun bindFriendshipRepository(impl: FriendshipRepositoryImpl): FriendshipRepository

    @Binds
    @Singleton
    abstract fun bindStreakRepository(impl: StreakRepositoryImpl): StreakRepository

    @Binds
    @Singleton
    abstract fun bindNotificationRepository(impl: NotificationRepositoryImpl): NotificationRepository

    @Binds
    @Singleton
    abstract fun bindLocationRepository(impl: LocationRepositoryImpl): LocationRepository

    @Binds
    @Singleton
    abstract fun bindCameraRepository(impl: CameraRepositoryImpl): CameraRepository

    @Binds
    @Singleton
    abstract fun bindAppGuardRepository(impl: AppGuardRepositoryImpl): AppGuardRepository

    @Binds
    @Singleton
    abstract fun bindNudgeRepository(impl: NudgeRepositoryImpl): NudgeRepository

    @Binds
    @Singleton
    abstract fun bindContactSyncRepository(impl: ContactSyncRepositoryImpl): ContactSyncRepository
}
