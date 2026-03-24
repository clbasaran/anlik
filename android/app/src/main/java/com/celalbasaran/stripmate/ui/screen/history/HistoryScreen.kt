package com.celalbasaran.stripmate.ui.screen.history

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapProperties
import com.google.android.gms.maps.model.MapStyleOptions
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.MarkerComposable
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import com.google.maps.android.compose.rememberMarkerState
import com.celalbasaran.stripmate.data.model.Strip
import com.celalbasaran.stripmate.ui.component.EmptyState
import com.celalbasaran.stripmate.ui.component.SkeletonPhotoCard
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.PureBlack
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import com.celalbasaran.stripmate.util.TimeAgo

// ─── Helpers ────────────────────────────────────────────────────────────────────

private fun isNetworkAvailable(context: Context): Boolean {
    val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    val network = cm.activeNetwork ?: return false
    val caps = cm.getNetworkCapabilities(network) ?: return false
    return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
}

// ─── Screen ─────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(
    onPhotoClick: (String) -> Unit,
    onNotificationsClick: () -> Unit,
    viewModel: HistoryViewModel = hiltViewModel()
) {
    val photos by viewModel.photos.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isRefreshing by viewModel.isRefreshing.collectAsState()
    val isLoadingMore by viewModel.isLoadingMore.collectAsState()
    val notificationCount by viewModel.notificationCount.collectAsState()
    val isDeleting by viewModel.isDeleting.collectAsState()

    val context = LocalContext.current

    // View state
    val prefs = remember { context.getSharedPreferences("stripmate_prefs", android.content.Context.MODE_PRIVATE) }
    var isMapView by rememberSaveable { mutableStateOf(false) }
    var isGridLayout by rememberSaveable { mutableStateOf(prefs.getString("feed_layout", "single") == "grid") }
    var showDeleteAlert by remember { mutableStateOf(false) }
    var showReportDialog by remember { mutableStateOf(false) }
    var reportTargetStrip by remember { mutableStateOf<Strip?>(null) }
    var isOnline by remember { mutableStateOf(isNetworkAvailable(context)) }
    // Simulate isSendingPhoto — in a real app this would come from a shared state holder
    var isSendingPhoto by remember { mutableStateOf(false) }

    // Lazy list / grid states
    val listState = rememberLazyListState()
    val gridState = rememberLazyGridState()

    // Pagination: single-column
    val shouldLoadMoreList by remember {
        derivedStateOf {
            val lastVisible = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            lastVisible >= photos.size - 3
        }
    }
    LaunchedEffect(shouldLoadMoreList) {
        if (shouldLoadMoreList && photos.isNotEmpty()) viewModel.loadMore()
    }

    // Pagination: grid
    val shouldLoadMoreGrid by remember {
        derivedStateOf {
            val lastVisible = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            lastVisible >= photos.size - 3
        }
    }
    LaunchedEffect(shouldLoadMoreGrid) {
        if (shouldLoadMoreGrid && photos.isNotEmpty()) viewModel.loadMore()
    }

    // ── Delete confirmation dialog ──────────────────────────────────────────
    if (showDeleteAlert) {
        AlertDialog(
            onDismissRequest = { showDeleteAlert = false },
            title = {
                Text(
                    text = "geçmişi temizle?",
                    color = TextPrimary,
                    fontWeight = FontWeight.Bold
                )
            },
            text = {
                Text(
                    text = "gönderdiğin tum fotoğraflar kalıcı olarak silinecek.",
                    color = TextSecondary
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteAlert = false
                    viewModel.clearHistory()
                }) {
                    Text("sil", color = Color.Red, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteAlert = false }) {
                    Text("iptal", color = TextSecondary)
                }
            },
            containerColor = DarkSurface,
            tonalElevation = 0.dp
        )
    }

    // ── Report dialog ───────────────────────────────────────────────────────
    if (showReportDialog && reportTargetStrip != null) {
        AlertDialog(
            onDismissRequest = {
                showReportDialog = false
                reportTargetStrip = null
            },
            title = {
                Text(
                    text = "fotoğrafı bildir",
                    color = TextPrimary,
                    fontWeight = FontWeight.Bold
                )
            },
            text = {
                Text(
                    text = "bu fotoğrafı neden bildiriyorsun?\nuygunsuz içerik içeren fotoğraflar incelenir ve kaldırılır.",
                    color = TextSecondary
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    // TODO: Wire reportContent via UserRepository when added to Android
                    showReportDialog = false
                    reportTargetStrip = null
                }) {
                    Text("bildir", color = Color.Red, fontWeight = FontWeight.Bold)
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    showReportDialog = false
                    reportTargetStrip = null
                }) {
                    Text("iptal", color = TextSecondary)
                }
            },
            containerColor = DarkSurface,
            tonalElevation = 0.dp
        )
    }

    // ── Main layout ─────────────────────────────────────────────────────────
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(PureBlack)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {

            // ── Custom Header ───────────────────────────────────────────────
            HistoryHeader(
                isMapView = isMapView,
                isGridLayout = isGridLayout,
                notificationCount = notificationCount,
                onToggleMap = { isMapView = it },
                onToggleGrid = { isGridLayout = it },
                onNotificationsClick = onNotificationsClick,
                onDeleteClick = { showDeleteAlert = true }
            )

            // ── Offline Banner ──────────────────────────────────────────────
            AnimatedVisibility(
                visible = !isOnline,
                enter = slideInVertically() + fadeIn(),
                exit = slideOutVertically() + fadeOut()
            ) {
                OfflineBanner(
                    onRetry = {
                        isOnline = isNetworkAvailable(context)
                        viewModel.refresh()
                    }
                )
            }

            // ── Content ─────────────────────────────────────────────────────
            if (isMapView) {
                PhotoMapView(photos = photos, onPhotoClick = onPhotoClick)
            } else {
                FeedContent(
                    photos = photos,
                    isLoading = isLoading,
                    isRefreshing = isRefreshing,
                    isLoadingMore = isLoadingMore,
                    isGridLayout = isGridLayout,
                    currentUserId = viewModel.currentUserId,
                    listState = listState,
                    gridState = gridState,
                    onPhotoClick = onPhotoClick,
                    onReaction = { photoId, emoji -> viewModel.toggleReaction(photoId, emoji) },
                    onDeleteStrip = { viewModel.deleteStrip(it) },
                    onReportStrip = { strip ->
                        reportTargetStrip = strip
                        showReportDialog = true
                    },
                    onRefresh = { viewModel.refresh() }
                )
            }
        }

        // ── Sending photo overlay ───────────────────────────────────────────
        AnimatedVisibility(
            visible = isSendingPhoto,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.fillMaxSize()
        ) {
            SendingPhotoOverlay()
        }

        // ── Deleting overlay ────────────────────────────────────────────────
        if (isDeleting) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.6f)),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = TextPrimary, strokeWidth = 2.dp)
            }
        }
    }
}

