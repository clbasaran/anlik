package com.celalbasaran.stripmate.ui.screen.camera

import android.Manifest
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.component.VoiceRecordButton
import com.celalbasaran.stripmate.ui.theme.ErrorRed
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.SuccessGreen
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

@Composable
fun PreviewScreen(
    viewModel: CameraViewModel
) {
    val uiState by viewModel.uiState.collectAsState()
    val bitmap = uiState.capturedBitmap ?: return
    val context = LocalContext.current
    val snackbarHostState = remember { SnackbarHostState() }
    var hasMicPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        )
    }
    val micPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> hasMicPermission = granted }

    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearError()
        }
    }

    // Friend selection sheet
    if (uiState.showFriendSheet) {
        FriendSelectionSheet(
            friends = uiState.availableFriends,
            selectedIds = uiState.selectedReceiverIds,
            comment = uiState.initialComment,
            isUploading = uiState.isUploading,
            onToggleFriend = { viewModel.toggleFriendSelection(it) },
            onCommentChange = { viewModel.updateComment(it) },
            onSend = { viewModel.sendPhoto() },
            onDismiss = { viewModel.hideFriendSheet() }
        )
    }

    Box(modifier = Modifier.fillMaxSize()) {
        // Full-screen captured image
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = "Çekilen fotoğraf",
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )

        // Top-left: X retake button
        IconButton(
            onClick = { viewModel.retakePhoto() },
            modifier = Modifier
                .padding(top = 48.dp, start = 16.dp)
                .align(Alignment.TopStart)
        ) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Tekrar çek",
                tint = Color.White,
                modifier = Modifier.size(32.dp)
            )
        }

        // Bottom bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .background(PureBlack.copy(alpha = 0.6f))
                .padding(horizontal = 24.dp, vertical = 20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Voice record button
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                VoiceRecordButton(
                    isRecording = uiState.isRecording,
                    onStartRecording = {
                        if (hasMicPermission) {
                            viewModel.startRecording(context)
                        } else {
                            micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                        }
                    },
                    onStopRecording = { viewModel.stopRecording() }
                )

                if (uiState.voiceData != null && !uiState.isRecording) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Ses kaydedildi",
                        color = SuccessGreen,
                        style = MaterialTheme.typography.labelSmall,
                        fontSize = 10.sp
                    )
                }
            }

            // Send button
            Button(
                onClick = { viewModel.showFriendSheet() },
                enabled = !uiState.isUploading,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White,
                    contentColor = Color.Black,
                    disabledContainerColor = Color.White.copy(alpha = 0.3f)
                ),
                shape = RoundedCornerShape(28.dp),
                modifier = Modifier.height(48.dp)
            ) {
                if (uiState.isUploading) {
                    CircularProgressIndicator(
                        color = Color.Black,
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "gönderiliyor...",
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    )
                } else {
                    Text(
                        text = "gönder",
                        fontWeight = FontWeight.Bold,
                        fontSize = 15.sp
                    )
                }
            }
        }

        // Snackbar
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 100.dp, start = 16.dp, end = 16.dp)
        ) { data ->
            Snackbar(
                snackbarData = data,
                containerColor = ErrorRed,
                contentColor = Color.White,
                shape = RoundedCornerShape(12.dp)
            )
        }
    }
}
