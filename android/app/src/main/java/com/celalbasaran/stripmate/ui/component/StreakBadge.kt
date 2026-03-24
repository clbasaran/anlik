package com.celalbasaran.stripmate.ui.component

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.data.model.FriendshipTier
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.StreakOrange
import com.celalbasaran.stripmate.ui.theme.StreakRed
import com.celalbasaran.stripmate.ui.theme.TierKadim
import com.celalbasaran.stripmate.ui.theme.TierMuhabbet
import com.celalbasaran.stripmate.ui.theme.TierSirdas
import com.celalbasaran.stripmate.ui.theme.TierTanidik
import com.celalbasaran.stripmate.ui.theme.TierYakin

@Composable
fun StreakBadge(
    streakCount: Int,
    tier: FriendshipTier? = null,
    modifier: Modifier = Modifier
) {
    val color = when (tier) {
        FriendshipTier.TANIDIK -> TierTanidik
        FriendshipTier.MUHABBET -> TierMuhabbet
        FriendshipTier.YAKIN -> TierYakin
        FriendshipTier.SIRDAS -> TierSirdas
        FriendshipTier.KADIM -> TierKadim
        null -> when {
            streakCount >= 100 -> StreakRed
            streakCount >= 30 -> StreakOrange
            streakCount >= 7 -> Color(0xFFFFCC00)
            else -> Color(0xFF8E8E93)
        }
    }

    Row(
        modifier = modifier
            .background(
                color = DarkSurfaceVariant,
                shape = RoundedCornerShape(12.dp)
            )
            .padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "\uD83D\uDD25",
            fontSize = 14.sp
        )
        Spacer(modifier = Modifier.width(4.dp))
        Text(
            text = streakCount.toString(),
            color = color,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold
        )
    }
}
