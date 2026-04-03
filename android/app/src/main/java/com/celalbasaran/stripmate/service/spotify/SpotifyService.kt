package com.celalbasaran.stripmate.service.spotify

import javax.inject.Inject
import javax.inject.Singleton

data class SpotifyTrack(
    val id: String,
    val name: String,
    val artist: String,
    val albumImageUrl: String? = null,
    val previewUrl: String? = null
)

@Singleton
class SpotifyService @Inject constructor() {

    suspend fun searchTracks(query: String): List<SpotifyTrack> {
        if (query.isBlank()) return emptyList()
        // Spotify search is a future integration; return empty for now.
        return emptyList()
    }
}
