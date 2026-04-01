package com.celalbasaran.stripmate.ui.component

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.ImageLoader
import coil.compose.AsyncImage
import coil.decode.GifDecoder
import coil.request.ImageRequest
import com.celalbasaran.stripmate.service.giphy.GiphyService
import com.celalbasaran.stripmate.service.giphy.GiphySticker
import com.celalbasaran.stripmate.ui.theme.DarkSurface
import com.celalbasaran.stripmate.ui.theme.DarkSurfaceVariant
import com.celalbasaran.stripmate.ui.theme.StripMateBlue
import com.celalbasaran.stripmate.ui.theme.TextPrimary
import com.celalbasaran.stripmate.ui.theme.TextSecondary
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * GIPHY sticker picker presented as a modal bottom sheet.
 * Matches the iOS GiphyStickerPicker behavior: trending on open, debounced search.
 *
 * @param onDismiss Called when the sheet is dismissed.
 * @param onStickerSelected Called with (originalUrl, stickerId) when user taps a sticker.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GiphyStickerPicker(
    onDismiss: () -> Unit,
    onStickerSelected: (originalUrl: String, stickerId: String) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    val giphyService = remember { GiphyService() }
    var searchText by remember { mutableStateOf("") }
    var stickers by remember { mutableStateOf<List<GiphySticker>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }

    // GIF-capable image loader
    val gifImageLoader = remember {
        ImageLoader.Builder(context)
            .components {
                add(GifDecoder.Factory())
            }
            .crossfade(true)
            .build()
    }

    // Load trending on first open
    LaunchedEffect(Unit) {
        isLoading = true
        try {
            stickers = giphyService.trendingStickers()
        } catch (_: Exception) { }
        isLoading = false
    }

    // Debounced search
    LaunchedEffect(searchText) {
        if (searchText.isBlank()) {
            isLoading = true
            try {
                stickers = giphyService.trendingStickers()
            } catch (_: Exception) { }
            isLoading = false
            return@LaunchedEffect
        }
        delay(400) // debounce
        isLoading = true
        try {
            stickers = giphyService.searchStickers(searchText)
        } catch (_: Exception) { }
        isLoading = false
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = Color(0xFF141414),
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(top = 10.dp, bottom = 4.dp)
                    .size(width = 36.dp, height = 4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Color.White.copy(alpha = 0.3f))
            )
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .height(480.dp)
        ) {
            // Title bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Sticker Ekle",
                    color = TextPrimary,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f)
                )
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Kapat",
                        tint = TextSecondary
                    )
                }
            }

            // Search bar
            TextField(
                value = searchText,
                onValueChange = { searchText = it },
                placeholder = {
                    Text("GIPHY'de ara...", color = TextSecondary.copy(alpha = 0.6f))
                },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = null,
                        tint = TextSecondary.copy(alpha = 0.5f),
                        modifier = Modifier.size(18.dp)
                    )
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.White.copy(alpha = 0.1f),
                    unfocusedContainerColor = Color.White.copy(alpha = 0.1f),
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary,
                    cursorColor = StripMateBlue,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent
                ),
                shape = RoundedCornerShape(24.dp),
                singleLine = true
            )

            // Content
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
            ) {
                when {
                    isLoading && stickers.isEmpty() -> {
                        CircularProgressIndicator(
                            color = StripMateBlue,
                            modifier = Modifier
                                .size(32.dp)
                                .align(Alignment.Center),
                            strokeWidth = 2.dp
                        )
                    }
                    stickers.isEmpty() -> {
                        Column(
                            modifier = Modifier.align(Alignment.Center),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "\uD83D\uDE36",
                                fontSize = 36.sp
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(
                                text = "sticker bulunamadi",
                                color = TextSecondary.copy(alpha = 0.5f),
                                fontSize = 14.sp
                            )
                        }
                    }
                    else -> {
                        LazyVerticalGrid(
                            columns = GridCells.Fixed(4),
                            contentPadding = PaddingValues(12.dp),
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            items(stickers, key = { it.id }) { sticker ->
                                AsyncImage(
                                    model = ImageRequest.Builder(context)
                                        .data(sticker.previewUrl)
                                        .crossfade(true)
                                        .build(),
                                    imageLoader = gifImageLoader,
                                    contentDescription = sticker.title,
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier
                                        .height(80.dp)
                                        .clip(RoundedCornerShape(8.dp))
                                        .clickable {
                                            onStickerSelected(sticker.originalUrl, sticker.id)
                                            scope.launch {
                                                sheetState.hide()
                                                onDismiss()
                                            }
                                        }
                                )
                            }
                        }
                    }
                }
            }

            // GIPHY Attribution (required by GIPHY TOS)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Powered by",
                    color = Color.White.copy(alpha = 0.3f),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = "GIPHY",
                    color = Color.White.copy(alpha = 0.5f),
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

/**
 * Composable to render a GIF image from a GIPHY URL in a chat bubble.
 * Uses Coil with GIF decoder.
 */
@Composable
fun GiphyMessageImage(
    url: String,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val gifImageLoader = remember {
        ImageLoader.Builder(context)
            .components {
                add(GifDecoder.Factory())
            }
            .crossfade(true)
            .build()
    }

    AsyncImage(
        model = ImageRequest.Builder(context)
            .data(url)
            .crossfade(true)
            .build(),
        imageLoader = gifImageLoader,
        contentDescription = "GIF Sticker",
        contentScale = ContentScale.Fit,
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
    )
}
