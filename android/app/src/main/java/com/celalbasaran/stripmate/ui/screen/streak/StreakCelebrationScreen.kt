package com.celalbasaran.stripmate.ui.screen.streak

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import kotlinx.coroutines.delay
import kotlin.random.Random

@Composable
fun StreakCelebrationScreen(
    streakCount: Int,
    friendName: String,
    onDismiss: () -> Unit
) {
    var showContent by remember { mutableStateOf(false) }
    val screenWidth = LocalConfiguration.current.screenWidthDp
    val screenHeight = LocalConfiguration.current.screenHeightDp

    // Generate confetti particles
    val particles = remember {
        List(30) {
            ConfettiData(
                startX = Random.nextFloat() * screenWidth,
                startY = -20f,
                endY = screenHeight.toFloat() + 20,
                size = Random.nextFloat() * 5 + 3,
                opacity = Random.nextFloat() * 0.5f + 0.3f,
                delay = Random.nextLong(0, 500)
            )
        }
    }

    LaunchedEffect(Unit) {
        delay(100)
        showContent = true
    }

    val milestoneMessage = when (streakCount) {
        7 -> "Bir haftalik seri!\nBu inanilmaz bir baslangic."
        30 -> "Bir aylik seri!\nEfsane ikilsiniz."
        100 -> "Yuz gun! \uD83C\uDFC6\nGercek dostluk bu."
        365 -> "Tam bir yil! \uD83D\uDC8E\nEfsanesiniz."
        else -> "$streakCount gun birlikte.\nDevam edin!"
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack.copy(alpha = 0.85f)),
        contentAlignment = Alignment.Center
    ) {
        // Confetti particles
        particles.forEach { particle ->
            var animateY by remember { mutableStateOf(false) }
            LaunchedEffect(Unit) {
                delay(particle.delay)
                animateY = true
            }
            val yOffset by animateFloatAsState(
                targetValue = if (animateY) particle.endY else particle.startY,
                animationSpec = tween(durationMillis = Random.nextInt(2000, 4000)),
                label = "confetti"
            )

            Box(
                modifier = Modifier
                    .offset(x = particle.startX.dp, y = yOffset.dp)
                    .size(particle.size.dp)
                    .alpha(particle.opacity)
                    .background(Color.White, RoundedCornerShape(50))
            )
        }

        // Content
        AnimatedVisibility(
            visible = showContent,
            enter = fadeIn(tween(600)) + scaleIn(tween(600))
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(32.dp)
            ) {
                Text(
                    text = "\uD83D\uDD25",
                    fontSize = 80.sp
                )

                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = "$streakCount gun!",
                    color = TextPrimary,
                    fontSize = 48.sp,
                    fontWeight = FontWeight.Black
                )

                Spacer(modifier = Modifier.height(12.dp))

                Text(
                    text = milestoneMessage,
                    color = TextSecondary.copy(alpha = 0.6f),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = "sen & $friendName",
                    color = TextSecondary.copy(alpha = 0.4f),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )

                Spacer(modifier = Modifier.height(32.dp))

                Button(
                    onClick = onDismiss,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.White,
                        contentColor = Color.Black
                    ),
                    shape = RoundedCornerShape(50)
                ) {
                    Text(
                        text = "Harika!",
                        fontWeight = FontWeight.Bold,
                        fontSize = 17.sp,
                        modifier = Modifier.padding(horizontal = 24.dp, vertical = 4.dp)
                    )
                }
            }
        }
    }
}

private data class ConfettiData(
    val startX: Float,
    val startY: Float,
    val endY: Float,
    val size: Float,
    val opacity: Float,
    val delay: Long
)
