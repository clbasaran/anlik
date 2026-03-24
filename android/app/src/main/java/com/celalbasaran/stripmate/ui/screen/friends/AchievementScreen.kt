package com.celalbasaran.stripmate.ui.screen.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Tab
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.data.model.Achievement
import com.celalbasaran.stripmate.data.model.AchievementCategory
import com.celalbasaran.stripmate.data.model.UserAchievement
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.StreakOrange
import com.celalbasaran.stripmate.ui.theme.SuccessGreen
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import java.text.SimpleDateFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AchievementScreen(
    onBack: () -> Unit,
    viewModel: AchievementViewModel = hiltViewModel()
) {
    val unlockedAchievements by viewModel.unlockedAchievements.collectAsState()
    val progressMap by viewModel.progressMap.collectAsState()

    var selectedTab by remember { mutableIntStateOf(0) }
    val categories = AchievementCategory.entries.toList()
    val tabTitles = listOf("Fotoğraflar", "Streak'ler", "Sosyal", "Kaşif")

    val filteredAchievements = Achievement.ALL_ACHIEVEMENTS.filter {
        it.category == categories[selectedTab]
    }

    val dateFormat = remember { SimpleDateFormat("dd.MM.yyyy", Locale("tr")) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Basarimlar", fontWeight = FontWeight.Bold) },
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

        // Summary
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "\uD83C\uDFC5",
                fontSize = 24.sp
            )
            Spacer(modifier = Modifier.size(8.dp))
            Text(
                text = "${unlockedAchievements.size} / ${Achievement.ALL_ACHIEVEMENTS.size} basarim acildi",
                color = TextSecondary,
                fontSize = 14.sp
            )
        }

        // Category tabs
        ScrollableTabRow(
            selectedTabIndex = selectedTab,
            containerColor = PureBlack,
            contentColor = TextPrimary,
            edgePadding = 16.dp,
            indicator = { tabPositions ->
                SecondaryIndicator(
                    Modifier.tabIndicatorOffset(tabPositions[selectedTab]),
                    color = StripMateBlue
                )
            }
        ) {
            tabTitles.forEachIndexed { index, title ->
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

        // Achievement grid
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(filteredAchievements, key = { it.id }) { achievement ->
                val unlocked = unlockedAchievements.firstOrNull { it.achievementId == achievement.id }
                val progress = progressMap[achievement.id] ?: 0

                AchievementCard(
                    achievement = achievement,
                    unlockedAt = unlocked,
                    currentProgress = progress,
                    dateFormat = dateFormat
                )
            }
        }
    }
}

@Composable
private fun AchievementCard(
    achievement: Achievement,
    unlockedAt: UserAchievement?,
    currentProgress: Int,
    dateFormat: SimpleDateFormat
) {
    val isUnlocked = unlockedAt != null
    val progress = if (isUnlocked) 1f else (currentProgress.toFloat() / achievement.requirement).coerceIn(0f, 1f)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(if (isUnlocked) DarkSurface else DarkSurface.copy(alpha = 0.5f))
            .alpha(if (isUnlocked) 1f else 0.5f)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Emoji
        Text(
            text = achievement.emoji,
            fontSize = 36.sp,
            modifier = Modifier.alpha(if (isUnlocked) 1f else 0.3f)
        )

        Spacer(modifier = Modifier.height(8.dp))

        // Title
        Text(
            text = achievement.title,
            color = if (isUnlocked) TextPrimary else TextSecondary,
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        // Description
        Text(
            text = achievement.description,
            color = TextSecondary,
            fontSize = 11.sp,
            textAlign = TextAlign.Center,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )

        Spacer(modifier = Modifier.height(8.dp))

        if (isUnlocked) {
            // Unlock date
            Text(
                text = dateFormat.format(unlockedAt!!.unlockedAt),
                color = SuccessGreen,
                fontSize = 11.sp
            )
        } else {
            // Progress bar
            LinearProgressIndicator(
                progress = { progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = StreakOrange,
                trackColor = DarkSurfaceVariant
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "$currentProgress / ${achievement.requirement}",
                color = TextSecondary,
                fontSize = 10.sp
            )
        }
    }
}
