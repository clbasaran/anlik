package com.celalbasaran.stripmate.ui.component

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.PlaceholderColor

@Composable
private fun shimmerBrush(): Brush {
    val transition = rememberInfiniteTransition(label = "shimmer")
    val translateAnim by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1000f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200),
            repeatMode = RepeatMode.Restart
        ),
        label = "shimmer_translate"
    )

    return Brush.linearGradient(
        colors = listOf(
            DarkSurface,
            DarkSurfaceVariant,
            DarkSurface
        ),
        start = Offset(translateAnim - 500f, translateAnim - 500f),
        end = Offset(translateAnim, translateAnim)
    )
}

@Composable
fun SkeletonBox(
    width: Dp = Dp.Unspecified,
    height: Dp,
    modifier: Modifier = Modifier
) {
    val brush = shimmerBrush()
    Box(
        modifier = modifier
            .then(
                if (width != Dp.Unspecified) Modifier.width(width) else Modifier.fillMaxWidth()
            )
            .height(height)
            .clip(RoundedCornerShape(8.dp))
            .background(brush)
    )
}

@Composable
fun SkeletonCircle(
    size: Dp = 44.dp,
    modifier: Modifier = Modifier
) {
    val brush = shimmerBrush()
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(brush)
    )
}

@Composable
fun SkeletonPhotoCard(
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SkeletonCircle(size = 40.dp)
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                SkeletonBox(width = 120.dp, height = 14.dp)
                Spacer(modifier = Modifier.height(6.dp))
                SkeletonBox(width = 80.dp, height = 12.dp)
            }
        }
        Spacer(modifier = Modifier.height(12.dp))
        SkeletonBox(height = 300.dp)
        Spacer(modifier = Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            SkeletonBox(width = 40.dp, height = 28.dp)
            SkeletonBox(width = 40.dp, height = 28.dp)
            SkeletonBox(width = 40.dp, height = 28.dp)
        }
    }
}

@Composable
fun SkeletonMessageBubble(
    isRight: Boolean,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = if (isRight) Arrangement.End else Arrangement.Start
    ) {
        SkeletonBox(
            width = 200.dp,
            height = 40.dp
        )
    }
}
