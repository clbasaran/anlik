package com.celalbasaran.stripmate.data.model.recap

import java.util.Date

/**
 * Zaman dağılımı: sabah/öğle/akşam/gece fotoğraf sayıları.
 */
data class TimeDistribution(
    val morning: Int = 0,    // 06:00-11:59
    val afternoon: Int = 0,  // 12:00-16:59
    val evening: Int = 0,    // 17:00-20:59
    val night: Int = 0       // 21:00-05:59
) {
    val total: Int get() = morning + afternoon + evening + night

    val dominantPeriod: String
        get() {
            if (total == 0) return ""
            val periods = listOf(
                "sabah" to morning,
                "öğleden sonra" to afternoon,
                "akşam" to evening,
                "gece" to night
            )
            return periods.maxByOrNull { it.second }?.first ?: ""
        }

    val dominantIcon: String
        get() {
            if (total == 0) return "schedule"
            val periods = listOf(
                "wb_twilight" to morning,
                "wb_sunny" to afternoon,
                "nights_stay" to evening,
                "dark_mode" to night
            )
            return periods.maxByOrNull { it.second }?.first ?: "schedule"
        }

    companion object {
        val EMPTY = TimeDistribution()
    }
}

/**
 * Haftalık trend karşılaştırması.
 */
sealed class WeekTrend {
    data class Up(val percentage: Int) : WeekTrend()
    data class Down(val percentage: Int) : WeekTrend()
    data object Same : WeekTrend()
    data object FirstWeek : WeekTrend()

    val isPositive: Boolean get() = this is Up

    val description: String
        get() = when (this) {
            is Up -> "geçen haftaya göre %$percentage daha fazla"
            is Down -> "geçen haftaya göre %$percentage daha az"
            is Same -> "geçen haftayla aynı tempo"
            is FirstWeek -> "ilk haftan kutlu olsun!"
        }
}

/**
 * Seri kilometre taşı.
 */
data class StreakMilestone(
    val friendId: String,
    val friendDisplayName: String,
    val milestoneValue: Int,   // 7, 14, 30, 50, 100
    val currentStreak: Int
) {
    val id: String get() = "${friendId}_$milestoneValue"
}

/**
 * Haftalık özet modeli — iOS RollcallSummary karşılığı.
 */
data class WeeklySummary(
    val weekNumber: Int,
    val year: Int,
    val startDate: Date,
    val endDate: Date,

    // Temel metrikler
    val photosCount: Int,
    val sentCount: Int = 0,
    val receivedCount: Int = 0,
    val thumbnailUrl: String? = null,

    // Şehirler
    val uniqueCities: List<String> = emptyList(),

    // Arkadaş etkileşimi
    val friendsInteractedCount: Int = 0,
    val topFriendId: String? = null,
    val topFriendDisplayName: String? = null,
    val topFriendPhotoCount: Int = 0,

    // Zaman kalıpları
    val mostActiveDay: Int? = null,          // Calendar weekday (1=Paz, 2=Pzt, ..., 7=Cmt)
    val mostActiveDayName: String? = null,
    val mostActiveDayCount: Int = 0,
    val timeDistribution: TimeDistribution = TimeDistribution.EMPTY,

    // Seri içgörüleri
    val streakMilestones: List<StreakMilestone> = emptyList(),
    val longestActiveStreak: Int = 0,

    // Önceki hafta karşılaştırması
    val previousWeekPhotosCount: Int? = null,
    val trend: WeekTrend = WeekTrend.FirstWeek,

    // Öne çıkan fotoğraf
    val highlightPhotoUrl: String? = null,
    val firstPhotoTimestamp: Date? = null,
    val lastPhotoTimestamp: Date? = null
) {
    val id: String get() = "$year-W$weekNumber"

    /** Gösterilecek toplam sayfa sayısı (boş sayfalar hariç). */
    val storyPageCount: Int
        get() {
            var count = 3 // başlık + fotoğraf sayısı + grid (her zaman var)
            if (topFriendId != null) count += 1
            if (uniqueCities.isNotEmpty()) count += 1
            if (photosCount >= 3) count += 1 // zaman kalıpları
            if (longestActiveStreak > 0 || streakMilestones.isNotEmpty()) count += 1
            return count
        }

    companion object {
        private val weekdayNames = listOf(
            "", "Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"
        )

        fun weekdayName(weekday: Int): String {
            return if (weekday in 1..7) weekdayNames[weekday] else ""
        }
    }
}
