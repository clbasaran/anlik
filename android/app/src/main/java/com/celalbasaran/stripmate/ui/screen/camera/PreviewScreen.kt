package com.celalbasaran.stripmate.ui.screen.camera

import android.Manifest
import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material.icons.filled.Save
import androidx.compose.material.icons.filled.Check
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.component.VideoPlayerView
import com.celalbasaran.stripmate.ui.component.VoiceRecordButton
import com.celalbasaran.stripmate.ui.theme.ErrorRed
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.SuccessGreen
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import androidx.compose.ui.text.font.FontFamily

@Composable
fun PreviewScreen(
    viewModel: CameraViewModel
) {
    val uiState by viewModel.uiState.collectAsState()
    // Need either a photo or video to show preview
    if (uiState.capturedBitmap == null && uiState.capturedVideoUri == null) return
    val context = LocalContext.current
    val view = LocalView.current

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
        // Full-screen captured content (video or image)
        if (uiState.capturedVideoUri != null) {
            VideoPlayerView(
                uri = uiState.capturedVideoUri!!,
                modifier = Modifier.fillMaxSize(),
                startMuted = false
            )
        } else if (uiState.capturedBitmap != null) {
            Image(
                bitmap = uiState.capturedBitmap!!.asImageBitmap(),
                contentDescription = "Cekilen fotograf",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        }

        // Video duration label
        if (uiState.isVideoMode) {
            Text(
                text = String.format("%.1fs", uiState.videoDuration),
                color = Color.White,
                fontSize = 12.sp,
                fontFamily = FontFamily.Monospace,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(16.dp)
                    .background(Color.Black.copy(alpha = 0.5f), RoundedCornerShape(4.dp))
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            )
        }

        // Top-left: X retake button
        IconButton(
            onClick = { view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK); viewModel.retakePhoto() },
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

        // "galeriye kaydedildi" toast
        AnimatedVisibility(
            visible = uiState.showSavedToast,
            enter = fadeIn() + scaleIn(),
            exit = fadeOut() + scaleOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 140.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .background(
                        color = Color.Black.copy(alpha = 0.6f),
                        shape = RoundedCornerShape(50)
                    )
                    .padding(horizontal = 16.dp, vertical = 10.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(14.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "galeriye kaydedildi",
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        // Secret label (shown above bottom bar when active)
        AnimatedVisibility(
            visible = uiState.isSecret,
            enter = fadeIn() + scaleIn(),
            exit = fadeOut() + scaleOut(),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 100.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .background(
                        color = Color.White.copy(alpha = 0.15f),
                        shape = RoundedCornerShape(50)
                    )
                    .padding(horizontal = 14.dp, vertical = 6.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(12.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "gizli an",
                    color = Color.White,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        // Bottom bar
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
        ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(PureBlack.copy(alpha = 0.6f))
                .padding(horizontal = 24.dp, vertical = 20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Save to gallery button
                IconButton(
                    onClick = { view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK); viewModel.saveToGallery(context) },
                    enabled = !uiState.isSavingToGallery && !uiState.isUploading && !uiState.showSuccess,
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.12f))
                ) {
                    if (uiState.isSavingToGallery) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Default.Save,
                            contentDescription = "kaydet",
                            tint = Color.White,
                            modifier = Modifier.size(18.dp)
                        )
                    }
                }

                // Voice record button (hidden for video mode)
                if (!uiState.isVideoMode) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        VoiceRecordButton(
                            isRecording = uiState.isRecording,
                            onStartRecording = {
                                view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                if (hasMicPermission) {
                                    viewModel.startRecording(context)
                                } else {
                                    micPermissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                                }
                            },
                            onStopRecording = { view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK); viewModel.stopRecording() }
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
                }

                // Secret toggle button
                IconButton(
                    onClick = { view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK); viewModel.toggleSecret() },
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(
                            if (uiState.isSecret) Color.White
                            else Color.White.copy(alpha = 0.12f)
                        )
                ) {
                    Icon(
                        imageVector = if (uiState.isSecret) Icons.Default.Lock else Icons.Default.LockOpen,
                        contentDescription = if (uiState.isSecret) "Gizli an acik" else "Gizli an kapali",
                        tint = if (uiState.isSecret) Color.Black else Color.White.copy(alpha = 0.6f),
                        modifier = Modifier.size(20.dp)
                    )
                }

                // Collage button
                IconButton(
                    onClick = { view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK); viewModel.startCollage() },
                    enabled = !uiState.isUploading && !uiState.showSuccess,
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.12f))
                ) {
                    Icon(
                        imageVector = Icons.Default.GridView,
                        contentDescription = "Kolaj",
                        tint = Color.White.copy(alpha = 0.6f),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            // Send button
            Button(
                    onClick = { view.performHapticFeedback(HapticFeedbackConstants.CONFIRM); viewModel.showFriendSheet() },
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
            } // end Button
        } // end outer Row
        } // end Column (bottom bar)

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
