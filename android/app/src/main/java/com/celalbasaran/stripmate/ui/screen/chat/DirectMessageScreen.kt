package com.celalbasaran.stripmate.ui.screen.chat

import android.content.Intent
import android.net.Uri
import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandHorizontally
import androidx.compose.animation.shrinkHorizontally
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AddReaction
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.Report
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.text.ClickableText
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.R
import com.celalbasaran.stripmate.util.rememberReduceMotion
import com.celalbasaran.stripmate.data.model.DirectMessage
import com.celalbasaran.stripmate.service.giphy.GiphyService
import com.celalbasaran.stripmate.ui.component.GiphyMessageImage
import com.celalbasaran.stripmate.ui.component.GiphyStickerPicker
import com.celalbasaran.stripmate.ui.component.SkeletonMessageBubble
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.component.VoicePlaybackBubble
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.ErrorRed
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.util.TimeAgo

private val URL_REGEX = Regex(
    """(https?://[^\s<>"{}|\\^`\[\]]+)""",
    RegexOption.IGNORE_CASE
)

/**
 * Detects whether a DM message body is a photo uploaded via PhotoPicker —
 * stored at gs://<bucket>/dm_photos/... and served via Firebase Storage HTTPS.
 * These should render as inline images, not raw URL link previews.
 */
