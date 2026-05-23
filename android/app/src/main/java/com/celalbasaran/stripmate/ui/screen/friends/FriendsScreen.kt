package com.celalbasaran.stripmate.ui.screen.friends

import android.content.Intent
import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Contacts
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.QuestionAnswer
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.R
import com.celalbasaran.stripmate.data.model.Friend
import com.celalbasaran.stripmate.data.model.FriendshipTier
import com.celalbasaran.stripmate.data.model.Streak
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.shimmerEffect
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
fun FriendsScreen(
    onFriendClick: (String) -> Unit,
    onQRClick: () -> Unit,
    onInboxClick: () -> Unit,
    onSettingsClick: () -> Unit = {},
    onSupportClick: () -> Unit = {},
    onContactSyncClick: () -> Unit = {},
    viewModel: FriendsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val clipboardManager = LocalClipboardManager.current
    val context = LocalContext.current
    val view = LocalView.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        when {
            uiState.isLoading && uiState.friends.isEmpty() -> {
                // Skeleton loading
                Column(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp, vertical = 16.dp)
                ) {
                    // Skeleton header
                    SkeletonProfileHero()
                    Spacer(modifier = Modifier.height(16.dp))
                    repeat(5) {
                        SkeletonFriendRow()
                        Spacer(modifier = Modifier.height(10.dp))
                    }
                }
            }

            else -> {
                PullToRefreshBox(
                    isRefreshing = uiState.isRefreshing,
                    onRefresh = { viewModel.refresh() },
                    modifier = Modifier.fillMaxSize()
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(bottom = 120.dp)
                    ) {
                        // ── Profile Hero Header ──
                        item {
                            ProfileHeroHeader(
                                uiState = uiState,
                                onProfileClick = {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    onSettingsClick()
                                },
                                onShareCode = { code ->
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    val shareText = "anlık.'ta beni ekle!\n\nDavet kodum: $code"
                                    val sendIntent = Intent().apply {
                                        action = Intent.ACTION_SEND
                                        putExtra(Intent.EXTRA_TEXT, shareText)
                                        type = "text/plain"
                                    }
                                    context.startActivity(Intent.createChooser(sendIntent, null))
                                },
                                onQRClick = {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    onQRClick()
                                },
                                onSupportClick = {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    onSupportClick()
                                },
                                onContactSyncClick = {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    onContactSyncClick()
                                }
                            )
                        }

                        // ── Search Section ──
                        item {
                            SearchSection(
                                searchCode = uiState.searchCode,
                                isSearching = uiState.isSearching,
                                searchError = uiState.searchError,
                                searchedProfile = uiState.searchedProfile,
                                onSearchCodeChange = { viewModel.updateSearchCode(it) },
                                onSearch = {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    viewModel.searchByCode()
                                },
                                onSendRequest = {
                                    view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                                    viewModel.sendRequest(it)
                                }
                            )
                        }

                        // Separator
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(horizontal = 40.dp, vertical = 12.dp)
                                    .height(0.5.dp)
                                    .background(Color.White.copy(alpha = 0.06f))
                            )
                        }

                        // ── Incoming Requests ──
                        if (uiState.pendingRequests.isNotEmpty()) {
                            item {
                                SectionHeader(
                                    title = "gelen istekler · ${uiState.pendingRequests.size}"
                                )
                            }

                            items(
                                items = uiState.pendingRequests,
                                key = { "pending_${it.userId}" }
                            ) { request ->
                                FriendCard(
                                    friend = request,
                                    streak = null,
                                    currentUserId = uiState.currentUserId,
                                    onAccept = {
                                        view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                                        viewModel.acceptRequest(request.userId)
                                    },
                                    onDecline = {
                                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                        viewModel.declineRequest(request.userId)
                                    },
                                    onRemove = {
                                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                        viewModel.removeFriend(request.userId)
                                    },
                                    onClick = {
                                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                        onFriendClick(request.userId)
                                    }
                                )
                            }

                            // Separator
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(horizontal = 40.dp, vertical = 12.dp)
                                        .height(0.5.dp)
                                        .background(Color.White.copy(alpha = 0.06f))
                                )
                            }
                        }

                        // ── Friends Header ──
                        item {
                            SectionHeader(
                                title = "arkadaşların · ${uiState.friends.size}"
                            )
                        }

                        // ── Name Filter (3+ friends) ──
                        if (uiState.friends.size >= 3) {
                            item {
                                NameFilter(
                                    filter = uiState.friendFilter,
                                    onFilterChange = { viewModel.updateFriendFilter(it) }
                                )
                            }
                        }

                        // ── Friends List ──
                        // Filter + sort favorites to the top so high-touch friends
                        // are always at the head of long lists.
                        val filteredFriends = run {
                            val base = if (uiState.friendFilter.isBlank()) {
                                uiState.friends
                            } else {
                                uiState.friends.filter { friend ->
                                    val name = (friend.profile?.displayName ?: friend.profile?.username ?: "").lowercase()
                                    name.contains(uiState.friendFilter.trim().lowercase())
                                }
                            }
                            base.sortedWith(compareByDescending<com.celalbasaran.stripmate.data.model.Friend> { it.isFavorite }
                                .thenByDescending { it.timestamp })
                        }

                        if (filteredFriends.isEmpty() && uiState.outgoingRequests.isEmpty()) {
                            if (uiState.friendFilter.isNotBlank()) {
                                item {
                                    Text(
                                        text = stringResource(R.string.friends_search_empty),
                                        color = Color.White.copy(alpha = 0.4f),
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Medium,
                                        textAlign = TextAlign.Center,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(top = 16.dp)
                                    )
                                }
                            } else {
                                item {
                                    EmptyFriendsState()
                                }
                            }
                        } else {
                            items(
                                items = filteredFriends,
                                key = { it.userId }
                            ) { friend ->
                                FriendCard(
                                    friend = friend,
                                    streak = uiState.streaks[friend.userId],
                                    currentUserId = uiState.currentUserId,
                                    onAccept = null,
                                    onDecline = null,
                                    onRemove = null,
                                    onClick = {
                                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                        onFriendClick(friend.userId)
                                    },
                                    onToggleFavorite = { f ->
                                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                        viewModel.toggleFavorite(f.userId, f.isFavorite)
                                    }
                                )
                            }

                            // Outgoing requests
                            items(
                                items = uiState.outgoingRequests,
                                key = { "outgoing_${it.userId}" }
                            ) { friend ->
                                FriendCard(
                                    friend = friend,
                                    streak = null,
                                    currentUserId = uiState.currentUserId,
                                    onAccept = null,
                                    onDecline = null,
                                    onRemove = {
                                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                        viewModel.removeFriend(friend.userId)
                                    },
                                    onClick = {}
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// ── Profile Hero Header (matches iOS header) ──

@Composable
private fun ProfileHeroHeader(
    uiState: FriendsUiState,
    onProfileClick: () -> Unit,
    onShareCode: (String) -> Unit,
    onQRClick: () -> Unit,
    onSupportClick: () -> Unit,
    onContactSyncClick: () -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(top = 8.dp, bottom = 8.dp)
    ) {
        // Profile hero card
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Color.White.copy(alpha = 0.05f))
                .clickable { onProfileClick() }
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Avatar
            UserAvatar(
                imageUrl = uiState.currentProfile?.avatarUrl,
                displayName = uiState.currentProfile?.displayName ?: "?",
                size = 56.dp
            )

            Spacer(modifier = Modifier.width(14.dp))

            // Name + username
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = uiState.currentProfile?.displayName ?: "yükleniyor...",
                    color = Color.White,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1
                )
                uiState.currentProfile?.username?.let { username ->
                    if (username.isNotEmpty()) {
                        Text(
                            text = "@$username",
                            color = Color.White.copy(alpha = 0.4f),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            maxLines = 1
                        )
                    }
                }
            }

            // Stats
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                val activeFriendCount = uiState.friends.size
                val activeStreakCount = uiState.streaks.values.count { it.currentStreak > 0 }

                StatPill(value = "$activeFriendCount", label = "arkadaş")
                StatPill(value = "$activeStreakCount", label = "seri")
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Action row: share code + QR + support
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // Share invite code button
            val code = uiState.myInviteCode
            if (code.isNotEmpty()) {
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(50))
                        .background(Color.White.copy(alpha = 0.08f))
                        .clickable { onShareCode(code) }
                        .padding(horizontal = 14.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.Share,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.6f),
                        modifier = Modifier.size(11.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = code,
                        color = Color.White.copy(alpha = 0.6f),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        fontFamily = FontFamily.Monospace
                    )
                }
            }

            // QR button
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f))
                    .clickable { onQRClick() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.QrCode,
                    contentDescription = "QR",
                    tint = Color.White.copy(alpha = 0.6f),
                    modifier = Modifier.size(14.dp)
                )
            }

            // Support chat button
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f))
                    .clickable { onSupportClick() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.QuestionAnswer,
                    contentDescription = "Destek",
                    tint = Color.White.copy(alpha = 0.6f),
                    modifier = Modifier.size(14.dp)
                )
            }

            // Contact sync button
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.08f))
                    .clickable { onContactSyncClick() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Contacts,
                    contentDescription = "Rehberden Bul",
                    tint = Color.White.copy(alpha = 0.6f),
                    modifier = Modifier.size(14.dp)
                )
            }

        }
    }
}

