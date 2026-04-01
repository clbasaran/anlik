package com.celalbasaran.stripmate.ui.screen.camera

import android.graphics.Bitmap
import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.data.model.CollageAspectRatio
import com.celalbasaran.stripmate.data.model.CollageBackground
import com.celalbasaran.stripmate.data.model.CollageCornerStyle
import com.celalbasaran.stripmate.data.model.CollageLayout
import com.celalbasaran.stripmate.data.model.PhotoTransform
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.util.CollageBuilder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

@Composable
fun CollageScreen(
    viewModel: CameraViewModel,
    onAddPhoto: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val photos = uiState.collagePhotos
    val selectedLayout = uiState.collageLayout
    val gap = uiState.collageGap
    val background = uiState.collageBackground
    val cornerStyle = uiState.collageCornerStyle
    val aspectRatio = uiState.collageAspectRatio
    val transforms = uiState.collageTransforms
    val view = LocalView.current

    val availableLayouts = remember(photos.size) {
        CollageLayout.layoutsFor(photos.size)
    }

    var previewReady by remember { mutableStateOf(false) }
    var showFinalizeTick by remember { mutableStateOf(false) }

    // Mark preview ready when we have enough photos
    LaunchedEffect(photos.size, selectedLayout) {
        previewReady = photos.size >= selectedLayout.photoCount
    }

    Box(modifier = Modifier.fillMaxSize().background(PureBlack)) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 48.dp, start = 16.dp, end = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { viewModel.cancelCollage() }) {
                    Icon(Icons.Default.Close, "Kapat", tint = Color.White, modifier = Modifier.size(28.dp))
                }

                Column(modifier = Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("kolaj", color = TextPrimary, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    Text(
                        "fotografi surukle",
                        color = TextSecondary.copy(alpha = 0.6f),
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium
                    )
                }

                Text(
                    "${photos.size}/4",
                    color = TextSecondary,
                    fontSize = 14.sp,
                    fontFamily = FontFamily.Monospace,
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Photo strip
            PhotoStrip(
                photos = photos,
                onSwap = { from, to ->
                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                    viewModel.swapCollagePhotos(from, to)
                },
                onRemove = { index ->
                    view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                    viewModel.removeFromCollage(index)
                },
                onReplace = { index ->
                    view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                    viewModel.setCollageReplaceIndex(index)
                    onAddPhoto()
                }
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Interactive collage preview
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = 24.dp),
                contentAlignment = Alignment.Center
            ) {
                if (previewReady) {
                    InteractiveCollagePreview(
                        photos = photos,
                        layout = selectedLayout,
                        gap = gap,
                        background = background,
                        cornerStyle = cornerStyle,
                        aspectRatio = aspectRatio,
                        transforms = transforms,
                        onTransformChanged = { index, transform ->
                            viewModel.setCollageTransform(index, transform)
                        }
                    )
                } else {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .aspectRatio(aspectRatio.ratio)
                            .background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(16.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            "${selectedLayout.photoCount - photos.size} foto daha ekle",
                            color = TextSecondary,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Aspect ratio picker
            AspectRatioPicker(
                selected = aspectRatio,
                onSelect = {
                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                    viewModel.setCollageAspectRatio(it)
                }
            )

            Spacer(modifier = Modifier.height(8.dp))

            // Layout selector
            if (availableLayouts.isNotEmpty()) {
                val thumbnailHeight = when (aspectRatio) {
                    CollageAspectRatio.PORTRAIT -> 56.dp
                    CollageAspectRatio.INSTAGRAM -> 40.dp
                    CollageAspectRatio.SQUARE -> 32.dp
                }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp)
                        .horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    availableLayouts.forEach { layout ->
                        val isSelected = layout == selectedLayout
                        Box(
                            modifier = Modifier
                                .size(width = 32.dp, height = thumbnailHeight)
                                .scale(if (isSelected) 1.1f else 1f)
                                .clip(RoundedCornerShape(6.dp))
                                .background(Color.Black)
                                .then(
                                    if (isSelected) Modifier.border(2.dp, Color.White.copy(alpha = 0.8f), RoundedCornerShape(6.dp))
                                    else Modifier.border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(6.dp))
                                )
                                .clickable {
                                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                                    viewModel.selectCollageLayout(layout)
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            LiveLayoutPreview(
                                layout = layout, photos = photos, aspectRatio = aspectRatio,
                                modifier = Modifier.fillMaxSize().padding(3.dp)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Gap slider
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Default.Add, null, tint = TextSecondary, modifier = Modifier.size(14.dp))
                Slider(
                    value = gap,
                    onValueChange = { viewModel.setCollageGap(it) },
                    valueRange = 0f..20f, steps = 19,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                    colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = Color.White, inactiveTrackColor = Color.White.copy(alpha = 0.2f))
                )
                Text("${gap.toInt()}px", color = TextSecondary, fontSize = 12.sp, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.Medium)
            }

            // Corner + Background row
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("kose", color = TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                Spacer(Modifier.width(6.dp))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .background(Color.White.copy(alpha = 0.1f))
                        .clickable {
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                            viewModel.setCollageCornerStyle(if (cornerStyle == CollageCornerStyle.SHARP) CollageCornerStyle.ROUNDED else CollageCornerStyle.SHARP)
                        }
                        .padding(horizontal = 10.dp, vertical = 5.dp)
                ) {
                    Text(if (cornerStyle == CollageCornerStyle.SHARP) "keskin" else "yumusak", color = Color.White.copy(alpha = 0.7f), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                }
                Spacer(Modifier.weight(1f))
                Text("arka plan", color = TextSecondary, fontSize = 12.sp, fontWeight = FontWeight.Medium)
                Spacer(Modifier.width(8.dp))
                BackgroundCircle(Color.Black, background == CollageBackground.BLACK) { view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK); viewModel.setCollageBackground(CollageBackground.BLACK) }
                Spacer(Modifier.width(8.dp))
                BackgroundCircleWhite(background == CollageBackground.WHITE) { view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK); viewModel.setCollageBackground(CollageBackground.WHITE) }
                Spacer(Modifier.width(8.dp))
                BackgroundCircleBlur(background == CollageBackground.BLUR_FILL) { view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK); viewModel.setCollageBackground(CollageBackground.BLUR_FILL) }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Bottom action bar
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (photos.size < 4) {
                    Button(
                        onClick = { view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP); onAddPhoto() },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.12f), contentColor = Color.White),
                        shape = RoundedCornerShape(28.dp),
                        modifier = Modifier.height(48.dp)
                    ) {
                        Icon(Icons.Default.Add, null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("foto ekle", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                } else {
                    Spacer(Modifier.width(1.dp))
                }

                Button(
                    onClick = {
                        view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                        showFinalizeTick = true
                        viewModel.finalizeCollage()
                    },
                    enabled = previewReady,
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = Color.Black, disabledContainerColor = Color.White.copy(alpha = 0.3f)),
                    shape = RoundedCornerShape(28.dp),
                    modifier = Modifier.height(48.dp)
                ) {
                    Text("kullan", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                    Spacer(Modifier.width(6.dp))
                    Icon(Icons.Default.Check, null, modifier = Modifier.size(18.dp))
                }
            }
        }

        // Finalize tick
        AnimatedVisibility(showFinalizeTick, enter = scaleIn(initialScale = 0.5f, animationSpec = spring(dampingRatio = 0.6f)) + fadeIn(), exit = fadeOut()) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.6f)), contentAlignment = Alignment.Center) {
                Icon(Icons.Default.Check, null, tint = Color.White, modifier = Modifier.size(72.dp))
            }
        }
    }
}

