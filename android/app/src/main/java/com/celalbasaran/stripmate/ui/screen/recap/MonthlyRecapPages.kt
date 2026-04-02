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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import androidx.compose.ui.platform.LocalContext
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.data.model.recap.MonthlySummary
import kotlinx.coroutines.delay

// ─── Sayfa 1: Ay Başlığı ───────────────────────────────────────────────────

@Composable
fun MonthlyTitlePage(summary: MonthlySummary) {
    var showContent by remember { mutableStateOf(false) }
    var displayedCount by remember { mutableIntStateOf(0) }

    val alpha = remember { Animatable(0f) }

    LaunchedEffect(Unit) {
        delay(200)
        showContent = true
        alpha.animateTo(1f, tween(800))
    }

    LaunchedEffect(Unit) {
        val target = summary.totalPhotos
        val steps = minOf(target, 30)
        if (steps > 0) {
            val interval = 800L / steps
            for (i in 1..steps) {
                delay(interval)
                displayedCount = (target.toDouble() * i / steps).toInt()
            }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        summary.thumbnailUrl?.let { url ->
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(url)
                    .crossfade(true)
                    .build(),
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
                text = summary.monthName,
                fontSize = 56.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                modifier = Modifier.alpha(alpha.value)
            )

            Text(
                text = "${summary.year}",
                fontSize = 18.sp,
                color = Color.White.copy(alpha = 0.5f),
                modifier = Modifier.alpha(alpha.value)
            )

            Spacer(modifier = Modifier.height(24.dp))

            // Dev fotoğraf sayısı
            Text(
                text = "$displayedCount",
                fontSize = 72.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Text(
                text = "an bu ay",
                fontSize = 22.sp,
                color = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.alpha(alpha.value)
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Gönderilen / Alınan pill'ler
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.alpha(alpha.value)
            ) {
                RecapPill(icon = Icons.Default.ArrowUpward, text = "${summary.totalSent} gönderilen")
                RecapPill(icon = Icons.Default.ArrowDownward, text = "${summary.totalReceived} alınan")
            }

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "günde ortalama %.1f an".format(summary.averagePhotosPerDay),
                fontSize = 14.sp,
                color = Color.White.copy(alpha = 0.4f),
                modifier = Modifier.alpha(alpha.value)
            )

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "anlık.",
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.2f),
                modifier = Modifier.alpha(alpha.value)
            )
        }
    }
}

// ─── Sayfa 2: Haftalık Bar Chart ────────────────────────────────────────────

@Composable
fun MonthlyWeeklyChartPage(summary: MonthlySummary) {
    var showBars by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(300)
        showBars = true
    }

    val maxWeekCount = maxOf(summary.weeklyBreakdown.maxOrNull() ?: 1, 1)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "HAFTALIK AKTİVİTE",
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White.copy(alpha = 0.4f),
            letterSpacing = 1.5.sp
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Bar chart
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterHorizontally),
            verticalAlignment = Alignment.Bottom
        ) {
            summary.weeklyBreakdown.forEachIndexed { index, count ->
                val barHeight = remember { Animatable(8f) }

                LaunchedEffect(showBars) {
                    if (showBars) {
                        val target = maxOf(count.toFloat() / maxWeekCount * 160f, 8f)
                        barHeight.animateTo(
                            target,
                            spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessLow)
                        )
                    }
                }

                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "$count",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White.copy(alpha = 0.7f)
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Box(
                        modifier = Modifier
                            .width(40.dp)
                            .height(barHeight.value.dp)
                            .background(
                                if (count == maxWeekCount) Color.White
                                else Color.White.copy(alpha = 0.3f),
                                RoundedCornerShape(8.dp)
                            )
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Text(
                        text = "H${index + 1}",
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.5f)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // En aktif hafta bilgisi
        summary.mostActiveWeekNumber?.let { activeWeek ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Star,
                    contentDescription = null,
                    tint = Color(0xFFFFCC00),
                    modifier = Modifier.size(14.dp)
                )
                Text(
                    text = "en aktif hafta: Hafta $activeWeek (${summary.mostActiveWeekCount} an)",
                    fontSize = 14.sp,
                    color = Color.White.copy(alpha = 0.6f)
                )
            }
        }
    }
}

// ─── Sayfa 3: Ayın En İyi Arkadaşı ─────────────────────────────────────────

@Composable
fun MonthlyTopFriendPage(summary: MonthlySummary) {
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
                text = "AYIN EN İYİ ARKADAŞI",
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

        RecapPill(icon = Icons.Default.Photo, text = "${summary.topFriendPhotoCount} an paylaştınız")

        if (summary.uniqueFriendsCount > 1) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "bu ay ${summary.uniqueFriendsCount} arkadaşınla etkileştin",
                fontSize = 14.sp,
                color = Color.White.copy(alpha = 0.35f),
                modifier = Modifier.alpha(alpha.value)
            )
        }
    }
}

// ─── Sayfa 4: Ayın Şehirleri ───────────────────────────────────────────────

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MonthlyCitiesPage(summary: MonthlySummary) {
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

// ─── Sayfa 5: Top 9 Fotoğraf Grid ──────────────────────────────────────────

@Composable
fun MonthlyPhotoGridPage(summary: MonthlySummary, strips: List<Strip>) {
    var showContent by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        delay(100)
        showContent = true
    }

    val topPhotos = remember(strips) {
        strips
            .sortedWith(compareByDescending<Strip> { it.receiverIds.size }.thenByDescending { it.timestamp })
            .take(9)
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
            text = "${summary.monthName} öne çıkanları",
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Spacer(modifier = Modifier.height(16.dp))

        // 3x3 grid
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(((topPhotos.size / 3 + if (topPhotos.size % 3 > 0) 1 else 0) * 133).dp)
                .padding(horizontal = 12.dp),
            userScrollEnabled = false
        ) {
            items(topPhotos) { strip ->
                AsyncImage(
                    model = ImageRequest.Builder(LocalContext.current)
                        .data(strip.thumbnailUrl ?: strip.imageUrl)
                        .crossfade(true)
                        .build(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .height(130.dp)
                        .clip(RoundedCornerShape(6.dp))
                        .background(Color.White.copy(alpha = 0.06f))
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // Özet satırı
        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(horizontal = 32.dp)
        ) {
            MiniStat(icon = Icons.Default.PhotoLibrary, value = "${summary.totalPhotos}", label = "an")
            MiniStat(icon = Icons.Default.People, value = "${summary.uniqueFriendsCount}", label = "arkadaş")
            MiniStat(icon = Icons.Default.LocationOn, value = "${summary.uniqueCities.size}", label = "şehir")
            MiniStat(
                icon = Icons.Default.CalendarMonth,
                value = "%.1f".format(summary.averagePhotosPerDay),
                label = "gün/ort."
            )
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