// ─── Custom Header ──────────────────────────────────────────────────────────────

@Composable
private fun HistoryHeader(
    isMapView: Boolean,
    isGridLayout: Boolean,
    notificationCount: Int,
    onToggleMap: (Boolean) -> Unit,
    onToggleGrid: (Boolean) -> Unit,
    onNotificationsClick: () -> Unit,
    onDeleteClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, bottom = 8.dp)
    ) {
        // Brand logotype
        Text(
            text = "anl\u0131k.",
            fontSize = 22.sp,
            fontWeight = FontWeight.Black,
            color = TextPrimary,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(8.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Notification bell
            IconButton(
                onClick = onNotificationsClick,
                modifier = Modifier.size(36.dp)
            ) {
                BadgedBox(
                    badge = {
                        if (notificationCount > 0) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .offset(x = 1.dp, y = (-1).dp)
                                    .background(TextPrimary, CircleShape)
                            )
                        }
                    }
                ) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .background(
                                color = Color.White.copy(alpha = 0.08f),
                                shape = CircleShape
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Notifications,
                            contentDescription = "bildirimler",
                            tint = TextPrimary,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            // View toggle pill: akis / harita
            ViewTogglePill(
                isMapView = isMapView,
                onToggle = onToggleMap
            )

            Spacer(modifier = Modifier.weight(1f))

            // Delete button
            IconButton(
                onClick = onDeleteClick,
                modifier = Modifier.size(36.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .background(
                            color = Color.White.copy(alpha = 0.08f),
                            shape = CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = "geçmişi temizle",
                        tint = Color.White.copy(alpha = 0.4f),
                        modifier = Modifier.size(14.dp)
                    )
                }
            }
        }
    }
}

