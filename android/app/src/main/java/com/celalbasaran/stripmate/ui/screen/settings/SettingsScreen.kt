package com.celalbasaran.stripmate.ui.screen.settings

import android.content.Intent
import android.net.Uri
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.ErrorRed
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBack: () -> Unit,
    onEditProfile: () -> Unit,
    onNotificationSettings: () -> Unit,
    onPrivacySettings: () -> Unit,
    onAppearanceSettings: () -> Unit,
    onWidgetSettings: () -> Unit,
    onStorageSettings: () -> Unit,
    onSupport: () -> Unit,
    onAbout: () -> Unit,
    onBlockedUsers: () -> Unit,
    onPrivacyPolicy: () -> Unit,
    onTermsOfService: () -> Unit,
    onLoggedOut: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val inviteCode by viewModel.inviteCode.collectAsState()
    val currentProfile by viewModel.currentProfile.collectAsState()

    var showLogoutDialog by remember { mutableStateOf(false) }
    var showDeleteDialog by remember { mutableStateOf(false) }

    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Ayarlar") },
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

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
        ) {
            // MARK: - Profile Header
            ProfileHeader(
                displayName = currentProfile?.displayName,
                username = currentProfile?.username,
                avatarUrl = currentProfile?.avatarUrl,
                inviteCode = inviteCode,
                onAvatarClick = { /* avatar change */ },
                onCodeCopy = { viewModel.copyInviteCode(context) }
            )

            Spacer(modifier = Modifier.height(24.dp))

            // HESAP
            SettingsSection(title = "HESAP") {
                SettingsRow(icon = Icons.Default.Person, label = "Profili düzenle", onClick = onEditProfile)
                SettingsRow(icon = Icons.Default.Notifications, label = "Bildirimler", onClick = onNotificationSettings)
                SettingsRow(icon = Icons.Default.Lock, label = "Gizlilik", onClick = onPrivacySettings)
            }

            Spacer(modifier = Modifier.height(16.dp))

            // UYGULAMA
            SettingsSection(title = "UYGULAMA") {
                SettingsRow(icon = Icons.Default.Palette, label = "Görünüm", onClick = onAppearanceSettings)
                SettingsRow(icon = Icons.Default.Widgets, label = "Widget", onClick = onWidgetSettings)
                SettingsRow(icon = Icons.Default.Storage, label = "Depolama ve veri", onClick = onStorageSettings)
            }

            Spacer(modifier = Modifier.height(16.dp))

            // DESTEK
            SettingsSection(title = "DESTEK") {
                SettingsRow(icon = Icons.AutoMirrored.Filled.HelpOutline, label = "Yardım ve destek", onClick = onSupport)
                SettingsRow(icon = Icons.Default.Info, label = "Hakkında", onClick = onAbout)
            }

            Spacer(modifier = Modifier.height(16.dp))

            // YASAL
            SettingsSection(title = "YASAL") {
                SettingsRow(icon = Icons.Default.Description, label = "Kullanım koşulları", onClick = onTermsOfService)
                SettingsRow(icon = Icons.Default.Security, label = "Gizlilik politikası", onClick = onPrivacyPolicy)
            }

            Spacer(modifier = Modifier.height(16.dp))

            // HESAP YONETIMI
            SettingsSection(title = "HESAP YÖNETİMİ") {
                SettingsRow(
                    icon = Icons.AutoMirrored.Filled.Logout,
                    label = "Çıkış yap",
                    showChevron = false,
                    onClick = { showLogoutDialog = true }
                )
                SettingsRow(
                    icon = Icons.Default.Delete,
                    label = "Hesabımı sil",
                    isDestructive = true,
                    showChevron = false,
                    onClick = { showDeleteDialog = true }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Version footer
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = "anlik.",
                    color = TextPrimary.copy(alpha = 0.1f),
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = "v1.0.0",
                    color = TextPrimary.copy(alpha = 0.12f),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            Spacer(modifier = Modifier.height(40.dp))
        }
    }

    // Logout dialog
    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text("Çıkış yap", color = TextPrimary) },
            text = { Text("Hesabından çıkış yapmak istediğin kesin mi?", color = TextSecondary) },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.logout()
                        showLogoutDialog = false
                        onLoggedOut()
                    }
                ) {
                    Text("Çıkış yap", color = ErrorRed)
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutDialog = false }) {
                    Text("Iptal", color = TextSecondary)
                }
            },
            containerColor = DarkSurface
        )
    }

    // Delete account dialog
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Hesabi sil", color = ErrorRed, fontWeight = FontWeight.Bold) },
            text = {
                Text(
                    "Bu islem geri alınamaz! Tum verileriniz, fotoğraflarıniz ve bağlantılarınız kalıcı olarak silinecek.",
                    color = TextSecondary
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteAccount()
                        showDeleteDialog = false
                        onLoggedOut()
                    }
                ) {
                    Text("Kalici olarak sil", color = ErrorRed, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) {
                    Text("Vazgec", color = TextSecondary)
                }
            },
            containerColor = DarkSurface
        )
    }
}

