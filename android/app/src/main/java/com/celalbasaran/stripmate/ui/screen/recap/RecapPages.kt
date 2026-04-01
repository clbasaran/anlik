package com.celalbasaran.stripmate.ui.screen.recap

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Photo
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.data.model.recap.WeeklySummary
import kotlinx.coroutines.delay

// ─── Sayfa 1: Başlık Kartı ─────────────────────────────────────────────────

@Composable
fun RecapTitlePage(summary: WeeklySummary) {
    var showContent by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(200)
        showContent = true
    }

    val alpha = remember { Animatable(0f) }
    val offsetY = remember { Animatable(20f) }

    LaunchedEffect(showContent) {
        if (showContent) {
            alpha.animateTo(1f, tween(800))
        }
    }
    LaunchedEffect(showContent) {
        if (showContent) {
            offsetY.animateTo(0f, tween(800))
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // Bulanık arka plan
        summary.highlightPhotoUrl?.let { url ->
            AsyncImage(
                model = url,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .alpha(0.15f)
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "Hafta ${summary.weekNumber}",
                fontSize = 56.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.alpha(alpha.value)
            )

            Spacer(modifier = Modifier.height(8.dp))

            val dateFormatter = remember { java.text.SimpleDateFormat("d MMM", java.util.Locale("tr")) }
            Text(
                text = "${dateFormatter.format(summary.startDate)} – ${dateFormatter.format(summary.endDate)}",
                fontSize = 18.sp,
                color = Color.White.copy(alpha = 0.6f),
                modifier = Modifier.alpha(alpha.value)
            )

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "anlık.",
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.3f),
                modifier = Modifier.alpha(alpha.value)
            )
        }
    }
}

// ─── Sayfa 2: Fotoğraf Sayısı + Trend ─────────────────────────────────────

@Composable
fun RecapPhotoCountPage(summary: WeeklySummary) {
    var displayedCount by remember { mutableIntStateOf(0) }
    var showTrend by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        val target = summary.photosCount
        val steps = minOf(target, 30)
        if (steps > 0) {
            val interval = 800L / steps
            for (i in 1..steps) {
                delay(interval)
                displayedCount = (target.toDouble() * i / steps).toInt()
            }
        }
        delay(200)
        showTrend = true
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "$displayedCount",
            fontSize = 80.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Text(
            text = "an bu hafta",
            fontSize = 22.sp,
            color = Color.White.copy(alpha = 0.7f)
        )

        Spacer(modifier = Modifier.height(20.dp))

        // Gönderilen / Alınan pill'ler
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            RecapPill(
                icon = Icons.Default.ArrowUpward,
                text = "${summary.sentCount} gönderilen"
            )
            RecapPill(
                icon = Icons.Default.ArrowDownward,
                text = "${summary.receivedCount} alınan"
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Trend
        if (showTrend) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                val trendColor = if (summary.trend.isPositive) Color(0xFF34C759) else Color.White.copy(alpha = 0.5f)
                Text(
                    text = summary.trend.description,
                    fontSize = 14.sp,
                    color = Color.White.copy(alpha = 0.6f)
                )
            }
        }
    }
}

// ─── Sayfa 3: En İyi Arkadaş ──────────────────────────────────────────────

@Composable
fun RecapTopFriendPage(summary: WeeklySummary) {
    var showContent by remember { mutableStateOf(false) }
    val scale = remember { Animatable(0.3f) }
    val alpha = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        delay(150)
        showContent = true
        alpha.animateTo(1f, spring(dampingRatio = 0.65f, stiffness = Spring.StiffnessLow))
    }
    LaunchedEffect(showContent) {
        if (showContent) {
            scale.animateTo(1f, spring(dampingRatio = 0.65f, stiffness = Spring.StiffnessLow))
        }
    }

    val friendName = summary.topFriendDisplayName ?: "Arkadaşın"

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Üst etiket
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier.alpha(alpha.value)
        ) {
            Icon(
                imageVector = Icons.Default.Favorite,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.4f),
                modifier = Modifier.size(12.dp)
            )
            Text(
                text = "EN ÇOK PAYLAŞTIĞIN KİŞİ",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White.copy(alpha = 0.4f),
                letterSpacing = 1.5.sp
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Avatar placeholder
        Box(
            modifier = Modifier
                .size(120.dp)
                .scale(scale.value)
                .clip(CircleShape)
                .background(
                    Brush.linearGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.15f),
                            Color.White.copy(alpha = 0.05f)
                        )
                    )
                ),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = friendName.take(1).uppercase(),
                fontSize = 48.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White.copy(alpha = 0.5f)
            )
        }

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = friendName,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White,
            modifier = Modifier.alpha(alpha.value)
        )

        Spacer(modifier = Modifier.height(12.dp))

        RecapPill(
            icon = Icons.Default.Photo,
            text = "${summary.topFriendPhotoCount} an paylaştınız"
        )

        if (summary.friendsInteractedCount > 1) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "bu hafta ${summary.friendsInteractedCount} arkadaşınla etkileştin",
                fontSize = 14.sp,
                color = Color.White.copy(alpha = 0.35f),
                modifier = Modifier.alpha(alpha.value)
            )
        }
    }
}

