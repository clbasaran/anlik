package com.celalbasaran.stripmate.ui.screen.friends

import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.ExperimentalAnimationApi
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.CalendarToday
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Today
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import coil.request.ImageRequest
import androidx.compose.ui.platform.LocalContext
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.ui.theme.shimmerEffect
import kotlinx.coroutines.delay

private val tooltipExplanations = mapOf(
    "ilk foto" to "arkadaşlığınızın ilk fotoğrafı",
    "toplam foto" to "toplam paylaşılan foto sayısı",
    "en aktif gün" to "en çok foto paylaştığınız gün",
    "mevcut seri" to "aralıksız paylaşım serisi",
    "en uzun seri" to "en uzun foto serisi",
    "gönderilen" to "senin gönderdiğin",
    "alınan" to "arkadaşının gönderdiği"
)

@OptIn(ExperimentalMaterial3Api::class, ExperimentalAnimationApi::class)
@Composable
fun FriendshipProfileScreen(
    friendId: String,
    onBack: () -> Unit,
    onPhotoClick: (String) -> Unit = {},
    viewModel: FriendshipProfileViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val view = LocalView.current

    var appeared by remember { mutableStateOf(false) }
    var chartAppeared by remember { mutableStateOf(false) }
    var activeTooltip by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(friendId) {
        viewModel.loadFriendship(friendId)
    }

    LaunchedEffect(uiState.isLoading) {
        if (!uiState.isLoading) {
            appeared = true
        }
    }

    // Auto-dismiss tooltip
    LaunchedEffect(activeTooltip) {
        if (activeTooltip != null) {
            delay(2000)
            activeTooltip = null
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("arkadaşlık profili", fontWeight = FontWeight.Bold) },
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

        if (uiState.isLoading) {
            SkeletonLoading()
            return
        }

        val gridState = rememberLazyGridState()

        // Detect when we reach the end for pagination
        val shouldLoadMore by remember {
            derivedStateOf {
                val lastVisible = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                val totalItems = gridState.layoutInfo.totalItemsCount
                lastVisible >= totalItems - 4 && uiState.hasMorePhotos && !uiState.isLoadingMore
            }
        }

        LaunchedEffect(shouldLoadMore) {
            if (shouldLoadMore) {
                viewModel.loadMorePhotos()
            }
        }

        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            state = gridState,
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(2.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            // Header
            item(span = { GridItemSpan(3) }) {
                AnimatedVisibility(
                    visible = appeared,
                    enter = fadeIn(tween(400)) + slideInVertically(
                        initialOffsetY = { 40 },
                        animationSpec = spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessLow)
                    )
                ) {
                    AvatarHeader(
                        myAvatarUrl = uiState.myProfile?.avatarUrl,
                        friendAvatarUrl = uiState.friendProfile?.avatarUrl,
                        myName = uiState.myProfile?.displayName ?: "",
                        friendName = uiState.friendProfile?.displayName ?: ""
                    )
                }
            }

            item(span = { GridItemSpan(3) }) {
                Spacer(modifier = Modifier.height(20.dp))
            }

            // Stats cards
            item(span = { GridItemSpan(3) }) {
                AnimatedVisibility(
                    visible = appeared,
                    enter = fadeIn(tween(400, delayMillis = 100)) + slideInVertically(
                        initialOffsetY = { 40 },
                        animationSpec = spring(
                            dampingRatio = 0.7f,
                            stiffness = Spring.StiffnessLow
                        )
                    )
                ) {
                    StatsCardsRow(
                        stats = uiState.stats,
                        formatDate = viewModel::formatDate,
                        activeTooltip = activeTooltip,
                        onTooltipTap = { key ->
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            activeTooltip = key
                        }
                    )
                }
            }

            // Monthly activity chart
            item(span = { GridItemSpan(3) }) {
                Spacer(modifier = Modifier.height(20.dp))
            }

            item(span = { GridItemSpan(3) }) {
                AnimatedVisibility(
                    visible = appeared,
                    enter = fadeIn(tween(400, delayMillis = 200)) + slideInVertically(
                        initialOffsetY = { 40 },
                        animationSpec = spring(
                            dampingRatio = 0.7f,
                            stiffness = Spring.StiffnessLow
                        )
                    )
                ) {
                    MonthlyActivityChart(
                        monthlyData = uiState.stats.monthlyActivity,
                        chartAppeared = chartAppeared,
                        onAppeared = { chartAppeared = true }
                    )
                }
            }

            // Shared photos header
            item(span = { GridItemSpan(3) }) {
                Spacer(modifier = Modifier.height(20.dp))
            }

            item(span = { GridItemSpan(3) }) {
                AnimatedVisibility(
                    visible = appeared,
                    enter = fadeIn(tween(400, delayMillis = 300)) + slideInVertically(
                        initialOffsetY = { 40 },
                        animationSpec = spring(
                            dampingRatio = 0.7f,
                            stiffness = Spring.StiffnessLow
                        )
                    )
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "paylasilan anlar",
                            color = TextSecondary,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                        if (uiState.sharedPhotos.isNotEmpty()) {
                            Text(
                                text = uiState.sharedPhotos.size.toString(),
                                color = Color.White.copy(alpha = 0.35f),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }

            item(span = { GridItemSpan(3) }) {
                Spacer(modifier = Modifier.height(8.dp))
            }

            // Grid photos with pagination
            items(uiState.displayedPhotos) { strip ->
                val currentUserId = uiState.myProfile?.id ?: ""
                val locked = strip.isLockedFor(currentUserId)

                Box(
                    modifier = Modifier
                        .aspectRatio(1f)
                        .clip(RoundedCornerShape(4.dp))
                        .clickable {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            onPhotoClick(strip.id)
                        },
                    contentAlignment = Alignment.Center
                ) {
                    AsyncImage(
                        model = ImageRequest.Builder(LocalContext.current)
                            .data(strip.smallThumbnailUrl ?: strip.thumbnailUrl ?: strip.imageUrl)
                            .crossfade(true)
                            .build(),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxSize()
                            .then(
                                if (locked) Modifier.blur(30.dp) else Modifier
                            )
                    )

                    if (locked) {
                        Icon(
                            imageVector = Icons.Default.Lock,
                            contentDescription = null,
                            tint = Color.White.copy(alpha = 0.7f),
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }

            // Loading more indicator
            if (uiState.isLoadingMore) {
                item(span = { GridItemSpan(3) }) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(24.dp),
                            strokeWidth = 2.dp
                        )
                    }
                }
            }

            // Bottom spacing
            item(span = { GridItemSpan(3) }) {
                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

// MARK: - Skeleton Loading

@Composable
private fun SkeletonLoading() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp)
            .padding(top = 20.dp)
    ) {
        // Header skeleton
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(60.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f))
                    .shimmerEffect()
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(2.dp)
                    .padding(horizontal = 16.dp)
                    .background(Color.White.copy(alpha = 0.06f))
                    .shimmerEffect()
            )
            Box(
                modifier = Modifier
                    .size(60.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f))
                    .shimmerEffect()
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Stats skeleton
        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            items(4) {
                Box(
                    modifier = Modifier
                        .width(130.dp)
                        .height(90.dp)
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color.White.copy(alpha = 0.06f))
                        .shimmerEffect()
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Chart skeleton
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White.copy(alpha = 0.06f))
                .shimmerEffect()
        )

        Spacer(modifier = Modifier.height(24.dp))

        // Grid skeleton
        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            repeat(3) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .aspectRatio(1f)
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color.White.copy(alpha = 0.06f))
                        .shimmerEffect()
                )
            }
        }
        Spacer(modifier = Modifier.height(2.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            repeat(3) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .aspectRatio(1f)
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color.White.copy(alpha = 0.06f))
                        .shimmerEffect()
                )
            }
        }
        Spacer(modifier = Modifier.height(2.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            repeat(3) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .aspectRatio(1f)
                        .clip(RoundedCornerShape(4.dp))
                        .background(Color.White.copy(alpha = 0.06f))
                        .shimmerEffect()
                )
            }
        }
    }
}

