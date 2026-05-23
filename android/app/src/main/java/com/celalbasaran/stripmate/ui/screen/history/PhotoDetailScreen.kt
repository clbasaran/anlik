package com.celalbasaran.stripmate.ui.screen.history

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AddReaction
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Report
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.celalbasaran.stripmate.data.model.Comment
import com.celalbasaran.stripmate.service.giphy.GiphyService
import android.net.Uri
import com.celalbasaran.stripmate.ui.component.GiphyMessageImage
import com.celalbasaran.stripmate.ui.component.VideoPlayerView
import com.celalbasaran.stripmate.ui.component.GiphyStickerPicker
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.component.VoicePlaybackBubble
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.util.TimeAgo
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import androidx.compose.material.icons.filled.Share
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.net.URL

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PhotoDetailScreen(
    stripId: String,
    onBack: () -> Unit,
    onReceiverClick: (String) -> Unit,
    viewModel: PhotoDetailViewModel = hiltViewModel()
) {
    val strip by viewModel.strip.collectAsState()
    val messages by viewModel.messages.collectAsState()
    val inputText by viewModel.inputText.collectAsState()
    val replyingTo by viewModel.replyingTo.collectAsState()
    val isSender by viewModel.isSender.collectAsState()
    val receiverProfiles by viewModel.sortedReceiverProfiles.collectAsState()
    val unreadReceivers by viewModel.unreadReceivers.collectAsState()
    val senderDisplayName by viewModel.senderDisplayName.collectAsState()
    val isSecretLocked by viewModel.isSecretLocked.collectAsState()
    val showUnlockAnimation by viewModel.showUnlockAnimation.collectAsState()

    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var isPreparingShare by remember { mutableStateOf(false) }
    var showMenu by remember { mutableStateOf(false) }
    var showOverlay by remember { mutableStateOf(true) }
    var showStickerPicker by remember { mutableStateOf(false) }
    var showPhotoReply by remember { mutableStateOf(false) }
    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }
    var isChatFocused by remember { mutableStateOf(false) }

    LaunchedEffect(stripId) {
        viewModel.loadStrip(stripId)
    }

    // Secret unlock animation - shown fullscreen on top
    val currentStrip = strip
    if (showUnlockAnimation && currentStrip != null) {
        SecretUnlockAnimation(
            photoUrl = currentStrip.imageUrl,
            onAnimationComplete = { viewModel.onUnlockAnimationComplete() }
        )
        return
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        if (isSecretLocked) {
            // Secret locked: do NOT load image at all — show solid black + lock overlay
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(PureBlack),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Spacer(modifier = Modifier.weight(1f))
                    Icon(
                        imageVector = Icons.Default.Lock,
                        contentDescription = "Gizli an",
                        tint = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.size(36.dp)
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = "gizli an",
                        color = Color.White.copy(alpha = 0.8f),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "bu anı görmek için sen de bir an paylaş",
                        color = Color.White.copy(alpha = 0.4f),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 4.dp)
                    )
                    Spacer(modifier = Modifier.weight(1f))

                    // Sender info at bottom
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = senderDisplayName,
                            color = Color.White.copy(alpha = 0.6f),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium
                        )
                        strip?.let {
                            Text(
                                text = TimeAgo.format(it.timestamp),
                                color = Color.White.copy(alpha = 0.4f),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }
        } else if (currentStrip != null && currentStrip.isVideo && !currentStrip.videoUrl.isNullOrBlank()) {
            // Video playback
            VideoPlayerView(
                uri = Uri.parse(currentStrip.videoUrl),
                modifier = Modifier
                    .fillMaxSize()
                    .pointerInput(Unit) {
                        detectTapGestures(
                            onTap = {
                                if (!isChatFocused) {
                                    showOverlay = !showOverlay
                                } else {
                                    isChatFocused = false
                                }
                            }
                        )
                    },
                startMuted = true
            )
        } else {
            // Normal: show zoomable image
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(strip?.imageUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = "Fotograf detay",
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer(
                        scaleX = scale,
                        scaleY = scale,
                        translationX = offsetX,
                        translationY = offsetY
                    )
                    .pointerInput(Unit) {
                        detectTransformGestures { _, pan, zoom, _ ->
                            scale = (scale * zoom).coerceIn(1f, 5f)
                            if (scale > 1f) {
                                offsetX += pan.x
                                offsetY += pan.y
                            } else {
                                offsetX = 0f
                                offsetY = 0f
                            }
                        }
                    }
                    .pointerInput(Unit) {
                        detectTapGestures(
                            onTap = {
                                if (!isChatFocused) {
                                    showOverlay = !showOverlay
                                } else {
                                    isChatFocused = false
                                }
                            },
                            onDoubleTap = {
                                if (scale > 1f) {
                                    scale = 1f
                                    offsetX = 0f
                                    offsetY = 0f
                                } else {
                                    scale = 2.5f
                                }
                            }
                        )
                    }
            )
        }

        // Back button always visible for locked state
        if (isSecretLocked) {
            IconButton(
                onClick = onBack,
                modifier = Modifier
                    .statusBarsPadding()
                    .padding(8.dp)
                    .size(44.dp)
                    .background(Color.White.copy(alpha = 0.12f), CircleShape)
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Geri",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        // Overlay UI (only when NOT secret-locked)
        AnimatedVisibility(
            visible = showOverlay && scale <= 1f && !isSecretLocked,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
            ) {
                // ── Top bar (iOS style: back | center info | menu) ──
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(PureBlack.copy(alpha = 0.5f))
                        .padding(horizontal = 8.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Back button
                    IconButton(
                        onClick = onBack,
                        modifier = Modifier
                            .size(44.dp)
                            .background(Color.White.copy(alpha = 0.12f), CircleShape)
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Geri",
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                    }

                    Spacer(modifier = Modifier.weight(1f))

                    // Center: location pill or sender info
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        strip?.cityName?.let { city ->
                            Row(
                                modifier = Modifier
                                    .background(
                                        color = Color.White.copy(alpha = 0.15f),
                                        shape = RoundedCornerShape(16.dp)
                                    )
                                    .padding(horizontal = 10.dp, vertical = 5.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(4.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.LocationOn,
                                    contentDescription = null,
                                    tint = Color.White,
                                    modifier = Modifier.size(12.dp)
                                )
                                Text(
                                    text = city,
                                    color = Color.White,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        } ?: run {
                            Text(
                                text = senderDisplayName,
                                color = Color.White,
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                        strip?.let {
                            Text(
                                text = TimeAgo.formatLong(it.timestamp),
                                color = Color.White.copy(alpha = 0.6f),
                                fontSize = 11.sp
                            )
                        }
                    }

                    Spacer(modifier = Modifier.weight(1f))

                    // Right: share+delete or menu
                    if (isSender) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            // Share / export button
                            IconButton(
                                onClick = {
                                    val imageUrl = strip?.imageUrl ?: return@IconButton
                                    scope.launch {
                                        isPreparingShare = true
                                        try {
                                            val watermarked = withContext(Dispatchers.IO) {
                                                val url = URL(imageUrl)
                                                val original = android.graphics.BitmapFactory.decodeStream(url.openStream())
                                                addWatermark(original)
                                            }
                                            // Save to cache and share
                                            val file = File(context.cacheDir, "share_photo.jpg")
                                            file.outputStream().use { out ->
                                                watermarked.compress(Bitmap.CompressFormat.JPEG, 92, out)
                                            }
                                            val uri = FileProvider.getUriForFile(
                                                context,
                                                "${context.packageName}.fileprovider",
                                                file
                                            )
                                            val intent = Intent(Intent.ACTION_SEND).apply {
                                                type = "image/jpeg"
                                                putExtra(Intent.EXTRA_STREAM, uri)
                                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                            }
                                            context.startActivity(Intent.createChooser(intent, "Disa aktar"))
                                        } catch (_: Exception) { }
                                        isPreparingShare = false
                                    }
                                },
                                enabled = !isPreparingShare,
                                modifier = Modifier
                                    .size(44.dp)
                                    .background(Color.White.copy(alpha = 0.12f), CircleShape)
                            ) {
                                if (isPreparingShare) {
                                    androidx.compose.material3.CircularProgressIndicator(
                                        color = Color.White,
                                        modifier = Modifier.size(18.dp),
                                        strokeWidth = 2.dp
                                    )
                                } else {
                                    Icon(
                                        imageVector = Icons.Default.Share,
                                        contentDescription = "Disa aktar",
                                        tint = Color.White,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }

                            // Delete button
                            IconButton(
                                onClick = {
                                    strip?.let { viewModel.deleteStrip(it) }
                                    onBack()
                                },
                                modifier = Modifier
                                    .size(44.dp)
                                    .background(Color.White.copy(alpha = 0.12f), CircleShape)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Delete,
                                    contentDescription = "Sil",
                                    tint = Color(0xFFFF3B30),
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                    } else {
                        Box {
                            IconButton(
                                onClick = { showMenu = true },
                                modifier = Modifier
                                    .size(44.dp)
                                    .background(Color.White.copy(alpha = 0.12f), CircleShape)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.MoreVert,
                                    contentDescription = "Menu",
                                    tint = Color.White,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                            DropdownMenu(
                                expanded = showMenu,
                                onDismissRequest = { showMenu = false },
                                containerColor = DarkSurface
                            ) {
                                DropdownMenuItem(
                                    text = { Text("Şikayet et", color = TextPrimary) },
                                    onClick = { showMenu = false },
                                    leadingIcon = {
                                        Icon(
                                            Icons.Default.Report,
                                            contentDescription = null,
                                            tint = TextSecondary
                                        )
                                    }
                                )
                                DropdownMenuItem(
                                    text = { Text("Engelle", color = Color(0xFFFF3B30)) },
                                    onClick = { showMenu = false },
                                    leadingIcon = {
                                        Icon(
                                            Icons.Default.Block,
                                            contentDescription = null,
                                            tint = Color(0xFFFF3B30)
                                        )
                                    }
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.weight(1f))

                // Receiver list (if sender)
                if (isSender && receiverProfiles.isNotEmpty()) {
                    LazyRow(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(receiverProfiles, key = { it.id }) { profile ->
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier.clickable {
                                    viewModel.markChatOpened(profile.id)
                                    onReceiverClick(profile.id)
                                }
                            ) {
                                Box {
                                    UserAvatar(
                                        imageUrl = profile.avatarUrl,
                                        displayName = profile.displayName,
                                        size = 44.dp
                                    )
                                    if (profile.id in unreadReceivers) {
                                        Box(
                                            modifier = Modifier
                                                .align(Alignment.TopEnd)
                                                .offset(x = 2.dp, y = (-2).dp)
                                                .size(12.dp)
                                                .background(Color(0xFFFF3B30), CircleShape)
                                                .border(2.dp, Color.Black, CircleShape)
                                        )
                                    }
                                }
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    text = profile.displayName ?: profile.username ?: "",
                                    color = TextSecondary,
                                    fontSize = 11.sp,
                                    maxLines = 1
                                )
                            }
                        }
                    }
                }

                // ── Chat overlay ──
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding()
                        .imePadding()
                        .padding(bottom = 8.dp)
                ) {
                    // Messages
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f, fill = false)
                            .heightIn(max = 300.dp)
                            .padding(horizontal = 16.dp),
                        reverseLayout = true
                    ) {
                        items(
                            items = messages.reversed(),
                            key = { it.id }
                        ) { comment ->
                            StripChatBubble(
                                comment = comment,
                                isMine = viewModel.isMyMessage(comment)
                            )
                        }
                    }

                    // Reply preview
                    replyingTo?.let { reply ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 4.dp)
                                .background(
                                    DarkSurfaceVariant,
                                    RoundedCornerShape(8.dp)
                                )
                                .padding(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .width(3.dp)
                                    .height(24.dp)
                                    .background(StripMateBlue, RoundedCornerShape(2.dp))
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = reply.text,
                                color = TextSecondary,
                                fontSize = 13.sp,
                                maxLines = 1,
                                modifier = Modifier.weight(1f)
                            )
                            Text(
                                text = "\u2715",
                                color = TextSecondary,
                                modifier = Modifier.clickable { viewModel.clearReply() }
                            )
                        }
                    }

                    // ── Input bar (iOS style: camera | textfield | send in rounded container) ──
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                            .background(
                                color = Color.White.copy(alpha = 0.08f),
                                shape = RoundedCornerShape(22.dp)
                            )
                            .border(
                                width = 0.5.dp,
                                color = Color.White.copy(alpha = 0.15f),
                                shape = RoundedCornerShape(22.dp)
                            )
                            .padding(horizontal = 6.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.Bottom,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        // Camera button
                        IconButton(
                            onClick = { showPhotoReply = true },
                            modifier = Modifier.size(36.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.CameraAlt,
                                contentDescription = "Fotoğraf yanıt",
                                tint = Color.White.copy(alpha = 0.5f),
                                modifier = Modifier.size(18.dp)
                            )
                        }

                        // Text field
                        TextField(
                            value = inputText,
                            onValueChange = { viewModel.updateInput(it) },
                            placeholder = {
                                Text(
                                    "mesaj yaz...",
                                    color = Color.White.copy(alpha = 0.4f),
                                    fontSize = 16.sp
                                )
                            },
                            modifier = Modifier
                                .weight(1f)
                                .onFocusChanged { focusState ->
                                    isChatFocused = focusState.isFocused
                                    if (focusState.isFocused) showOverlay = true
                                },
                            colors = TextFieldDefaults.colors(
                                focusedContainerColor = Color.Transparent,
                                unfocusedContainerColor = Color.Transparent,
                                focusedTextColor = Color.White,
                                unfocusedTextColor = Color.White,
                                cursorColor = Color.White,
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent
                            ),
                            textStyle = androidx.compose.ui.text.TextStyle(fontSize = 16.sp),
                            maxLines = 4,
                            singleLine = false
                        )

                        // Sticker button
                        IconButton(
                            onClick = { showStickerPicker = true },
                            modifier = Modifier.size(36.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.AddReaction,
                                contentDescription = "Sticker",
                                tint = Color.White.copy(alpha = 0.5f),
                                modifier = Modifier.size(18.dp)
                            )
                        }

                        // Send button - prominent when text exists
                        AnimatedVisibility(visible = inputText.isNotBlank()) {
                            IconButton(
                                onClick = { viewModel.sendMessage() },
                                modifier = Modifier
                                    .size(36.dp)
                                    .background(Color.White, CircleShape)
                            ) {
                                Icon(
                                    imageVector = Icons.AutoMirrored.Filled.Send,
                                    contentDescription = "Gonder",
                                    tint = Color.Black,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // Giphy Sticker Picker
    if (showStickerPicker) {
        GiphyStickerPicker(
            onDismiss = { showStickerPicker = false },
            onStickerSelected = { originalUrl, _ ->
                viewModel.sendGiphyMessage(originalUrl)
            }
        )
    }

    // Photo Reply Camera Sheet
    if (showPhotoReply) {
        PhotoReplySheet(
            onCapture = { bitmap ->
                viewModel.sendPhotoReply(bitmap)
            },
            onDismiss = { showPhotoReply = false }
        )
    }
}

@Composable
private fun StripChatBubble(
    comment: Comment,
    isMine: Boolean
) {
    val bgColor = if (isMine) Color.White else DarkSurfaceVariant
    val textColor = if (isMine) Color.Black else TextPrimary

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        horizontalAlignment = if (isMine) Alignment.End else Alignment.Start
    ) {
        // Reply quote
        comment.replyToText?.let { replyText ->
            Row(
                modifier = Modifier
                    .padding(bottom = 2.dp)
                    .background(
                        DarkSurfaceVariant.copy(alpha = 0.5f),
                        RoundedCornerShape(8.dp)
                    )
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .width(2.dp)
                        .height(16.dp)
                        .background(StripMateBlue, RoundedCornerShape(1.dp))
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = replyText,
                    color = TextSecondary,
                    fontSize = 11.sp,
                    maxLines = 1
                )
            }
        }

        // Voice, Giphy, or text
        if (!comment.voiceUrl.isNullOrBlank()) {
            VoicePlaybackBubble(
                voiceUrl = comment.voiceUrl,
                isSentByMe = isMine
            )
        } else if (GiphyService.isGiphyUrl(comment.text)) {
            // Render Giphy URL as animated GIF
            GiphyMessageImage(
                url = comment.text.trim(),
                modifier = Modifier
                    .size(width = 180.dp, height = 180.dp)
            )
        } else {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .background(bgColor)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Text(
                    text = comment.text,
                    color = textColor,
                    fontSize = 14.sp
                )
            }
        }

        Text(
            text = TimeAgo.format(comment.timestamp),
            color = TextSecondary.copy(alpha = 0.6f),
            fontSize = 10.sp,
            modifier = Modifier.padding(top = 2.dp, start = 4.dp, end = 4.dp)
        )
    }
}

// MARK: - Watermark

private fun addWatermark(original: Bitmap): Bitmap {
    val w = original.width
    val h = original.height
    val output = original.copy(Bitmap.Config.ARGB_8888, true)
    val canvas = Canvas(output)

    // Gradient bar at bottom
    val barHeight = (h * 0.06f)
    val gradientPaint = Paint().apply {
        shader = LinearGradient(
            0f, h - barHeight, 0f, h.toFloat(),
            android.graphics.Color.TRANSPARENT,
            android.graphics.Color.argb(128, 0, 0, 0),
            Shader.TileMode.CLAMP
        )
    }
    canvas.drawRect(0f, h - barHeight, w.toFloat(), h.toFloat(), gradientPaint)

    // Brand text
    val fontSize = w * 0.035f
    val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = android.graphics.Color.argb(179, 255, 255, 255)
        textSize = fontSize
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }
    val brandName = "anl\u0131k."
    val textY = h - barHeight + (barHeight + fontSize) / 2f
    canvas.drawText(brandName, w / 2f, textY, textPaint)

    return output
}