// ─── View Toggle Pill ───────────────────────────────────────────────────────────

@Composable
private fun ViewTogglePill(
    isMapView: Boolean,
    onToggle: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .background(
                color = Color.White.copy(alpha = 0.06f),
                shape = RoundedCornerShape(50)
            )
            .padding(3.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ToggleButton(
            label = "akis",
            isActive = !isMapView,
            onClick = { onToggle(false) }
        )
        ToggleButton(
            label = "harita",
            isActive = isMapView,
            onClick = { onToggle(true) }
        )
    }
}

@Composable
private fun ToggleButton(
    label: String,
    isActive: Boolean,
    onClick: () -> Unit
) {
    val bgColor = if (isActive) Color.White else Color.Transparent
    val textColor = if (isActive) Color.Black else Color.White.copy(alpha = 0.45f)

    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(bgColor)
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = textColor
        )
    }
}

// ─── Offline Banner ─────────────────────────────────────────────────────────────

@Composable
private fun OfflineBanner(onRetry: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            modifier = Modifier
                .background(
                    color = Color.White.copy(alpha = 0.08f),
                    shape = RoundedCornerShape(50)
                )
                .padding(horizontal = 14.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = "cevrimdisi",
                fontSize = 12.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White.copy(alpha = 0.6f)
            )
            Spacer(modifier = Modifier.width(12.dp))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(Color.White.copy(alpha = 0.12f))
                    .clickable { onRetry() }
                    .padding(horizontal = 10.dp, vertical = 4.dp)
            ) {
                Text(
                    text = "tekrar dene",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
            }
        }
    }
}

// ─── Map View ───────────────────────────────────────────────────────────────────

@Composable
private fun PhotoMapView(
    photos: List<Strip>,
    onPhotoClick: (String) -> Unit
) {
    val photosWithLocation = photos.filter { it.latitude != null && it.longitude != null }

    if (photosWithLocation.isEmpty()) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(DarkSurface),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Outlined.Map,
                    contentDescription = null,
                    tint = TextSecondary,
                    modifier = Modifier.size(48.dp)
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "harita görünümü",
                    color = TextPrimary,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "konum bilgisi olan fotoğraf yok.\nkonum izni vererek fotoğraflarına\nkonum ekleyebilirsin.",
                    color = TextSecondary,
                    fontSize = 14.sp,
                    textAlign = TextAlign.Center,
                    lineHeight = 20.sp
                )
            }
        }
        return
    }

    val cameraPositionState = rememberCameraPositionState {
        val firstPhoto = photosWithLocation.first()
        position = CameraPosition.fromLatLngZoom(
            LatLng(firstPhoto.latitude!!, firstPhoto.longitude!!),
            10f
        )
    }

    GoogleMap(
        modifier = Modifier.fillMaxSize(),
        cameraPositionState = cameraPositionState,
        properties = MapProperties(
            mapStyleOptions = MapStyleOptions(mapDarkStyle)
        ),
        uiSettings = MapUiSettings(
            zoomControlsEnabled = false,
            mapToolbarEnabled = false
        )
    ) {
        photosWithLocation.forEach { strip ->
            val markerState = rememberMarkerState(
                key = strip.id,
                position = LatLng(strip.latitude!!, strip.longitude!!)
            )
            MarkerComposable(
                state = markerState,
                title = strip.cityName ?: TimeAgo.format(strip.timestamp),
                onClick = {
                    onPhotoClick(strip.id)
                    true
                }
            ) {
                // Circular photo thumbnail like iOS
                val thumbUrl = strip.smallThumbnailUrl
                    ?: strip.thumbnailUrl
                    ?: strip.imageUrl
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .clip(CircleShape)
                        .border(2.dp, Color.White, CircleShape)
                        .background(DarkSurface),
                    contentAlignment = Alignment.Center
                ) {
                    AsyncImage(
                        model = thumbUrl,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )
                }
            }
        }
    }
}

// Dark map style JSON
private val mapDarkStyle = """
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}
]
""".trimIndent()

