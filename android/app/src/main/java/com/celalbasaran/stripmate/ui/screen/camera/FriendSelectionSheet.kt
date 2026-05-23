package com.celalbasaran.stripmate.ui.screen.camera

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarOutline
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.data.model.Friend
import com.celalbasaran.stripmate.data.model.SendGroup
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendSelectionSheet(
    friends: List<Friend>,
    selectedIds: Set<String>,
    comment: String,
    isUploading: Boolean,
    onToggleFriend: (String) -> Unit,
    onSelectIds: (Set<String>) -> Unit,
    onCommentChange: (String) -> Unit,
    onSend: () -> Unit,
    onDismiss: () -> Unit,
    sheetVm: FriendSheetViewModel = hiltViewModel()
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val searchText by sheetVm.searchText.collectAsState()
    val sendGroups by sheetVm.sendGroups.collectAsState()
    val showCreateDialog by sheetVm.showCreateDialog.collectAsState()
    val newGroupName by sheetVm.newGroupName.collectAsState()
    val errorMessage by sheetVm.errorMessage.collectAsState()

    val q = searchText.trim().lowercase()
    val filteredFriends = remember(friends, q) {
        if (q.isEmpty()) friends
        else friends.filter {
            (it.profile?.displayName ?: "").lowercase().contains(q) ||
                    (it.profile?.username ?: "").lowercase().contains(q) ||
                    it.userId.lowercase().contains(q)
        }
    }
    val favorites = filteredFriends.filter { it.isFavorite }
    val regulars = filteredFriends.filter { !it.isFavorite }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = DarkSurface,
        dragHandle = {
            Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Spacer(modifier = Modifier.height(8.dp))
                Box(
                    modifier = Modifier
                        .size(width = 36.dp, height = 4.dp)
                        .background(DarkSurfaceVariant, RoundedCornerShape(2.dp))
                )
                Spacer(modifier = Modifier.height(8.dp))
            }
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .padding(bottom = 32.dp)
        ) {
            Text(
                text = "Kime gönderilsin?",
                color = TextPrimary,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 12.dp)
            )

            // Search bar
            OutlinedTextField(
                value = searchText,
                onValueChange = sheetVm::setSearchText,
                placeholder = { Text("ara") },
                singleLine = true,
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary,
                    cursorColor = TextPrimary,
                    focusedBorderColor = TextPrimary.copy(alpha = 0.4f),
                    unfocusedBorderColor = DarkSurfaceVariant,
                    focusedPlaceholderColor = TextSecondary,
                    unfocusedPlaceholderColor = TextSecondary
                ),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(12.dp))

            if (friends.isEmpty()) {
                Text(
                    text = "Henüz arkadaşın yok. Arkadaşlarını ekle!",
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(vertical = 24.dp)
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 200.dp, max = 400.dp)
                ) {
                    // Send groups — only when no search
                    if (q.isEmpty() && sendGroups.isNotEmpty()) {
                        item { SectionHeader("gruplar") }
                        items(sendGroups, key = { "g_${it.id}" }) { group ->
                            GroupRow(
                                group = group,
                                allSelected = group.memberIds.isNotEmpty()
                                        && selectedIds.containsAll(group.memberIds),
                                onToggle = {
                                    val members = group.memberIds.toSet()
                                    if (selectedIds.containsAll(members)) {
                                        onSelectIds(selectedIds - members)
                                    } else {
                                        onSelectIds(selectedIds + members)
                                    }
                                }
                            )
                        }
                    }

                    if (favorites.isNotEmpty()) {
                        item { SectionHeader("favoriler") }
                        items(favorites, key = { "f_${it.userId}" }) { friend ->
                            FriendRow(
                                friend = friend,
                                isSelected = selectedIds.contains(friend.userId),
                                onToggle = { onToggleFriend(friend.userId) },
                                onToggleFavorite = {
                                    sheetVm.toggleFavorite(friend.userId, friend.isFavorite)
                                }
                            )
                        }
                    }

                    if (regulars.isNotEmpty()) {
                        if (favorites.isNotEmpty() || (q.isEmpty() && sendGroups.isNotEmpty())) {
                            item { SectionHeader("tüm arkadaşlar") }
                        }
                        items(regulars, key = { "r_${it.userId}" }) { friend ->
                            FriendRow(
                                friend = friend,
                                isSelected = selectedIds.contains(friend.userId),
                                onToggle = { onToggleFriend(friend.userId) },
                                onToggleFavorite = {
                                    sheetVm.toggleFavorite(friend.userId, friend.isFavorite)
                                }
                            )
                        }
                    }

                    if (filteredFriends.isEmpty() && q.isNotEmpty()) {
                        item {
                            Text(
                                text = "bu aramayla kimse çıkmadı",
                                color = TextSecondary,
                                style = MaterialTheme.typography.bodySmall,
                                modifier = Modifier.padding(vertical = 24.dp)
                            )
                        }
                    }
                }
            }

            // Save selection as group
            if (q.isEmpty() && selectedIds.size >= 2) {
                Spacer(modifier = Modifier.height(8.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
                        .clickable { sheetVm.openCreateGroupDialog() }
                        .padding(vertical = 12.dp, horizontal = 14.dp)
                ) {
                    Text(
                        text = "+ seçimi grup olarak kaydet",
                        color = TextPrimary.copy(alpha = 0.85f),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            OutlinedTextField(
                value = comment,
                onValueChange = onCommentChange,
                placeholder = { Text("Yorum ekle (isteğe bağlı)") },
                maxLines = 2,
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
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(20.dp))

            Button(
                onClick = onSend,
                enabled = selectedIds.isNotEmpty() && !isUploading,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White,
                    contentColor = Color.Black,
                    disabledContainerColor = Color.White.copy(alpha = 0.3f)
                ),
                shape = RoundedCornerShape(28.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
            ) {
                if (isUploading) {
                    CircularProgressIndicator(
                        color = Color.Black,
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                        Icon(
                            imageVector = Icons.Default.Send,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = if (selectedIds.isEmpty()) "arkadaş seç" else "gönder (${selectedIds.size})",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                    }
                }
            }
        }
    }

    if (showCreateDialog) {
        AlertDialog(
            onDismissRequest = sheetVm::closeCreateGroupDialog,
            title = { Text("grubu adlandır") },
            text = {
                Column {
                    Text(
                        "seçili ${selectedIds.size} kişi bu grup adıyla bir arada saklanır.",
                        color = TextSecondary,
                        fontSize = 13.sp
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    OutlinedTextField(
                        value = newGroupName,
                        onValueChange = sheetVm::setNewGroupName,
                        placeholder = { Text("grup adı") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                TextButton(onClick = { sheetVm.createGroupFromSelection(selectedIds.toList()) }) {
                    Text("kaydet")
                }
            },
            dismissButton = {
                TextButton(onClick = sheetVm::closeCreateGroupDialog) { Text("iptal") }
            },
            containerColor = DarkSurface
        )
    }

    errorMessage?.let { msg ->
        AlertDialog(
            onDismissRequest = sheetVm::clearError,
            title = { Text("hata") },
            text = { Text(msg) },
            confirmButton = { TextButton(onClick = sheetVm::clearError) { Text("tamam") } },
            containerColor = DarkSurface
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title.uppercase(),
        color = TextSecondary,
        fontSize = 11.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(top = 12.dp, bottom = 4.dp)
    )
}

@Composable
private fun FriendRow(
    friend: Friend,
    isSelected: Boolean,
    onToggle: () -> Unit,
    onToggleFavorite: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Checkbox(
            checked = isSelected,
            onCheckedChange = { onToggle() },
            colors = CheckboxDefaults.colors(
                checkedColor = StripMateBlue,
                uncheckedColor = TextSecondary,
                checkmarkColor = Color.White
            )
        )
        Spacer(modifier = Modifier.width(8.dp))
        UserAvatar(
            imageUrl = friend.profile?.avatarUrl,
            displayName = friend.profile?.displayName ?: friend.userId,
            size = 40.dp
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = friend.profile?.displayName ?: friend.userId,
                    color = TextPrimary,
                    fontWeight = FontWeight.Medium,
                    style = MaterialTheme.typography.bodyMedium
                )
                if (friend.isFavorite) {
                    Spacer(modifier = Modifier.width(4.dp))
                    Icon(
                        imageVector = Icons.Default.Star,
                        contentDescription = null,
                        tint = Color(0xFFFFD60A),
                        modifier = Modifier.size(13.dp)
                    )
                }
            }
            friend.profile?.username?.let { username ->
                Text(
                    text = "@$username",
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }
        IconButton(onClick = onToggleFavorite) {
            Icon(
                imageVector = if (friend.isFavorite) Icons.Default.Star else Icons.Default.StarOutline,
                contentDescription = if (friend.isFavorite) "favoriden çıkar" else "favorile",
                tint = if (friend.isFavorite) Color(0xFFFFD60A) else TextSecondary,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

@Composable
private fun GroupRow(
    group: SendGroup,
    allSelected: Boolean,
    onToggle: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Checkbox(
            checked = allSelected,
            onCheckedChange = { onToggle() },
            colors = CheckboxDefaults.colors(
                checkedColor = StripMateBlue,
                uncheckedColor = TextSecondary,
                checkmarkColor = Color.White
            )
        )
        Spacer(modifier = Modifier.width(8.dp))
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(20.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "★",
                color = TextPrimary.copy(alpha = 0.7f),
                fontSize = 18.sp
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = group.name,
                color = TextPrimary,
                fontWeight = FontWeight.Medium,
                style = MaterialTheme.typography.bodyMedium
            )
            Text(
                text = "${group.memberIds.size} kişi",
                color = TextSecondary,
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}
