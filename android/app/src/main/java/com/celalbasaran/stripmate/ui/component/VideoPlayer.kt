package com.celalbasaran.stripmate.ui.component

import android.content.Context
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.net.URL
import java.security.MessageDigest

// MARK: - Video Cache

/**
 * File-based cache for short video clips (max 5s).
 * Mirrors iOS VideoCache: SHA256-keyed local files in cacheDir, 100 MB cap with LRU trim.
 * Eliminates buffering delay by serving videos from disk after first download.
 */
object VideoCache {
    private const val MAX_CACHE_BYTES: Long = 100L * 1024L * 1024L // 100 MB
    private const val DIR_NAME = "video_cache_v2"
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private fun cacheDir(context: Context): File {
        val dir = File(context.cacheDir, DIR_NAME)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun keyFor(url: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(url.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    fun localFile(context: Context, remoteUrl: String): File =
        File(cacheDir(context), "v2_${keyFor(remoteUrl)}.mp4")

    fun cachedFile(context: Context, remoteUrl: String): File? {
        val f = localFile(context, remoteUrl)
        return if (f.exists() && f.length() > 0) f else null
    }

    /** Synchronously download and cache a remote video. Returns the local file or null on failure. */
    suspend fun download(context: Context, remoteUrl: String): File? = withContext(Dispatchers.IO) {
        cachedFile(context, remoteUrl)?.let { return@withContext it }

        val target = localFile(context, remoteUrl)
        val tmp = File(target.parentFile, "${target.name}.part")
        try {
            URL(remoteUrl).openStream().use { input ->
                tmp.outputStream().use { output -> input.copyTo(output) }
            }
            if (target.exists()) target.delete()
            tmp.renameTo(target)
            ioScope.launch { trimIfNeeded(context) }
            target
        } catch (_: Exception) {
            tmp.delete()
            null
        }
    }

    /** Fire-and-forget prefetch — safe to call from UI threads. No-op if already cached. */
    fun prefetch(context: Context, remoteUrl: String) {
        if (cachedFile(context, remoteUrl) != null) return
        ioScope.launch { download(context, remoteUrl) }
    }

    private fun trimIfNeeded(context: Context) {
        val files = cacheDir(context).listFiles()?.toList().orEmpty()
        var totalSize = files.sumOf { it.length() }
        if (totalSize <= MAX_CACHE_BYTES) return

        val sorted = files.sortedBy { it.lastModified() }
        val target = MAX_CACHE_BYTES / 2
        for (f in sorted) {
            val len = f.length()
            if (f.delete()) totalSize -= len
            if (totalSize <= target) break
        }
    }
}

// MARK: - Video Player View

/**
 * Reusable looping video player for strip clips.
 *
 * @param uri Video source. http(s) URLs are routed through [VideoCache] for instant playback;
 *            file URIs play directly.
 * @param interactive When false, taps are ignored (parent owns the gesture, e.g. feed cards
 *            opening detail). The mute button is also hidden.
 * @param autoPlay Start playback automatically (default true).
 * @param startMuted Start muted (default true). Inline feed videos must stay muted.
 */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
@Composable
fun VideoPlayerView(
    uri: Uri,
    modifier: Modifier = Modifier,
    startMuted: Boolean = true,
    autoPlay: Boolean = true,
    interactive: Boolean = true
) {
    val context = LocalContext.current
    var isMuted by remember { mutableStateOf(startMuted) }

    val exoPlayer = remember(uri) {
        // Resolve playback URI: prefer cached local file for remote sources.
        val playbackUri: Uri = if (uri.scheme == "http" || uri.scheme == "https") {
            VideoCache.cachedFile(context, uri.toString())
                ?.let { Uri.fromFile(it) }
                ?: run {
                    // Stream now, populate cache for next time.
                    VideoCache.prefetch(context, uri.toString())
                    uri
                }
        } else {
            uri
        }

        // Strip videos are 5s max — minimize buffer to start playback instantly.
        // iOS uses preferredForwardBufferDuration=2s; mirror that here.
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                /* minBufferMs = */ 500,
                /* maxBufferMs = */ 2_000,
                /* bufferForPlaybackMs = */ 250,
                /* bufferForPlaybackAfterRebufferMs = */ 500
            )
            .build()

        ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .build()
            .apply {
                setMediaItem(MediaItem.fromUri(playbackUri))
                repeatMode = Player.REPEAT_MODE_ALL
                volume = if (startMuted) 0f else 1f
                playWhenReady = autoPlay
                prepare()
            }
    }

    DisposableEffect(exoPlayer) {
        onDispose { exoPlayer.release() }
    }

    Box(modifier = modifier) {
        AndroidView(
            factory = { ctx ->
                PlayerView(ctx).apply {
                    player = exoPlayer
                    useController = false
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        if (interactive) {
            IconButton(
                onClick = {
                    isMuted = !isMuted
                    exoPlayer.volume = if (isMuted) 0f else 1f
                },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(12.dp)
                    .size(32.dp)
                    .background(Color.Black.copy(alpha = 0.5f), CircleShape)
            ) {
                Icon(
                    imageVector = if (isMuted) Icons.AutoMirrored.Filled.VolumeOff else Icons.AutoMirrored.Filled.VolumeUp,
                    contentDescription = if (isMuted) "Sesi ac" else "Sesi kapat",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}
