package com.celalbasaran.stripmate.ui.screen.profile

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.PersonRemove
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.celalbasaran.stripmate.data.model.FriendshipTier
import com.celalbasaran.stripmate.ui.component.EmptyState
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.ErrorRed
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendProfileScreen(
    userId: String,
    onBack: () -> Unit,
    onMessage: (String) -> Unit,
    onPhotoClick: (String) -> Unit,
    viewModel: FriendProfileViewModel = hiltViewModel()
) {
    val profile by viewModel.profile.collectAsState()
    val streak by viewModel.streak.collectAsState()
    val sharedPhotos by viewModel.sharedPhotos.collectAsState()

    var showRemoveDialog by remember { mutableStateOf(false) }

    LaunchedEffect(userId) {
        viewModel.loadProfile(userId)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Profil") },
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

        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(2.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            // Profile header (full span)
            item(span = { GridItemSpan(3) }) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Spacer(modifier = Modifier.height(16.dp))

                    // Avatar
                    UserAvatar(
                        imageUrl = profile?.avatarUrl,
                        displayName = profile?.displayName,
                        size = 96.dp
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    // Name + status emoji
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = profile?.displayName ?: "",
                            color = TextPrimary,
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold
                        )
                        profile?.statusEmoji?.let { emoji ->
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(text = emoji, fontSize = 20.sp)
                        }
                    }

                    // Username
                    profile?.username?.let { username ->
                        Text(
                            text = "@$username",
                            color = TextPrimary.copy(alpha = 0.35f),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }

                    // Bio
                    profile?.bio?.let { bio ->
                        if (bio.isNotBlank()) {
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = bio,
                                color = TextPrimary.copy(alpha = 0.55f),
                                fontSize = 14.sp,
                                textAlign = TextAlign.Center,
                                maxLines = 3,
                                modifier = Modifier.padding(horizontal = 12.dp)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(28.dp))

                    // Streak stat pills (iOS style: 3 pills in a row)
                    streak?.let { streakData ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            StatPill(
                                value = "${streakData.currentStreak}",
                                label = "gunluk seri",
                                icon = Icons.Default.AutoAwesome,
                                modifier = Modifier.weight(1f)
                            )
                            StatPill(
                                value = "${streakData.longestStreak}",
                                label = "en uzun seri",
                                icon = Icons.Default.EmojiEvents,
                                modifier = Modifier.weight(1f)
                            )
                            StatPill(
                                value = "${streakData.totalExchanges}",
                                label = "toplam an",
                                icon = Icons.Default.CameraAlt,
                                modifier = Modifier.weight(1f)
                            )
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // Tier badge (iOS style: capsule)
                        TierBadgeCapsule(tier = streakData.friendshipTier)

                        Spacer(modifier = Modifier.height(28.dp))
                    }

                    // Shared photos section header (iOS style: uppercase label + count)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 14.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = "BIRLIKTE PAYLASILAN ANLAR",
                            color = TextPrimary.copy(alpha = 0.45f),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 1.sp
                        )
                        Text(
                            text = "${sharedPhotos.size}",
                            color = TextPrimary.copy(alpha = 0.3f),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }

            // Shared photos grid (3 columns matching iOS)
            if (sharedPhotos.isEmpty()) {
                item(span = { GridItemSpan(3) }) {
                    EmptyState(
                        icon = "\uD83D\uDCF7",
                        message = "Henüz paylaşılmış an yok"
                    )
                }
            } else {
                items(sharedPhotos.take(30), key = { it.id }) { strip ->
                    AsyncImage(
                        model = strip.thumbnailUrl ?: strip.imageUrl,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .aspectRatio(1f)
                            .clip(RoundedCornerShape(2.dp))
                            .clickable { onPhotoClick(strip.id) }
                    )
                }
            }

            // Remove friend button (iOS style: red capsule at bottom)
            item(span = { GridItemSpan(3) }) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 24.dp, bottom = 120.dp)
                ) {
                    OutlinedButton(
                        onClick = { showRemoveDialog = true },
                        shape = RoundedCornerShape(50),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = ErrorRed.copy(alpha = 0.08f)
                        ),
                        border = BorderStroke(
                            0.5.dp,
                            ErrorRed.copy(alpha = 0.15f)
                        )
                    ) {
                        Icon(
                            Icons.Default.PersonRemove,
                            contentDescription = null,
                            tint = ErrorRed.copy(alpha = 0.8f),
                            modifier = Modifier.size(14.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            "Arkadaşlıktan çıkar",
                            color = ErrorRed.copy(alpha = 0.8f),
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }
    }

    // Remove friend dialog
    if (showRemoveDialog) {
        AlertDialog(
            onDismissRequest = { showRemoveDialog = false },
            title = { Text("Arkadaşı çıkar", color = TextPrimary) },
            text = {
                Text(
                    "${profile?.displayName ?: "Bu kişiyi"} arkadaş listenden çıkarmak istediğin kesin mi?",
                    color = TextSecondary
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.removeFriend(userId)
                        showRemoveDialog = false
                        onBack()
                    }
                ) {
                    Text("Cikar", color = ErrorRed)
                }
            },
            dismissButton = {
                TextButton(onClick = { showRemoveDialog = false }) {
                    Text("Vazgec", color = TextSecondary)
                }
            },
            containerColor = DarkSurface
        )
    }

}

/**
 * iOS-style stat pill: icon + large value + small label, in a rounded rect card.
 */
@Composable
private fun StatPill(
    value: String,
    label: String,
    icon: ImageVector,
    modifier: Modifier = Modifier
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
            .background(
                Color.White.copy(alpha = 0.04f),
                RoundedCornerShape(16.dp)
            )
            .border(
                0.5.dp,
                Color.White.copy(alpha = 0.06f),
                RoundedCornerShape(16.dp)
            )
            .padding(vertical = 16.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = TextPrimary.copy(alpha = 0.6f),
            modifier = Modifier.size(18.dp)
        )
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = value,
            color = TextPrimary,
            fontSize = 22.sp,
            fontWeight = FontWeight.ExtraBold
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            color = TextPrimary.copy(alpha = 0.35f),
            fontSize = 10.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center
        )
    }
}

/**
 * iOS-style tier badge capsule: icon + tier name in a rounded pill.
 */
@Composable
private fun TierBadgeCapsule(tier: FriendshipTier) {
    val tierIcon = when (tier) {
        FriendshipTier.TANIDIK -> Icons.Default.Star
        FriendshipTier.MUHABBET -> Icons.Default.Star
        FriendshipTier.YAKIN -> Icons.Default.Star
        FriendshipTier.SIRDAS -> Icons.Default.Star
        FriendshipTier.KADIM -> Icons.Default.Star
    }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(
                Color.White.copy(alpha = 0.06f),
                RoundedCornerShape(50)
            )
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Icon(
            imageVector = tierIcon,
            contentDescription = null,
            tint = TextPrimary,
            modifier = Modifier.size(14.dp)
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = tier.tierName,
            color = TextPrimary.copy(alpha = 0.7f),
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}
