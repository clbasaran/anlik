package com.celalbasaran.stripmate.ui.screen.history

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.delay
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * Gizli an acma animasyonu: kilit sallaniyor -> catliyor -> parcalaniyor -> fotograf aciliyor
 * iOS SecretUnlockAnimation'in Android Compose karsiligi.
 */

private enum class UnlockPhase {
    IDLE, SHAKE, CRACK, SHATTER, REVEAL
}

private data class Fragment(
    val icon: ImageVector,
    val angleDeg: Double,
    val distance: Float,
    val rotation: Float,
    val size: Float,
    val delayMs: Long
)

@Composable
fun SecretUnlockAnimation(
    photoUrl: String,
    onAnimationComplete: () -> Unit
) {
    var phase by remember { mutableStateOf(UnlockPhase.IDLE) }

    // Shake offset
    val shakeOffset = remember { Animatable(0f) }

    // Lock scale for crack
    val lockScale = remember { Animatable(1f) }
    val lockAlpha = remember { Animatable(1f) }

    // Photo blur and alpha
    val photoBlur = remember { Animatable(30f) }
    val photoAlpha = remember { Animatable(0.3f) }

    // Overlay darkness
    val overlayAlpha = remember { Animatable(0.7f) }

    // Fragments
    val fragments = remember {
        val icons = listOf(
            Icons.Default.Lock,
            Icons.Default.LockOpen,
            Icons.Default.Star,
            Icons.Default.Favorite,
            Icons.Default.Circle
        )
        (0 until 12).map { i ->
            Fragment(
                icon = icons[i % icons.size],
                angleDeg = i * 30.0 + Random.nextDouble(-15.0, 15.0),
                distance = Random.nextFloat() * 150f + 150f,
                rotation = Random.nextFloat() * 720f - 360f,
                size = Random.nextFloat() * 10f + 8f,
                delayMs = (Random.nextFloat() * 150).toLong()
            )
        }
    }
    val fragmentProgress = remember { Animatable(0f) }

    // Run the animation sequence
    LaunchedEffect(Unit) {
        delay(300)

        // Phase 1: Shake
        phase = UnlockPhase.SHAKE
        repeat(6) {
            shakeOffset.animateTo(
                targetValue = if (it % 2 == 0) 8f else -8f,
                animationSpec = tween(60, easing = LinearEasing)
            )
        }
        shakeOffset.animateTo(0f, animationSpec = tween(40))

        // Phase 2: Crack
        phase = UnlockPhase.CRACK
        lockScale.animateTo(1.1f, animationSpec = tween(200))
        lockAlpha.animateTo(0.8f, animationSpec = tween(200))
        delay(100)

        // Phase 3: Shatter
        phase = UnlockPhase.SHATTER
        // Hide lock
        lockAlpha.animateTo(0f, animationSpec = tween(150))
        // Fly fragments outward
        fragmentProgress.animateTo(
            1f,
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessLow
            )
        )
        // Start revealing photo
        photoAlpha.animateTo(0.6f, animationSpec = tween(300))
        overlayAlpha.animateTo(0.3f, animationSpec = tween(300))

        delay(200)

        // Phase 4: Reveal
        phase = UnlockPhase.REVEAL
        // Dissolve blur and darken overlay
        photoBlur.animateTo(0f, animationSpec = tween(800))
        photoAlpha.animateTo(1f, animationSpec = tween(800))
        overlayAlpha.animateTo(0f, animationSpec = tween(800))

        delay(600)

        // Complete - transition to chat screen
        onAnimationComplete()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // Background photo (blurred)
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(photoUrl)
                .crossfade(true)
                .build(),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .blur(photoBlur.value.dp)
                .alpha(photoAlpha.value)
                .scale(if (phase == UnlockPhase.REVEAL) 1f else 1.05f)
        )

        // Dark overlay
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = overlayAlpha.value))
        )

        // Lock icon (visible during IDLE, SHAKE, CRACK)
        if (phase != UnlockPhase.SHATTER && phase != UnlockPhase.REVEAL || lockAlpha.value > 0.01f) {
            Box(
                modifier = Modifier.align(Alignment.Center)
            ) {
                // Glow
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.1f),
                    modifier = Modifier
                        .size(80.dp)
                        .blur(20.dp)
                        .offset(x = shakeOffset.value.dp)
                        .scale(lockScale.value)
                        .alpha(lockAlpha.value)
                        .align(Alignment.Center)
                )
                // Main lock
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = "Gizli an kilidi",
                    tint = Color.White,
                    modifier = Modifier
                        .size(64.dp)
                        .offset(x = shakeOffset.value.dp)
                        .scale(lockScale.value)
                        .alpha(lockAlpha.value)
                        .align(Alignment.Center)
                )
            }
        }

        // Fragments
        Box(modifier = Modifier.align(Alignment.Center)) {
            fragments.forEach { frag ->
                val radians = Math.toRadians(frag.angleDeg)
                val progress = fragmentProgress.value
                val dx = (cos(radians) * frag.distance * progress).toFloat()
                val dy = (sin(radians) * frag.distance * progress).toFloat()
                val fragAlpha = (1f - progress).coerceIn(0f, 0.7f)
                val fragScale = 1f - progress * 0.7f

                Icon(
                    imageVector = frag.icon,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = fragAlpha),
                    modifier = Modifier
                        .size(frag.size.dp)
                        .offset(x = dx.dp, y = dy.dp)
                        .rotate(frag.rotation * progress)
                        .scale(fragScale)
                )
            }
        }
    }
}
