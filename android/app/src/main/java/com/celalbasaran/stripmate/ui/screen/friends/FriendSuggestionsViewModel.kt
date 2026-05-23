package com.celalbasaran.stripmate.ui.screen.friends

import android.content.Context
import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.service.auth.AuthRepository
import com.celalbasaran.stripmate.service.contacts.ContactSyncRepository
import com.celalbasaran.stripmate.service.contacts.MatchedContact
import com.celalbasaran.stripmate.service.friendship.FriendshipRepository
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import javax.inject.Inject

/**
 * Drives the "people you might know" suggestion sheet shown to users with
 * fewer than 3 friends. Capped to once per 7 days.
 */
@HiltViewModel
class FriendSuggestionsViewModel @Inject constructor(
    private val contactSyncRepository: ContactSyncRepository,
    private val friendshipRepository: FriendshipRepository,
    private val authRepository: AuthRepository,
    @ApplicationContext private val appContext: Context
) : ViewModel() {

    sealed class State {
        object Idle : State()
        object Loading : State()
        data class Ready(val matches: List<MatchedContact>) : State()
        data class Error(val message: String) : State()
    }

    private val prefs: SharedPreferences =
        appContext.getSharedPreferences("friend_suggestions", Context.MODE_PRIVATE)

    private val _state = MutableStateFlow<State>(State.Idle)
    val state: StateFlow<State> = _state

    private val _shouldShow = MutableStateFlow(false)
    val shouldShow: StateFlow<Boolean> = _shouldShow

    val sentRequestIds = MutableStateFlow<Set<String>>(emptySet())

    private val _myInviteCode = MutableStateFlow("")
    val myInviteCode: StateFlow<String> = _myInviteCode

    /**
     * Evaluate whether the suggestion sheet should be shown. Called from the
     * main screen once after auth completes. Triggers when:
     *  - user has fewer than 3 accepted friends
     *  - the sheet hasn't been shown in the last 7 days
     */
    fun evaluateTrigger() {
        viewModelScope.launch {
            try {
                val friends = friendshipRepository.fetchFriends()
                val accepted = friends.count { !it.isPending }
                if (accepted >= 3) return@launch

                val lastShown = prefs.getLong("lastShownAt", 0L)
                val sevenDaysMs = 7L * 24 * 60 * 60 * 1000
                if (lastShown != 0L && System.currentTimeMillis() - lastShown < sevenDaysMs) {
                    return@launch
                }

                _shouldShow.value = true
            } catch (_: Exception) {
                // No-op — trigger evaluation failures are silent (next launch tries again).
            }
        }
    }

    /** Begin contact-sync flow when the sheet opens. */
    fun loadSuggestions(rawContactsHashes: List<String>) {
        viewModelScope.launch {
            _state.value = State.Loading
            try {
                val matches = contactSyncRepository.matchContacts(rawContactsHashes)
                _state.value = State.Ready(matches)
            } catch (e: Exception) {
                _state.value = State.Error(e.message ?: "Hata")
            }
        }
    }

    fun loadInviteCode() {
        viewModelScope.launch {
            val uid = authRepository.currentUserId() ?: return@launch
            _myInviteCode.value = authRepository.fetchProfile(uid)?.inviteCode ?: ""
        }
    }

    fun sendFriendRequest(toUserId: String) {
        val currentUid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        viewModelScope.launch {
            try {
                FirebaseFirestore.getInstance().collection("friend_requests").add(
                    mapOf(
                        "senderId" to currentUid,
                        "receiverId" to toUserId,
                        "status" to "pending",
                        "createdAt" to FieldValue.serverTimestamp()
                    )
                ).await()
                sentRequestIds.value = sentRequestIds.value + toUserId
            } catch (_: Exception) {
                // Silent — UI can show retry indirectly by user re-tapping.
            }
        }
    }

    fun dismiss() {
        prefs.edit().putLong("lastShownAt", System.currentTimeMillis()).apply()
        _shouldShow.value = false
    }
}