@Composable
private fun StatPill(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.35f),
            fontSize = 10.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

// ── Search Section (matches iOS) ──

@Composable
private fun SearchSection(
    searchCode: String,
    isSearching: Boolean,
    searchError: String?,
    searchedProfile: com.celalbasaran.stripmate.data.model.UserProfile?,
    onSearchCodeChange: (String) -> Unit,
    onSearch: () -> Unit,
    onSendRequest: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
    ) {
        // Section title
        Text(
            text = stringResource(R.string.friends_search_title),
            color = Color.White.copy(alpha = 0.5f),
            fontSize = 13.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.sp,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
        )

        Spacer(modifier = Modifier.height(8.dp))

        // Search field - capsule style like iOS
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(50))
                .background(Color.White.copy(alpha = 0.08f))
                .padding(horizontal = 18.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            BasicTextField(
                value = searchCode,
                onValueChange = onSearchCodeChange,
                textStyle = TextStyle(
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold
                ),
                cursorBrush = SolidColor(Color.White),
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    imeAction = ImeAction.Search
                ),
                keyboardActions = KeyboardActions(
                    onSearch = { onSearch() }
                ),
                modifier = Modifier.weight(1f),
                decorationBox = { innerTextField ->
                    Box {
                        if (searchCode.isEmpty()) {
                            Text(
                                text = stringResource(R.string.friends_search_hint),
                                color = Color.White.copy(alpha = 0.3f),
                                fontSize = 16.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                        innerTextField()
                    }
                }
            )

            Spacer(modifier = Modifier.width(8.dp))

            if (isSearching) {
                CircularProgressIndicator(
                    color = Color.White,
                    modifier = Modifier.size(18.dp),
                    strokeWidth = 2.dp
                )
            } else {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = "Ara",
                    tint = Color.White.copy(alpha = 0.4f),
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        // Error
        if (searchError != null) {
            Text(
                text = searchError,
                color = Color.White.copy(alpha = 0.5f),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
            )
        }

        // Search result card
        AnimatedVisibility(
            visible = searchedProfile != null,
            enter = scaleIn(initialScale = 0.95f) + fadeIn()
        ) {
            searchedProfile?.let { profile ->
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color.White.copy(alpha = 0.04f))
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Avatar placeholder with initial
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.08f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = (profile.displayName?.firstOrNull() ?: '?').uppercase(),
                            color = Color.White,
                            fontSize = 17.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    Spacer(modifier = Modifier.width(12.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = profile.displayName ?: stringResource(R.string.friends_profile_fallback),
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                        Text(
                            text = profile.inviteCode ?: "",
                            color = Color.White.copy(alpha = 0.4f),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            fontFamily = FontFamily.Monospace
                        )
                    }

                    // Add button
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(Color.White)
                            .clickable { onSendRequest(profile.id) }
                            .padding(horizontal = 20.dp, vertical = 9.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.friends_add_cta),
                            color = Color.Black,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }
    }
}

// ── Section Header ──

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title.uppercase(),
        color = Color.White.copy(alpha = 0.5f),
        fontSize = 13.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = 1.sp,
        modifier = Modifier.padding(horizontal = 28.dp, vertical = 8.dp)
    )
}