// ── Interactive Collage Preview ──────────────────────────────────────────

@Composable
private fun InteractiveCollagePreview(
    photos: List<Bitmap>,
    layout: CollageLayout,
    gap: Float,
    background: CollageBackground,
    cornerStyle: CollageCornerStyle,
    aspectRatio: CollageAspectRatio,
    transforms: Map<Int, PhotoTransform>,
    onTransformChanged: (Int, PhotoTransform) -> Unit
) {
    val cornerRadius = if (cornerStyle == CollageCornerStyle.ROUNDED) 16.dp else 0.dp

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(aspectRatio.ratio)
            .clip(RoundedCornerShape(16.dp))
    ) {
        val previewW = constraints.maxWidth.toFloat()
        val previewH = constraints.maxHeight.toFloat()
        val scaleX = previewW / aspectRatio.width
        val scaleY = previewH / aspectRatio.height
        val cells = CollageBuilder.getCells(layout, gap, aspectRatio)
        val density = LocalDensity.current
        val cornerRadiusPx = with(density) { cornerRadius.toPx() } * scaleX

        // Background
        when (background) {
            CollageBackground.BLACK -> Box(Modifier.fillMaxSize().background(Color.Black))
            CollageBackground.WHITE -> Box(Modifier.fillMaxSize().background(Color.White))
            CollageBackground.BLUR_FILL -> {
                if (photos.isNotEmpty()) {
                    Image(
                        bitmap = photos[0].asImageBitmap(),
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize().blur(30.dp)
                    )
                } else {
                    Box(Modifier.fillMaxSize().background(Color.Black))
                }
            }
        }

        // Photo cells
        cells.forEachIndexed { index, cellRect ->
            if (index < photos.size) {
                val left = cellRect.left * scaleX
                val top = cellRect.top * scaleY
                val cellW = cellRect.width() * scaleX
                val cellH = cellRect.height() * scaleY
                val transform = transforms[index] ?: PhotoTransform()

                InteractivePhotoCell(
                    bitmap = photos[index],
                    left = left,
                    top = top,
                    cellW = cellW,
                    cellH = cellH,
                    cornerRadius = cornerRadiusPx,
                    transform = transform,
                    onTransformChanged = { newTransform ->
                        onTransformChanged(index, newTransform)
                    }
                )
            }
        }
    }
}

