package com.celalbasaran.stripmate.ui.screen.recap

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.data.model.recap.WeekTrend
import com.celalbasaran.stripmate.data.model.recap.WeeklySummary
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * Haftalik ozet paylasim karti — Instagram Stories icin 1080x1920 boyutunda
 * markali gorsel uretir. Capture icin offscreen olarak render edilir.
 */
@Composable
fun WeeklySummaryShareCard(
    summary: WeeklySummary,
    modifier: Modifier = Modifier
) {
    val dateFormatter = remember { SimpleDateFormat("d", Locale("tr")) }
    val dateFormatterFull = remember { SimpleDateFormat("d MMMM yyyy", Locale("tr")) }
    val weekRange = "${dateFormatter.format(summary.startDate)}-${dateFormatterFull.format(summary.endDate)}"

    val trendText = when (val t = summary.trend) {
        is WeekTrend.Up -> "\u2191 %${t.percentage} daha fazla"
        is WeekTrend.Down -> "\u2193 %${t.percentage} daha az"
        is WeekTrend.Same -> "= ayni tempo"
        is WeekTrend.FirstWeek -> "\u2728 ilk haftan!"
    }

    val trendColor = when (summary.trend) {
        is WeekTrend.Up -> Color(0xFF34C759)
        is WeekTrend.Down -> Color(0xFFFF3B30).copy(alpha = 0.8f)
        else -> Color.White.copy(alpha = 0.6f)
    }

    // Koyu mor/lacivert -> siyah degrade arka plan
    val backgroundGradient = Brush.verticalGradient(
        colors = listOf(
            Color(0xFF1F1240),   // koyu mor
            Color(0xFF0D0826),   // koyu lacivert
            Color.Black
        )
    )

    Box(
        modifier = modifier
            .width(1080.dp)
            .height(1920.dp)
            .background(backgroundGradient)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 60.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(120.dp))

            // Ust: "anlik." logo
            Text(
                text = "anl\u0131k.",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Spacer(modifier = Modifier.height(16.dp))

            // Hafta araligi
            Text(
                text = weekRange,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White
            )

            Spacer(modifier = Modifier.height(80.dp))

            // Buyuk istatistik: fotograf sayisi
            Text(
                text = "${summary.photosCount}",
                fontSize = 96.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Text(
                text = "foto\u011Fraf payla\u015F\u0131ld\u0131",
                fontSize = 20.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.7f)
            )

            Spacer(modifier = Modifier.height(60.dp))

            // Top friend bolumu
            summary.topFriendDisplayName?.let { friendName ->
                TopFriendCard(
                    name = friendName,
                    photoCount = summary.topFriendPhotoCount
                )

                Spacer(modifier = Modifier.height(40.dp))
            }

            // Seri badge
            if (summary.longestActiveStreak > 0) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(50))
                        .padding(horizontal = 28.dp, vertical = 14.dp)
                ) {
                    Text(text = "\uD83D\uDD25", fontSize = 24.sp)
                    Text(
                        text = "${summary.longestActiveStreak} g\u00FCn seri",
                        fontSize = 20.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }

                Spacer(modifier = Modifier.height(32.dp))
            }

            // Trend gostergesi
            Text(
                text = trendText,
                fontSize = 18.sp,
                fontWeight = FontWeight.Medium,
                color = trendColor,
                modifier = Modifier
                    .background(trendColor.copy(alpha = 0.12f), RoundedCornerShape(50))
                    .padding(horizontal = 24.dp, vertical = 10.dp)
            )

            Spacer(modifier = Modifier.weight(1f))

            // Alt watermark
            Text(
                text = "anl\u0131k.",
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.25f)
            )

            Spacer(modifier = Modifier.height(6.dp))

            Text(
                text = "stripmate.app",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.15f)
            )

            Spacer(modifier = Modifier.height(80.dp))
        }
    }
}

@Composable
private fun TopFriendCard(
    name: String,
    photoCount: Int
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(20.dp))
            .padding(horizontal = 24.dp, vertical = 20.dp)
    ) {
        // Avatar placeholder
        Box(
            modifier = Modifier
                .size(72.dp)
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
                text = name.take(1).uppercase(),
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White.copy(alpha = 0.6f)
            )
        }

        Spacer(modifier = Modifier.width(16.dp))

        Column {
            Text(
                text = name,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = "ile en \u00E7ok payla\u015Ft\u0131n",
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.6f)
            )

            if (photoCount > 0) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "$photoCount an birlikte",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.4f)
                )
            }
        }
    }
}