// ── Name Filter ──

@Composable
private fun NameFilter(
    filter: String,
    onFilterChange: (String) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.Search,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.4f),
            modifier = Modifier.size(13.dp)
        )
        Spacer(modifier = Modifier.width(8.dp))
        BasicTextField(
            value = filter,
            onValueChange = onFilterChange,
            textStyle = TextStyle(
                color = Color.White,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium
            ),
            cursorBrush = SolidColor(Color.White),
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            decorationBox = { innerTextField ->
                Box {
                    if (filter.isEmpty()) {
                        Text(
                            text = stringResource(R.string.friends_filter_hint),
                            color = Color.White.copy(alpha = 0.3f),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    innerTextField()
                }
            }
        )
    }
}

// ── Friend Card (matches iOS friendCard) ──

@Composable
private fun FriendCard(
    friend: Friend,
    streak: Streak?,
    currentUserId: String?,
    onAccept: (() -> Unit)?,
    onDecline: (() -> Unit)?,
    onRemove: (() -> Unit)?,
    onClick: () -> Unit,
    onToggleFavorite: ((Friend) -> Unit)? = null
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp, vertical = 5.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.04f))
            .clickable(enabled = !friend.isPending) { onClick() }
            .padding(14.dp)
    ) {
        // Header row: avatar + name + actions
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            UserAvatar(
                imageUrl = friend.profile?.avatarUrl,
                displayName = friend.profile?.displayName ?: friend.userId,
                size = 44.dp
            )

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = friend.profile?.displayName ?: friend.profile?.username ?: stringResource(R.string.isimsiz),
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 1
                    )
                    if (friend.isFavorite) {
                        Spacer(modifier = Modifier.width(5.dp))
                        Icon(
                            imageVector = Icons.Default.Star,
                            contentDescription = null,
                            tint = Color(0xFFFFD60A),
                            modifier = Modifier.size(13.dp)
                        )
                    }
                }

                if (friend.isPending) {
                    val isIncoming = friend.requesterId != null && friend.requesterId != currentUserId
                    Text(
                        text = if (isIncoming) stringResource(R.string.friends_pending_incoming) else stringResource(R.string.friends_pending_outgoing),
                        color = Color.White.copy(alpha = 0.4f),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            // Actions
            if (friend.isPending) {
                val isIncoming = friend.requesterId != null && friend.requesterId != currentUserId
                if (isIncoming) {
                    // Accept + decline
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(Color.White)
                                .clickable { onAccept?.invoke() }
                                .padding(horizontal = 16.dp, vertical = 8.dp)
                        ) {
                            Text(
                                text = stringResource(R.string.friends_accept_cta),
                                color = Color.Black,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }

                        Box(
                            modifier = Modifier
                                .size(44.dp)
                                .clip(CircleShape)
                                .background(Color.White.copy(alpha = 0.08f))
                                .clickable { onDecline?.invoke() },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "✕",
                                color = Color.White.copy(alpha = 0.4f),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                } else {
                    // Outgoing - cancel button
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(Color.White.copy(alpha = 0.08f))
                            .clickable { onRemove?.invoke() }
                            .padding(horizontal = 16.dp, vertical = 8.dp)
                    ) {
                        Text(
                            text = stringResource(R.string.friends_cancel_cta),
                            color = Color.White.copy(alpha = 0.5f),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            } else {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    // Favorite toggle
                    if (onToggleFavorite != null) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(Color.White.copy(alpha = 0.06f))
                                .clickable { onToggleFavorite(friend) },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = if (friend.isFavorite)
                                    Icons.Default.Star
                                else
                                    Icons.Outlined.StarBorder,
                                contentDescription = if (friend.isFavorite) "favoriden çıkar" else "favorile",
                                tint = if (friend.isFavorite) Color(0xFFFFD60A) else Color.White.copy(alpha = 0.5f),
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                    // DM button
                    Box(
                        modifier = Modifier
                            .size(44.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.12f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.ChatBubble,
                            contentDescription = stringResource(R.string.friends_send_message),
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }
        }

        // Streak row (only for active friends)
        if (!friend.isPending && streak != null) {
            FriendCardStreakRow(streak = streak, currentUserId = currentUserId)
        }

        // Tier progress bar (only for active friends with score)
        if (!friend.isPending && streak != null && streak.friendshipScore > 0) {
            FriendCardTierProgress(streak = streak)
        }
    }
}

// ── Streak Row (matches iOS friendCardStreak) ──

@Composable
private fun FriendCardStreakRow(
    streak: Streak,
    currentUserId: String?
) {
    Row(
        modifier = Modifier
            .padding(top = 10.dp)
            .padding(start = 56.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Streak count
        if (streak.currentStreak > 0) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "✦",
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "${streak.currentStreak}",
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        // Tier icon + name
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Text(
                text = tierIconEmoji(streak.friendshipTier),
                fontSize = 11.sp
            )
            Text(
                text = streak.friendshipTier.tierName,
                color = TextSecondary,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium
            )
        }

        // "senin sıran" badge
        if (currentUserId != null &&
            streak.lastSenderId != currentUserId &&
            streak.currentStreak > 0
        ) {
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Color.White.copy(alpha = 0.08f))
                    .padding(horizontal = 8.dp, vertical = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.CameraAlt,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.7f),
                    modifier = Modifier.size(10.dp)
                )
                Text(
                    text = stringResource(R.string.friends_turn_badge),
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }

        // Expiring soon
        if (streak.isExpiringSoon) {
            Icon(
                imageVector = Icons.Default.Timer,
                contentDescription = stringResource(R.string.friends_expiring_soon),
                tint = TextSecondary,
                modifier = Modifier.size(11.dp)
            )
        }

        Spacer(modifier = Modifier.weight(1f))
    }
}

// ── Tier Progress Bar (matches iOS friendCardTierProgress) ──

@Composable
private fun FriendCardTierProgress(streak: Streak) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp)
            .height(2.dp)
            .clip(RoundedCornerShape(50))
            .background(Color.White.copy(alpha = 0.06f))
    ) {
        val gradientColors = tierGradient(streak.friendshipTier)
        Box(
            modifier = Modifier
                .fillMaxWidth(streak.tierProgress.toFloat().coerceIn(0f, 1f))
                .height(2.dp)
                .clip(RoundedCornerShape(50))
                .background(
                    brush = Brush.horizontalGradient(gradientColors)
                )
        )
    }
}

