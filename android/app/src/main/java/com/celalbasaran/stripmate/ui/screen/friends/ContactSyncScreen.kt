package com.celalbasaran.stripmate.ui.screen.friends

import android.Manifest
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.People
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.celalbasaran.stripmate.service.contacts.MatchedContact

private val Purple = Color(0xFF9B59B6)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContactSyncScreen(
    onBack: () -> Unit,
    viewModel: ContactSyncViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    val sentIds by viewModel.sentRequestIds.collectAsState()

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) viewModel.syncContacts(context)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Rehberden Bul") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Geri")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black,
                    titleContentColor = Color.White,
                    navigationIconContentColor = Color.White
                )
            )
        },
        containerColor = Color.Black
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when (val s = state) {
                is ContactSyncUiState.Idle -> IdleContent {
                    permissionLauncher.launch(Manifest.permission.READ_CONTACTS)
                }
                is ContactSyncUiState.Loading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        CircularProgressIndicator(color = Purple)
                        Text(
                            "Rehber taranıyor...",
                            color = Color.White.copy(alpha = 0.6f)
                        )
                    }
                }
                is ContactSyncUiState.Done -> ResultsContent(
                    matched = s.matched,
                    unmatched = s.unmatched,
                    sentIds = sentIds,
                    onAdd = { userId -> viewModel.sendFriendRequest(userId) },
                    onInvite = { contact ->
                        val smsUri = Uri.parse("smsto:${contact.phone}")
                        val intent = Intent(Intent.ACTION_SENDTO, smsUri).apply {
                            putExtra("sms_body", "Anlık'ı dene! https://stripmate.app/invite")
                        }
                        context.startActivity(intent)
                    }
                )
                is ContactSyncUiState.Error -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        modifier = Modifier.padding(32.dp)
                    ) {
                        Text(
                            s.message,
                            color = MaterialTheme.colorScheme.error,
                            textAlign = TextAlign.Center
                        )
                        Button(
                            onClick = { permissionLauncher.launch(Manifest.permission.READ_CONTACTS) },
                            colors = ButtonDefaults.buttonColors(containerColor = Purple)
                        ) {
                            Text("Tekrar Dene")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun IdleContent(onStart: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.People,
            contentDescription = null,
            modifier = Modifier.size(72.dp),
            tint = Purple
        )
        Spacer(Modifier.height(24.dp))
        Text(
            "Rehberindeki Arkadaşlarını Bul",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White,
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Telefon numaraları şifreli kontrol edilir.",
            color = Color.White.copy(alpha = 0.5f),
            textAlign = TextAlign.Center
        )
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = onStart,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = Purple)
        ) {
            Text("Rehbere Eriş")
        }
    }
}

@Composable
private fun ResultsContent(
    matched: List<MatchedContact>,
    unmatched: List<RawContact>,
    sentIds: Set<String>,
    onAdd: (String) -> Unit,
    onInvite: (RawContact) -> Unit
) {
    LazyColumn(modifier = Modifier.fillMaxSize()) {
        if (matched.isNotEmpty()) {
            item { SectionHeader("Anlık'ta Olanlar (${matched.size})") }
            items(matched) { contact ->
                MatchedContactRow(
                    contact = contact,
                    sent = contact.userId in sentIds,
                    onAdd = { onAdd(contact.userId) }
                )
            }
        }
        if (unmatched.isNotEmpty()) {
            item { SectionHeader("Davet Et (${unmatched.size})") }
            items(unmatched) { contact ->
                UnmatchedContactRow(contact = contact, onInvite = { onInvite(contact) })
            }
        }
        if (matched.isEmpty() && unmatched.isEmpty()) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        "Rehberinizdeki kişiler henüz Anlık'ta değil.",
                        color = Color.White.copy(alpha = 0.5f),
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
        fontWeight = FontWeight.SemiBold,
        color = Color.White.copy(alpha = 0.5f),
        fontSize = 13.sp
    )
}

@Composable
private fun MatchedContactRow(
    contact: MatchedContact,
    sent: Boolean,
    onAdd: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(contact.avatarUrl.ifEmpty { null })
                .crossfade(true)
                .build(),
            contentDescription = null,
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(Purple.copy(alpha = 0.2f))
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(
                contact.displayName,
                fontWeight = FontWeight.Medium,
                color = Color.White
            )
            Text(
                "@${contact.username}",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.5f)
            )
        }
        if (sent) {
            Icon(
                Icons.Default.Check,
                contentDescription = null,
                tint = Color(0xFF27AE60)
            )
        } else {
            OutlinedButton(
                onClick = onAdd,
                shape = RoundedCornerShape(20.dp)
            ) {
                Text("Ekle", color = Purple)
            }
        }
    }
}

@Composable
private fun UnmatchedContactRow(contact: RawContact, onInvite: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(Color.Gray.copy(alpha = 0.2f)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                contact.name.firstOrNull()?.toString() ?: "?",
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }
        Spacer(Modifier.width(12.dp))
        Text(
            contact.name,
            modifier = Modifier.weight(1f),
            color = Color.White
        )
        TextButton(onClick = onInvite) {
            Text("Davet Et", color = Purple)
        }
    }
}
