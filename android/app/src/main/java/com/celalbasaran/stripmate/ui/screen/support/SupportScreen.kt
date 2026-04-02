package com.celalbasaran.stripmate.ui.screen.support

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

private data class FaqItem(val question: String, val answer: String)

private val faqItems = listOf(
    FaqItem(
        "Arkadaşımı nasıl eklerim?",
        "Arkadaş ekle bölümüne git ve arkadaşının 8 haneli davet kodunu gir. Ya da QR kodunu taratabilirsin."
    ),
    FaqItem(
        "Fotoğraflarım ne kadar süre saklanır?",
        "Fotoğraflar 30 gün boyunca saklanır. Bu süre sonunda otomatik olarak silinir."
    ),
    FaqItem(
        "Seri (streak) nasil calisir?",
        "Her gun bir arkadaşına fotoğraf gönderdiğinde serin artar. 1 gun atlarsan seriye devam edersin, 2 gun atlarsan serin sıfırlanır."
    ),
    FaqItem(
        "Widget nasil eklenir?",
        "Ana ekrani basili tut → sol ustteki + butonuna bas → anlik. uygulamasini bul → istediğin boyutu sec."
    ),
    FaqItem(
        "Hesabimi nasil silerim?",
        "Ayarlar → Hesap yonetimi → Hesabimi sil. Bu islem geri alınamaz ve tum verilerin kalici olarak silinir."
    ),
    FaqItem(
        "Maksimum kaç arkadaş ekleyebilirim?",
        "En fazla 50 arkadaş ekleyebilirsin. anlik. küçük ve samimi bir paylaşım alanı olmayı hedefler."
    )
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupportScreen(
    onBack: () -> Unit,
    onSupportChat: () -> Unit = {}
) {
    val context = LocalContext.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text("Yardim ve Destek") },
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
            // Live Support
            SectionHeader("CANLI DESTEK")
            SectionCard {
                SupportRow(
                    icon = Icons.Default.Chat,
                    label = "Canli Destek",
                    description = "Bize aninda yaz",
                    onClick = onSupportChat
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Contact
            SectionHeader("ILETISIM")
            SectionCard {
                SupportRow(
                    icon = Icons.Default.Email,
                    label = "Sorun bildir",
                    description = "Bize e-posta gönder",
                    onClick = { sendSupportEmail(context) }
                )
                SupportDivider()
                SupportRow(
                    icon = Icons.Default.Lightbulb,
                    label = "Ozellik oner",
                    description = "Fikirlerini paylas",
                    onClick = { sendFeatureEmail(context) }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Rate
            SectionHeader("DEGERLENDIR")
            SectionCard {
                SupportRow(
                    icon = Icons.Default.Star,
                    label = "Uygulamayi degerlendir",
                    description = "Play Store'da bize yildiz ver",
                    onClick = {
                        val intent = Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse("market://details?id=com.celalbasaran.stripmate")
                        )
                        try {
                            context.startActivity(intent)
                        } catch (_: Exception) {
                            // Play Store not installed
                        }
                    }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // FAQ
            SectionHeader("SIK SORULAN SORULAR")
            SectionCard {
                faqItems.forEachIndexed { index, item ->
                    FaqRow(item = item)
                    if (index < faqItems.lastIndex) {
                        SupportDivider()
                    }
                }
            }

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
private fun SectionCard(content: @Composable () -> Unit) {
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
private fun SupportDivider() {
    HorizontalDivider(color = TextSecondary.copy(alpha = 0.06f))
}

@Composable
private fun SupportRow(
    icon: ImageVector,
    label: String,
    description: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
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
                fontSize = 12.sp
            )
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.OpenInNew,
            contentDescription = null,
            tint = TextSecondary.copy(alpha = 0.3f),
            modifier = Modifier.size(14.dp)
        )
    }
}

@Composable
private fun FaqRow(item: FaqItem) {
    var expanded by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { expanded = !expanded }
            .padding(vertical = 10.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = item.question,
                color = TextPrimary.copy(alpha = 0.7f),
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.weight(1f)
            )
            Icon(
                imageVector = if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                contentDescription = null,
                tint = TextSecondary.copy(alpha = 0.3f),
                modifier = Modifier.size(20.dp)
            )
        }
        AnimatedVisibility(visible = expanded) {
            Text(
                text = item.answer,
                color = TextSecondary.copy(alpha = 0.5f),
                fontSize = 14.sp,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
    }
}

private fun sendSupportEmail(context: Context) {
    val deviceInfo = "${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.RELEASE}"
    val subject = Uri.encode("anlik. - Sorun Bildirimi")
    val body = Uri.encode("\n\n---\nCihaz: $deviceInfo\nUygulama: v1.0.0")
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("mailto:info@celalbasaran.com?subject=$subject&body=$body"))
    context.startActivity(intent)
}

private fun sendFeatureEmail(context: Context) {
    val subject = Uri.encode("anlik. - Ozellik Onerisi")
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("mailto:info@celalbasaran.com?subject=$subject"))
    context.startActivity(intent)
}
