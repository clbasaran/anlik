package com.celalbasaran.stripmate.ui.screen.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Photo
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
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SharedMomentsScreen(
    userId: String,
    onBack: () -> Unit,
    onPhotoClick: (String) -> Unit,
    viewModel: SharedMomentsViewModel = hiltViewModel()
) {
    val sharedPhotos by viewModel.sharedPhotos.collectAsState()
    val friendProfile by viewModel.friendProfile.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    LaunchedEffect(userId) {
        viewModel.loadSharedPhotos(userId)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        // Top bar
        TopAppBar(
            title = {
                Text(
                    text = "Ortak Album",
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp
                )
            },
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
                CircularProgressIndicator(
                    color = TextPrimary.copy(alpha = 0.4f),
                    modifier = Modifier.size(32.dp),
                    strokeWidth = 2.dp
                )
            }
        } else if (sharedPhotos.isEmpty()) {
            // Empty state
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Default.Image,
                        contentDescription = "foto yok",
                        tint = TextPrimary.copy(alpha = 0.4f),
                        modifier = Modifier.size(36.dp)
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = "Henuz ortak foto yok",
                        color = TextPrimary.copy(alpha = 0.4f),
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        } else {
            val monthGroups = viewModel.groupedByMonth()
            val friendshipDuration = viewModel.friendshipDuration()

            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                // Header section (full span)
                item(span = { GridItemSpan(3) }) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 8.dp, bottom = 16.dp)
                    ) {
                        // Friend name
                        Text(
                            text = friendProfile?.displayName ?: "",
                            color = TextPrimary,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold
                        )

                        Spacer(modifier = Modifier.height(6.dp))

                        // Stats row: photo count + friendship duration
                        Row(
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = Icons.Default.Photo,
                                contentDescription = null,
                                tint = TextPrimary.copy(alpha = 0.4f),
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(4.dp))
                            Text(
                                text = "${sharedPhotos.size} foto",
                                color = TextPrimary.copy(alpha = 0.4f),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Medium
                            )

                            friendshipDuration?.let { duration ->
                                Spacer(modifier = Modifier.width(16.dp))
                                Icon(
                                    imageVector = Icons.Default.AccessTime,
                                    contentDescription = null,
                                    tint = TextPrimary.copy(alpha = 0.4f),
                                    modifier = Modifier.size(14.dp)
                                )
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = duration,
                                    color = TextPrimary.copy(alpha = 0.4f),
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            }
                        }
                    }
                }

                // Memory highlights: first & last photo
                if (sharedPhotos.size > 1) {
                    item(span = { GridItemSpan(3) }) {
                        Column(modifier = Modifier.padding(bottom = 20.dp)) {
                            Text(
                                text = "Anlar",
                                color = TextPrimary.copy(alpha = 0.5f),
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(modifier = Modifier.height(10.dp))

                            val sorted = sharedPhotos.sortedBy { it.timestamp }
                            val first = sorted.first()
                            val last = sorted.last()

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                MemoryCard(
                                    strip = first,
                                    label = "Ilk foto",
                                    modifier = Modifier.weight(1f),
                                    onClick = { onPhotoClick(first.id) }
                                )
                                MemoryCard(
                                    strip = last,
                                    label = "En son",
                                    modifier = Modifier.weight(1f),
                                    onClick = { onPhotoClick(last.id) }
                                )
                            }
                        }
                    }
                }

                // Month groups
                monthGroups.forEach { group ->
                    // Month header (full span)
                    item(span = { GridItemSpan(3) }) {
                        Text(
                            text = formatMonthYear(group.year, group.month),
                            color = TextPrimary.copy(alpha = 0.5f),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            modifier = Modifier.padding(top = 16.dp, bottom = 10.dp)
                        )
                    }

                    // Photos in this month
                    items(group.strips, key = { it.id }) { strip ->
                        AsyncImage(
                            model = strip.smallThumbnailUrl ?: strip.thumbnailUrl ?: strip.imageUrl,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .aspectRatio(1f)
                                .clip(RoundedCornerShape(6.dp))
                                .clickable { onPhotoClick(strip.id) }
                        )
                    }
                }

                // Bottom spacing
                item(span = { GridItemSpan(3) }) {
                    Spacer(modifier = Modifier.height(32.dp))
                }
            }
        }
    }
}

@Composable
private fun MemoryCard(
    strip: com.celalbasaran.stripmate.data.model.Strip,
    label: String,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    val dateFormatter = SimpleDateFormat("d MMM yyyy", Locale("tr"))

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.clickable(onClick = onClick)
    ) {
        AsyncImage(
            model = strip.smallThumbnailUrl ?: strip.thumbnailUrl ?: strip.imageUrl,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White.copy(alpha = 0.06f))
        )

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = label,
            color = TextPrimary.copy(alpha = 0.7f),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold
        )
        Text(
            text = dateFormatter.format(strip.timestamp),
            color = TextPrimary.copy(alpha = 0.35f),
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

/** Format month+year in Turkish: "Mart 2026" */
private fun formatMonthYear(year: Int, month: Int): String {
    val calendar = Calendar.getInstance().apply {
        set(Calendar.YEAR, year)
        set(Calendar.MONTH, month)
        set(Calendar.DAY_OF_MONTH, 1)
    }
    val formatter = SimpleDateFormat("LLLL yyyy", Locale("tr"))
    val result = formatter.format(calendar.time)
    // Capitalize first letter
    return result.replaceFirstChar { it.uppercase() }
}
