package com.celalbasaran.stripmate.ui.screen.privacy

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
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrivacySettingsScreen(
    onBack: () -> Unit,
    onBlockedUsers: () -> Unit
) {
    var hideOnline by remember { mutableStateOf(false) }
    var hideReadReceipts by remember { mutableStateOf(false) }
    var hideLeaderboard by remember { mutableStateOf(false) }
    var shareLocation by remember { mutableStateOf(true) }
    var showDistance by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Gizlilik") },
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
            // Visibility
            SectionHeader("GORUNURLUK")
            SettingsCard {
                PrivacyToggle(
                    icon = Icons.Default.VisibilityOff,
                    label = "Cevrimici durumunu gizle",
                    description = "Digerleri seni cevrimici goremez",
                    isChecked = hideOnline,
                    onCheckedChange = { hideOnline = it }
                )
                PrivacyDivider()
                PrivacyToggle(
                    icon = Icons.Default.Visibility,
                    label = "Okundu bilgisini gizle",
                    description = "Mesajlari okudugun bilgisi gönderilmez",
                    isChecked = hideReadReceipts,
                    onCheckedChange = { hideReadReceipts = it }
                )
                PrivacyDivider()
                PrivacyToggle(
                    icon = Icons.Default.EmojiEvents,
                    label = "Liderlik tablosundan gizlen",
                    description = "Siralamada gorunmezsin",
                    isChecked = hideLeaderboard,
                    onCheckedChange = { hideLeaderboard = it }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Location
            SectionHeader("KONUM")
            SettingsCard {
                PrivacyToggle(
                    icon = Icons.Default.LocationOn,
                    label = "Konum paylasimi",
                    description = "Fotoğraflara konum bilgisi eklenir",
                    isChecked = shareLocation,
                    onCheckedChange = { shareLocation = it }
                )
                PrivacyDivider()
                PrivacyToggle(
                    icon = Icons.Default.Straighten,
                    label = "Mesafe goster",
                    description = "Widget'ta arkadaşınla arandaki mesafe",
                    isChecked = showDistance,
                    onCheckedChange = { showDistance = it }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            Text(
                text = "Gizlilik ayarların yalnızca bu hesap için geçerlidir. Engellenen kullanıcılar seni arkadaş olarak ekleyemez ve sana mesaj gönderemez.",
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
private fun PrivacyDivider() {
    HorizontalDivider(
        color = TextSecondary.copy(alpha = 0.06f),
        modifier = Modifier.padding(start = 36.dp)
    )
}

@Composable
private fun PrivacyToggle(
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
                maxLines = 2
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