@Composable
private fun InteractivePhotoCell(
    bitmap: Bitmap,
    left: Float,
    top: Float,
    cellW: Float,
    cellH: Float,
    cornerRadius: Float,
    transform: PhotoTransform,
    onTransformChanged: (PhotoTransform) -> Unit
) {
    val view = LocalView.current
    val density = LocalDensity.current
    val leftDp = with(density) { left.toDp() }
    val topDp = with(density) { top.toDp() }
    val cellWDp = with(density) { cellW.toDp() }
    val cellHDp = with(density) { cellH.toDp() }
    val cornerDp = with(density) { cornerRadius.toDp() }

    val bmpRatio = bitmap.width.toFloat() / bitmap.height.toFloat()
    val cellRatio = cellW / cellH

    // Base aspect-fill size
    val baseW: Float
    val baseH: Float
    if (bmpRatio > cellRatio) {
        baseH = cellH
        baseW = baseH * bmpRatio
    } else {
        baseW = cellW
        baseH = baseW / bmpRatio
    }

    // Accumulator for in-progress gesture
    var dragOffX by remember { mutableFloatStateOf(0f) }
    var dragOffY by remember { mutableFloatStateOf(0f) }
    var pinchScale by remember { mutableFloatStateOf(1f) }

    val totalScale = transform.scale * pinchScale
    val drawW = baseW * totalScale
    val drawH = baseH * totalScale
    val overflowX = ((drawW - cellW) / 2f).coerceAtLeast(1f)
    val overflowY = ((drawH - cellH) / 2f).coerceAtLeast(1f)

    val currentOffsetX = transform.offsetX * overflowX + dragOffX
    val currentOffsetY = transform.offsetY * overflowY + dragOffY

    Box(
        modifier = Modifier
            .offset(leftDp, topDp)
            .size(cellWDp, cellHDp)
            .clip(RoundedCornerShape(cornerDp))
            .pointerInput(Unit) {
                detectTransformGestures(
                    panZoomLock = false,
                    onGesture = { _, pan, zoom, _ ->
                        dragOffX += pan.x
                        dragOffY += pan.y
                        pinchScale *= zoom
                    }
                )
            }
            .pointerInput(Unit) {
                // Commit on gesture end — detectTransformGestures doesn't have onEnd,
                // so we detect up events
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        if (event.changes.all { !it.pressed }) {
                            // All pointers up — commit
                            val newScale = (transform.scale * pinchScale).coerceIn(1f, 3f)
                            val newDrawW = baseW * newScale
                            val newDrawH = baseH * newScale
                            val newOverflowX = ((newDrawW - cellW) / 2f).coerceAtLeast(1f)
                            val newOverflowY = ((newDrawH - cellH) / 2f).coerceAtLeast(1f)
                            val newOffX = (transform.offsetX + dragOffX / newOverflowX).coerceIn(-1f, 1f)
                            val newOffY = (transform.offsetY + dragOffY / newOverflowY).coerceIn(-1f, 1f)
                            onTransformChanged(PhotoTransform(newOffX, newOffY, newScale))
                            dragOffX = 0f
                            dragOffY = 0f
                            pinchScale = 1f
                            view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                        }
                    }
                }
            }
    ) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .graphicsLayer {
                    scaleX = totalScale
                    scaleY = totalScale
                    translationX = currentOffsetX
                    translationY = currentOffsetY
                }
                .fillMaxSize()
        )
    }
}

// ── Background Circles ──────────────────────────────────────────────────

@Composable
private fun BackgroundCircle(color: Color, isSelected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(CircleShape)
            .background(color)
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) Color.White else Color.White.copy(alpha = 0.2f), CircleShape)
            .clickable(onClick = onClick)
    )
}

@Composable
private fun BackgroundCircleWhite(isSelected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(CircleShape)
            .background(Color.White)
            .border(0.5.dp, Color.Black.copy(alpha = 0.3f), CircleShape)
            .then(if (isSelected) Modifier.border(2.dp, Color.White, CircleShape) else Modifier)
            .clickable(onClick = onClick)
    )
}