// MARK: - Shimmer Effect (uses shared shimmerEffect from theme)

// MARK: - Avatar Header

@Composable
private fun AvatarHeader(
    myAvatarUrl: String?,
    friendAvatarUrl: String?,
    myName: String,
    friendName: String
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxWidth()
        ) {
            // My avatar
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (myAvatarUrl != null) {
                    AsyncImage(
                        model = ImageRequest.Builder(LocalContext.current)
                            .data(myAvatarUrl)
                            .crossfade(true)
                            .build(),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(64.dp)
                            .clip(CircleShape)
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .size(64.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.CameraAlt,
                            contentDescription = null,
                            tint = TextSecondary,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = myName,
                    color = TextPrimary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            // Gradient connection line
            Box(
                modifier = Modifier
                    .width(48.dp)
                    .height(2.dp)
                    .background(
                        brush = Brush.horizontalGradient(
                            colors = listOf(
                                Color.White.copy(alpha = 0.1f),
                                Color.White.copy(alpha = 0.35f),
                                Color.White.copy(alpha = 0.1f)
                            )
                        )
                    )
            )

            // Friend avatar
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                if (friendAvatarUrl != null) {
                    AsyncImage(
                        model = ImageRequest.Builder(LocalContext.current)
                            .data(friendAvatarUrl)
                            .crossfade(true)
                            .build(),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .size(64.dp)
                            .clip(CircleShape)
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .size(64.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.CameraAlt,
                            contentDescription = null,
                            tint = TextSecondary,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                }
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = friendName,
                    color = TextPrimary,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

// MARK: - Stats Cards Row

@OptIn(ExperimentalAnimationApi::class)
@Composable
private fun StatsCardsRow(
    stats: FriendshipStats,
    formatDate: (java.util.Date) -> String,
    activeTooltip: String?,
    onTooltipTap: (String) -> Unit
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        item {
            StatCard(
                label = "ilk foto",
                value = stats.firstPhotoDate?.let { formatDate(it) } ?: "-",
                icon = Icons.Default.CalendarToday,
                tooltipKey = "ilk foto",
                activeTooltip = activeTooltip,
                onTap = onTooltipTap
            )
        }
        item {
            StatCard(
                label = "toplam foto",
                value = stats.totalPhotos.toString(),
                icon = Icons.Default.CameraAlt,
                tooltipKey = "toplam foto",
                activeTooltip = activeTooltip,
                onTap = onTooltipTap
            )
        }
        item {
            StatCard(
                label = "gönderilen",
                value = stats.sentPhotos.toString(),
                icon = Icons.Default.ArrowUpward,
                tooltipKey = "gönderilen",
                activeTooltip = activeTooltip,
                onTap = onTooltipTap
            )
        }
        item {
            StatCard(
                label = "alınan",
                value = stats.receivedPhotos.toString(),
                icon = Icons.Default.ArrowDownward,
                tooltipKey = "alınan",
                activeTooltip = activeTooltip,
                onTap = onTooltipTap
            )
        }
        item {
            StatCard(
                label = "en aktif gün",
                value = stats.mostActiveDay,
                icon = Icons.Default.Today,
                tooltipKey = "en aktif gün",
                activeTooltip = activeTooltip,
                onTap = onTooltipTap
            )
        }
        item {
            StatCard(
                label = "mevcut seri",
                value = stats.currentStreak.toString(),
                icon = Icons.Default.LocalFireDepartment,
                tooltipKey = "mevcut seri",
                activeTooltip = activeTooltip,
                onTap = onTooltipTap
            )
        }
        item {
            StatCard(
                label = "en uzun seri",
                value = stats.longestStreak.toString(),
                icon = Icons.Default.Star,
                tooltipKey = "en uzun seri",
                activeTooltip = activeTooltip,
                onTap = onTooltipTap
            )
        }
    }
}

// MARK: - Stat Card

@OptIn(ExperimentalAnimationApi::class)
@Composable
private fun StatCard(
    label: String,
    value: String,
    icon: ImageVector,
    tooltipKey: String,
    activeTooltip: String?,
    onTap: (String) -> Unit
) {
    Box {
        Column(
            modifier = Modifier
                .width(130.dp)
                .background(
                    Color.White.copy(alpha = 0.05f),
                    RoundedCornerShape(16.dp)
                )
                .clickable(
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() }
                ) { onTap(tooltipKey) }
                .padding(16.dp),
            horizontalAlignment = Alignment.Start
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.4f),
                modifier = Modifier.size(16.dp)
            )
            Spacer(modifier = Modifier.height(10.dp))

            AnimatedContent(
                targetState = value,
                transitionSpec = {
                    (fadeIn(tween(300)) + slideInVertically { -it / 2 })
                        .togetherWith(fadeOut(tween(200)))
                },
                label = "counter"
            ) { targetValue ->
                Text(
                    text = targetValue,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = label.uppercase(),
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White.copy(alpha = 0.5f),
                letterSpacing = 0.5.sp
            )
        }

        // Tooltip popup
        AnimatedVisibility(
            visible = activeTooltip == tooltipKey,
            enter = fadeIn(tween(200)),
            exit = fadeOut(tween(200)),
            modifier = Modifier.align(Alignment.TopCenter)
        ) {
            val explanation = tooltipExplanations[tooltipKey] ?: ""
            Text(
                text = explanation,
                fontSize = 12.sp,
                color = Color.White,
                modifier = Modifier
                    .padding(bottom = 4.dp)
                    .background(
                        Color.White.copy(alpha = 0.15f),
                        RoundedCornerShape(50)
                    )
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            )
        }
    }
}

// MARK: - Monthly Activity Chart

@Composable
private fun MonthlyActivityChart(
    monthlyData: List<MonthlyCount>,
    chartAppeared: Boolean,
    onAppeared: () -> Unit
) {
    if (monthlyData.isEmpty()) return

    val maxCount = (monthlyData.maxOfOrNull { it.count } ?: 1).coerceAtLeast(1)

    LaunchedEffect(Unit) {
        onAppeared()
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Color.White.copy(alpha = 0.05f),
                RoundedCornerShape(16.dp)
            )
            .padding(16.dp)
    ) {
        Text(
            text = "aylik aktivite",
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White.copy(alpha = 0.5f)
        )

        Spacer(modifier = Modifier.height(16.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.Bottom
        ) {
            monthlyData.forEachIndexed { index, month ->
                val targetHeight: Dp = if (month.count > 0) {
                    (month.count.toFloat() / maxCount * 80).coerceAtLeast(4f).dp
                } else {
                    4.dp
                }

                val animatedHeight by animateDpAsState(
                    targetValue = if (chartAppeared) targetHeight else 4.dp,
                    animationSpec = tween(
                        durationMillis = 600,
                        delayMillis = index * 60,
                        easing = FastOutSlowInEasing
                    ),
                    label = "bar_$index"
                )

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Bottom,
                    modifier = Modifier.weight(1f)
                ) {
                    if (month.count > 0) {
                        Text(
                            text = month.count.toString(),
                            fontSize = 10.sp,
                            color = Color.White.copy(alpha = 0.6f),
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                    }

                    Box(
                        modifier = Modifier
                            .width(24.dp)
                            .height(animatedHeight)
                            .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                            .background(
                                if (month.count > 0) Color.White.copy(alpha = 0.6f)
                                else Color.White.copy(alpha = 0.1f)
                            )
                    )

                    Spacer(modifier = Modifier.height(6.dp))

                    Text(
                        text = month.monthLabel,
                        fontSize = 11.sp,
                        color = Color.White.copy(alpha = 0.5f),
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    }
}
