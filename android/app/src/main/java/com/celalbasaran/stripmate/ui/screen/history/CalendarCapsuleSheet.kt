package com.celalbasaran.stripmate.ui.screen.history

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import java.util.Calendar
import java.util.Date

private val turkishMonths = listOf(
    "Ocak", "\u015Eubat", "Mart", "Nisan", "May\u0131s", "Haziran",
    "Temmuz", "A\u011Fustos", "Eyl\u00FCl", "Ekim", "Kas\u0131m", "Aral\u0131k"
)

private val turkishWeekdays = listOf("Pzt", "Sal", "\u00C7ar", "Per", "Cum", "Cmt", "Paz")

/**
 * Calendar Capsule bottom sheet matching iOS CalendarCapsuleView.
 * Shows a full calendar grid, highlights days with photos, and allows selecting a day to see its photos.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarCapsuleSheet(
    photos: List<Strip>,
    onDismiss: () -> Unit,
    onPhotoClick: (String) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var displayedMonth by remember { mutableStateOf(Calendar.getInstance()) }
    var selectedDate by remember { mutableStateOf<Calendar?>(null) }

    // Precompute days with photos
    val daysWithPhotos = remember(photos) {
        val set = mutableSetOf<String>()
        for (strip in photos) {
            val cal = Calendar.getInstance().apply { time = strip.timestamp }
            val key = "${cal.get(Calendar.YEAR)}-${cal.get(Calendar.MONTH)}-${cal.get(Calendar.DAY_OF_MONTH)}"
            set.add(key)
        }
        set
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = PureBlack,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
        ) {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 20.dp, bottom = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "g\u00FCnl\u00FCk kaps\u00FCl",
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary,
                    modifier = Modifier.weight(1f)
                )
                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .size(32.dp)
                        .background(Color.White.copy(alpha = 0.12f), CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Kapat",
                        tint = Color.White,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }

            // Month navigator
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = {
                    displayedMonth = (displayedMonth.clone() as Calendar).apply {
                        add(Calendar.MONTH, -1)
                    }
                    selectedDate = null
                }) {
                    Icon(
                        imageVector = Icons.Default.ChevronLeft,
                        contentDescription = "Önceki ay",
                        tint = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.size(18.dp)
                    )
                }

                Spacer(modifier = Modifier.weight(1f))

                Text(
                    text = "${turkishMonths[displayedMonth.get(Calendar.MONTH)]} ${displayedMonth.get(Calendar.YEAR)}",
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = TextPrimary
                )

                Spacer(modifier = Modifier.weight(1f))

                IconButton(onClick = {
                    displayedMonth = (displayedMonth.clone() as Calendar).apply {
                        add(Calendar.MONTH, 1)
                    }
                    selectedDate = null
                }) {
                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = "Sonraki ay",
                        tint = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            // Weekday headers
            Row(modifier = Modifier.fillMaxWidth()) {
                turkishWeekdays.forEach { day ->
                    Text(
                        text = day,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.4f),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Calendar grid
            val today = Calendar.getInstance()
            val slots = computeDaysInMonth(displayedMonth)
            val displayMonth = displayedMonth.get(Calendar.MONTH)
            val displayYear = displayedMonth.get(Calendar.YEAR)

            LazyVerticalGrid(
                columns = GridCells.Fixed(7),
                verticalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                items(42) { index ->
                    val dateCal = slots[index]
                    if (dateCal != null) {
                        val dayNum = dateCal.get(Calendar.DAY_OF_MONTH)
                        val isCurrentMonth = dateCal.get(Calendar.MONTH) == displayMonth &&
                                dateCal.get(Calendar.YEAR) == displayYear
                        val isToday = dateCal.get(Calendar.YEAR) == today.get(Calendar.YEAR) &&
                                dateCal.get(Calendar.MONTH) == today.get(Calendar.MONTH) &&
                                dateCal.get(Calendar.DAY_OF_MONTH) == today.get(Calendar.DAY_OF_MONTH)
                        val isSelected = selectedDate?.let { sel ->
                            sel.get(Calendar.YEAR) == dateCal.get(Calendar.YEAR) &&
                                    sel.get(Calendar.MONTH) == dateCal.get(Calendar.MONTH) &&
                                    sel.get(Calendar.DAY_OF_MONTH) == dateCal.get(Calendar.DAY_OF_MONTH)
                        } ?: false
                        val dayKey = "${dateCal.get(Calendar.YEAR)}-${dateCal.get(Calendar.MONTH)}-${dateCal.get(Calendar.DAY_OF_MONTH)}"
                        val hasPhotos = daysWithPhotos.contains(dayKey)

                        CalendarDayCell(
                            day = dayNum,
                            isCurrentMonth = isCurrentMonth,
                            isToday = isToday,
                            isSelected = isSelected,
                            hasPhotos = hasPhotos,
                            onClick = {
                                selectedDate = if (isSelected) null else dateCal
                            }
                        )
                    } else {
                        Box(modifier = Modifier.height(48.dp))
                    }
                }
            }

            // Selected day content
            selectedDate?.let { selDate ->
                val stripsForDay = photos.filter { strip ->
                    val cal = Calendar.getInstance().apply { time = strip.timestamp }
                    cal.get(Calendar.YEAR) == selDate.get(Calendar.YEAR) &&
                            cal.get(Calendar.MONTH) == selDate.get(Calendar.MONTH) &&
                            cal.get(Calendar.DAY_OF_MONTH) == selDate.get(Calendar.DAY_OF_MONTH)
                }

                Spacer(modifier = Modifier.height(12.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(0.5.dp)
                        .background(Color.White.copy(alpha = 0.15f))
                )
                Spacer(modifier = Modifier.height(10.dp))

                if (stripsForDay.isEmpty()) {
                    Text(
                        text = "bu g\u00FCn foto yok",
                        fontSize = 14.sp,
                        color = Color.White.copy(alpha = 0.5f),
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 24.dp)
                    )
                } else {
                    // Day header
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "${selDate.get(Calendar.DAY_OF_MONTH)} ${turkishMonths[selDate.get(Calendar.MONTH)]}",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = TextPrimary
                        )
                        Spacer(modifier = Modifier.weight(1f))
                        Text(
                            text = "${stripsForDay.size} an",
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color.White.copy(alpha = 0.5f)
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // Horizontal strip previews
                    LazyRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(stripsForDay, key = { it.id }) { strip ->
                            val thumbUrl = strip.smallThumbnailUrl ?: strip.thumbnailUrl ?: strip.imageUrl
                            AsyncImage(
                                model = thumbUrl,
                                contentDescription = null,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .size(width = 80.dp, height = 106.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(Color.White.copy(alpha = 0.08f))
                                    .clickable { onPhotoClick(strip.id) }
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(40.dp))
        }
    }
}

@Composable
private fun CalendarDayCell(
    day: Int,
    isCurrentMonth: Boolean,
    isToday: Boolean,
    isSelected: Boolean,
    hasPhotos: Boolean,
    onClick: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .height(48.dp)
            .clickable { onClick() }
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(34.dp)
        ) {
            if (isSelected) {
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .background(Color.White, CircleShape)
                )
            } else if (isToday) {
                Box(
                    modifier = Modifier
                        .size(34.dp)
                        .background(Color.Transparent, CircleShape)
                        .then(
                            Modifier.background(Color.Transparent)
                        )
                ) {
                    Box(
                        modifier = Modifier
                            .size(34.dp)
                            .clip(CircleShape)
                            .background(Color.Transparent)
                            .then(
                                Modifier
                                    .size(34.dp)
                                    .clip(CircleShape)
                            )
                    ) {
                        // Stroke circle for today
                        Box(
                            modifier = Modifier
                                .matchParentSize()
                                .background(Color.Transparent, CircleShape)
                                .padding(0.5.dp)
                                .background(Color.Transparent, CircleShape)
                        )
                    }
                }
            }

            Text(
                text = "$day",
                fontSize = 15.sp,
                fontWeight = if (isToday || isSelected) FontWeight.Bold else FontWeight.Normal,
                color = when {
                    isSelected -> Color.Black
                    else -> Color.White
                }.copy(alpha = if (isCurrentMonth) 1f else 0.2f)
            )
        }

        Spacer(modifier = Modifier.height(3.dp))

        Box(
            modifier = Modifier
                .size(4.dp)
                .background(
                    if (hasPhotos) Color.White else Color.Transparent,
                    CircleShape
                )
        )
    }
}

/**
 * Compute the 42 calendar day slots (6 rows x 7 cols) for a given month.
 * Uses Monday as first day of week (matching iOS/Turkish calendar).
 */
