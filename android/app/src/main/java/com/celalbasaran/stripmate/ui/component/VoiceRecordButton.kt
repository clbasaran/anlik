package com.celalbasaran.stripmate.ui.component

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.ErrorRed
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import kotlinx.coroutines.delay

@Composable
fun VoiceRecordButton(
    isRecording: Boolean,
    onStartRecording: () -> Unit,
    onStopRecording: () -> Unit,
    modifier: Modifier = Modifier,
    maxDurationSeconds: Int = 15
) {
    var recordingDuration by remember { mutableLongStateOf(0L) }

    LaunchedEffect(isRecording) {
        recordingDuration = 0L
        if (isRecording) {
            while (true) {
                delay(100)
                recordingDuration += 100
                if (recordingDuration >= maxDurationSeconds * 1000L) {
                    onStopRecording()
                    break
                }
            }
        }
    }

    val infiniteTransition = rememberInfiniteTransition(label = "recording_pulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(600),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    val bgColor by animateColorAsState(
        targetValue = if (isRecording) ErrorRed else DarkSurfaceVariant,
        animationSpec = tween(200),
        label = "bg_color"
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .scale(if (isRecording) pulseScale else 1f)
                .background(color = bgColor, shape = CircleShape)
                .pointerInput(Unit) {
                    detectTapGestures(
                        onPress = {
                            onStartRecording()
                            tryAwaitRelease()
                            onStopRecording()
                        }
                    )
                },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Mic,
                contentDescription = "Sesli yorum",
                tint = Color.White,
                modifier = Modifier.size(24.dp)
            )
        }

        if (isRecording) {
            val seconds = (recordingDuration / 1000).toInt()
            Text(
                text = "${seconds}s / ${maxDurationSeconds}s",
                color = ErrorRed,
                fontSize = 11.sp,
                style = MaterialTheme.typography.labelSmall
            )
        }
    }
}