// ─── Feed Content ───────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FeedContent(
    photos: List<Strip>,
    isLoading: Boolean,
    isRefreshing: Boolean,
    isLoadingMore: Boolean,
    isGridLayout: Boolean,
    currentUserId: String?,
    listState: androidx.compose.foundation.lazy.LazyListState,
    gridState: androidx.compose.foundation.lazy.grid.LazyGridState,
    onPhotoClick: (String) -> Unit,
    onReaction: (String, String) -> Unit,
    onDeleteStrip: (Strip) -> Unit,
    onReportStrip: (Strip) -> Unit,
    onRefresh: () -> Unit
) {
    when {
        isLoading -> {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(5) {
                    SkeletonPhotoCard()
                }
            }
        }

        photos.isEmpty() -> {
            EmptyState(
                icon = "\uD83D\uDCF7",
                message = "henüz bir an yok.\nbir arkadaşına fotoğraf gönder,\nanlarınız burada biriksin.",
                modifier = Modifier
                    .fillMaxSize()
                    .padding(top = 100.dp)
            )
        }

        else -> {
            PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = onRefresh,
                modifier = Modifier.fillMaxSize()
            ) {
                if (isGridLayout) {
                    // ── Grid layout (2 columns) ─────────────────────────────
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(2),
                        state = gridState,
                        horizontalArrangement = Arrangement.spacedBy(2.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(
                            items = photos,
                            key = { it.id }
                        ) { strip ->
                            GridPhotoCard(
                                strip = strip,
                                currentUserId = currentUserId,
                                onPhotoClick = { onPhotoClick(strip.id) },
                                onReport = { onReportStrip(strip) }
                            )
                        }

                        if (isLoadingMore) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator(
                                        color = StripMateBlue,
                                        modifier = Modifier.size(24.dp),
                                        strokeWidth = 2.dp
                                    )
                                }
                            }
                        }
                    }
                } else {
                    // ── Single column layout ────────────────────────────────
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(
                            items = photos,
                            key = { it.id }
                        ) { strip ->
                            FeedPhotoCard(
                                strip = strip,
                                currentUserId = currentUserId,
                                onPhotoClick = { onPhotoClick(strip.id) },
                                onReaction = { emoji -> onReaction(strip.id, emoji) },
                                onDelete = { onDeleteStrip(strip) },
                                onReport = { onReportStrip(strip) }
                            )
                        }

                        if (isLoadingMore) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator(
                                        color = StripMateBlue,
                                        modifier = Modifier.size(24.dp),
                                        strokeWidth = 2.dp
                                    )
                                }
                            }
                        }

                        // Bottom spacer for tab bar clearance
                        item {
                            Spacer(modifier = Modifier.height(120.dp))
                        }
                    }
                }
            }
        }
    }
}

// ─── Feed Photo Card (single column — matches iOS feedCard) ─────────────────────

@Composable
private fun FeedPhotoCard(
    strip: Strip,
    currentUserId: String?,
    onPhotoClick: () -> Unit,
    onReaction: (String) -> Unit,
    onDelete: () -> Unit,
    onReport: () -> Unit
) {
    val isSentByMe = strip.senderId == currentUserId
    var showContextMenu by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onPhotoClick() }
    ) {
        // Photo
        AsyncImage(
            model = strip.thumbnailUrl ?: strip.imageUrl,
            contentDescription = "fotoğraf",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxWidth()
                .height(400.dp)
        )

        // Bottom gradient overlay
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(120.dp)
                .align(Alignment.BottomCenter)
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            Color.Transparent,
                            Color.Black.copy(alpha = 0.7f),
                            Color.Black
                        ),
                        startY = 0f,
                        endY = Float.POSITIVE_INFINITY
                    )
                )
        )

        // Info bar at bottom
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.BottomCenter)
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            Column(modifier = Modifier.weight(1f)) {
                // Direction indicator
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = if (isSentByMe) "\u2197" else "\u2199",
                        fontSize = 9.sp,
                        color = Color.White.copy(alpha = 0.5f)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = if (isSentByMe) "gönderildi" else "alındı",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White.copy(alpha = 0.5f)
                    )
                }

                Spacer(modifier = Modifier.height(3.dp))

                // Location + time
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (!strip.cityName.isNullOrBlank()) {
                        Text(
                            text = strip.cityName,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.White
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                    }
                    Text(
                        text = TimeAgo.format(strip.timestamp),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White.copy(alpha = 0.4f)
                    )
                }
            }

            // Context menu button (long-press alternative)
            Box {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .background(
                            color = Color.White.copy(alpha = 0.1f),
                            shape = CircleShape
                        )
                        .clickable { showContextMenu = true },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "\u2026",
                        color = Color.White.copy(alpha = 0.4f),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                DropdownMenu(
                    expanded = showContextMenu,
                    onDismissRequest = { showContextMenu = false },
                    containerColor = DarkSurface
                ) {
                    if (isSentByMe) {
                        DropdownMenuItem(
                            text = {
                                Text(
                                    "kalici olarak sil",
                                    color = Color.Red
                                )
                            },
                            onClick = {
                                showContextMenu = false
                                onDelete()
                            }
                        )
                    } else {
                        DropdownMenuItem(
                            text = {
                                Text(
                                    "fotoğrafı bildir",
                                    color = Color.Red
                                )
                            },
                            onClick = {
                                showContextMenu = false
                                onReport()
                            }
                        )
                    }
                }
            }
        }
    }
}

