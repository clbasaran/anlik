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
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.OpenInNew
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.BuildConfig
import com.celalbasaran.stripmate.R
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

private data class FaqItem(val question: String, val answer: String)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SupportScreen(
    onBack: () -> Unit,
    onSupportChat: () -> Unit = {}
) {
    val context = LocalContext.current
    val faqItems = rememberSupportFaqItems()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        TopAppBar(
            title = { Text(stringResource(R.string.support_title)) },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = stringResource(R.string.common_back),
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
            SectionHeader(stringResource(R.string.support_section_live))
            SectionCard {
                SupportRow(
                    icon = Icons.AutoMirrored.Filled.Chat,
                    label = stringResource(R.string.support_live_label),
                    description = stringResource(R.string.support_live_desc),
                    onClick = onSupportChat
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Contact
            SectionHeader(stringResource(R.string.support_section_contact))
            SectionCard {
                SupportRow(
                    icon = Icons.Default.Email,
                    label = stringResource(R.string.support_issue_label),
                    description = stringResource(R.string.support_issue_desc),
                    onClick = { sendSupportEmail(context) }
                )
                SupportDivider()
                SupportRow(
                    icon = Icons.Default.Lightbulb,
                    label = stringResource(R.string.support_feature_label),
                    description = stringResource(R.string.support_feature_desc),
                    onClick = { sendFeatureEmail(context) }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Rate
            SectionHeader(stringResource(R.string.support_section_rate))
            SectionCard {
                SupportRow(
                    icon = Icons.Default.Star,
                    label = stringResource(R.string.support_rate_label),
                    description = stringResource(R.string.support_rate_desc),
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
            SectionHeader(stringResource(R.string.support_section_faq))
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
private fun rememberSupportFaqItems(): List<FaqItem> = listOf(
    FaqItem(
        stringResource(R.string.support_faq_add_friend_q),
        stringResource(R.string.support_faq_add_friend_a)
    ),
    FaqItem(
        stringResource(R.string.support_faq_retention_q),
        stringResource(R.string.support_faq_retention_a)
    ),
    FaqItem(
        stringResource(R.string.support_faq_streak_q),
        stringResource(R.string.support_faq_streak_a)
    ),
    FaqItem(
        stringResource(R.string.support_faq_widget_q),
        stringResource(R.string.support_faq_widget_a)
    ),
    FaqItem(
        stringResource(R.string.support_faq_delete_q),
        stringResource(R.string.support_faq_delete_a)
    ),
    FaqItem(
        stringResource(R.string.support_faq_limit_q),
        stringResource(R.string.support_faq_limit_a)
    )
)

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
    val subject = Uri.encode(context.getString(R.string.support_email_subject_issue))
    val body = Uri.encode(
        "\n\n---\n${context.getString(R.string.support_email_body_device, deviceInfo)}\n${context.getString(R.string.support_email_body_app, BuildConfig.VERSION_NAME)}"
    )
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("mailto:info@celalbasaran.com?subject=$subject&body=$body"))
    context.startActivity(intent)
}

private fun sendFeatureEmail(context: Context) {
    val subject = Uri.encode(context.getString(R.string.support_email_subject_feature))
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("mailto:info@celalbasaran.com?subject=$subject"))
    context.startActivity(intent)
}
