package com.celalbasaran.stripmate.ui.screen.camera

import android.Manifest
import android.util.Log
import android.view.HapticFeedbackConstants
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.SurfaceOrientedMeteringPointFactory
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import coil.compose.AsyncImage
import coil.request.ImageRequest
import androidx.compose.ui.layout.ContentScale
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Cameraswitch
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FlashAuto
import androidx.compose.material.icons.filled.FlashOff
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.hilt.navigation.compose.hiltViewModel
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.SuccessGreen
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.ui.theme.WarningYellow
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Flash mode enum matching iOS (off -> on -> auto)
enum class FlashMode(val label: String) {
    OFF("Kapali"),
    ON("Acik"),
    AUTO("Otomatik");

    fun next(): FlashMode = when (this) {
        OFF -> ON
        ON -> AUTO
        AUTO -> OFF
    }

    fun toImageCaptureMode(): Int = when (this) {
        OFF -> ImageCapture.FLASH_MODE_OFF
        ON -> ImageCapture.FLASH_MODE_ON
        AUTO -> ImageCapture.FLASH_MODE_AUTO
    }
}

@Composable
fun CameraScreen(
    viewModel: CameraViewModel = hiltViewModel(),
    onNavigateToSettings: (() -> Unit)? = null,
    onPreviewStateChange: ((Boolean) -> Unit)? = null
) {
    val uiState by viewModel.uiState.collectAsState()

    // Notify parent when preview mode changes (to hide tab bar)
    LaunchedEffect(uiState.capturedBitmap, uiState.capturedVideoUri, uiState.showSuccess) {
        onPreviewStateChange?.invoke(uiState.capturedBitmap != null || uiState.capturedVideoUri != null || uiState.showSuccess)
    }
    var hasCameraPermission by remember { mutableStateOf(false) }
    val context = LocalContext.current

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> hasCameraPermission = granted }

    LaunchedEffect(Unit) {
        hasCameraPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.CAMERA
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        if (!hasCameraPermission) {
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    when {
        uiState.capturedBitmap != null -> {
            PreviewScreen(viewModel = viewModel)
        }
        uiState.showSuccess -> {
            SuccessOverlay()
        }
        hasCameraPermission -> {
            CameraPreviewContent(
                viewModel = viewModel,
                onNavigateToSettings = onNavigateToSettings
            )
        }
        else -> {
            CameraPermissionRequired(
                onRequest = { permissionLauncher.launch(Manifest.permission.CAMERA) }
            )
        }
    }
}

@Composable
private fun CameraPreviewContent(
    viewModel: CameraViewModel,
    onNavigateToSettings: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val view = LocalView.current
    val uiState by viewModel.uiState.collectAsState()

    // Camera state — restore last used lens
    var lensFacing by remember { mutableIntStateOf(viewModel.getSavedLensFacing()) }
    var flashMode by remember { mutableStateOf(FlashMode.OFF) }
    var imageCapture by remember { mutableStateOf<ImageCapture?>(null) }
    var camera by remember { mutableStateOf<Camera?>(null) }

    // Exposure
    var exposureBias by remember { mutableFloatStateOf(0f) }
    var showExposureSlider by remember { mutableStateOf(false) }

    // Focus ring
    var focusPoint by remember { mutableStateOf<Offset?>(null) }
    var showFocusRing by remember { mutableStateOf(false) }
    val focusRingAlpha = remember { Animatable(0f) }
    val focusRingScale = remember { Animatable(1.5f) }

    // Profile
    val profileAvatarUrl = uiState.profileAvatarUrl
    val profileInitial = uiState.profileDisplayName?.firstOrNull()?.uppercase() ?: "?"

    val previewView = remember {
        PreviewView(context).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
    }

    // Save lens preference when changed
    LaunchedEffect(lensFacing) {
        viewModel.saveLensFacing(lensFacing == CameraSelector.LENS_FACING_FRONT)
    }

    // Camera binding - only rebind when lens facing changes
    DisposableEffect(lensFacing) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            val rotation = (context as? android.app.Activity)?.windowManager?.defaultDisplay?.rotation
                ?: android.view.Surface.ROTATION_0

            val preview = Preview.Builder()
                .setTargetRotation(rotation)
                .build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }

            val capture = ImageCapture.Builder()
                .setTargetRotation(rotation)
                .setFlashMode(flashMode.toImageCaptureMode())
                .build()
            imageCapture = capture

            val cameraSelector = CameraSelector.Builder()
                .requireLensFacing(lensFacing)
                .build()

            try {
                cameraProvider.unbindAll()
                val cam = cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    preview,
                    capture
                )
                camera = cam
            } catch (e: Exception) {
                Log.e("CameraScreen", "Camera bind failed", e)
            }
        }, ContextCompat.getMainExecutor(context))

        onDispose {
            // Don't unbindAll here - let lifecycle handle it
        }
    }

    // Update flash mode without rebinding camera
    LaunchedEffect(flashMode) {
        imageCapture?.flashMode = flashMode.toImageCaptureMode()
    }

    // Exposure bias update
    LaunchedEffect(exposureBias, camera) {
        val cam = camera ?: return@LaunchedEffect
        val cameraInfo = cam.cameraInfo
        val range = cameraInfo.exposureState.exposureCompensationRange
        val step = cameraInfo.exposureState.exposureCompensationStep.toFloat()
        if (step > 0f) {
            val index = (exposureBias / step).toInt().coerceIn(range.lower, range.upper)
            cam.cameraControl.setExposureCompensationIndex(index)
        }
    }

    // Focus ring animation
    LaunchedEffect(showFocusRing) {
        if (showFocusRing) {
            launch {
                focusRingAlpha.snapTo(1f)
                focusRingScale.snapTo(1.5f)
                focusRingScale.animateTo(1f, tween(200))
            }
            delay(1000)
            focusRingAlpha.animateTo(0f, tween(300))
            showFocusRing = false
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        // Camera preview - full screen
        AndroidView(
            factory = { previewView },
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    detectTapGestures(
                        onDoubleTap = {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            // Double tap to flip camera
                            lensFacing =
                                if (lensFacing == CameraSelector.LENS_FACING_BACK)
                                    CameraSelector.LENS_FACING_FRONT
                                else
                                    CameraSelector.LENS_FACING_BACK
                        },
                        onTap = { offset ->
                            // Focus on tap
                            focusPoint = offset
                            showFocusRing = true

                            // Trigger autofocus at tapped point
                            camera?.let { cam ->
                                val factory = SurfaceOrientedMeteringPointFactory(
                                    size.width.toFloat(),
                                    size.height.toFloat()
                                )
                                val point = factory.createPoint(offset.x, offset.y)
                                val action = FocusMeteringAction.Builder(point).build()
                                cam.cameraControl.startFocusAndMetering(action)
                            }
                        }
                    )
                }
        )

        // Focus ring overlay
        if (showFocusRing) {
            focusPoint?.let { point ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .drawBehind {
                            drawCircle(
                                color = Color.Yellow,
                                radius = 35.dp.toPx() * focusRingScale.value,
                                center = point,
                                style = Stroke(width = 1.5.dp.toPx()),
                                alpha = focusRingAlpha.value
                            )
                        }
                )
            }
        }

        // ===== HUD OVERLAY =====
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
        ) {
            // ── Top Row: Profile pill (left) | Friends count (center) | Flash (right) ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Profile avatar button (top-left)
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.08f))
                        .border(0.5.dp, Color.White.copy(alpha = 0.12f), CircleShape)
                        .clickable {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            onNavigateToSettings?.invoke()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    if (!profileAvatarUrl.isNullOrBlank()) {
                        AsyncImage(
                            model = ImageRequest.Builder(LocalContext.current)
                                .data(profileAvatarUrl)
                                .crossfade(true)
                                .build(),
                            contentDescription = "Profil",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(44.dp)
                                .clip(CircleShape)
                        )
                    } else {
                        Text(
                            text = profileInitial,
                            color = Color.White,
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }

                Spacer(modifier = Modifier.weight(1f))

                // Friends count pill (center)
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(50))
                        .background(Color.White.copy(alpha = 0.12f))
                        .border(0.5.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(50))
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Person,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "${uiState.availableFriends.size} arkadaş",
                        color = Color.White,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                // Notification bell (top-right) - placeholder for symmetry
                Spacer(modifier = Modifier.size(44.dp))
            }

            Spacer(modifier = Modifier.weight(1f))

            // ── Bottom HUD: Flash (left), Shutter (center), Exposure (right) - iOS layout ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 32.dp)
                    .padding(bottom = 140.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                // Left: Flash toggle (like iOS)
                IconButton(
                    onClick = {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        flashMode = flashMode.next()
                    },
                    modifier = Modifier
                        .size(50.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.12f))
                        .border(0.5.dp, Color.White.copy(alpha = 0.12f), CircleShape)
                ) {
                    Icon(
                        imageVector = when (flashMode) {
                            FlashMode.OFF -> Icons.Default.FlashOff
                            FlashMode.ON -> Icons.Default.FlashOn
                            FlashMode.AUTO -> Icons.Default.FlashAuto
                        },
                        contentDescription = "Flas: ${flashMode.label}",
                        tint = if (flashMode == FlashMode.OFF) Color.White else WarningYellow,
                        modifier = Modifier.size(22.dp)
                    )
                }

                // Center: Shutter button (tap to capture, long-press to record video)
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    // REC indicator
                    if (uiState.isRecordingVideo) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Box(Modifier.size(8.dp).background(Color.Red, CircleShape))
                            Text(
                                text = String.format("%.1fs", uiState.videoDuration),
                                color = Color.White,
                                fontSize = 14.sp,
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }

                    Box(contentAlignment = Alignment.Center) {
                        // Progress ring during recording
                        if (uiState.isRecordingVideo) {
                            CircularProgressIndicator(
                                progress = { uiState.videoRecordingProgress },
                                modifier = Modifier.size(84.dp),
                                color = Color.Red,
                                strokeWidth = 4.dp,
                                trackColor = Color.Transparent
                            )
                        }

                        // Outer ring
                        Box(
                            modifier = Modifier
                                .size(78.dp)
                                .border(2.5.dp, Color.White.copy(alpha = 0.8f), CircleShape)
                        )

                        // Inner circle with tap + long press
                        val innerSize by animateDpAsState(
                            targetValue = if (uiState.isRecordingVideo) 72.dp else 62.dp,
                            label = "shutter_size"
                        )
                        val innerColor by animateColorAsState(
                            targetValue = if (uiState.isRecordingVideo) Color.Red else Color.White,
                            label = "shutter_color"
                        )
                        Box(
                            modifier = Modifier
                                .size(innerSize)
                                .background(innerColor, CircleShape)
                                .pointerInput(Unit) {
                                    detectTapGestures(
                                        onTap = {
                                            if (uiState.isRecordingVideo) {
                                                viewModel.stopVideoRecording()
                                            } else if (uiState.capturedBitmap == null && uiState.capturedVideoUri == null) {
                                                view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                                                performCapture(
                                                    imageCapture, viewModel, context,
                                                    isFrontCamera = lensFacing == CameraSelector.LENS_FACING_FRONT
                                                )
                                            }
                                        },
                                        onLongPress = {
                                            if (uiState.capturedBitmap == null && uiState.capturedVideoUri == null) {
                                                view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                                                viewModel.startVideoRecording(context)
                                            }
                                        }
                                    )
                                }
                        )
                    }
                }

                // Right: Exposure toggle (like iOS)
                IconButton(
                    onClick = {
                        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        showExposureSlider = !showExposureSlider
                    },
                    modifier = Modifier
                        .size(50.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.12f))
                        .border(0.5.dp, Color.White.copy(alpha = 0.12f), CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.WbSunny,
                        contentDescription = "Pozlama",
                        tint = if (showExposureSlider || exposureBias != 0f)
                            WarningYellow else Color.White,
                        modifier = Modifier.size(22.dp)
                    )
                }
            }
        }

        // ── Vertical Exposure Slider (right side) ──
        AnimatedVisibility(
            visible = showExposureSlider,
            enter = slideInHorizontally(initialOffsetX = { it }) + fadeIn(),
            exit = slideOutHorizontally(targetOffsetX = { it }) + fadeOut(),
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 16.dp)
        ) {
            Column(
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(Color.Black.copy(alpha = 0.5f))
                    .border(0.5.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(20.dp))
                    .padding(horizontal = 8.dp, vertical = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                // Sun icon (bright)
                Icon(
                    imageVector = Icons.Default.WbSunny,
                    contentDescription = null,
                    tint = WarningYellow,
                    modifier = Modifier.size(16.dp)
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Vertical slider (rotated horizontal)
                Box(
                    modifier = Modifier
                        .width(30.dp)
                        .height(180.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Slider(
                        value = exposureBias,
                        onValueChange = { exposureBias = it },
                        valueRange = -2f..2f,
                        steps = 39,
                        modifier = Modifier
                            .width(180.dp)
                            .rotate(-90f),
                        colors = SliderDefaults.colors(
                            thumbColor = WarningYellow,
                            activeTrackColor = WarningYellow,
                            inactiveTrackColor = Color.White.copy(alpha = 0.3f)
                        )
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Sun icon (dim)
                Icon(
                    imageVector = Icons.Default.WbSunny,
                    contentDescription = null,
                    tint = Color.White.copy(alpha = 0.4f),
                    modifier = Modifier.size(12.dp)
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Reset button
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(
                            if (exposureBias == 0f) Color.White.copy(alpha = 0.15f)
                            else WarningYellow.copy(alpha = 0.3f)
                        )
                        .clickable {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            exposureBias = 0f
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "0",
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.ExtraBold
                    )
                }
            }
        }
    }
}

private fun performCapture(
    imageCapture: ImageCapture?,
    viewModel: CameraViewModel,
    context: android.content.Context,
    isFrontCamera: Boolean = false
) {
    val capture = imageCapture ?: return

    // Get screen aspect ratio for cropping (to match iOS full-screen photo)
    val displayMetrics = context.resources.displayMetrics
    val screenWidth = displayMetrics.widthPixels
    val screenHeight = displayMetrics.heightPixels
    val screenRatio = screenHeight.toFloat() / screenWidth.toFloat()

    capture.takePicture(
        ContextCompat.getMainExecutor(context),
        object : ImageCapture.OnImageCapturedCallback() {
            override fun onCaptureSuccess(image: ImageProxy) {
                val rotationDegrees = image.imageInfo.rotationDegrees
                val rawBitmap = image.toBitmap()
                image.close()

                // Step 1: Apply rotation and mirror
                val matrix = android.graphics.Matrix()
                if (rotationDegrees != 0) {
                    matrix.postRotate(rotationDegrees.toFloat())
                }
                if (isFrontCamera) {
                    matrix.postScale(-1f, 1f)
                }
                val needsTransform = rotationDegrees != 0 || isFrontCamera
                val rotated = if (needsTransform) {
                    android.graphics.Bitmap.createBitmap(
                        rawBitmap, 0, 0,
                        rawBitmap.width, rawBitmap.height,
                        matrix, true
                    )
                } else {
                    rawBitmap
                }

                // Step 2: Crop to screen aspect ratio (like iOS full-screen photo)
                val bw = rotated.width
                val bh = rotated.height
                val bitmapRatio = bh.toFloat() / bw.toFloat()

                val cropped = if (bitmapRatio < screenRatio) {
                    // Bitmap is wider than screen → crop width (center crop)
                    val targetWidth = (bh / screenRatio).toInt()
                    val xOffset = (bw - targetWidth) / 2
                    android.graphics.Bitmap.createBitmap(rotated, xOffset, 0, targetWidth, bh)
                } else if (bitmapRatio > screenRatio) {
                    // Bitmap is taller than screen → crop height (center crop)
                    val targetHeight = (bw * screenRatio).toInt()
                    val yOffset = (bh - targetHeight) / 2
                    android.graphics.Bitmap.createBitmap(rotated, 0, yOffset, bw, targetHeight)
                } else {
                    rotated
                }

                viewModel.captureFromBitmap(cropped)
            }

            override fun onError(exception: androidx.camera.core.ImageCaptureException) {
                Log.e("CameraScreen", "Capture failed", exception)
            }
        }
    )
}

@Composable
private fun SuccessOverlay() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = "gonderildi",
                tint = SuccessGreen,
                modifier = Modifier.size(64.dp)
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Gonderildi!",
                color = TextPrimary,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun CameraPermissionRequired(onRequest: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                imageVector = Icons.Default.CameraAlt,
                contentDescription = "kamera",
                tint = TextPrimary,
                modifier = Modifier.size(64.dp)
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Kamera izni gerekli",
                color = TextPrimary,
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Fotoğraf çekmek icin\nkamera iznine ihtiyacımız var",
                color = TextSecondary,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(24.dp))
            androidx.compose.material3.Button(
                onClick = onRequest,
                colors = androidx.compose.material3.ButtonDefaults.buttonColors(
                    containerColor = Color.White,
                    contentColor = Color.Black
                ),
                shape = RoundedCornerShape(28.dp)
            ) {
                Text("Izin Ver", fontWeight = FontWeight.Bold)
            }
        }
    }
}
