package com.celalbasaran.stripmate.ui.screen.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

private val tourTitles = listOf(
    "fotoğraf çek, gönder",
    "en yakinlarini ekle",
    "anlarina geri don",
    "widget'ini kur"
)

private val tourDescriptions = listOf(
    "kamerayı aç, anını yakala ve arkadaşlarına gönder.",
    "arkadaş kodunu paylaş, sadece senin insanların burada.",
    "gönderdiğin ve aldığın tum anlar burada kalır.",
    "ana ekranina anlik. widget'ini ekle."
)

@Composable
fun AppTourScreen(
    onComplete: () -> Unit
) {
    var currentStep by remember { mutableIntStateOf(0) }
    val isLastStep = currentStep == 3
    val progressAnimated by animateFloatAsState(
        targetValue = (currentStep + 1) / 4f,
        animationSpec = tween(400, easing = FastOutSlowInEasing),
        label = "progress"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp)
                .padding(top = 16.dp, bottom = 32.dp)
        ) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "anlik.",
                    color = Color.White,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "${currentStep + 1}/4",
                    color = Color.White.copy(alpha = 0.5f),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Demo area
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(370.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .background(Color.White.copy(alpha = 0.04f))
                    .border(
                        width = 1.dp,
                        color = Color.White.copy(alpha = 0.08f),
                        shape = RoundedCornerShape(24.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                when (currentStep) {
                    0 -> CameraDemoView()
                    1 -> FriendsDemoView()
                    2 -> HistoryDemoView()
                    3 -> WidgetDemoView()
                }
            }

            Spacer(modifier = Modifier.height(32.dp))

            // Title
            Text(
                text = tourTitles[currentStep],
                color = Color.White,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                lineHeight = 34.sp
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Description
            Text(
                text = tourDescriptions[currentStep],
                color = Color.White.copy(alpha = 0.45f),
                fontSize = 15.sp,
                lineHeight = 22.sp
            )

            Spacer(modifier = Modifier.weight(1f))

            // Progress bar
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Color.White.copy(alpha = 0.06f))
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(progressAnimated)
                        .height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(Color.White)
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // Continue / Ready button
            Button(
                onClick = {
                    if (isLastStep) {
                        onComplete()
                    } else {
                        currentStep++
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isLastStep) Color.White else Color.White.copy(alpha = 0.1f)
                )
            ) {
                Text(
                    text = if (isLastStep) "hazirim" else "devam et",
                    color = if (isLastStep) Color.Black else Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            // Skip button (hidden on last step)
            if (!isLastStep) {
                TextButton(
                    onClick = { onComplete() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 4.dp)
                ) {
                    Text(
                        text = "atla",
                        color = Color.White.copy(alpha = 0.35f),
                        fontSize = 14.sp
                    )
                }
            } else {
                Spacer(modifier = Modifier.height(48.dp))
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Step 1: Camera Demo
// ---------------------------------------------------------------------------

@Composable
private fun CameraDemoView() {
    var showGrid by remember { mutableStateOf(false) }
    var showFlash by remember { mutableStateOf(false) }
    var showShutter by remember { mutableStateOf(false) }
    var shutterPressed by remember { mutableStateOf(false) }
    var showBadge by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(300)
        showGrid = true
        delay(500)
        showFlash = true
        delay(600)
        showShutter = true
        delay(800)
        shutterPressed = true
        delay(400)
        shutterPressed = false
        delay(300)
        showBadge = true
    }

    val shutterScale by animateFloatAsState(
        targetValue = if (shutterPressed) 0.8f else 1f,
        animationSpec = tween(200),
        label = "shutter"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // Camera viewfinder background
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(3f / 4f)
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White.copy(alpha = 0.06f))
                .align(Alignment.TopCenter)
        ) {
            // Grid lines
            AnimatedVisibility(
                visible = showGrid,
                enter = fadeIn(tween(400))
            ) {
                Box(modifier = Modifier.fillMaxSize()) {
                    // Vertical lines
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(start = 80.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .width(0.5.dp)
                                .matchParentSize()
                                .background(Color.White.copy(alpha = 0.15f))
                        )
                    }
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(end = 80.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .width(0.5.dp)
                                .matchParentSize()
                                .background(Color.White.copy(alpha = 0.15f))
                                .align(Alignment.CenterEnd)
                        )
                    }
                    // Horizontal lines
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(top = 70.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .height(0.5.dp)
                                .fillMaxWidth()
                                .background(Color.White.copy(alpha = 0.15f))
                        )
                    }
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(bottom = 70.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .height(0.5.dp)
                                .fillMaxWidth()
                                .background(Color.White.copy(alpha = 0.15f))
                                .align(Alignment.BottomCenter)
                        )
                    }
                }
            }

            // Flash icon
            AnimatedVisibility(
                visible = showFlash,
                enter = fadeIn(tween(300)) + scaleIn(tween(300)),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.15f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.FlashOn,
                        contentDescription = null,
                        tint = Color.Yellow,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // Gonderildi badge
            AnimatedVisibility(
                visible = showBadge,
                enter = fadeIn(tween(300)) + scaleIn(
                    tween(400, easing = FastOutSlowInEasing)
                ),
                modifier = Modifier.align(Alignment.Center)
            ) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(Color(0xFF34C759).copy(alpha = 0.9f))
                        .padding(horizontal = 20.dp, vertical = 10.dp)
                ) {
                    Text(
                        text = "gönderildi",
                        color = Color.White,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }

        // Shutter button
        AnimatedVisibility(
            visible = showShutter,
            enter = fadeIn(tween(300)) + slideInVertically(
                tween(400),
                initialOffsetY = { it / 2 }
            ),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 8.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .scale(shutterScale)
                    .clip(CircleShape)
                    .background(Color.White)
                    .border(3.dp, Color.White.copy(alpha = 0.3f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(46.dp)
                        .clip(CircleShape)
                        .background(Color.White)
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Step 2: Friends Demo
// ---------------------------------------------------------------------------

private data class DemoFriend(
    val initial: String,
    val name: String,
    val color: Color
)

private val demoFriends = listOf(
    DemoFriend("A", "ayse", Color(0xFFFF6B6B)),
    DemoFriend("M", "mehmet", Color(0xFF4ECDC4)),
    DemoFriend("E", "elif", Color(0xFFFFBE0B)),
    DemoFriend("C", "can", Color(0xFF845EF7))
)

@Composable
private fun FriendsDemoView() {
    var visibleCount by remember { mutableIntStateOf(0) }
    var acceptedIndex by remember { mutableIntStateOf(-1) }
    var showCode by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(400)
        for (i in demoFriends.indices) {
            visibleCount = i + 1
            delay(350)
        }
        delay(500)
        acceptedIndex = 1
        delay(600)
        showCode = true
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(12.dp))

        // Friend cards
        demoFriends.forEachIndexed { index, friend ->
            AnimatedVisibility(
                visible = index < visibleCount,
                enter = fadeIn(tween(300)) + slideInVertically(
                    tween(350, easing = FastOutSlowInEasing),
                    initialOffsetY = { it }
                )
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(Color.White.copy(alpha = 0.06f))
                        .padding(horizontal = 12.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Avatar
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(friend.color),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = friend.initial,
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    Spacer(modifier = Modifier.width(10.dp))

                    Text(
                        text = friend.name,
                        color = Color.White,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium,
                        modifier = Modifier.weight(1f)
                    )

                    // Add / Accepted button
                    if (index == acceptedIndex) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color(0xFF34C759))
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    } else {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color.White.copy(alpha = 0.1f))
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text(
                                text = "ekle",
                                color = Color.White,
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // Friend code
        AnimatedVisibility(
            visible = showCode,
            enter = fadeIn(tween(400)) + scaleIn(
                tween(400, easing = FastOutSlowInEasing)
            )
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.White.copy(alpha = 0.08f))
                    .border(
                        1.dp,
                        Color.White.copy(alpha = 0.12f),
                        RoundedCornerShape(12.dp)
                    )
                    .padding(horizontal = 24.dp, vertical = 12.dp)
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "senin kodun",
                        color = Color.White.copy(alpha = 0.4f),
                        fontSize = 11.sp
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "CELAL037",
                        color = Color.White,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 3.sp
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))
    }
}

// ---------------------------------------------------------------------------
// Step 3: History Demo
// ---------------------------------------------------------------------------

@Composable
private fun HistoryDemoView() {
    var visiblePhotoCount by remember { mutableIntStateOf(0) }
    var showStats by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(300)
        for (i in 1..6) {
            visiblePhotoCount = i
            delay(250)
        }
        delay(400)
        showStats = true
    }

    val photoColors = listOf(
        Color(0xFFFF6B6B).copy(alpha = 0.3f),
        Color(0xFF4ECDC4).copy(alpha = 0.3f),
        Color(0xFFFFBE0B).copy(alpha = 0.3f),
        Color(0xFF845EF7).copy(alpha = 0.3f),
        Color(0xFFFF9FF3).copy(alpha = 0.3f),
        Color(0xFF54A0FF).copy(alpha = 0.3f)
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // Photo grid
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
            userScrollEnabled = false
        ) {
            items(6) { index ->
                AnimatedVisibility(
                    visible = index < visiblePhotoCount,
                    enter = fadeIn(tween(300)) + scaleIn(
                        tween(350, easing = FastOutSlowInEasing)
                    )
                ) {
                    Box(
                        modifier = Modifier
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(photoColors[index]),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Image,
                            contentDescription = null,
                            tint = Color.White.copy(alpha = 0.4f),
                            modifier = Modifier.size(28.dp)
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Stats bar
        AnimatedVisibility(
            visible = showStats,
            enter = fadeIn(tween(400)) + slideInVertically(
                tween(400, easing = FastOutSlowInEasing),
                initialOffsetY = { it }
            )
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.White.copy(alpha = 0.06f))
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                StatItem(value = "36", label = "gönderilen")
                StatItem(value = "57", label = "alinan")
                StatItem(value = "12", label = "gun serisi")
            }
        }
    }
}

@Composable
private fun StatItem(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.4f),
            fontSize = 11.sp
        )
    }
}

