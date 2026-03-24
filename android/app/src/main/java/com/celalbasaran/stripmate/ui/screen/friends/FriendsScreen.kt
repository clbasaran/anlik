package com.celalbasaran.stripmate.ui.screen.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Badge
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.data.model.Friend
import com.celalbasaran.stripmate.data.model.Streak
import com.celalbasaran.stripmate.ui.component.EmptyState
import com.celalbasaran.stripmate.ui.component.StreakBadge
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.ErrorRed
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.SuccessGreen
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.util.TimeAgo

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendsScreen(
    onFriendClick: (String) -> Unit,
    onQRClick: () -> Unit,
    onInboxClick: () -> Unit,
    viewModel: FriendsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val clipboardManager = LocalClipboardManager.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = {
                Text(
                    text = "Arkadaşlar",
                    fontWeight = FontWeight.Bold
                )
            },
            actions = {
                // Inbox / pending requests
                if (uiState.pendingRequests.isNotEmpty()) {
                    IconButton(onClick = onInboxClick) {
                        Box {
                            Icon(
                                imageVector = Icons.Default.PersonAdd,
                                contentDescription = "Gelen istekler",
                                tint = TextPrimary
                            )
                            Badge(
                                containerColor = StripMateBlue,
                                modifier = Modifier.align(Alignment.TopEnd)
                            ) {
                                Text(
                                    text = uiState.pendingRequests.size.toString(),
                                    fontSize = 10.sp
                                )
                            }
                        }
                    }
                }

                IconButton(onClick = onQRClick) {
                    Icon(
                        imageVector = Icons.Default.QrCode,
                        contentDescription = "QR Kod",
                        tint = TextPrimary
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = PureBlack,
                titleContentColor = TextPrimary
            )
        )

        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = StripMateBlue)
                }
            }

            else -> {
                PullToRefreshBox(
                    isRefreshing = uiState.isRefreshing,
                    onRefresh = { viewModel.refresh() },
                    modifier = Modifier.fillMaxSize()
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize()
                    ) {
                        // Invite code badge
                        item {
                            if (uiState.myInviteCode.isNotEmpty()) {
                                InviteCodeBadge(
                                    code = uiState.myInviteCode,
                                    onCopy = {
                                        clipboardManager.setText(AnnotatedString(uiState.myInviteCode))
                                    }
                                )
                            }
                        }

                        // Search section
                        item {
                            SearchSection(
                                searchCode = uiState.searchCode,
                                isSearching = uiState.isSearching,
                                searchError = uiState.searchError,
                                searchedProfile = uiState.searchedProfile,
                                onSearchCodeChange = { viewModel.updateSearchCode(it) },
                                onSearch = { viewModel.searchByCode() },
                                onSendRequest = { viewModel.sendRequest(it) }
                            )
                        }

                        // Incoming requests section
                        if (uiState.pendingRequests.isNotEmpty()) {
                            item {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = "gelen istekler · ${uiState.pendingRequests.size}",
                                    color = Color.White.copy(alpha = 0.35f),
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp,
                                    letterSpacing = 1.sp,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                                )
                            }

                            items(
                                items = uiState.pendingRequests,
                                key = { "pending_${it.userId}" }
                            ) { request ->
                                PendingRequestItem(
                                    friend = request,
                                    onAccept = { viewModel.acceptRequest(request.userId) },
                                    onDecline = { viewModel.declineRequest(request.userId) }
                                )
                            }

                            item {
                                HorizontalDivider(
                                    color = DarkSurfaceVariant,
                                    modifier = Modifier.padding(vertical = 8.dp)
                                )
                            }
                        }

                        // Friends list header
                        item {
                            Text(
                                text = "arkadaşların · ${uiState.friends.size}",
                                color = Color.White.copy(alpha = 0.35f),
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp,
                                letterSpacing = 1.sp,
                                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                            )
                        }

                        if (uiState.friends.isEmpty()) {
                            item {
                                EmptyState(
                                    icon = "\uD83D\uDC6B",
                                    message = "Henüz arkadaşın yok.\nDavet kodunu paylaş veya arkadaşının kodunu gir!",
                                    modifier = Modifier.padding(top = 32.dp)
                                )
                            }
                        } else {
                            items(
                                items = uiState.friends,
                                key = { it.userId }
                            ) { friend ->
                                FriendItem(
                                    friend = friend,
                                    streak = uiState.streaks[friend.userId],
                                    onClick = { onFriendClick(friend.userId) }
                                )
                            }
                        }

                        item { Spacer(modifier = Modifier.height(80.dp)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun InviteCodeBadge(
    code: String,
    onCopy: () -> Unit
) {
    Card(
        colors = CardDefaults.cardColors(
            containerColor = DarkSurface
        ),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clickable { onCopy() }
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column {
                Text(
                    text = "Davet kodun",
                    color = TextSecondary,
                    style = MaterialTheme.typography.labelSmall
                )
                Text(
                    text = code,
                    color = TextPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.sp
                )
            }
            Text(
                text = "Kopyala",
                color = StripMateBlue,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

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
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = searchCode,
                onValueChange = onSearchCodeChange,
                placeholder = { Text("8 haneli davet kodu") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    imeAction = ImeAction.Search
                ),
                keyboardActions = KeyboardActions(
                    onSearch = { onSearch() }
                ),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary,
                    cursorColor = TextPrimary,
                    focusedBorderColor = TextPrimary,
                    unfocusedBorderColor = DarkSurfaceVariant,
                    focusedPlaceholderColor = TextSecondary,
                    unfocusedPlaceholderColor = TextSecondary
                ),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.weight(1f)
            )

            Spacer(modifier = Modifier.width(8.dp))

            IconButton(
                onClick = onSearch,
                enabled = !isSearching && searchCode.length == 8
            ) {
                if (isSearching) {
                    CircularProgressIndicator(
                        color = StripMateBlue,
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Ara",
                        tint = if (searchCode.length == 8) TextPrimary else TextSecondary
                    )
                }
            }
        }

        if (searchError != null) {
            Text(
                text = searchError,
                color = ErrorRed,
                style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.padding(top = 4.dp)
            )
        }

        // Found user card
        if (searchedProfile != null) {
            Spacer(modifier = Modifier.height(8.dp))
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = DarkSurface
                ),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    UserAvatar(
                        imageUrl = searchedProfile.avatarUrl,
                        displayName = searchedProfile.displayName,
                        size = 44.dp
                    )

                    Spacer(modifier = Modifier.width(12.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = searchedProfile.displayName ?: "",
                            color = TextPrimary,
                            fontWeight = FontWeight.SemiBold
                        )
                        searchedProfile.username?.let { username ->
                            Text(
                                text = "@$username",
                                color = TextSecondary,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }

                    Button(
                        onClick = { onSendRequest(searchedProfile.id) },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = StripMateBlue
                        ),
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Text(
                            text = "Ekle",
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PendingRequestItem(
    friend: Friend,
    onAccept: () -> Unit,
    onDecline: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        UserAvatar(
            imageUrl = friend.profile?.avatarUrl,
            displayName = friend.profile?.displayName ?: friend.userId,
            size = 44.dp
        )

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = friend.profile?.displayName ?: friend.userId,
                color = TextPrimary,
                fontWeight = FontWeight.Medium,
                style = MaterialTheme.typography.bodyMedium
            )
            friend.profile?.username?.let { username ->
                Text(
                    text = "@$username",
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }

        Button(
            onClick = onAccept,
            colors = ButtonDefaults.buttonColors(
                containerColor = SuccessGreen
            ),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.height(32.dp)
        ) {
            Text(
                text = "Kabul",
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        Spacer(modifier = Modifier.width(6.dp))

        Button(
            onClick = onDecline,
            colors = ButtonDefaults.buttonColors(
                containerColor = DarkSurfaceVariant
            ),
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.height(32.dp)
        ) {
            Text(
                text = "Reddet",
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = TextSecondary
            )
        }
    }
}

@Composable
private fun FriendItem(
    friend: Friend,
    streak: Streak?,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        UserAvatar(
            imageUrl = friend.profile?.avatarUrl,
            displayName = friend.profile?.displayName ?: friend.userId,
            size = 48.dp
        )

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = friend.profile?.displayName ?: friend.userId,
                color = TextPrimary,
                fontWeight = FontWeight.Medium,
                style = MaterialTheme.typography.bodyLarge
            )

            Row(verticalAlignment = Alignment.CenterVertically) {
                friend.profile?.username?.let { username ->
                    Text(
                        text = "@$username",
                        color = TextSecondary,
                        style = MaterialTheme.typography.bodySmall
                    )
                }

                friend.profile?.lastActive?.let { lastActive ->
                    Text(
                        text = " \u00B7 ",
                        color = TextSecondary,
                        style = MaterialTheme.typography.bodySmall
                    )
                    Text(
                        text = TimeAgo.format(lastActive),
                        color = TextSecondary,
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }

        if (streak != null && streak.currentStreak > 0) {
            StreakBadge(
                streakCount = streak.currentStreak,
                tier = streak.friendshipTier
            )
        }
    }
}
