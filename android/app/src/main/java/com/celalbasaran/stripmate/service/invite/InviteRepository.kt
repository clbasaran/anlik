package com.celalbasaran.stripmate.service.invite

import android.content.ClipboardManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.util.AppEventBus
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.functions.FirebaseFunctions
import com.google.firebase.functions.ktx.functions
import com.google.firebase.ktx.Firebase
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Resolves invite-link redemption from three sources:
 * - Universal/App Link (https://anlik.web.app/i/<CODE>) → opens app directly with code
 * - Custom URL scheme (stripmate://invite?code=<CODE>) → legacy/in-app share
 * - Clipboard payload "anlik:invite=<CODE>" → deferred deep link (set by the
 *   landing page when the app wasn't installed yet)
 *
 * On successful redemption, calls the `acceptInvite` Cloud Function which
 * atomically creates a bilateral accepted friendship between the caller and
 * the inviter. Emits an [Event.InviteAccepted] event so the UI can show a
 * welcome banner.
 */
@Singleton
class InviteRepository @Inject constructor(
    @ApplicationContext private val appContext: Context,
    private val authRepository: AuthRepository
) {
    sealed class Event {
        data class InviteAccepted(
            val inviterUserId: String,
            val displayName: String,
            val alreadyFriends: Boolean
        ) : Event()
    }

    private val _events = MutableSharedFlow<Event>(
        replay = 0,
        extraBufferCapacity = 4,
        onBufferOverflow = BufferOverflow.DROP_OLDEST
    )
    val events: SharedFlow<Event> = _events.asSharedFlow()

    private val prefs: SharedPreferences =
        appContext.getSharedPreferences("invite", Context.MODE_PRIVATE)

    private val processedCodes = mutableSetOf<String>()

    /** Try to extract an invite code from a URI. Returns null if not an invite link. */
    fun extractCode(uri: Uri): String? {
        val host = uri.host ?: return null
        val scheme = uri.scheme ?: return null
        // Universal/App Link: https://anlik.web.app/i/<CODE>
        if ((scheme == "https" || scheme == "http") &&
            (host == "anlik.web.app" || host == "stripmate-app.web.app")
        ) {
            val parts = uri.pathSegments
            if (parts.size >= 2 && parts[0] == "i") {
                return parts[1].uppercase().takeIf { it.length in 4..16 }
            }
        }
        // Custom scheme: stripmate://invite?code=<CODE> or anlik://invite?code=<CODE>
        if (scheme == "stripmate" || scheme == "anlik") {
            if (host == "invite" || uri.pathSegments.firstOrNull() == "invite") {
                val code = uri.getQueryParameter("code")?.uppercase()
                if (code != null && code.length in 4..16) return code
            }
        }
        return null
    }

    /** Read the system clipboard for a deferred invite payload set by the web landing page. */
    fun extractCodeFromClipboard(): String? {
        return try {
            val cm = appContext.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                ?: return null
            val clip = cm.primaryClip ?: return null
            if (clip.itemCount == 0) return null
            val text = clip.getItemAt(0).coerceToText(appContext)?.toString() ?: return null
            val prefix = "anlik:invite="
            if (!text.startsWith(prefix)) return null
            val code = text.removePrefix(prefix).trim().uppercase()
            if (code.length !in 4..16) return null
            // Clear so the same code doesn't trigger again on next foreground.
            cm.setPrimaryClip(android.content.ClipData.newPlainText("", ""))
            code
        } catch (e: Exception) {
            Log.w("InviteRepository", "Clipboard read failed", e)
            null
        }
    }

    /** Public entry point. Returns true if the URI was an invite link (regardless of accept outcome). */
    suspend fun handleIncoming(uri: Uri): Boolean {
        val code = extractCode(uri) ?: return false
        redeem(code)
        return true
    }

    /** Check the clipboard once and redeem if a deferred invite payload is present. */
    suspend fun checkClipboardForDeferredInvite() {
        val code = extractCodeFromClipboard() ?: return
        redeem(code)
    }

    /** Call the acceptInvite Cloud Function for a code. No-op on duplicate. */
    suspend fun redeem(rawCode: String) {
        val code = rawCode.trim().uppercase()
        if (code.isEmpty() || code in processedCodes) return
        processedCodes.add(code)

        if (FirebaseAuth.getInstance().currentUser == null) {
            // Stash for retry post-login.
            prefs.edit().putString("pendingInviteCode", code).apply()
            return
        }

        try {
            @Suppress("UNCHECKED_CAST")
            val result = Firebase.functions("europe-west1")
                .getHttpsCallable("acceptInvite")
                .call(mapOf("inviteCode" to code))
                .await()
                .data as? Map<String, Any?> ?: return

            prefs.edit().remove("pendingInviteCode").apply()

            // Mark friend gate as passed so the user goes straight into the app.
            appContext.getSharedPreferences("friend_gate", Context.MODE_PRIVATE)
                .edit().putBoolean("hasPassedFriendGate", true).apply()

            val inviter = result["inviter"] as? Map<*, *>
            val inviterId = inviter?.get("userId") as? String ?: ""
            val displayName = inviter?.get("displayName") as? String ?: ""
            val alreadyFriends = (result["alreadyFriends"] as? Boolean) ?: false

            if (inviterId.isNotEmpty()) {
                _events.tryEmit(Event.InviteAccepted(inviterId, displayName, alreadyFriends))
                AppEventBus.post(AppEventBus.Event.FriendListChanged)
            }
        } catch (e: Exception) {
            Log.w("InviteRepository", "acceptInvite failed for $code", e)
            // Allow retry next time.
            processedCodes.remove(code)
        }
    }

    /** Call once after auth completes to redeem any code stashed before sign-in. */
    suspend fun redeemPendingIfAny() {
        val code = prefs.getString("pendingInviteCode", null) ?: return
        redeem(code)
    }
}