// ─── Grid Photo Card (compact — matches iOS gridCard) ───────────────────────────

@Composable
private fun GridPhotoCard(
    strip: Strip,
    currentUserId: String?,
    onPhotoClick: () -> Unit,
    onReport: () -> Unit
) {
    var showContextMenu by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(180.dp)
            .clickable { onPhotoClick() }
    ) {
        AsyncImage(
            model = strip.smallThumbnailUrl ?: strip.thumbnailUrl ?: strip.imageUrl,
            contentDescription = "fotoğraf",
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
        )

        // Bottom gradient
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(60.dp)
                .align(Alignment.BottomCenter)
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Color.Black.copy(alpha = 0.6f))
                    )
                )
        )

        // Relative time
        Text(
            text = TimeAgo.format(strip.timestamp),
            fontSize = 10.sp,
            fontWeight = FontWeight.Medium,
            color = Color.White.copy(alpha = 0.5f),
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(8.dp)
        )

        // Context menu for report
        if (strip.senderId != currentUserId) {
            Box(modifier = Modifier.align(Alignment.TopEnd)) {
                Box(
                    modifier = Modifier
                        .padding(4.dp)
                        .size(24.dp)
                        .background(
                            color = Color.Black.copy(alpha = 0.4f),
                            shape = CircleShape
                        )
                        .clickable { showContextMenu = true },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "\u2026",
                        color = Color.White.copy(alpha = 0.6f),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                DropdownMenu(
                    expanded = showContextMenu,
                    onDismissRequest = { showContextMenu = false },
                    containerColor = DarkSurface
                ) {
                    DropdownMenuItem(
                        text = {
                            Text(
                                "fotoğrafı bildir",
                                color = Color.Red
                            )
                        },
                        onClick = {
                            showContextMenu = false
                            onReport()
                        }
                    )
                }
            }
        }
    }
}

// ─── Sending Photo Overlay ──────────────────────────────────────────────────────

@Composable
private fun SendingPhotoOverlay() {
    val infiniteTransition = rememberInfiniteTransition(label = "sending")
    val rotation by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(1000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "rotation"
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.7f)),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            // Animated ring
            Box(
                modifier = Modifier.size(64.dp),
                contentAlignment = Alignment.Center
            ) {
                // Background ring
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .drawBehind {
                            drawCircle(
                                color = Color.White.copy(alpha = 0.1f),
                                style = Stroke(width = 4.dp.toPx())
                            )
                        }
                )
                // Spinning arc
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .rotate(rotation)
                        .drawBehind {
                            drawArc(
                                color = Color.White,
                                startAngle = 0f,
                                sweepAngle = 252f,
                                useCenter = false,
                                style = Stroke(
                                    width = 4.dp.toPx(),
                                    cap = StrokeCap.Round
                                )
                            )
                        }
                )
                // Plane icon
                Text(
                    text = "\u2708",
                    fontSize = 22.sp,
                    color = Color.White
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            Text(
                text = "gönderiliyor...",
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White.copy(alpha = 0.8f)
            )
        }
    }
}
