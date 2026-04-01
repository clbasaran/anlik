package com.celalbasaran.stripmate.ui.screen.recap

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.tween
import android.app.Activity
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.data.model.recap.WeeklySummary
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Sayfa tipleri — boş veri olanlar filtrelenir.
 */
private enum class RecapPage {
    TITLE, PHOTO_COUNT, TOP_FRIEND, CITIES, TIME_PATTERNS, STREAKS, PHOTO_GRID
}

/**
 * Instagram Stories benzeri haftalık recap deneyimi.
 * Auto-advancing progress bar + tap left/right navigation.
 */
@Composable
fun WeeklyRecapScreen(
    summary: WeeklySummary,
    strips: List<Strip>,
    currentUserId: String,
    onDismiss: () -> Unit
) {
    val pages = remember(summary) {
        buildList {
            add(RecapPage.TITLE)
            add(RecapPage.PHOTO_COUNT)
            if (summary.topFriendId != null) add(RecapPage.TOP_FRIEND)
            if (summary.uniqueCities.isNotEmpty()) add(RecapPage.CITIES)
            if (summary.photosCount >= 3 && summary.timeDistribution.total > 0) add(RecapPage.TIME_PATTERNS)
            if (summary.longestActiveStreak > 0 || summary.streakMilestones.isNotEmpty()) add(RecapPage.STREAKS)
            add(RecapPage.PHOTO_GRID)
        }
    }

    var currentPage by remember { mutableIntStateOf(0) }
    val progress = remember { Animatable(0f) }
    val pageDurationMs = 5000L

    // Auto-advance timer
    LaunchedEffect(currentPage) {
        progress.snapTo(0f)
        progress.animateTo(
            targetValue = 1f,
            animationSpec = tween(
                durationMillis = pageDurationMs.toInt(),
                easing = LinearEasing
            )
        )
        // When animation completes, go next
        if (currentPage < pages.size - 1) {
            currentPage++
        } else {
            onDismiss()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Page content
        when (pages.getOrNull(currentPage)) {
            RecapPage.TITLE -> RecapTitlePage(summary)
            RecapPage.PHOTO_COUNT -> RecapPhotoCountPage(summary)
            RecapPage.TOP_FRIEND -> RecapTopFriendPage(summary)
            RecapPage.CITIES -> RecapCitiesPage(summary)
            RecapPage.TIME_PATTERNS -> RecapTimePatternsPage(summary)
            RecapPage.STREAKS -> RecapStreaksPage(summary)
            RecapPage.PHOTO_GRID -> RecapPhotoGridPage(summary, strips, currentUserId)
            null -> {}
        }

        // Progress bar at top
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp)
                .align(Alignment.TopCenter),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            pages.forEachIndexed { index, _ ->
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(2.5.dp)
                        .clip(RoundedCornerShape(50))
                        .background(Color.White.copy(alpha = 0.3f))
                ) {
                    val barProgress = when {
                        index < currentPage -> 1f
                        index == currentPage -> progress.value
                        else -> 0f
                    }
                    Box(
                        modifier = Modifier
                            .fillMaxHeight()
                            .fillMaxWidth(barProgress)
                            .background(Color.White, RoundedCornerShape(50))
                    )
                }
            }
        }

        // Share + Close buttons
        Row(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 24.dp, end = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            val context = LocalContext.current
            val scope = rememberCoroutineScope()

            // Share button
            IconButton(
                onClick = {
                    scope.launch {
                        val activity = context as? Activity ?: return@launch
                        val bitmap = withContext(Dispatchers.Default) {
                            ShareCardUtil.captureComposable(activity) {
                                WeeklySummaryShareCard(summary = summary)
                            }
                        } ?: return@launch
                        val uri = ShareCardUtil.saveBitmapToCache(context, bitmap) ?: return@launch
                        if (ShareCardUtil.isInstagramInstalled(context)) {
                            ShareCardUtil.shareToInstagramStories(context, uri)
                        } else {
                            ShareCardUtil.shareGeneric(context, uri)
                        }
                    }
                },
                modifier = Modifier
                    .size(36.dp)
                    .background(Color.White.copy(alpha = 0.1f), CircleShape)
            ) {
                Icon(
                    imageVector = Icons.Default.Share,
                    contentDescription = "Paylaş",
                    tint = Color.White,
                    modifier = Modifier.size(14.dp)
                )
            }

            // Close button
            IconButton(
                onClick = onDismiss,
                modifier = Modifier
                    .size(36.dp)
                    .background(Color.White.copy(alpha = 0.1f), CircleShape)
            ) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Kapat",
                    tint = Color.White,
                    modifier = Modifier.size(14.dp)
                )
            }
        }

        // Left/Right tap zones
        Row(modifier = Modifier.fillMaxSize()) {
            // Left tap -> previous
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() }
                    ) {
                        if (currentPage > 0) {
                            currentPage--
                        }
                    }
            )
            // Right tap -> next
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() }
                    ) {
                        if (currentPage < pages.size - 1) {
                            currentPage++
                        } else {
                            onDismiss()
                        }
                    }
            )
        }
    }
}