// ─── Sayfa 4: Şehirler ────────────────────────────────────────────────────

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun RecapCitiesPage(summary: WeeklySummary) {
    var showContent by remember { mutableStateOf(false) }
    val scale = remember { Animatable(0.3f) }
    val alpha = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        delay(200)
        showContent = true
        alpha.animateTo(1f, tween(500))
    }
    LaunchedEffect(showContent) {
        if (showContent) {
            scale.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy))
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.LocationOn,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.8f),
            modifier = Modifier
                .size(48.dp)
                .scale(scale.value)
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "${summary.uniqueCities.size}",
            fontSize = 64.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Text(
            text = "farklı şehirden paylaşıldı",
            fontSize = 18.sp,
            color = Color.White.copy(alpha = 0.6f)
        )

        Spacer(modifier = Modifier.height(20.dp))

        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.alpha(alpha.value)
        ) {
            summary.uniqueCities.forEach { city ->
                Text(
                    text = city,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White,
                    modifier = Modifier
                        .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(50))
                        .padding(horizontal = 14.dp, vertical = 8.dp)
                )
            }
        }
    }
}

// ─── Sayfa 5: Zaman Kalıpları ──────────────────────────────────────────────

@Composable
fun RecapTimePatternsPage(summary: WeeklySummary) {
    var showBars by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(300)
        showBars = true
    }

    val maxCount = maxOf(
        summary.timeDistribution.morning,
        summary.timeDistribution.afternoon,
        summary.timeDistribution.evening,
        summary.timeDistribution.night,
        1
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "PAYLAŞIM SAATLERİN",
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White.copy(alpha = 0.4f),
            letterSpacing = 1.5.sp
        )

        Spacer(modifier = Modifier.height(32.dp))

        TimeBarRow("Sabah", summary.timeDistribution.morning, maxCount, showBars)
        Spacer(modifier = Modifier.height(16.dp))
        TimeBarRow("Öğle", summary.timeDistribution.afternoon, maxCount, showBars)
        Spacer(modifier = Modifier.height(16.dp))
        TimeBarRow("Akşam", summary.timeDistribution.evening, maxCount, showBars)
        Spacer(modifier = Modifier.height(16.dp))
        TimeBarRow("Gece", summary.timeDistribution.night, maxCount, showBars)

        Spacer(modifier = Modifier.height(24.dp))

        if (summary.timeDistribution.dominantPeriod.isNotEmpty()) {
            Text(
                text = "en çok ${summary.timeDistribution.dominantPeriod} paylaşıyorsun",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White
            )
        }

        summary.mostActiveDayName?.let { dayName ->
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "$dayName en aktif günün",
                fontSize = 14.sp,
                color = Color.White.copy(alpha = 0.5f)
            )
        }
    }
}

@Composable
private fun TimeBarRow(label: String, count: Int, maxCount: Int, showBars: Boolean) {
    val barProgress = remember { Animatable(0f) }

    LaunchedEffect(showBars) {
        if (showBars) {
            barProgress.animateTo(
                if (maxCount > 0) count.toFloat() / maxCount else 0f,
                spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessLow)
            )
        }
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            fontSize = 14.sp,
            color = Color.White.copy(alpha = 0.6f),
            modifier = Modifier.width(50.dp)
        )

        Spacer(modifier = Modifier.width(12.dp))

        Box(
            modifier = Modifier
                .weight(1f)
                .height(12.dp)
                .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(6.dp))
        ) {
            val isMax = count == maxCount
            Box(
                modifier = Modifier
                    .fillMaxWidth(barProgress.value)
                    .height(12.dp)
                    .background(
                        Color.White.copy(alpha = if (isMax) 0.8f else 0.4f),
                        RoundedCornerShape(6.dp)
                    )
            )
        }

        Spacer(modifier = Modifier.width(12.dp))

        Text(
            text = "$count",
            fontSize = 12.sp,
            color = Color.White.copy(alpha = 0.5f),
            modifier = Modifier.width(24.dp),
            textAlign = TextAlign.End
        )
    }
}

