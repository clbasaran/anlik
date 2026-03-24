package com.celalbasaran.stripmate.ui.screen.history

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Report
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.celalbasaran.stripmate.data.model.Comment
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.component.VoicePlaybackBubble
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.util.TimeAgo

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
    val receiverProfiles by viewModel.receiverProfiles.collectAsState()
    val senderDisplayName by viewModel.senderDisplayName.collectAsState()

    var showMenu by remember { mutableStateOf(false) }
    var showOverlay by remember { mutableStateOf(true) }
    var scale by remember { mutableFloatStateOf(1f) }
    var offsetX by remember { mutableFloatStateOf(0f) }
    var offsetY by remember { mutableFloatStateOf(0f) }

    LaunchedEffect(stripId) {
        viewModel.loadStrip(stripId)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        // Zoomable image
        AsyncImage(
            model = strip?.imageUrl,
            contentDescription = "Fotoğraf detay",
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
                        onTap = { showOverlay = !showOverlay },
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

        // Overlay UI
        AnimatedVisibility(
            visible = showOverlay && scale <= 1f,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
            ) {
                // Top bar
                TopAppBar(
                    title = {
                        Column {
                            Text(
                                text = senderDisplayName,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 16.sp
                            )
                            strip?.let {
                                Text(
                                    text = TimeAgo.formatLong(it.timestamp),
                                    color = TextSecondary,
                                    fontSize = 12.sp
                                )
                            }
                        }
                    },
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Geri",
                                tint = TextPrimary
                            )
                        }
                    },
                    actions = {
                        if (isSender) {
                            // Sender: prominent red delete button directly in top bar
                            IconButton(onClick = {
                                strip?.let { viewModel.deleteStrip(it) }
                                onBack()
                            }) {
                                Icon(
                                    imageVector = Icons.Default.Delete,
                                    contentDescription = "Sil",
                                    tint = Color(0xFFFF3B30)
                                )
                            }
                        } else {
                            // Receiver: three-dot menu with Şikayet et & Engelle
                            Box {
                                IconButton(onClick = { showMenu = true }) {
                                    Icon(
                                        imageVector = Icons.Default.MoreVert,
                                        contentDescription = "Menu",
                                        tint = TextPrimary
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
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = PureBlack.copy(alpha = 0.7f),
                        titleContentColor = TextPrimary
                    )
                )

                // Location pill
                strip?.cityName?.let { city ->
                    Row(
                        modifier = Modifier
                            .padding(horizontal = 16.dp, vertical = 4.dp)
                            .background(
                                color = DarkSurfaceVariant.copy(alpha = 0.8f),
                                shape = RoundedCornerShape(16.dp)
                            )
                            .padding(horizontal = 10.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.LocationOn,
                            contentDescription = null,
                            tint = TextSecondary,
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = city,
                            color = TextSecondary,
                            style = MaterialTheme.typography.labelSmall
                        )
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
                        items(receiverProfiles) { profile ->
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier.clickable { onReceiverClick(profile.id) }
                            ) {
                                UserAvatar(
                                    imageUrl = profile.avatarUrl,
                                    displayName = profile.displayName,
                                    size = 44.dp
                                )
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

                // Strip chat overlay
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(DarkSurface.copy(alpha = 0.9f))
                        .navigationBarsPadding()
                        .padding(bottom = 8.dp)
                ) {
                    // Messages
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp)
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

                    // Input bar
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                            .imePadding(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        TextField(
                            value = inputText,
                            onValueChange = { viewModel.updateInput(it) },
                            placeholder = {
                                Text("Mesaj yaz...", color = TextSecondary)
                            },
                            modifier = Modifier.weight(1f),
                            colors = TextFieldDefaults.colors(
                                focusedContainerColor = DarkSurfaceVariant,
                                unfocusedContainerColor = DarkSurfaceVariant,
                                focusedTextColor = TextPrimary,
                                unfocusedTextColor = TextPrimary,
                                cursorColor = StripMateBlue,
                                focusedIndicatorColor = Color.Transparent,
                                unfocusedIndicatorColor = Color.Transparent
                            ),
                            shape = RoundedCornerShape(20.dp),
                            singleLine = true
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        IconButton(
                            onClick = { viewModel.sendMessage() },
                            enabled = inputText.isNotBlank()
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.Send,
                                contentDescription = "Gonder",
                                tint = if (inputText.isNotBlank()) StripMateBlue else TextSecondary
                            )
                        }
                    }
                }
            }
        }
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

        // Voice or text
        if (!comment.voiceUrl.isNullOrBlank()) {
            VoicePlaybackBubble(
                voiceUrl = comment.voiceUrl,
                isSentByMe = isMine
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
