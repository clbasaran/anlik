package com.celalbasaran.stripmate.ui.screen.friends

import android.content.Context
import android.provider.ContactsContract
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.celalbasaran.stripmate.service.contacts.ContactSyncRepository
import com.celalbasaran.stripmate.service.contacts.MatchedContact
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.security.MessageDigest
import javax.inject.Inject

data class RawContact(val name: String, val phone: String, val hash: String)

sealed class ContactSyncUiState {
    object Idle : ContactSyncUiState()
    object Loading : ContactSyncUiState()
    data class Done(
        val matched: List<MatchedContact>,
        val unmatched: List<RawContact>
    ) : ContactSyncUiState()
    data class Error(val message: String) : ContactSyncUiState()
}

@HiltViewModel
class ContactSyncViewModel @Inject constructor(
    private val repository: ContactSyncRepository
) : ViewModel() {

    private val _state = MutableStateFlow<ContactSyncUiState>(ContactSyncUiState.Idle)
    val state: StateFlow<ContactSyncUiState> = _state

    val sentRequestIds = MutableStateFlow<Set<String>>(emptySet())

    fun syncContacts(context: Context) {
        viewModelScope.launch {
            _state.value = ContactSyncUiState.Loading
            try {
                val rawContacts = readContacts(context)
                val hashes = rawContacts.map { it.hash }
                val matched = repository.matchContacts(hashes)
                val matchedHashes = matched.map { it.hash }.toSet()
                val unmatched = rawContacts.filter { it.hash !in matchedHashes }
                _state.value = ContactSyncUiState.Done(matched, unmatched)
            } catch (e: Exception) {
                _state.value = ContactSyncUiState.Error(e.message ?: "Hata oluştu")
            }
        }
    }

    fun sendFriendRequest(toUserId: String) {
        val currentUid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        viewModelScope.launch {
            try {
                val db = FirebaseFirestore.getInstance()
                db.collection("friend_requests").add(
                    mapOf(
                        "senderId" to currentUid,
                        "receiverId" to toUserId,
                        "status" to "pending",
                        "createdAt" to FieldValue.serverTimestamp()
                    )
                ).await()
                sentRequestIds.value = sentRequestIds.value + toUserId
            } catch (e: Exception) {
                // Silently fail — user can retry
            }
        }
    }

    private fun readContacts(context: Context): List<RawContact> {
        val contacts = mutableListOf<RawContact>()
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )
        context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            projection, null, null, null
        )?.use { cursor ->
            val nameIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val phoneIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (cursor.moveToNext()) {
                val name = cursor.getString(nameIdx) ?: continue
                val phone = normalizePhone(cursor.getString(phoneIdx) ?: continue)
                if (phone.isEmpty()) continue
                val hash = sha256(phone)
                contacts.add(RawContact(name, phone, hash))
            }
        }
        // Deduplicate by hash (one number per unique hash)
        return contacts.distinctBy { it.hash }
    }

    private fun normalizePhone(phone: String): String {
        var digits = phone.filter { it.isDigit() }
        if (digits.length == 10 && digits.startsWith("0")) digits = "90" + digits.drop(1)
        else if (digits.length == 10) digits = "90" + digits
        return digits
    }

    private fun sha256(input: String): String {
        val bytes = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
        return bytes.joinToString("") { "%02x".format(it) }
    }
}