// ─── Sayfa 6: Seri Öne Çıkanları ──────────────────────────────────────────

@Composable
fun RecapStreaksPage(summary: WeeklySummary) {
    var showContent by remember { mutableStateOf(false) }
    val scale = remember { Animatable(0.3f) }

    LaunchedEffect(Unit) {
        delay(200)
        showContent = true
        scale.animateTo(1f, spring(dampingRatio = Spring.DampingRatioMediumBouncy))
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "\uD83D\uDD25", // fire emoji
            fontSize = 64.sp,
            modifier = Modifier.scale(scale.value)
        )

        Spacer(modifier = Modifier.height(16.dp))

        if (summary.streakMilestones.isNotEmpty()) {
            Text(
                text = "SERİ KİLOMETRE TAŞLARI",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White.copy(alpha = 0.5f),
                letterSpacing = 1.5.sp
            )

            Spacer(modifier = Modifier.height(16.dp))

            summary.streakMilestones.forEach { milestone ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(12.dp))
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "\uD83D\uDD25 ${milestone.milestoneValue} gün",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                    Text(
                        text = milestone.friendDisplayName,
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.6f)
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
            }
        } else {
            Text(
                text = "EN UZUN AKTİF SERİN",
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White.copy(alpha = 0.5f),
                letterSpacing = 1.5.sp
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "${summary.longestActiveStreak} gün",
                fontSize = 48.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }
    }
}

// ─── Sayfa 7: Fotoğraf Grid + Kapanış ──────────────────────────────────────

@Composable
fun RecapPhotoGridPage(
    summary: WeeklySummary,
    strips: List<Strip>,
    currentUserId: String
) {
    var showContent by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(100)
        showContent = true
    }

    val topPhotos = remember(strips) {
        strips
            .filter { !it.isLockedFor(currentUserId) }
            .sortedWith(compareByDescending<Strip> { it.receiverIds.size }.thenByDescending { it.timestamp })
            .take(6)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .alpha(if (showContent) 1f else 0f),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(60.dp))

        Text(
            text = "haftanın öne çıkanları",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Spacer(modifier = Modifier.height(16.dp))

        // 2x3 grid
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(((topPhotos.size / 2 + topPhotos.size % 2) * 184).dp)
                .padding(horizontal = 16.dp),
            userScrollEnabled = false
        ) {
            items(topPhotos) { strip ->
                AsyncImage(
                    model = strip.thumbnailUrl ?: strip.imageUrl,
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .height(180.dp)
                        .clip(RoundedCornerShape(8.dp))
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Özet satırı
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(horizontal = 32.dp)
        ) {
            MiniStat(icon = Icons.Default.PhotoLibrary, value = "${summary.photosCount}", label = "an")
            MiniStat(icon = Icons.Default.People, value = "${summary.friendsInteractedCount}", label = "arkadaş")
            MiniStat(icon = Icons.Default.LocationOn, value = "${summary.uniqueCities.size}", label = "şehir")
        }

        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "anlık.",
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = Color.White.copy(alpha = 0.2f)
        )

        Spacer(modifier = Modifier.height(40.dp))
    }
}

// ─── Shared Components ─────────────────────────────────────────────────────

@Composable
fun RecapPill(
    icon: ImageVector,
    text: String,
    modifier: Modifier = Modifier
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        modifier = modifier
            .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.8f),
            modifier = Modifier.size(14.dp)
        )
        Text(
            text = text,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = Color.White.copy(alpha = 0.8f)
        )
    }
}

@Composable
fun MiniStat(icon: ImageVector, value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.5f),
            modifier = Modifier.size(14.dp)
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = value,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        Text(
            text = label,
            fontSize = 10.sp,
            color = Color.White.copy(alpha = 0.4f)
        )
    }
}
