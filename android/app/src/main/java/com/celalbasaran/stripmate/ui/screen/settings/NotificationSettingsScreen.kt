package com.celalbasaran.stripmate.ui.screen.settings

import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Campaign
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.DarkMode
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Photo
import androidx.compose.material.icons.filled.Summarize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationSettingsScreen(
    onBack: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val notificationPrefs by viewModel.notificationPrefs.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Bildirim Ayarlari") },
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
            // Activity
            SectionHeader("AKTIVITE")
            SettingsCard {
                NotifToggle(
                    icon = Icons.Default.Photo,
                    label = "Yeni anlar",
                    description = "Arkadaşların yeni bir an paylaştığında",
                    isChecked = notificationPrefs["photo_received"] ?: true,
                    onCheckedChange = { viewModel.toggleNotification("photo_received", it) }
                )
                SettingsDivider()
                NotifToggle(
                    icon = Icons.Default.ChatBubble,
                    label = "Yorumlar",
                    description = "Anlarina yorum yapildiginda",
                    isChecked = notificationPrefs["comment_received"] ?: true,
                    onCheckedChange = { viewModel.toggleNotification("comment_received", it) }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Messages
            SectionHeader("MESAJLAR")
            SettingsCard {
                NotifToggle(
                    icon = Icons.Default.Email,
                    label = "Direkt mesajlar",
                    description = "Yeni bir direkt mesaj aldığında",
                    isChecked = notificationPrefs["message_received"] ?: true,
                    onCheckedChange = { viewModel.toggleNotification("message_received", it) }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Social
            SectionHeader("SOSYAL")
            SettingsCard {
                NotifToggle(
                    icon = Icons.Default.PersonAdd,
                    label = "Arkadaşlık istekleri",
                    description = "Yeni bir arkadaşlık isteği aldığında",
                    isChecked = notificationPrefs["friend_added"] ?: true,
                    onCheckedChange = { viewModel.toggleNotification("friend_added", it) }
                )
                SettingsDivider()
                NotifToggle(
                    icon = Icons.Default.LocalFireDepartment,
                    label = "Seri uyarilari",
                    description = "Serin sona ermek uzereyken",
                    isChecked = notificationPrefs["streak_warning"] ?: true,
                    onCheckedChange = { viewModel.toggleNotification("streak_warning", it) }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Prompts
            SectionHeader("GÖREVLER")
            SettingsCard {
                NotifToggle(
                    icon = Icons.Default.Campaign,
                    label = "Günün görevi",
                    description = "Günlük fotoğraf görevi yayınlandığında",
                    isChecked = notificationPrefs["daily_prompt"] ?: true,
                    onCheckedChange = { viewModel.toggleNotification("daily_prompt", it) }
                )
                SettingsDivider()
                NotifToggle(
                    icon = Icons.Default.Summarize,
                    label = "Haftalik ozet",
                    description = "Pazar gunleri haftalik istatistiklerin",
                    isChecked = notificationPrefs["weekly_summary"] ?: true,
                    onCheckedChange = { viewModel.toggleNotification("weekly_summary", it) }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Quiet hours
            SectionHeader("SESSIZ SAATLER")
            SettingsCard {
                NotifToggle(
                    icon = Icons.Default.DarkMode,
                    label = "Sessiz saatler",
                    description = "23:00 - 07:00 arası bildirimler sessize alınır",
                    isChecked = notificationPrefs["quiet_hours_enabled"] ?: false,
                    onCheckedChange = { viewModel.toggleNotification("quiet_hours_enabled", it) }
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "Bildirim tercihlerin hem bu cihazda hem de sunucuda saklanır. Sessiz saatler aktifken hiçbir bildirim gönderilmez.",
                color = TextSecondary.copy(alpha = 0.3f),
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
            )

            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        text = title,
        color = TextSecondary.copy(alpha = 0.5f),
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold,
        letterSpacing = 1.sp,
        modifier = Modifier.padding(start = 4.dp, bottom = 10.dp)
    )
}

@Composable
private fun SettingsCard(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(DarkSurface.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
            .padding(horizontal = 18.dp, vertical = 12.dp)
    ) {
        content()
    }
}

@Composable
private fun SettingsDivider() {
    HorizontalDivider(
        color = TextSecondary.copy(alpha = 0.06f),
        modifier = Modifier.padding(start = 36.dp)
    )
}

@Composable
private fun NotifToggle(
    icon: ImageVector,
    label: String,
    description: String,
    isChecked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = TextSecondary.copy(alpha = 0.5f),
            modifier = Modifier.size(18.dp)
        )
        Spacer(modifier = Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                color = TextPrimary.copy(alpha = 0.8f),
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = description,
                color = TextSecondary.copy(alpha = 0.35f),
                fontSize = 12.sp,
                maxLines = 1
            )
        }
        Switch(
            checked = isChecked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = StripMateBlue,
                uncheckedThumbColor = TextSecondary,
                uncheckedTrackColor = DarkSurfaceVariant
            )
        )
    }
}