private fun isDmPhotoUrl(text: String): Boolean {
    val trimmed = text.trim()
    if (!trimmed.startsWith("http") || trimmed.contains(' ') || trimmed.contains('\n')) return false
    val lower = trimmed.lowercase()
    return lower.contains("firebasestorage.googleapis.com") && lower.contains("dm_photos")
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun DirectMessageScreen(
    onBack: () -> Unit,
    onProfileClick: (String) -> Unit,
    viewModel: DirectMessageViewModel = hiltViewModel()
) {
    val messages by viewModel.messages.collectAsState()
    val inputText by viewModel.inputText.collectAsState()
    val replyingTo by viewModel.replyingTo.collectAsState()
    val isPartnerTyping by viewModel.isPartnerTyping.collectAsState()
    val partnerProfile by viewModel.partnerProfile.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isLoadingMore by viewModel.isLoadingMore.collectAsState()
    val wordFilterError by viewModel.wordFilterError.collectAsState()

    var showStickerPicker by remember { mutableStateOf(false) }
    val reduceMotion = rememberReduceMotion()

    val photoPickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            viewModel.sendPhotoMessage(uri)
        }
    }

    val listState = rememberLazyListState()
    val clipboardManager = LocalClipboardManager.current
    val context = LocalContext.current
    val view = LocalView.current

    // Show word filter error as toast
    LaunchedEffect(wordFilterError) {
        wordFilterError?.let { msg ->
            android.widget.Toast.makeText(context, msg, android.widget.Toast.LENGTH_SHORT).show()
            viewModel.clearWordFilterError()
        }
    }

    val shouldLoadMore by remember {
        derivedStateOf {
            val lastVisibleItem = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            lastVisibleItem >= messages.size - 5
        }
    }

    LaunchedEffect(shouldLoadMore) {
        if (shouldLoadMore && messages.isNotEmpty()) {
            viewModel.loadMore()
        }
    }

    // Scroll to bottom on new message
    LaunchedEffect(messages.firstOrNull()?.id) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(0)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
            .imePadding()
    ) {
        // Top bar with avatar
        TopAppBar(
            title = {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.clickable {
                        partnerProfile?.let { onProfileClick(it.id) }
                    }
                ) {
                    UserAvatar(
                        imageUrl = partnerProfile?.avatarUrl,
                        displayName = partnerProfile?.displayName,
                        size = 44.dp
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = partnerProfile?.displayName ?: "",
                            fontWeight = FontWeight.SemiBold,
                            fontSize = 16.sp
                        )
                        partnerProfile?.username?.let { uname ->
                            Text(
                                text = "@$uname",
                                color = TextSecondary,
                                fontSize = 12.sp
                            )
                        }
                        if (isPartnerTyping) {
                            Text(
                                text = stringResource(R.string.dm_typing),
                                color = StripMateBlue,
                                fontSize = 12.sp
                            )
                        }
                    }
                }
            },
            navigationIcon = {
                IconButton(onClick = {
                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                    onBack()
                }) {
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

        // Messages
        if (isLoading && messages.isEmpty()) {
            // Skeleton loading placeholders
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 20.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp, Alignment.Bottom)
            ) {
                Spacer(modifier = Modifier.weight(1f))
                SkeletonMessageBubble(isRight = false)
                SkeletonMessageBubble(isRight = true)
                SkeletonMessageBubble(isRight = false)
                SkeletonMessageBubble(isRight = true)
                SkeletonMessageBubble(isRight = false)
                SkeletonMessageBubble(isRight = true)
            }
        }

        if (!isLoading && messages.isEmpty()) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = 28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    text = stringResource(R.string.dm_empty_title),
                    color = TextPrimary,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = stringResource(R.string.dm_empty_body),
                    color = TextSecondary,
                    fontSize = 14.sp,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }
        }

        if (!isLoading || messages.isNotEmpty()) LazyColumn(
            state = listState,
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            reverseLayout = true,
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            // Typing indicator
            if (isPartnerTyping) {
                item {
                    TypingIndicator()
                }
            }

            items(
                items = messages,
                key = { it.id }
            ) { message ->
                val isMine = viewModel.isMyMessage(message)
                var showContextMenu by remember { mutableStateOf(false) }
                var dragOffset by remember { mutableFloatStateOf(0f) }

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .pointerInput(Unit) {
                            detectHorizontalDragGestures(
                                onDragEnd = {
                                    if (dragOffset > 80f) {
                                        viewModel.setReply(message)
                                    }
                                    dragOffset = 0f
                                },
                                onHorizontalDrag = { _, dragAmount ->
                                    if (dragAmount > 0) {
                                        dragOffset += dragAmount
                                    }
                                }
                            )
                        }
                ) {
                    MessageBubble(
                        message = message,
                        isMine = isMine,
                        onDoubleTap = {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            viewModel.toggleReaction(message.id, "\u2764\uFE0F")
                        },
                        onLongPress = {
                            view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                            showContextMenu = true
                        },
                        onLinkClick = { url ->
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                            context.startActivity(intent)
                        },
                        modifier = Modifier.fillMaxWidth()
                    )

                    // Context menu
                    DropdownMenu(
                        expanded = showContextMenu,
                        onDismissRequest = { showContextMenu = false },
                        containerColor = DarkSurface
                    ) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.dm_copy), color = TextPrimary) },
                            onClick = {
                                clipboardManager.setText(AnnotatedString(message.text))
                                showContextMenu = false
                            },
                            leadingIcon = {
                                Icon(Icons.Default.ContentCopy, null, tint = TextSecondary)
                            }
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.dm_reply), color = TextPrimary) },
                            onClick = {
                                viewModel.setReply(message)
                                showContextMenu = false
                            },
                            leadingIcon = {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = TextSecondary)
                            }
                        )
                        if (isMine) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.dm_delete), color = ErrorRed) },
                                onClick = {
                                    viewModel.deleteMessage(message.id)
                                    showContextMenu = false
                                },
                                leadingIcon = {
                                    Icon(Icons.Default.Delete, null, tint = ErrorRed)
                                }
                            )
                        } else {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.dm_report), color = TextPrimary) },
                                onClick = { showContextMenu = false },
                                leadingIcon = {
                                    Icon(Icons.Default.Report, null, tint = TextSecondary)
                                }
                            )
                        }
                    }
                }
            }

            // Load more indicator
            if (isLoadingMore) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            color = StripMateBlue,
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp
                        )
                    }
                }
            }
        }

        // Reply preview
        AnimatedVisibility(
            visible = replyingTo != null,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            replyingTo?.let { reply ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(DarkSurface)
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .width(3.dp)
                            .height(28.dp)
                            .background(StripMateBlue, RoundedCornerShape(2.dp))
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = stringResource(R.string.dm_replying),
                            color = StripMateBlue,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = reply.text,
                            color = TextSecondary,
                            fontSize = 13.sp,
                            maxLines = 1
                        )
                    }
                    Text(
                        text = "\u2715",
                        color = TextSecondary,
                        fontSize = 18.sp,
                        modifier = Modifier
                            .clickable { viewModel.clearReply() }
                            .padding(8.dp)
                    )
                }
            }
        }

        // Instagram-style input bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(DarkSurface)
                .padding(horizontal = 8.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Left action buttons: visible only when text is empty
            AnimatedVisibility(
                visible = inputText.isBlank(),
                enter = if (reduceMotion) fadeIn() else fadeIn() + expandHorizontally(expandFrom = Alignment.Start),
                exit = if (reduceMotion) fadeOut() else fadeOut() + shrinkHorizontally(shrinkTowards = Alignment.Start)
            ) {
                Row {
                    IconButton(
                        onClick = { showStickerPicker = true },
                        modifier = Modifier.size(40.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.AddReaction,
                            contentDescription = stringResource(R.string.dm_sticker_desc),
                            tint = TextSecondary
                        )
                    }
                    IconButton(
                        onClick = {
                            photoPickerLauncher.launch(
                                PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                            )
                        },
                        modifier = Modifier.size(40.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Image,
                            contentDescription = stringResource(R.string.dm_photo_desc),
                            tint = TextSecondary
                        )
                    }
                }
            }

            // Text field - expands when typing
            TextField(
                value = inputText,
                onValueChange = { viewModel.updateInput(it) },
                placeholder = {
                    Text(stringResource(R.string.dm_input_hint), color = TextSecondary)
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
                shape = RoundedCornerShape(24.dp),
                singleLine = false,
                maxLines = 4
            )

            Spacer(modifier = Modifier.width(4.dp))

            // Send button
            IconButton(
                onClick = {
                    view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                    viewModel.sendMessage()
                },
                enabled = inputText.isNotBlank()
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.Send,
                    contentDescription = stringResource(R.string.dm_send_desc),
                    tint = if (inputText.isNotBlank()) StripMateBlue else TextSecondary.copy(alpha = 0.4f)
                )
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
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun MessageBubble(
    message: DirectMessage,
    isMine: Boolean,
    onDoubleTap: () -> Unit,
    onLongPress: () -> Unit,
    onLinkClick: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val bgColor = if (isMine) Color.White else DarkSurfaceVariant
    val textColor = if (isMine) Color.Black else TextPrimary
    val alignment = if (isMine) Alignment.End else Alignment.Start

    val hasHeartReaction = message.reactions?.values?.contains("\u2764\uFE0F") == true

    Column(
        modifier = modifier.padding(vertical = 2.dp),
        horizontalAlignment = alignment
    ) {
        // Reply quote
        message.replyToText?.let { replyText ->
            Row(
                modifier = Modifier
                    .widthIn(max = 260.dp)
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

        // Bubble
        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .clip(
                    RoundedCornerShape(
                        topStart = 16.dp,
                        topEnd = 16.dp,
                        bottomStart = if (isMine) 16.dp else 4.dp,
                        bottomEnd = if (isMine) 4.dp else 16.dp
                    )
                )
                .background(bgColor)
                .combinedClickable(
                    onClick = {},
                    onDoubleClick = { onDoubleTap() },
                    onLongClick = { onLongPress() }
                )
                .padding(horizontal = 12.dp, vertical = 8.dp)
        ) {
            Column {
                if (message.isDeleted == true) {
                    Text(
                        text = stringResource(R.string.dm_removed),
                        color = textColor.copy(alpha = 0.5f),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Light
                    )
                } else if (GiphyService.isGiphyUrl(message.text)) {
                    // Render Giphy URL as animated GIF
                    GiphyMessageImage(
                        url = message.text.trim(),
                        modifier = Modifier
                            .size(width = 200.dp, height = 200.dp)
                    )
                } else if (isDmPhotoUrl(message.text)) {
                    // Render uploaded photo (Firebase Storage dm_photos URL) inline
                    coil.compose.AsyncImage(
                        model = message.text.trim(),
                        contentDescription = null,
                        contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                        modifier = Modifier
                            .size(width = 220.dp, height = 280.dp)
                            .clip(RoundedCornerShape(14.dp))
                    )
                } else {
                    // Linkified message text
                    LinkifiedText(
                        text = message.text,
                        textColor = textColor,
                        linkColor = if (isMine) StripMateBlue else StripMateBlue,
                        onLinkClick = onLinkClick
                    )
                }
            }
        }

        // Heart reaction indicator
        if (hasHeartReaction) {
            Icon(
                imageVector = Icons.Default.Favorite,
                contentDescription = null,
                tint = Color(0xFFFF3B30),
                modifier = Modifier
                    .size(16.dp)
                    .padding(top = 2.dp)
            )
        }

        // Link preview — skip when the message is a media URL (we already render
        // the GIF/photo inline above).
        if (message.isDeleted != true
            && !GiphyService.isGiphyUrl(message.text)
            && !isDmPhotoUrl(message.text)) {
            val firstUrl = remember(message.text) {
                URL_REGEX.find(message.text)?.value
            }
            firstUrl?.let { url ->
                LinkPreviewCard(
                    url = url,
                    isMine = isMine,
                    onClick = { onLinkClick(url) }
                )
            }
        }

        // Timestamp + Read receipt
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp)
        ) {
            Text(
                text = TimeAgo.format(message.timestamp),
                color = TextSecondary.copy(alpha = 0.5f),
                fontSize = 10.sp
            )
            if (isMine) {
                Spacer(modifier = Modifier.width(4.dp))
                ReadReceiptIndicator(isRead = message.readAt != null)
            }
        }
    }
}

/**
 * Read receipt indicator: single checkmark for delivered, double checkmark for read.
 */
@Composable
private fun ReadReceiptIndicator(isRead: Boolean) {
    val color = if (isRead) StripMateBlue else TextSecondary.copy(alpha = 0.5f)
    val text = if (isRead) "\u2713\u2713" else "\u2713"
    Text(
        text = text,
        color = color,
        fontSize = 11.sp,
        fontWeight = FontWeight.Bold
    )
}

/**
 * Animated typing indicator with bouncing dots.
 */
@Composable
private fun TypingIndicator() {
    val infiniteTransition = rememberInfiniteTransition(label = "typing")

    Row(
        modifier = Modifier
            .padding(vertical = 4.dp)
            .background(
                DarkSurfaceVariant,
                RoundedCornerShape(16.dp)
            )
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        repeat(3) { index ->
            val delay = index * 200
            val offsetY by infiniteTransition.animateFloat(
                initialValue = 0f,
                targetValue = -4f,
                animationSpec = infiniteRepeatable(
                    animation = tween(
                        durationMillis = 400,
                        delayMillis = delay,
                        easing = LinearEasing
                    ),
                    repeatMode = RepeatMode.Reverse
                ),
                label = "dot_$index"
            )
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .offset(y = offsetY.dp)
                    .clip(CircleShape)
                    .background(TextSecondary)
            )
        }
        Spacer(modifier = Modifier.width(4.dp))
        Text(
            text = stringResource(R.string.dm_typing),
            color = TextSecondary,
            fontSize = 12.sp
        )
    }
}

