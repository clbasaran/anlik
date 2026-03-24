package com.celalbasaran.stripmate.ui.screen.streak

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.data.model.FriendshipTier
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.StreakOrange
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.ui.theme.TierKadim
import com.celalbasaran.stripmate.ui.theme.TierMuhabbet
import com.celalbasaran.stripmate.ui.theme.TierSirdas
import com.celalbasaran.stripmate.ui.theme.TierTanidik
import com.celalbasaran.stripmate.ui.theme.TierYakin
import com.celalbasaran.stripmate.util.TimeAgo

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StreakDetailScreen(
    onBack: () -> Unit,
    onMessage: (String) -> Unit,
    viewModel: StreakDetailViewModel = hiltViewModel()
) {
    val streak by viewModel.streak.collectAsState()
    val friendProfile by viewModel.friendProfile.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Seri Detayi") },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Geri",
                        tint = TextPrimary
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = PureBlack,
                titleContentColor = TextPrimary
            )
        )

        if (isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = StripMateBlue)
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(24.dp))

                // Friend avatar and name
                friendProfile?.let { profile ->
                    UserAvatar(
                        imageUrl = profile.avatarUrl,
                        displayName = profile.displayName,
                        size = 80.dp
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = profile.displayName ?: "Kullanici",
                        color = TextPrimary,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    )
                    profile.username?.let {
                        Text(
                            text = "@$it",
                            color = TextSecondary,
                            fontSize = 14.sp
                        )
                    }
                }

                Spacer(modifier = Modifier.height(32.dp))

                // Streak fire and count
                streak?.let { s ->
                    Text(
                        text = "\uD83D\uDD25",
                        fontSize = 64.sp
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "${s.currentStreak} gun",
                        color = TextPrimary,
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Black
                    )

                    if (s.isExpiringSoon) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "⚠️ Seri bitmek uzere!",
                            color = StreakOrange,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }

                    Spacer(modifier = Modifier.height(32.dp))

                    // Friendship tier
                    val tier = s.friendshipTier
                    val tierColor = when (tier) {
                        FriendshipTier.TANIDIK -> TierTanidik
                        FriendshipTier.MUHABBET -> TierMuhabbet
                        FriendshipTier.YAKIN -> TierYakin
                        FriendshipTier.SIRDAS -> TierSirdas
                        FriendshipTier.KADIM -> TierKadim
                    }

                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(DarkSurface, RoundedCornerShape(16.dp))
                            .padding(20.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = tier.tierIcon,
                                fontSize = 24.sp
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(
                                    text = tier.tierName,
                                    color = tierColor,
                                    fontSize = 18.sp,
                                    fontWeight = FontWeight.Bold
                                )
                                Text(
                                    text = "Arkadaslik seviyesi",
                                    color = TextSecondary,
                                    fontSize = 12.sp
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // Progress to next tier
                        if (tier != FriendshipTier.KADIM) {
                            LinearProgressIndicator(
                                progress = { s.tierProgress.toFloat() },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(6.dp)
                                    .clip(RoundedCornerShape(3.dp)),
                                color = tierColor,
                                trackColor = tierColor.copy(alpha = 0.15f)
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "Sonraki seviye: ${s.nextTierThreshold} puan",
                                color = TextSecondary,
                                fontSize = 12.sp
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))

                    // Stats
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(DarkSurface, RoundedCornerShape(16.dp))
                            .padding(20.dp)
                    ) {
                        Text(
                            text = "ISTATISTIKLER",
                            color = TextSecondary,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.SemiBold,
                            letterSpacing = 1.sp
                        )
                        Spacer(modifier = Modifier.height(16.dp))

                        StatRow("Mevcut seri", "${s.currentStreak} gun")
                        HorizontalDivider(
                            color = TextSecondary.copy(alpha = 0.1f),
                            modifier = Modifier.padding(vertical = 12.dp)
                        )
                        StatRow("En uzun seri", "${s.longestStreak} gun")
                        HorizontalDivider(
                            color = TextSecondary.copy(alpha = 0.1f),
                            modifier = Modifier.padding(vertical = 12.dp)
                        )
                        StatRow("Toplam paylasim", "${s.totalExchanges}")
                        HorizontalDivider(
                            color = TextSecondary.copy(alpha = 0.1f),
                            modifier = Modifier.padding(vertical = 12.dp)
                        )
                        StatRow("Arkadaslik puani", "${s.friendshipScore}")
                        HorizontalDivider(
                            color = TextSecondary.copy(alpha = 0.1f),
                            modifier = Modifier.padding(vertical = 12.dp)
                        )
                        StatRow("Son paylasim", TimeAgo.formatLong(s.lastExchangeDate))
                    }

                    Spacer(modifier = Modifier.height(32.dp))
                }
            }
        }
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            color = TextSecondary,
            fontSize = 14.sp
        )
        Text(
            text = value,
            color = TextPrimary,
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}
