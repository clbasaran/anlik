package com.celalbasaran.stripmate.ui.screen.friends

import android.Manifest
import android.content.pm.PackageManager
import android.provider.ContactsContract
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.ui.component.UserAvatar
import java.security.MessageDigest

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendSuggestionsSheet(
    onDismiss: () -> Unit,
    viewModel: FriendSuggestionsViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    val sentIds by viewModel.sentRequestIds.collectAsState()

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val contactsPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            val hashes = readContacts(context)
            viewModel.loadSuggestions(hashes)
        }
    }

    LaunchedEffect(Unit) {
        viewModel.loadInviteCode()
        // If permission already granted, fetch suggestions immediately;
        // otherwise request it (the launcher resolves the rest).
        val granted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            val hashes = readContacts(context)
            viewModel.loadSuggestions(hashes)
        } else {
            contactsPermissionLauncher.launch(Manifest.permission.READ_CONTACTS)
        }
    }

    ModalBottomSheet(
        onDismissRequest = {
            viewModel.dismiss()
            onDismiss()
        },
        sheetState = sheetState,
        containerColor = Color.Black,
        contentColor = Color.White
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 320.dp)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "rehberinde anlık.'ta olanlar",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "ilk birkaç arkadaşı eklemek anlık.'ı seninle birlikte canlı tutar.",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.5f),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 24.dp)
            )
            Spacer(modifier = Modifier.height(20.dp))

            when (val s = state) {
                is FriendSuggestionsViewModel.State.Loading,
                is FriendSuggestionsViewModel.State.Idle -> {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 200.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = Color.White)
                    }
                }
                is FriendSuggestionsViewModel.State.Ready -> {
                    if (s.matches.isEmpty()) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 180.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "rehberinde anlık. kullanan kimseyi bulamadık",
                                color = Color.White.copy(alpha = 0.5f),
                                fontSize = 13.sp,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.padding(horizontal = 24.dp)
                            )
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(max = 480.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            items(s.matches, key = { it.userId }) { match ->
                                SuggestionRow(
                                    match = match,
                                    isSent = match.userId in sentIds,
                                    onAdd = { viewModel.sendFriendRequest(match.userId) }
                                )
                            }
                        }
                    }
                }
                is FriendSuggestionsViewModel.State.Error -> {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 200.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = s.message,
                            color = Color.White.copy(alpha = 0.5f),
                            fontSize = 13.sp,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(horizontal = 24.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

@Composable
private fun SuggestionRow(
    match: com.celalbasaran.stripmate.service.contacts.MatchedContact,
    isSent: Boolean,
    onAdd: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.04f), RoundedCornerShape(14.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        UserAvatar(
            imageUrl = match.avatarUrl.ifEmpty { null },
            displayName = match.displayName.ifEmpty { match.username },
            size = 44.dp
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = match.displayName.ifEmpty { match.username },
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1
            )
            if (match.username.isNotEmpty() && match.displayName.isNotEmpty()) {
                Text(
                    text = "@${match.username}",
                    color = Color.White.copy(alpha = 0.4f),
                    fontSize = 12.sp,
                    maxLines = 1
                )
            }
        }
        Box(
            modifier = Modifier
                .background(
                    if (isSent) Color.White.copy(alpha = 0.12f) else Color.White,
                    RoundedCornerShape(50)
                )
                .clickable(enabled = !isSent) { onAdd() }
                .padding(horizontal = 14.dp, vertical = 8.dp)
        ) {
            Text(
                text = if (isSent) "istek gitti" else "ekle",
                color = if (isSent) Color.White.copy(alpha = 0.5f) else Color.Black,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

/**
 * Reads contacts and returns SHA-256 hashed normalized phone numbers — same
 * format the matchContacts Cloud Function expects.
 */
private fun readContacts(context: android.content.Context): List<String> {
    val hashes = mutableSetOf<String>()
    val projection = arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER)
    context.contentResolver.query(
        ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
        projection, null, null, null
    )?.use { cursor ->
        val phoneIdx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
        if (phoneIdx < 0) return@use
        while (cursor.moveToNext()) {
            val raw = cursor.getString(phoneIdx) ?: continue
            val normalized = normalizePhone(raw)
            if (normalized.isNotEmpty()) hashes.add(sha256(normalized))
        }
    }
    return hashes.toList()
}

private fun normalizePhone(phone: String): String {
    var digits = phone.filter { it.isDigit() }
    if (digits.length == 11 && digits.startsWith("0")) digits = "90" + digits.drop(1)
    else if (digits.length == 10) digits = "90" + digits
    return digits
}

private fun sha256(input: String): String {
    val bytes = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
    return bytes.joinToString("") { "%02x".format(it) }
}