/**
 * Text composable that detects URLs and renders them as tappable links.
 */
@Composable
private fun LinkifiedText(
    text: String,
    textColor: Color,
    linkColor: Color,
    onLinkClick: (String) -> Unit
) {
    val annotatedString = remember(text) {
        buildAnnotatedString {
            var lastEnd = 0
            val matches = URL_REGEX.findAll(text)
            for (match in matches) {
                // Append plain text before the URL
                append(text.substring(lastEnd, match.range.first))
                // Append the URL with style and annotation
                pushStringAnnotation(tag = "URL", annotation = match.value)
                withStyle(
                    SpanStyle(
                        color = linkColor,
                        textDecoration = TextDecoration.Underline
                    )
                ) {
                    append(match.value)
                }
                pop()
                lastEnd = match.range.last + 1
            }
            // Append remaining text
            if (lastEnd < text.length) {
                append(text.substring(lastEnd))
            }
        }
    }

    @Suppress("DEPRECATION")
    ClickableText(
        text = annotatedString,
        style = MaterialTheme.typography.bodyMedium.copy(
            color = textColor,
            fontSize = 14.sp
        ),
        onClick = { offset ->
            annotatedString.getStringAnnotations("URL", offset, offset)
                .firstOrNull()?.let { annotation ->
                    onLinkClick(annotation.item)
                }
        }
    )
}

/**
 * Compact link preview card shown below messages containing URLs.
 */
@Composable
private fun LinkPreviewCard(
    url: String,
    isMine: Boolean,
    onClick: () -> Unit
) {
    val domain = remember(url) {
        try {
            Uri.parse(url).host?.removePrefix("www.") ?: url
        } catch (_: Exception) {
            url
        }
    }

    Row(
        modifier = Modifier
            .widthIn(max = 260.dp)
            .padding(top = 4.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(if (isMine) Color.White.copy(alpha = 0.85f) else DarkSurfaceVariant.copy(alpha = 0.7f))
            .clickable { onClick() }
            .padding(horizontal = 10.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Link icon
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(
                    if (isMine) StripMateBlue.copy(alpha = 0.12f)
                    else StripMateBlue.copy(alpha = 0.2f)
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Link,
                contentDescription = "link",
                tint = StripMateBlue,
                modifier = Modifier.size(14.dp)
            )
        }
        Spacer(modifier = Modifier.width(8.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = domain,
                color = if (isMine) Color.Black.copy(alpha = 0.8f) else TextPrimary,
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = url,
                color = if (isMine) Color.Black.copy(alpha = 0.5f) else TextSecondary,
                fontSize = 10.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}