private fun computeDaysInMonth(displayedMonth: Calendar): Array<Calendar?> {
    val slots = arrayOfNulls<Calendar>(42)
    val cal = displayedMonth.clone() as Calendar
    cal.set(Calendar.DAY_OF_MONTH, 1)

    // Convert Sunday=1..Saturday=7 to Monday=0..Sunday=6
    var weekday = cal.get(Calendar.DAY_OF_WEEK)
    weekday = (weekday + 5) % 7

    val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

    // Fill previous month trailing days
    for (i in (weekday - 1) downTo 0) {
        val prev = cal.clone() as Calendar
        prev.add(Calendar.DAY_OF_MONTH, -(weekday - i))
        slots[i] = prev
    }

    // Fill current month days
    for (day in 0 until daysInMonth) {
        val index = weekday + day
        if (index < 42) {
            val d = cal.clone() as Calendar
            d.set(Calendar.DAY_OF_MONTH, day + 1)
            slots[index] = d
        }
    }

    // Fill next month leading days
    val filledCount = weekday + daysInMonth
    if (filledCount < 42) {
        val nextMonth = cal.clone() as Calendar
        nextMonth.add(Calendar.MONTH, 1)
        nextMonth.set(Calendar.DAY_OF_MONTH, 1)
        for (i in filledCount until 42) {
            val d = nextMonth.clone() as Calendar
            d.set(Calendar.DAY_OF_MONTH, i - filledCount + 1)
            slots[i] = d
        }
    }

    return slots
}