// ── Empty State ──

@Composable
private fun EmptyFriendsState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 32.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = Icons.Default.Person,
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.2f),
            modifier = Modifier.size(48.dp)
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = stringResource(R.string.friends_empty_title),
            color = Color.White.copy(alpha = 0.5f),
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold
        )
        Text(
            text = stringResource(R.string.friends_empty_body),
            color = Color.White.copy(alpha = 0.35f),
            fontSize = 14.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 4.dp)
        )
    }
}

// ── Skeleton Loaders (matches iOS) ──

@Composable
private fun SkeletonProfileHero() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.06f))
                .shimmerEffect()
        )
        Spacer(modifier = Modifier.width(14.dp))
        Column {
            Box(
                modifier = Modifier
                    .size(120.dp, 14.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.White.copy(alpha = 0.06f))
                    .shimmerEffect()
            )
            Spacer(modifier = Modifier.height(6.dp))
            Box(
                modifier = Modifier
                    .size(80.dp, 12.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.White.copy(alpha = 0.04f))
                    .shimmerEffect()
            )
        }
    }
}

@Composable
private fun SkeletonFriendRow() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.04f))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.06f))
                .shimmerEffect()
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column {
            Box(
                modifier = Modifier
                    .size(100.dp, 14.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.White.copy(alpha = 0.06f))
                    .shimmerEffect()
            )
            Spacer(modifier = Modifier.height(4.dp))
            Box(
                modifier = Modifier
                    .size(60.dp, 12.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(Color.White.copy(alpha = 0.04f))
                    .shimmerEffect()
            )
        }
    }
}

// ── Helpers ──

private fun tierIconEmoji(tier: FriendshipTier): String {
    return when (tier) {
        FriendshipTier.TANIDIK -> "◌"
        FriendshipTier.MUHABBET -> "\u25CF"
        FriendshipTier.YAKIN -> "\u2666"
        FriendshipTier.SIRDAS -> "\u2605"
        FriendshipTier.KADIM -> "∞"
    }
}

private fun tierGradient(tier: FriendshipTier): List<Color> {
    return when (tier) {
        FriendshipTier.TANIDIK -> listOf(Color.White.copy(alpha = 0.2f), Color.White.copy(alpha = 0.3f))
        FriendshipTier.MUHABBET -> listOf(Color.White.copy(alpha = 0.3f), Color.White.copy(alpha = 0.4f))
        FriendshipTier.YAKIN -> listOf(Color.White.copy(alpha = 0.4f), Color.White.copy(alpha = 0.6f))
        FriendshipTier.SIRDAS -> listOf(Color.White.copy(alpha = 0.6f), Color.White.copy(alpha = 0.8f))
        FriendshipTier.KADIM -> listOf(Color.White.copy(alpha = 0.8f), Color.White)
    }
}
