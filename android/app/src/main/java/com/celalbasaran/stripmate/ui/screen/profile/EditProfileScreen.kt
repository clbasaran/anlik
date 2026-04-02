package com.celalbasaran.stripmate.ui.screen.profile

import android.net.Uri
import android.widget.Toast
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.border
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.celalbasaran.stripmate.service.spotify.SpotifyTrack
import com.celalbasaran.stripmate.ui.component.UserAvatar
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.ErrorRed
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.SuccessGreen
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditProfileScreen(
    onBack: () -> Unit,
    viewModel: EditProfileViewModel = hiltViewModel()
) {
    val displayName by viewModel.displayName.collectAsState()
    val username by viewModel.username.collectAsState()
    val bio by viewModel.bio.collectAsState()
    val avatarUrl by viewModel.avatarUrl.collectAsState()
    val dateOfBirth by viewModel.dateOfBirth.collectAsState()
    val statusEmoji by viewModel.statusEmoji.collectAsState()
    val isSaving by viewModel.isSaving.collectAsState()
    val usernameAvailable by viewModel.usernameAvailable.collectAsState()
    val saveSuccess by viewModel.saveSuccess.collectAsState()
    val email by viewModel.email.collectAsState()
    val inviteCode by viewModel.inviteCode.collectAsState()
    val favoriteSong by viewModel.favoriteSong.collectAsState()
    val zodiacSign by viewModel.zodiacSign.collectAsState()
    val personalityEmojis by viewModel.personalityEmojis.collectAsState()
    val spotifyQuery by viewModel.spotifyQuery.collectAsState()
    val spotifyResults by viewModel.spotifyResults.collectAsState()
    val isSearchingSpotify by viewModel.isSearchingSpotify.collectAsState()

    val clipboardManager = LocalClipboardManager.current
    val context = LocalContext.current

    var showDatePicker by remember { mutableStateOf(false) }
    var showEmojiPicker by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showPersonalityEmojiPicker by remember { mutableStateOf(false) }
    var showSpotifySheet by remember { mutableStateOf(false) }

    val zodiacSigns = remember {
        listOf(
            Triple("aries", "Koc", "\u2648"),
            Triple("taurus", "Boga", "\u2649"),
            Triple("gemini", "Ikizler", "\u264A"),
            Triple("cancer", "Yengec", "\u264B"),
            Triple("leo", "Aslan", "\u264C"),
            Triple("virgo", "Basak", "\u264D"),
            Triple("libra", "Terazi", "\u264E"),
            Triple("scorpio", "Akrep", "\u264F"),
            Triple("sagittarius", "Yay", "\u2650"),
            Triple("capricorn", "Oglak", "\u2651"),
            Triple("aquarius", "Kova", "\u2652"),
            Triple("pisces", "Balik", "\u2653")
        )
    }

    val emojiOptions = remember {
        listOf(
            "\uD83D\uDE0E", "\uD83E\uDD13", "\uD83E\uDD73", "\uD83D\uDE08", "\uD83E\uDD17",
            "\uD83E\uDD70", "\uD83D\uDE34", "\uD83E\uDD2F", "\uD83E\uDEE0", "\uD83D\uDE07",
            "\uD83E\uDD29", "\uD83E\uDEE1", "\uD83E\uDD14", "\uD83D\uDE43", "\uD83D\uDE1C",
            "\uD83E\uDD2A", "\uD83D\uDE02", "\uD83E\uDD72", "\uD83E\uDEE2", "\uD83E\uDD2B",
            "\uD83E\uDDD0", "\uD83E\uDD20", "\uD83D\uDC7B", "\uD83D\uDC80", "\uD83E\uDD16",
            "\uD83D\uDC7D", "\uD83C\uDF83", "\uD83E\uDD8B", "\uD83C\uDF38", "\uD83D\uDD25",
            "\u26A1", "\uD83C\uDF08", "\uD83C\uDFB5", "\uD83C\uDFAE", "\uD83D\uDCF8",
            "\uD83C\uDFC0", "\u26BD", "\uD83C\uDFA8", "\uD83D\uDCDA", "\uD83C\uDF55",
            "\u2615", "\uD83C\uDF7F", "\uD83C\uDF0A", "\uD83C\uDFD4\uFE0F", "\uD83C\uDF19",
            "\u2B50", "\uD83D\uDCAB", "\u2764\uFE0F", "\uD83D\uDC9C", "\uD83D\uDC9A"
        )
    }

    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri?.let { viewModel.uploadAvatar(it) }
    }

    val dateFormat = remember { SimpleDateFormat("dd.MM.yyyy", Locale("tr")) }

    if (saveSuccess) {
        onBack()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Profili düzenle") },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Geri",
                        tint = TextPrimary
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = PureBlack,
                titleContentColor = TextPrimary
            )
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(16.dp))

            // Avatar with edit overlay
            Box(
                modifier = Modifier
                    .size(100.dp)
                    .clickable { imagePicker.launch("image/*") },
                contentAlignment = Alignment.Center
            ) {
                UserAvatar(
                    imageUrl = avatarUrl,
                    displayName = displayName,
                    size = 100.dp
                )
                Box(
                    modifier = Modifier
                        .size(100.dp)
                        .clip(CircleShape)
                        .background(Color.Black.copy(alpha = 0.4f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.CameraAlt,
                        contentDescription = "Foto değiştir",
                        tint = Color.White,
                        modifier = Modifier.size(28.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Display name
            OutlinedTextField(
                value = displayName,
                onValueChange = { viewModel.updateDisplayName(it) },
                label = { Text("Gorunen ad") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
                colors = profileFieldColors()
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Username
            OutlinedTextField(
                value = username,
                onValueChange = { viewModel.updateUsername(it) },
                label = { Text("Kullanici adi") },
                singleLine = true,
                prefix = { Text("@", color = TextSecondary) },
                trailingIcon = {
                    usernameAvailable?.let { available ->
                        Icon(
                            imageVector = if (available) Icons.Default.Check else Icons.Default.Close,
                            contentDescription = null,
                            tint = if (available) SuccessGreen else ErrorRed
                        )
                    }
                },
                supportingText = {
                    usernameAvailable?.let { available ->
                        Text(
                            text = if (available) "Kullanilabilir" else "Bu isim alinmis",
                            color = if (available) SuccessGreen else ErrorRed
                        )
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = profileFieldColors()
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Bio
            OutlinedTextField(
                value = bio,
                onValueChange = {
                    if (it.length <= 60) viewModel.updateBio(it)
                },
                label = { Text("Bio") },
                singleLine = false,
                maxLines = 3,
                supportingText = {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End
                    ) {
                        Text(
                            text = "${bio.length}/60",
                            color = if (bio.length >= 55) ErrorRed.copy(alpha = 0.7f) else TextSecondary,
                            fontSize = 11.sp
                        )
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = profileFieldColors()
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Favorite Song (tap to open Spotify search)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(DarkSurfaceVariant)
                    .clickable { showSpotifySheet = true }
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text("🎵", fontSize = 20.sp)
                Text(
                    text = favoriteSong.ifEmpty { "Spotify'dan şarkı seç" },
                    color = if (favoriteSong.isNotEmpty()) TextPrimary else TextSecondary,
                    fontSize = 15.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                if (favoriteSong.isNotEmpty()) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Temizle",
                        tint = TextSecondary,
                        modifier = Modifier
                            .size(18.dp)
                            .clickable { viewModel.updateFavoriteSong("") }
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = null,
                        tint = TextSecondary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Zodiac Sign
            ReadOnlyFieldSection(title = "BURC") {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    zodiacSigns.forEach { (key, name, emoji) ->
                        val selected = zodiacSign == key
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier
                                .size(56.dp)
                                .background(
                                    if (selected) Color.White.copy(alpha = 0.12f) else Color.White.copy(alpha = 0.04f),
                                    RoundedCornerShape(12.dp)
                                )
                                .border(
                                    0.5.dp,
                                    if (selected) Color.White.copy(alpha = 0.2f) else Color.White.copy(alpha = 0.06f),
                                    RoundedCornerShape(12.dp)
                                )
                                .clickable { viewModel.updateZodiacSign(key) }
                                .padding(vertical = 6.dp)
                        ) {
                            Text(text = emoji, fontSize = 22.sp)
                            Text(
                                text = name,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Medium,
                                color = if (selected) TextPrimary.copy(alpha = 0.9f) else TextPrimary.copy(alpha = 0.4f)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Personality Emojis
            ReadOnlyFieldSection(title = "KISILIK EMOJILERI") {
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        for (i in 0 until 5) {
                            Box(
                                contentAlignment = Alignment.Center,
                                modifier = Modifier
                                    .size(52.dp)
                                    .background(
                                        if (i < personalityEmojis.size) Color.White.copy(alpha = 0.08f) else Color.White.copy(alpha = 0.03f),
                                        RoundedCornerShape(12.dp)
                                    )
                                    .border(0.5.dp, Color.White.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
                                    .clickable {
                                        if (i < personalityEmojis.size) {
                                            viewModel.removePersonalityEmoji(i)
                                        } else {
                                            showPersonalityEmojiPicker = true
                                        }
                                    }
                            ) {
                                if (i < personalityEmojis.size) {
                                    Text(text = personalityEmojis[i], fontSize = 28.sp)
                                } else {
                                    Text(text = "+", color = TextPrimary.copy(alpha = 0.25f), fontSize = 18.sp)
                                }
                            }
                        }
                    }
                    if (personalityEmojis.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = "Silmek icin emojiye dokun",
                            fontSize = 11.sp,
                            color = TextPrimary.copy(alpha = 0.2f)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Date of birth
            OutlinedTextField(
                value = dateOfBirth?.let { dateFormat.format(it) } ?: "",
                onValueChange = {},
                label = { Text("Dogum tarihi") },
                readOnly = true,
                enabled = false,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { showDatePicker = true },
                colors = profileFieldColors()
            )

            // Email (read-only)
            email?.let { emailValue ->
                if (emailValue.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(12.dp))
                    ReadOnlyFieldSection(title = "E-POSTA") {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    Color.White.copy(alpha = 0.03f),
                                    RoundedCornerShape(12.dp)
                                )
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = emailValue,
                                color = TextPrimary.copy(alpha = 0.35f),
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Medium,
                                modifier = Modifier.weight(1f)
                            )
                            Icon(
                                imageVector = Icons.Default.Lock,
                                contentDescription = "Kilitli",
                                tint = TextPrimary.copy(alpha = 0.2f),
                                modifier = Modifier.size(14.dp)
                            )
                        }
                    }
                }
            }

            // Invite code (read-only, copyable)
            if (inviteCode.isNotEmpty()) {
                Spacer(modifier = Modifier.height(12.dp))
                ReadOnlyFieldSection(title = "DAVET KODU") {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                Color.White.copy(alpha = 0.03f),
                                RoundedCornerShape(12.dp)
                            )
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = inviteCode,
                            color = TextPrimary.copy(alpha = 0.5f),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            fontFamily = FontFamily.Monospace,
                            letterSpacing = 2.sp,
                            modifier = Modifier.weight(1f)
                        )
                        IconButton(
                            onClick = {
                                clipboardManager.setText(AnnotatedString(inviteCode))
                                Toast.makeText(context, "Davet kodu kopyalandi", Toast.LENGTH_SHORT).show()
                            },
                            modifier = Modifier.size(24.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.ContentCopy,
                                contentDescription = "Kopyala",
                                tint = TextPrimary.copy(alpha = 0.4f),
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Save button
            Button(
                onClick = { viewModel.save() },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(50.dp),
                enabled = !isSaving && displayName.trim().isNotEmpty(),
                colors = ButtonDefaults.buttonColors(
                    containerColor = StripMateBlue
                ),
                shape = RoundedCornerShape(12.dp)
            ) {
                if (isSaving) {
                    CircularProgressIndicator(
                        color = Color.White,
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        text = "Kaydet",
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 16.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Delete account
            TextButton(
                onClick = { showDeleteDialog = true },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "Hesabi sil",
                    color = ErrorRed,
                    fontWeight = FontWeight.SemiBold
                )
            }

            Spacer(modifier = Modifier.height(24.dp))
        }
    }

    // Date picker dialog
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = dateOfBirth?.time
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            viewModel.updateDateOfBirth(Date(millis))
                        }
                        showDatePicker = false
                    }
                ) {
                    Text("Tamam", color = StripMateBlue)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text("Iptal", color = TextSecondary)
                }
            },
            colors = androidx.compose.material3.DatePickerDefaults.colors(
                containerColor = DarkSurface
            )
        ) {
            DatePicker(state = datePickerState)
        }
    }

    // Delete account dialog
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = {
                Text("Hesabi sil", color = ErrorRed, fontWeight = FontWeight.Bold)
            },
            text = {
                Text(
                    "Bu islem geri alınamaz. Tum verilerin, fotoğrafların ve arkadaşlıkların silinecek. Devam etmek istediğin kesin mi?",
                    color = TextSecondary
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteAccount()
                        showDeleteDialog = false
                    }
                ) {
                    Text("Sil", color = ErrorRed, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Vazgec", color = TextSecondary)
                }
            },
            containerColor = DarkSurface
        )
    }

    // Personality emoji picker sheet
    if (showPersonalityEmojiPicker) {
        ModalBottomSheet(
            onDismissRequest = { showPersonalityEmojiPicker = false },
            sheetState = rememberModalBottomSheetState(),
            containerColor = DarkSurface
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    text = "Emoji sec",
                    color = TextPrimary,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 16.dp)
                )
                LazyVerticalGrid(
                    columns = GridCells.Fixed(6),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.height(300.dp)
                ) {
                    items(emojiOptions) { emoji ->
                        val alreadySelected = personalityEmojis.contains(emoji)
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier
                                .size(48.dp)
                                .background(
                                    if (alreadySelected) Color.White.copy(alpha = 0.15f) else Color.Transparent,
                                    RoundedCornerShape(10.dp)
                                )
                                .clickable(enabled = !alreadySelected) {
                                    viewModel.addPersonalityEmoji(emoji)
                                    if (personalityEmojis.size >= 4) {
                                        showPersonalityEmojiPicker = false
                                    }
                                }
                        ) {
                            Text(
                                text = emoji,
                                fontSize = 32.sp,
                                modifier = Modifier.then(
                                    if (alreadySelected) Modifier else Modifier
                                )
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }

    // Spotify search sheet
    if (showSpotifySheet) {
        ModalBottomSheet(
            onDismissRequest = {
                showSpotifySheet = false
                viewModel.searchSpotify("") // clear results
            },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = DarkSurface
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .height(480.dp)
            ) {
                Text(
                    text = "\uD83C\uDFB5 Sarki ara",
                    color = TextPrimary,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 12.dp)
                )
                OutlinedTextField(
                    value = spotifyQuery,
                    onValueChange = { viewModel.searchSpotify(it) },
                    placeholder = { Text("Sarki veya sanatci adi...", color = TextSecondary) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    colors = profileFieldColors()
                )
                Spacer(modifier = Modifier.height(12.dp))

                if (isSearchingSpotify) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            color = StripMateBlue,
                            modifier = Modifier.size(24.dp),
                            strokeWidth = 2.dp
                        )
                    }
                } else if (spotifyResults.isEmpty() && spotifyQuery.isNotBlank()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 24.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Sonuc bulunamadi",
                            color = TextSecondary,
                            fontSize = 14.sp
                        )
                    }
                } else {
                    LazyColumn(
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        items(spotifyResults) { track ->
                            SpotifyTrackRow(
                                track = track,
                                onClick = {
                                    viewModel.selectTrack(track)
                                    showSpotifySheet = false
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SpotifyTrackRow(
    track: SpotifyTrack,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        AsyncImage(
            model = track.albumImageUrl,
            contentDescription = track.name,
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(DarkSurfaceVariant)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = track.name,
                color = TextPrimary,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                maxLines = 1
            )
            Text(
                text = track.artist,
                color = TextSecondary,
                fontSize = 13.sp,
                maxLines = 1
            )
        }
    }
}

@Composable
private fun ReadOnlyFieldSection(
    title: String,
    content: @Composable () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = title,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary.copy(alpha = 0.35f),
            letterSpacing = 0.5.sp,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp)
        )
        content()
    }
}

@Composable
private fun profileFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = TextPrimary,
    unfocusedTextColor = TextPrimary,
    disabledTextColor = TextPrimary,
    focusedBorderColor = StripMateBlue,
    unfocusedBorderColor = DarkSurfaceVariant,
    disabledBorderColor = DarkSurfaceVariant,
    focusedLabelColor = StripMateBlue,
    unfocusedLabelColor = TextSecondary,
    disabledLabelColor = TextSecondary,
    cursorColor = StripMateBlue,
    focusedContainerColor = Color.Transparent,
    unfocusedContainerColor = Color.Transparent,
    disabledContainerColor = Color.Transparent
)
