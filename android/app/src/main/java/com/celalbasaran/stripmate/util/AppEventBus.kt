package com.celalbasaran.stripmate.util

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * Process-wide event bus for cross-module signals (cache invalidation, etc.).
 * Mirrors iOS NotificationCenter usage: post on mutating actions, observe in
 * UI/cache layers to react.
 */
object AppEventBus {
    sealed class Event {
        /** Friendship list changed (add/accept/remove/block/unblock/favorite-toggle). */
        object FriendListChanged : Event()
        /** Send-groups created / updated / deleted. */
        object SendGroupsChanged : Event()
    }

    private val _events = MutableSharedFlow<Event>(
        replay = 0,
        extraBufferCapacity = 16,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val events: SharedFlow<Event> = _events.asSharedFlow()

    fun post(event: Event) {
        _events.tryEmit(event)
    }
}