@Composable
private fun ProfileHeader(
    displayName: String?,
    username: String?,
    avatarUrl: String?,
    inviteCode: String,
    onAvatarClick: () -> Unit,
    onCodeCopy: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Avatar with camera badge
        Box(
            modifier = Modifier
                .clickable(onClick = onAvatarClick)
        ) {
            if (!avatarUrl.isNullOrBlank()) {
                AsyncImage(
                    model = avatarUrl,
                    contentDescription = "Profil fotoğrafı",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(88.dp)
                        .clip(CircleShape)
                )
            } else {
                Box(
                    modifier = Modifier
                        .size(88.dp)
                        .clip(CircleShape)
                        .background(TextPrimary.copy(alpha = 0.08f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = (displayName?.firstOrNull()?.uppercase() ?: "?"),
                        color = TextPrimary,
                        fontSize = 32.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            // Camera badge
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .align(Alignment.BottomEnd)
                    .offset(x = 2.dp, y = 2.dp)
                    .background(Color.White, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.CameraAlt,
                    contentDescription = null,
                    tint = Color.Black,
                    modifier = Modifier.size(12.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Display name
        Text(
            text = displayName ?: "kullanici",
            color = TextPrimary,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold
        )

        // Username
        username?.let {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "@$it",
                color = TextSecondary.copy(alpha = 0.5f),
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Invite code pill
        Row(
            modifier = Modifier
                .background(TextPrimary.copy(alpha = 0.06f), RoundedCornerShape(50))
                .clickable(onClick = onCodeCopy)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = inviteCode,
                color = TextSecondary.copy(alpha = 0.6f),
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 2.sp
            )
        }
    }
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable () -> Unit
) {
    Column {
        Text(
            text = title,
            color = TextSecondary.copy(alpha = 0.5f),
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.sp,
            modifier = Modifier.padding(start = 4.dp, bottom = 10.dp)
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(TextPrimary.copy(alpha = 0.04f), RoundedCornerShape(16.dp))
        ) {
            content()
        }
    }
}

@Composable
private fun SettingsRow(
    icon: ImageVector,
    label: String,
    isDestructive: Boolean = false,
    showChevron: Boolean = true,
    onClick: (() -> Unit)? = null
) {
    val textColor = if (isDestructive) ErrorRed.copy(alpha = 0.7f) else TextPrimary.copy(alpha = 0.8f)
    val iconColor = if (isDestructive) ErrorRed.copy(alpha = 0.7f) else TextSecondary.copy(alpha = 0.5f)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = onClick != null) { onClick?.invoke() }
            .padding(horizontal = 18.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(20.dp)
        )

        Spacer(modifier = Modifier.width(14.dp))

        Text(
            text = label,
            color = textColor,
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f)
        )

        if (showChevron) {
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = TextSecondary.copy(alpha = 0.2f),
                modifier = Modifier.size(16.dp)
            )
        }
    }
}
