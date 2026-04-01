package com.celalbasaran.stripmate.ui.screen.memories

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import android.view.HapticFeedbackConstants
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.celalbasaran.stripmate.R
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import kotlin.math.abs
import kotlin.math.roundToInt

@Composable
fun MemoriesScreen(
    onBack: () -> Unit,
    onShare: () -> Unit = {},
    viewModel: MemoriesViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val strips = uiState.filteredStrips
    val currentIndex = uiState.currentIndex
    val view = LocalView.current

    if (uiState.isLoading) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(PureBlack),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = Color.White)
        }
        return
    }

    if (strips.isEmpty()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(PureBlack),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "henuz anin yok",
                    color = TextSecondary,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium
                )
                Spacer(modifier = Modifier.height(16.dp))
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Kapat",
                        tint = Color.White
                    )
                }
            }
        }
        return
    }

    val currentStrip = strips.getOrNull(currentIndex) ?: return

    // Swipe-down dismiss state
    var verticalDragOffset by remember { mutableFloatStateOf(0f) }
    var horizontalDrag by remember { mutableFloatStateOf(0f) }

    // Ken Burns animation state
    var kenBurnsScaleTarget by remember { mutableFloatStateOf(1.0f) }
    var kenBurnsOffsetX by remember { mutableFloatStateOf(0f) }
    var kenBurnsOffsetY by remember { mutableFloatStateOf(0f) }

    val kenBurnsScaleAnim by animateFloatAsState(
        targetValue = kenBurnsScaleTarget,
        animationSpec = tween(durationMillis = 5000, easing = LinearEasing),
        label = "kenBurnsScale"
    )
    val kenBurnsOffsetXAnim by animateFloatAsState(
        targetValue = kenBurnsOffsetX,
        animationSpec = tween(durationMillis = 5000, easing = LinearEasing),
        label = "kenBurnsX"
    )
    val kenBurnsOffsetYAnim by animateFloatAsState(
        targetValue = kenBurnsOffsetY,
        animationSpec = tween(durationMillis = 5000, easing = LinearEasing),
        label = "kenBurnsY"
    )

    // Trigger Ken Burns on index change
    LaunchedEffect(currentIndex) {
        kenBurnsScaleTarget = 1.0f
        kenBurnsOffsetX = 0f
        kenBurnsOffsetY = 0f
        kotlinx.coroutines.delay(100)
        kenBurnsScaleTarget = 1.05f + (Math.random().toFloat() * 0.07f)
        kenBurnsOffsetX = -15f + (Math.random().toFloat() * 30f)
        kenBurnsOffsetY = -15f + (Math.random().toFloat() * 30f)
    }

    // Speed selector menu
    var showSpeedMenu by remember { mutableStateOf(false) }

    val dismissAlpha = 1f - (abs(verticalDragOffset) / 1200f).coerceIn(0f, 0.5f)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(Unit) {
                var dragDirectionDecided = false
                var isVertical = false
                var startX = 0f
                var startY = 0f

                detectTapGestures(
                    onTap = {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        viewModel.togglePlayPause()
                    }
                )
            }
            .pointerInput(Unit) {
                var dragDirectionDecided = false
                var isVertical = false

                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        val change = event.changes.firstOrNull() ?: continue

                        if (change.pressed) {
                            val dx = change.position.x - (change.previousPosition.x)
                            val dy = change.position.y - (change.previousPosition.y)

                            if (!dragDirectionDecided && (abs(dx) > 10f || abs(dy) > 10f)) {
                                isVertical = abs(dy) > abs(dx)
                                dragDirectionDecided = true
                            }

                            if (dragDirectionDecided) {
                                if (isVertical) {
                                    verticalDragOffset += dy
                                } else {
                                    horizontalDrag += dx
                                }
                            }
                        } else {
                            // Pointer released
                            if (isVertical) {
                                if (verticalDragOffset > 400f) {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    onBack()
                                }
                                verticalDragOffset = 0f
                            } else {
                                if (horizontalDrag < -160f) {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    viewModel.nextStrip()
                                } else if (horizontalDrag > 160f) {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    viewModel.previousStrip()
                                }
                                horizontalDrag = 0f
                            }
                            dragDirectionDecided = false
                            isVertical = false
                        }
                    }
                }
            }
    ) {
        // Photo with Ken Burns, slide transition, and dismiss offset
        AnimatedContent(
            targetState = currentIndex,
            transitionSpec = {
                (slideInHorizontally { width -> width } + fadeIn())
                    .togetherWith(slideOutHorizontally { width -> -width } + fadeOut())
            },
            label = "photoSlide"
        ) { index ->
            val strip = strips.getOrNull(index) ?: return@AnimatedContent

            AsyncImage(
                model = strip.thumbnailUrl ?: strip.imageUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        scaleX = kenBurnsScaleAnim
                        scaleY = kenBurnsScaleAnim
                        translationX = kenBurnsOffsetXAnim
                        translationY = kenBurnsOffsetYAnim
                    }
                    .offset { IntOffset(0, verticalDragOffset.coerceAtLeast(0f).roundToInt()) }
                    .alpha(dismissAlpha)
            )
        }

        // Pause indicator
        AnimatedVisibility(
            visible = !uiState.isPlaying,
            enter = scaleIn(initialScale = 0.5f) + fadeIn(),
            exit = scaleOut(targetScale = 0.5f) + fadeOut(),
            modifier = Modifier.align(Alignment.Center)
        ) {
            Icon(
                imageVector = Icons.Default.Pause,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.size(64.dp)
            )
        }

        // Top gradient overlay
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Black.copy(alpha = 0.7f), Color.Transparent)
                    )
                )
        )

        // Bottom gradient overlay
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(250.dp)
                .align(Alignment.BottomCenter)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.85f))
                    )
                )
        )

        // Animated segmented progress bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 52.dp, start = 12.dp, end = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            strips.forEachIndexed { index, _ ->
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(3.dp)
                        .clip(RoundedCornerShape(1.5.dp))
                        .background(Color.White.copy(alpha = 0.3f))
                ) {
                    val fraction = when {
                        index < currentIndex -> 1f
                        index == currentIndex -> uiState.segmentProgress
                        else -> 0f
                    }
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(fraction = fraction.coerceIn(0f, 1f))
                            .height(3.dp)
                            .clip(RoundedCornerShape(1.5.dp))
                            .background(Color.White.copy(alpha = 0.9f))
                    )
                }
            }
        }

        // Top bar with close, speed selector, and filter
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 64.dp, start = 16.dp, end = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Kapat",
                    tint = Color.White,
                    modifier = Modifier.size(28.dp)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            // Speed selector
            Box {
                IconButton(onClick = { showSpeedMenu = true }) {
                    Text(
                        text = uiState.playbackSpeed.label,
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                DropdownMenu(
                    expanded = showSpeedMenu,
                    onDismissRequest = { showSpeedMenu = false }
                ) {
                    PlaybackSpeed.entries.forEach { speed ->
                        DropdownMenuItem(
                            text = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = speed.label,
                                        fontWeight = if (uiState.playbackSpeed == speed) FontWeight.Bold else FontWeight.Normal
                                    )
                                    if (uiState.playbackSpeed == speed) {
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Text(text = "~", fontWeight = FontWeight.Bold)
                                    }
                                }
                            },
                            onClick = {
                                viewModel.setPlaybackSpeed(speed)
                                showSpeedMenu = false
                            }
                        )
                    }
                }
            }

            // Period filter pills
            MemoryPeriod.entries.forEach { period ->
                val isSelected = uiState.selectedPeriod == period
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(
                            if (isSelected) Color.White.copy(alpha = 0.2f)
                            else Color.Transparent
                        )
                        .clickable { viewModel.selectPeriod(period) }
                        .padding(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = period.label,
                        color = if (isSelected) Color.White else Color.White.copy(alpha = 0.5f),
                        fontSize = 12.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                    )
                }
            }
        }

        // Bottom info overlay
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(start = 20.dp, bottom = 100.dp)
        ) {
            // Sender name or shimmer placeholder
            val senderName = uiState.senderNames[currentStrip.senderId]
            if (senderName != null) {
                Text(
                    text = senderName,
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
            } else {
                // Shimmer placeholder
                val infiniteTransition = rememberInfiniteTransition(label = "shimmer")
                val shimmerAlpha by infiniteTransition.animateFloat(
                    initialValue = 0.08f,
                    targetValue = 0.2f,
                    animationSpec = infiniteRepeatable(
                        animation = tween(1500, easing = LinearEasing),
                        repeatMode = RepeatMode.Reverse
                    ),
                    label = "shimmerAlpha"
                )
                Box(
                    modifier = Modifier
                        .width(100.dp)
                        .height(16.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color.White.copy(alpha = shimmerAlpha))
                )
            }
            Spacer(modifier = Modifier.height(4.dp))

            // Date
            Text(
                text = viewModel.formatDate(currentStrip.timestamp),
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 13.sp
            )

            // City
            if (!currentStrip.cityName.isNullOrEmpty()) {
                Spacer(modifier = Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = currentStrip.cityName ?: "",
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 13.sp
                    )
                }
            }
        }

        // Bottom controls
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(horizontal = 24.dp, vertical = 32.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Play/Pause
            IconButton(
                onClick = { viewModel.togglePlayPause() },
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.15f))
            ) {
                Icon(
                    imageVector = if (uiState.isPlaying) Icons.Default.Pause else Icons.Default.PlayArrow,
                    contentDescription = if (uiState.isPlaying) "Duraklat" else "Oynat",
                    tint = Color.White,
                    modifier = Modifier.size(24.dp)
                )
            }

            // Counter
            Text(
                text = "${currentIndex + 1} / ${strips.size}",
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium
            )

            // Share
            IconButton(
                onClick = onShare,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.15f))
            ) {
                Icon(
                    imageVector = Icons.Default.Share,
                    contentDescription = "Paylas",
                    tint = Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
    }
}
