package com.celalbasaran.stripmate.ui.screen.consent

import androidx.compose.animation.animateColorAsState
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

data class ConsentDocument(
    val title: String,
    val description: String
)

private val documents = listOf(
    ConsentDocument("Kullanım Koşulları", "Hizmet şartları"),
    ConsentDocument("Gizlilik Politikası", "Veri kullanımı"),
    ConsentDocument("KVKK Aydınlatma Metni", "Kişisel veriler"),
    ConsentDocument("EULA", "Son kullanıcı anlaşması")
)

@Composable
fun ConsentScreen(
    onAcceptAll: () -> Unit,
    onReadDocument: (String) -> Unit
) {
    var acceptedTerms by remember { mutableStateOf(false) }
    var acceptedPrivacy by remember { mutableStateOf(false) }
    var acceptedKVKK by remember { mutableStateOf(false) }
    var acceptedEULA by remember { mutableStateOf(false) }

    val acceptStates = listOf(acceptedTerms, acceptedPrivacy, acceptedKVKK, acceptedEULA)
    val allAccepted = acceptStates.all { it }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        // Header
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 48.dp, bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = Icons.Default.Shield,
                contentDescription = null,
                tint = TextSecondary.copy(alpha = 0.6f),
                modifier = Modifier.size(36.dp)
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "Yasal Belgeler",
                color = TextPrimary,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Devam etmek için aşağıdaki belgeleri\nokumalı ve onaylamalısın.",
                color = TextSecondary.copy(alpha = 0.5f),
                fontSize = 14.sp,
                textAlign = TextAlign.Center
            )
        }

        // Document list
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            ConsentRow(
                document = documents[0],
                isAccepted = acceptedTerms,
                onToggle = { acceptedTerms = !acceptedTerms },
                onRead = { onReadDocument("terms") }
            )
            ConsentRow(
                document = documents[1],
                isAccepted = acceptedPrivacy,
                onToggle = { acceptedPrivacy = !acceptedPrivacy },
                onRead = { onReadDocument("privacy") }
            )
            ConsentRow(
                document = documents[2],
                isAccepted = acceptedKVKK,
                onToggle = { acceptedKVKK = !acceptedKVKK },
                onRead = { onReadDocument("kvkk") }
            )
            ConsentRow(
                document = documents[3],
                isAccepted = acceptedEULA,
                onToggle = { acceptedEULA = !acceptedEULA },
                onRead = { onReadDocument("eula") }
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Info note
            Row(
                modifier = Modifier.padding(horizontal = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "ℹ️ Onayınız güvenli şekilde kaydedilir.",
                    color = TextSecondary.copy(alpha = 0.3f),
                    fontSize = 12.sp
                )
            }
        }

        // Bottom actions
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 28.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Select all
            Row(
                modifier = Modifier
                    .clickable {
                        val newValue = !allAccepted
                        acceptedTerms = newValue
                        acceptedPrivacy = newValue
                        acceptedKVKK = newValue
                        acceptedEULA = newValue
                    }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Checkbox(isChecked = allAccepted)
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    text = "Tümünü okudum ve kabul ediyorum",
                    color = TextPrimary.copy(alpha = 0.8f),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            Spacer(modifier = Modifier.height(14.dp))

            Button(
                onClick = onAcceptAll,
                enabled = allAccepted,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White,
                    contentColor = Color.Black,
                    disabledContainerColor = TextSecondary.copy(alpha = 0.15f),
                    disabledContentColor = TextSecondary
                ),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp)
            ) {
                Text(
                    text = "Devam et",
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp
                )
            }
        }
    }
}

@Composable
private fun ConsentRow(
    document: ConsentDocument,
    isAccepted: Boolean,
    onToggle: () -> Unit,
    onRead: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(DarkSurface.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(modifier = Modifier.clickable(onClick = onToggle)) {
            Checkbox(isChecked = isAccepted)
        }

        Spacer(modifier = Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = document.title,
                color = TextPrimary,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = "Oku ve onayla",
                color = TextSecondary.copy(alpha = 0.45f),
                fontSize = 12.sp
            )
        }

        Button(
            onClick = onRead,
            colors = ButtonDefaults.buttonColors(
                containerColor = TextSecondary.copy(alpha = 0.12f),
                contentColor = TextSecondary
            ),
            shape = RoundedCornerShape(50)
        ) {
            Icon(
                imageVector = Icons.Default.Description,
                contentDescription = null,
                modifier = Modifier.size(14.dp)
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text("Oku", fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun Checkbox(isChecked: Boolean) {
    val bgColor by animateColorAsState(
        targetValue = if (isChecked) Color.White else Color.Transparent,
        label = "checkbox"
    )
    val borderColor by animateColorAsState(
        targetValue = if (isChecked) Color.White else TextSecondary.copy(alpha = 0.3f),
        label = "border"
    )

    Box(
        modifier = Modifier
            .size(22.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(bgColor)
            .then(
                if (!isChecked) Modifier.background(Color.Transparent)
                else Modifier
            ),
        contentAlignment = Alignment.Center
    ) {
        if (isChecked) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = null,
                tint = Color.Black,
                modifier = Modifier.size(14.dp)
            )
        }
        // Border
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(Color.Transparent)
        )
    }
}
