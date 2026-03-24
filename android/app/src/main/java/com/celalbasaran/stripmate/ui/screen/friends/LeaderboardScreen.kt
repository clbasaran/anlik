package com.celalbasaran.stripmate.ui.screen.friends

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.TabRowDefaults.SecondaryIndicator
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.ui.component.EmptyState
import com.celalbasaran.stripmate.ui.component.StreakBadge
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

data class LeaderboardEntry(
    val userId: String,
    val displayName: String,
    val avatarUrl: String?,
    val streakCount: Int,
    val exchangeCount: Int,
    val friendshipTier: com.celalbasaran.stripmate.data.model.FriendshipTier,
    val isCurrentUser: Boolean
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LeaderboardScreen(
    onBack: () -> Unit,
    viewModel: LeaderboardViewModel = hiltViewModel()
) {
    val entries by viewModel.entries.collectAsState()
    var selectedTab by remember { mutableIntStateOf(0) }
    val tabs = listOf("Seri", "Degisim")

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Lider Tablosu", fontWeight = FontWeight.Bold) },
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

        // Tab row
        TabRow(
            selectedTabIndex = selectedTab,
            containerColor = DarkSurface,
            contentColor = TextPrimary,
            indicator = { tabPositions ->
                SecondaryIndicator(
                    Modifier.tabIndicatorOffset(tabPositions[selectedTab]),
                    color = StripMateBlue
                )
            }
        ) {
            tabs.forEachIndexed { index, title ->
                Tab(
                    selected = selectedTab == index,
                    onClick = { selectedTab = index },
                    text = {
                        Text(
                            text = title,
                            color = if (selectedTab == index) TextPrimary else TextSecondary,
                            fontWeight = if (selectedTab == index) FontWeight.SemiBold else FontWeight.Normal
                        )
                    }
                )
            }
        }

        val sortedEntries = when (selectedTab) {
            0 -> entries.sortedByDescending { it.streakCount }
            else -> entries.sortedByDescending { it.exchangeCount }
        }

        if (sortedEntries.isEmpty()) {
            EmptyState(
                icon = "\uD83C\uDFC6",
                message = "Henüz lider tablosu oluşturulmadı.\nArkadaş ekle ve fotoğraf paylaşarak başla!",
                modifier = Modifier
                    .fillMaxSize()
                    .padding(top = 80.dp)
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                itemsIndexed(sortedEntries) { index, entry ->
                    LeaderboardRow(
                        rank = index + 1,
                        entry = entry,
                        value = if (selectedTab == 0) entry.streakCount else entry.exchangeCount,
                        isStreakTab = selectedTab == 0
                    )
                }
            }
        }
    }
}

@Composable
private fun LeaderboardRow(
    rank: Int,
    entry: LeaderboardEntry,
    value: Int,
    isStreakTab: Boolean
) {
    val medalEmoji = when (rank) {
        1 -> "\uD83E\uDD47"
        2 -> "\uD83E\uDD48"
        3 -> "\uD83E\uDD49"
        else -> null
    }

    val bgColor = if (entry.isCurrentUser) StripMateBlue.copy(alpha = 0.1f) else DarkSurface
    val borderColor = if (entry.isCurrentUser) StripMateBlue.copy(alpha = 0.3f) else Color.Transparent

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Rank
        Box(
            modifier = Modifier.width(36.dp),
            contentAlignment = Alignment.Center
        ) {
            if (medalEmoji != null) {
                Text(text = medalEmoji, fontSize = 22.sp)
            } else {
                Text(
                    text = "#$rank",
                    color = TextSecondary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Avatar
        UserAvatar(
            imageUrl = entry.avatarUrl,
            displayName = entry.displayName,
            size = 40.dp
        )

        Spacer(modifier = Modifier.width(12.dp))

        // Name + tier
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = entry.displayName,
                    color = TextPrimary,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.SemiBold
                )
                if (entry.isCurrentUser) {
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "(Sen)",
                        color = StripMateBlue,
                        fontSize = 12.sp
                    )
                }
            }
            Text(
                text = entry.friendshipTier.tierName,
                color = TextSecondary,
                fontSize = 12.sp
            )
        }

        // Value
        if (isStreakTab) {
            StreakBadge(
                streakCount = value,
                tier = entry.friendshipTier
            )
        } else {
            Text(
                text = "$value",
                color = TextPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