// ---------------------------------------------------------------------------
// Step 4: Widget Demo
// ---------------------------------------------------------------------------

@Composable
private fun WidgetDemoView() {
    var showIcons by remember { mutableStateOf(false) }
    var showWidget by remember { mutableStateOf(false) }
    var showGuide by remember { mutableStateOf(false) }
    var guideStep by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        delay(300)
        showIcons = true
        delay(700)
        showWidget = true
        delay(600)
        showGuide = true
        for (i in 1..3) {
            delay(400)
            guideStep = i
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(8.dp))

        // Home screen icons
        AnimatedVisibility(
            visible = showIcons,
            enter = fadeIn(tween(400))
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                repeat(4) { index ->
                    val iconColors = listOf(
                        Color(0xFF007AFF),
                        Color(0xFF34C759),
                        Color(0xFFFF9500),
                        Color(0xFFFF2D55)
                    )
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .background(iconColors[index].copy(alpha = 0.3f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Box(
                            modifier = Modifier
                                .size(20.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(iconColors[index].copy(alpha = 0.6f))
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Widget
        AnimatedVisibility(
            visible = showWidget,
            enter = fadeIn(tween(400)) + scaleIn(
                tween(500, easing = FastOutSlowInEasing),
                initialScale = 0.8f
            )
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(Color.White.copy(alpha = 0.08f))
                    .border(
                        1.dp,
                        Color.White.copy(alpha = 0.12f),
                        RoundedCornerShape(20.dp)
                    )
                    .padding(20.dp)
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "anlik.",
                        color = Color.White,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        repeat(3) {
                            Box(
                                modifier = Modifier
                                    .size(44.dp)
                                    .clip(CircleShape)
                                    .background(Color.White.copy(alpha = 0.1f))
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "son anlar",
                        color = Color.White.copy(alpha = 0.35f),
                        fontSize = 11.sp
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Guide steps
        AnimatedVisibility(
            visible = showGuide,
            enter = fadeIn(tween(300))
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                val guideTexts = listOf(
                    "ana ekranda bos alana uzun bas",
                    "sol ustten + simgesine dokun",
                    "anlik. widget'ini sec ve ekle"
                )
                guideTexts.forEachIndexed { index, text ->
                    AnimatedVisibility(
                        visible = guideStep > index,
                        enter = fadeIn(tween(300)) + slideInVertically(
                            tween(300),
                            initialOffsetY = { it / 2 }
                        )
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(10.dp))
                                .background(Color.White.copy(alpha = 0.04f))
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(24.dp)
                                    .clip(CircleShape)
                                    .background(Color.White.copy(alpha = 0.12f)),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "${index + 1}",
                                    color = Color.White,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Text(
                                text = text,
                                color = Color.White.copy(alpha = 0.6f),
                                fontSize = 13.sp
                            )
                        }
                    }
                }
            }
        }
    }
}
