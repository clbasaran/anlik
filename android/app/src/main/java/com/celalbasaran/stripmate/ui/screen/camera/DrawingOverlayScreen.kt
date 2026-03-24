package com.celalbasaran.stripmate.ui.screen.camera

import android.graphics.Paint
import android.graphics.Path
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
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
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary

data class DrawingLine(
    val points: List<Offset>,
    val color: Color,
    val strokeWidth: Float
)

private val drawingColors = listOf(
    Color.White,
    Color.Red,
    Color.Yellow,
    Color(0xFF34C759), // green
    Color(0xFF007AFF), // blue
    Color(0xFFAF52DE), // purple
    Color(0xFFFF9500)  // orange
)

@Composable
fun DrawingOverlayScreen(
    onDone: () -> Unit,
    onCancel: () -> Unit
) {
    val lines = remember { mutableStateListOf<DrawingLine>() }
    var currentPoints by remember { mutableStateOf<List<Offset>>(emptyList()) }
    var selectedColor by remember { mutableStateOf(Color.White) }
    var strokeWidth by remember { mutableFloatStateOf(5f) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack.copy(alpha = 0.3f))
    ) {
        // Drawing canvas
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(Unit) {
                    detectDragGestures(
                        onDragStart = { offset ->
                            currentPoints = listOf(offset)
                        },
                        onDrag = { change, _ ->
                            currentPoints = currentPoints + change.position
                        },
                        onDragEnd = {
                            lines.add(
                                DrawingLine(
                                    points = currentPoints,
                                    color = selectedColor,
                                    strokeWidth = strokeWidth
                                )
                            )
                            currentPoints = emptyList()
                        }
                    )
                }
        ) {
            // Draw completed lines
            lines.forEach { line ->
                if (line.points.size >= 2) {
                    val path = androidx.compose.ui.graphics.Path().apply {
                        moveTo(line.points.first().x, line.points.first().y)
                        for (i in 1 until line.points.size) {
                            lineTo(line.points[i].x, line.points[i].y)
                        }
                    }
                    drawPath(
                        path = path,
                        color = line.color,
                        style = Stroke(
                            width = line.strokeWidth,
                            cap = StrokeCap.Round,
                            join = StrokeJoin.Round
                        )
                    )
                }
            }

            // Draw current line
            if (currentPoints.size >= 2) {
                val path = androidx.compose.ui.graphics.Path().apply {
                    moveTo(currentPoints.first().x, currentPoints.first().y)
                    for (i in 1 until currentPoints.size) {
                        lineTo(currentPoints[i].x, currentPoints[i].y)
                    }
                }
                drawPath(
                    path = path,
                    color = selectedColor,
                    style = Stroke(
                        width = strokeWidth,
                        cap = StrokeCap.Round,
                        join = StrokeJoin.Round
                    )
                )
            }
        }

        // Top controls
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            IconButton(
                onClick = onCancel,
                modifier = Modifier
                    .size(44.dp)
                    .background(Color.Black.copy(alpha = 0.4f), CircleShape)
            ) {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Iptal",
                    tint = TextPrimary
                )
            }

            Row {
                IconButton(
                    onClick = {
                        if (lines.isNotEmpty()) lines.removeAt(lines.lastIndex)
                    },
                    modifier = Modifier
                        .size(44.dp)
                        .background(Color.Black.copy(alpha = 0.4f), CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.Undo,
                        contentDescription = "Geri al",
                        tint = TextPrimary
                    )
                }

                Spacer(modifier = Modifier.width(8.dp))

                IconButton(
                    onClick = onDone,
                    modifier = Modifier
                        .size(44.dp)
                        .background(Color.White, CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = "Tamam",
                        tint = Color.Black
                    )
                }
            }
        }

        // Bottom controls - colors and width
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .background(Color.Black.copy(alpha = 0.6f))
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Color picker
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                drawingColors.forEach { color ->
                    Box(
                        modifier = Modifier
                            .size(if (color == selectedColor) 36.dp else 30.dp)
                            .background(color, CircleShape)
                            .then(
                                if (color == selectedColor) {
                                    Modifier.background(
                                        Color.Transparent,
                                        CircleShape
                                    )
                                } else Modifier
                            )
                            .pointerInput(Unit) {
                                detectDragGestures { _, _ -> }
                            }
                    ) {
                        // Clickable
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(color, CircleShape)
                                .pointerInput(color) {
                                    awaitPointerEventScope {
                                        while (true) {
                                            val event = awaitPointerEvent()
                                            if (event.changes.any { it.pressed }) {
                                                selectedColor = color
                                            }
                                        }
                                    }
                                }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Width slider
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(horizontal = 16.dp)
            ) {
                Text(
                    text = "Ince",
                    color = TextSecondary,
                    fontSize = 11.sp
                )
                Slider(
                    value = strokeWidth,
                    onValueChange = { strokeWidth = it },
                    valueRange = 1f..20f,
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 8.dp),
                    colors = SliderDefaults.colors(
                        thumbColor = Color.White,
                        activeTrackColor = Color.White.copy(alpha = 0.5f),
                        inactiveTrackColor = Color.White.copy(alpha = 0.15f)
                    )
                )
                Text(
                    text = "Kalin",
                    color = TextSecondary,
                    fontSize = 11.sp
                )
            }
        }
    }
}
