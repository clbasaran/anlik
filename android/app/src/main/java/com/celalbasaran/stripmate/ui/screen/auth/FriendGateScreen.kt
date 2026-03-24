package com.celalbasaran.stripmate.ui.screen.auth

import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.component.UserAvatar
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.ErrorRed
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.SuccessGreen
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter

@Composable
fun FriendGateScreen(
    viewModel: AuthViewModel,
    onGatePassed: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val clipboardManager = LocalClipboardManager.current
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.fetchPendingRequests()
    }

    LaunchedEffect(uiState.friendGatePassed) {
        if (uiState.friendGatePassed) {
            onGatePassed()
        }
    }

    // Check gate status on any relevant change
    LaunchedEffect(uiState.requestSent, uiState.codeShared, uiState.friendGatePassed) {
        viewModel.checkFriendGateStatus()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp)
    ) {
        Spacer(modifier = Modifier.height(60.dp))

        // Header
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Icon(
                imageVector = Icons.Default.PersonAdd,
                contentDescription = null,
                tint = TextPrimary,
                modifier = Modifier.size(48.dp)
            )

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "arkadaşını ekle",
                color = TextPrimary,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(12.dp))

            // Info box
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = DarkSurface
                ),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    text = "Devam etmek için en az bir arkadaş ekle, davet kodunu paylaş veya gelen isteği kabul et.",
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(16.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Search by invite code
        Text(
            text = "Davet Kodu ile Ara",
            color = TextPrimary,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.titleSmall
        )

        Spacer(modifier = Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = uiState.searchCode,
                onValueChange = { viewModel.updateSearchCode(it) },
                placeholder = { Text("8 haneli kod") },
                singleLine = true,
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

            Button(
                onClick = { viewModel.searchByInviteCode() },
                enabled = !uiState.isSearching && uiState.searchCode.length == 8,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White,
                    contentColor = Color.Black,
                    disabledContainerColor = DarkSurfaceVariant
                ),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.height(56.dp)
            ) {
                if (uiState.isSearching) {
                    CircularProgressIndicator(
                        color = Color.Black,
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp
                    )
                } else {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Ara"
                    )
                }
            }
        }

        // Search error
        if (uiState.searchError != null) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = uiState.searchError!!,
                color = ErrorRed,
                style = MaterialTheme.typography.labelSmall
            )
        }

        // Found user card
        if (uiState.searchedUser != null) {
            Spacer(modifier = Modifier.height(12.dp))
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
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    UserAvatar(
                        imageUrl = uiState.searchedUser!!.avatarUrl,
                        displayName = uiState.searchedUser!!.displayName,
                        size = 48.dp
                    )

                    Spacer(modifier = Modifier.width(12.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = uiState.searchedUser!!.displayName ?: "",
                            color = TextPrimary,
                            fontWeight = FontWeight.SemiBold,
                            style = MaterialTheme.typography.bodyLarge
                        )
                        uiState.searchedUser!!.username?.let { username ->
                            Text(
                                text = "@$username",
                                color = TextSecondary,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }

                    Button(
                        onClick = { viewModel.sendFriendRequest(uiState.searchedUser!!.id) },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = StripMateBlue
                        ),
                        shape = RoundedCornerShape(20.dp)
                    ) {
                        Text(
                            text = "ekle",
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
        }

        // Request sent indicator
        if (uiState.requestSent) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Arkadaşlık isteği gönderildi!",
                color = SuccessGreen,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Medium
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        HorizontalDivider(color = DarkSurfaceVariant)

        Spacer(modifier = Modifier.height(32.dp))

        // Share section
        Text(
            text = "Kodunu Paylas",
            color = TextPrimary,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.titleSmall
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Own code display
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
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        text = "Senin kodun",
                        color = TextSecondary,
                        style = MaterialTheme.typography.labelSmall
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = uiState.inviteCode.ifEmpty { "--------" },
                        color = TextPrimary,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 3.sp
                    )
                }

                Row {
                    // Copy button
                    IconButton(
                        onClick = {
                            clipboardManager.setText(AnnotatedString(uiState.inviteCode))
                        }
                    ) {
                        Icon(
                            imageVector = Icons.Default.ContentCopy,
                            contentDescription = "Kopyala",
                            tint = TextSecondary
                        )
                    }

                    // QR button
                    IconButton(
                        onClick = { viewModel.toggleQROverlay() }
                    ) {
                        Icon(
                            imageVector = Icons.Default.QrCode,
                            contentDescription = "QR Kod",
                            tint = TextSecondary
                        )
                    }

                    // Share button
                    IconButton(
                        onClick = {
                            val sendIntent = Intent().apply {
                                action = Intent.ACTION_SEND
                                putExtra(
                                    Intent.EXTRA_TEXT,
                                    "anlik. uygulamasinda beni ekle! Davet kodum: ${uiState.inviteCode}\n\nUygulamayi indir:\niOS: https://apps.apple.com/tr/app/anlik/id6759793761?l=tr\nAndroid: https://celalbasaran.com/anlik"
                                )
                                type = "text/plain"
                            }
                            context.startActivity(Intent.createChooser(sendIntent, "Davet kodunu paylas"))
                            viewModel.markCodeShared()
                        }
                    ) {
                        Icon(
                            imageVector = Icons.Default.Share,
                            contentDescription = "Paylas",
                            tint = TextSecondary
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Share action buttons row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            // WhatsApp share
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(
                    onClick = {
                        val text = "anlik. uygulamasinda beni ekle! Davet kodum: ${uiState.inviteCode}\n\nUygulamayi indir:\niOS: https://apps.apple.com/tr/app/anlik/id6759793761?l=tr\nAndroid: https://celalbasaran.com/anlik"
                        val encoded = java.net.URLEncoder.encode(text, "UTF-8")
                        val whatsappIntent = Intent(Intent.ACTION_VIEW).apply {
                            data = android.net.Uri.parse("https://wa.me/?text=$encoded")
                        }
                        try {
                            context.startActivity(whatsappIntent)
                            viewModel.markCodeShared()
                        } catch (_: Exception) {
                            // WhatsApp not installed, fall through to generic share
                            val sendIntent = Intent().apply {
                                action = Intent.ACTION_SEND
                                putExtra(Intent.EXTRA_TEXT, text)
                                type = "text/plain"
                            }
                            context.startActivity(Intent.createChooser(sendIntent, "Davet kodunu paylas"))
                            viewModel.markCodeShared()
                        }
                    },
                    modifier = Modifier
                        .size(56.dp)
                        .background(
                            color = DarkSurface,
                            shape = CircleShape
                        )
                ) {
                    Icon(
                        imageVector = Icons.Default.Share,
                        contentDescription = "WhatsApp",
                        tint = TextPrimary,
                        modifier = Modifier.size(24.dp)
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "WhatsApp",
                    color = TextSecondary.copy(alpha = 0.5f),
                    style = MaterialTheme.typography.labelSmall
                )
            }

            // QR Code
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(
                    onClick = { viewModel.toggleQROverlay() },
                    modifier = Modifier
                        .size(56.dp)
                        .background(
                            color = DarkSurface,
                            shape = CircleShape
                        )
                ) {
                    Icon(
                        imageVector = Icons.Default.QrCode,
                        contentDescription = "QR Kod",
                        tint = TextPrimary,
                        modifier = Modifier.size(24.dp)
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "QR Kod",
                    color = TextSecondary.copy(alpha = 0.5f),
                    style = MaterialTheme.typography.labelSmall
                )
            }

            // Generic share
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(
                    onClick = {
                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(
                                Intent.EXTRA_TEXT,
                                "anlik. uygulamasinda beni ekle! Davet kodum: ${uiState.inviteCode}\n\nUygulamayi indir:\niOS: https://apps.apple.com/tr/app/anlik/id6759793761?l=tr\nAndroid: https://celalbasaran.com/anlik"
                            )
                            type = "text/plain"
                        }
                        context.startActivity(Intent.createChooser(sendIntent, "Davet kodunu paylas"))
                        viewModel.markCodeShared()
                    },
                    modifier = Modifier
                        .size(56.dp)
                        .background(
                            color = DarkSurface,
                            shape = CircleShape
                        )
                ) {
                    Icon(
                        imageVector = Icons.Default.Share,
                        contentDescription = "Diger",
                        tint = TextPrimary,
                        modifier = Modifier.size(24.dp)
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Diger",
                    color = TextSecondary.copy(alpha = 0.5f),
                    style = MaterialTheme.typography.labelSmall
                )
            }
        }

        Spacer(modifier = Modifier.height(32.dp))

        HorizontalDivider(color = DarkSurfaceVariant)

        Spacer(modifier = Modifier.height(32.dp))

        // Pending requests
        if (uiState.pendingRequests.isNotEmpty()) {
            Text(
                text = "Gelen Istekler",
                color = TextPrimary,
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.titleSmall
            )

            Spacer(modifier = Modifier.height(12.dp))

            uiState.pendingRequests.forEach { friend ->
                Card(
                    colors = CardDefaults.cardColors(
                        containerColor = DarkSurface
                    ),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
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
                                fontWeight = FontWeight.SemiBold,
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
                            onClick = { viewModel.acceptFriendRequest(friend.userId) },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = SuccessGreen
                            ),
                            shape = RoundedCornerShape(20.dp)
                        ) {
                            Text(
                                text = "kabul et",
                                fontWeight = FontWeight.Bold,
                                color = Color.White
                            )
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(60.dp))
    }

    // QR Code Overlay
    if (uiState.showQROverlay && uiState.inviteCode.isNotEmpty()) {
        QRCodeOverlay(
            inviteCode = uiState.inviteCode,
            onDismiss = { viewModel.toggleQROverlay() }
        )
    }
    }
}

@Composable
private fun QRCodeOverlay(
    inviteCode: String,
    onDismiss: () -> Unit
) {
    val qrBitmap = remember(inviteCode) {
        generateFriendGateQRCode(inviteCode)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.95f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.clickable(enabled = false, onClick = {}) // prevent dismiss on content click
        ) {
            Text(
                text = "QR kodun",
                color = TextPrimary,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(24.dp))

            if (qrBitmap != null) {
                Box(
                    modifier = Modifier
                        .size(268.dp)
                        .background(Color.White, RoundedCornerShape(20.dp))
                        .padding(24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Image(
                        bitmap = qrBitmap.asImageBitmap(),
                        contentDescription = "QR Kod",
                        modifier = Modifier.fillMaxSize()
                    )
                }
            } else {
                Box(
                    modifier = Modifier
                        .size(268.dp)
                        .background(TextSecondary.copy(alpha = 0.1f), RoundedCornerShape(20.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "QR olusturulamadi",
                        color = TextSecondary,
                        fontSize = 13.sp
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            Text(
                text = inviteCode,
                color = TextPrimary,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 3.sp
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "arkadaşın bu kodu tarasın veya girsin",
                color = TextSecondary.copy(alpha = 0.4f),
                fontSize = 14.sp
            )

            Spacer(modifier = Modifier.height(24.dp))

            OutlinedButton(
                onClick = onDismiss,
                shape = RoundedCornerShape(50),
                colors = ButtonDefaults.outlinedButtonColors(
                    contentColor = TextPrimary
                )
            ) {
                Text(
                    text = "kapat",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 15.sp
                )
            }
        }
    }
}

private fun generateFriendGateQRCode(text: String): Bitmap? {
    return try {
        val writer = QRCodeWriter()
        val bitMatrix = writer.encode(text, BarcodeFormat.QR_CODE, 512, 512)
        val width = bitMatrix.width
        val height = bitMatrix.height
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
        for (x in 0 until width) {
            for (y in 0 until height) {
                bitmap.setPixel(
                    x, y,
                    if (bitMatrix[x, y]) android.graphics.Color.BLACK
                    else android.graphics.Color.WHITE
                )
            }
        }
        bitmap
    } catch (e: Exception) {
        null
    }
}
