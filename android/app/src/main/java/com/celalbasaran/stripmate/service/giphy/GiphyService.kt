package com.celalbasaran.stripmate.service.giphy

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import javax.inject.Inject
import javax.inject.Singleton

/**
 * GIPHY sticker model for search/trending results.
 */
data class GiphySticker(
    val id: String,
    val previewUrl: String,   // fixed_height_small — picker grid
    val originalUrl: String,  // original — saved to Firestore
    val title: String
)

/**
 * REST API client for GIPHY sticker search & trending.
 * Uses the same API key as the iOS app (Secrets.plist).
 */
@Singleton
class GiphyService @Inject constructor() {

    private val apiKey = "gFftw3FuFBXmeWPC9x7N4fbXQFcYvnGL"
    private val baseUrl = "https://api.giphy.com/v1/stickers"

    /**
     * Search GIPHY stickers with a query. Falls back to trending if query is blank.
     */
    suspend fun searchStickers(
        query: String,
        limit: Int = 30,
        offset: Int = 0
    ): List<GiphySticker> {
        if (query.isBlank()) return trendingStickers(limit, offset)
        val encoded = URLEncoder.encode(query, "UTF-8")
        val url = "$baseUrl/search?api_key=$apiKey&q=$encoded&limit=$limit&offset=$offset&rating=pg"
        return fetch(url)
    }

    /**
     * Fetch trending GIPHY stickers.
     */
    suspend fun trendingStickers(
        limit: Int = 30,
        offset: Int = 0
    ): List<GiphySticker> {
        val url = "$baseUrl/trending?api_key=$apiKey&limit=$limit&offset=$offset&rating=pg"
        return fetch(url)
    }

    private suspend fun fetch(urlString: String): List<GiphySticker> = withContext(Dispatchers.IO) {
        val connection = URL(urlString).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000

            if (connection.responseCode != 200) return@withContext emptyList()

            val responseText = connection.inputStream.bufferedReader().readText()
            val json = JSONObject(responseText)
            val dataArray = json.optJSONArray("data") ?: return@withContext emptyList()

            val stickers = mutableListOf<GiphySticker>()
            for (i in 0 until dataArray.length()) {
                val item = dataArray.optJSONObject(i) ?: continue
                val id = item.optString("id", "")
                val images = item.optJSONObject("images") ?: continue

                val preview = images.optJSONObject("fixed_height_small")
                val previewUrl = preview?.optString("url", "") ?: ""

                val original = images.optJSONObject("original")
                val originalUrl = original?.optString("url", "") ?: ""

                if (previewUrl.isNotBlank() && originalUrl.isNotBlank()) {
                    stickers.add(
                        GiphySticker(
                            id = id,
                            previewUrl = previewUrl,
                            originalUrl = originalUrl,
                            title = item.optString("title", "")
                        )
                    )
                }
            }
            stickers
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        /** Check if a message text is a GIPHY URL */
        fun isGiphyUrl(text: String): Boolean {
            val trimmed = text.trim()
            return trimmed.contains("giphy.com/") || trimmed.contains("media.giphy.com/")
        }
    }
}
