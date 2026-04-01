package com.celalbasaran.stripmate.data.model.recap

/**
 * Aylık özet modeli — iOS MonthlySummary karşılığı.
 */
data class MonthlySummary(
    val month: Int,
    val year: Int,
    val totalPhotos: Int,
    val totalSent: Int,
    val totalReceived: Int,
    val uniqueCities: List<String>,
    val uniqueFriendsCount: Int,
    val topFriendId: String?,
    val topFriendDisplayName: String?,
    val topFriendPhotoCount: Int,
    val averagePhotosPerDay: Double,
    val mostActiveWeekNumber: Int?,
    val mostActiveWeekCount: Int,
    val streakHighlight: Int,
    val weeklyBreakdown: List<Int>,  // haftalık fotoğraf sayıları (sparkline / bar chart için)
    val thumbnailUrl: String?
) {
    val id: String get() = "$year-${month.toString().padStart(2, '0')}"

    val monthName: String
        get() {
            val names = listOf(
                "", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
                "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
            )
            return if (month in 1..12) names[month] else ""
        }
}