@Composable
private fun BackgroundCircleBlur(isSelected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(26.dp)
            .clip(CircleShape)
            .background(Brush.linearGradient(listOf(Color(0x99AA00FF), Color(0x660066FF), Color(0x4DFF6699))))
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) Color.White else Color.White.copy(alpha = 0.2f), CircleShape)
            .clickable(onClick = onClick)
    )
}

// ── Aspect Ratio Picker ─────────────────────────────────────────────────

@Composable
private fun AspectRatioPicker(selected: CollageAspectRatio, onSelect: (CollageAspectRatio) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
        horizontalArrangement = Arrangement.Center
    ) {
        Row(
            modifier = Modifier.background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(24.dp)).padding(3.dp),
            horizontalArrangement = Arrangement.Center
        ) {
            CollageAspectRatio.entries.forEach { ratio ->
                val isSelected = ratio == selected
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(if (isSelected) Color.White else Color.Transparent)
                        .clickable { onSelect(ratio) }
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(ratio.label, color = if (isSelected) Color.Black else Color.White.copy(alpha = 0.5f), fontSize = 13.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                }
            }
        }
    }
}

// ── Photo Strip ─────────────────────────────────────────────────────────

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PhotoStrip(
    photos: List<Bitmap>,
    onSwap: (Int, Int) -> Unit,
    onRemove: (Int) -> Unit,
    onReplace: (Int) -> Unit
) {
    LazyRow(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        itemsIndexed(photos) { index, photo ->
            var showMenu by remember { mutableStateOf(false) }
            Box {
                Image(
                    bitmap = photo.asImageBitmap(),
                    contentDescription = "Foto ${index + 1}",
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(60.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .border(1.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(12.dp))
                        .combinedClickable(
                            onClick = {
                                val next = (index + 1) % photos.size
                                if (next != index) onSwap(index, next)
                            },
                            onLongClick = { showMenu = true }
                        )
                )
                Box(
                    modifier = Modifier.size(18.dp).offset((-4).dp, (-4).dp).background(Color.White.copy(alpha = 0.9f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Text("${index + 1}", color = Color.Black, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold)
                }
                DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                    DropdownMenuItem(text = { Text("kaldir") }, onClick = { showMenu = false; onRemove(index) })
                    DropdownMenuItem(text = { Text("yeniden cek") }, onClick = { showMenu = false; onReplace(index) })
                }
            }
        }
    }
}

// ── Live Layout Preview ─────────────────────────────────────────────────

@Composable
private fun LiveLayoutPreview(
    layout: CollageLayout,
    photos: List<Bitmap>,
    aspectRatio: CollageAspectRatio,
    modifier: Modifier = Modifier
) {
    val imageBitmaps = remember(photos) { photos.map { it.asImageBitmap() } }

    Canvas(modifier = modifier) {
        val canvasW = size.width
        val canvasH = size.height
        val cells = CollageBuilder.getCells(layout, 1f, aspectRatio)
        val scaleX = canvasW / aspectRatio.width
        val scaleY = canvasH / aspectRatio.height

        for ((index, cellRect) in cells.withIndex()) {
            val left = cellRect.left * scaleX
            val top = cellRect.top * scaleY
            val right = cellRect.right * scaleX
            val bottom = cellRect.bottom * scaleY
            val cellW = right - left
            val cellH = bottom - top

            val path = Path().apply {
                addRoundRect(androidx.compose.ui.geometry.RoundRect(left, top, right, bottom, 2f, 2f))
            }

            if (index < imageBitmaps.size) {
                val bmp = imageBitmaps[index]
                val bmpRatio = bmp.width.toFloat() / bmp.height.toFloat()
                val cellRatio = cellW / cellH
                val dstLeft: Float; val dstTop: Float; val dstW: Float; val dstH: Float
                if (bmpRatio > cellRatio) {
                    dstH = cellH; dstW = dstH * bmpRatio
                    dstLeft = left + (cellW - dstW) / 2f; dstTop = top
                } else {
                    dstW = cellW; dstH = dstW / bmpRatio
                    dstLeft = left; dstTop = top + (cellH - dstH) / 2f
                }
                clipPath(path) {
                    drawImage(bmp, dstOffset = androidx.compose.ui.unit.IntOffset(dstLeft.toInt(), dstTop.toInt()), dstSize = androidx.compose.ui.unit.IntSize(dstW.toInt(), dstH.toInt()))
                }
            } else {
                clipPath(path) { drawRect(Color.White.copy(alpha = 0.1f), Offset(left, top), Size(cellW, cellH)) }
            }
        }
    }
}
