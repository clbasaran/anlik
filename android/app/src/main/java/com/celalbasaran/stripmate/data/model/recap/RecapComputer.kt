package com.celalbasaran.stripmate.data.model.recap

import com.celalbasaran.stripmate.data.model.Strip
import java.util.Calendar
import java.util.Date

/**
 * Haftalık ve aylık özet hesaplama motoru.
 * Mevcut strip verisinden zengin içgörüler üretir.
 * iOS RollcallComputer karşılığı.
 */
object RecapComputer {

    // ─── Ana Hesaplama ──────────────────────────────────────────────────

    /**
     * Strip listesinden zengin haftalık özetler hesaplar.
     */
    fun computeWeeklySummaries(
        strips: List<Strip>,
        currentUserId: String,
        friendNameCache: Map<String, String> = emptyMap()
    ): List<WeeklySummary> {
        val calendar = Calendar.getInstance()

        // 1. ISO haftaya göre grupla
        data class WeekKey(val year: Int, val week: Int)

        val grouped = strips.groupBy { strip ->
            calendar.time = strip.timestamp
            WeekKey(
                calendar.get(Calendar.YEAR),
                calendar.get(Calendar.WEEK_OF_YEAR)
            )
        }

        // 2. Hafta verilerini oluştur
        data class WeekData(
            val key: WeekKey,
            val strips: List<Strip>,
            val start: Date,
            val end: Date
        )

        val weeklyData = grouped.map { (key, weekStrips) ->
            val sorted = weekStrips.sortedBy { it.timestamp }
            val refDate = sorted.firstOrNull()?.timestamp ?: Date()
            calendar.time = refDate
            calendar.set(Calendar.DAY_OF_WEEK, calendar.firstDayOfWeek)
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            val start = calendar.time
            calendar.add(Calendar.DAY_OF_YEAR, 6)
            val end = calendar.time
            WeekData(key, weekStrips, start, end)
        }.sortedByDescending { it.start }

        // 3. Her hafta için zengin özet oluştur
        return weeklyData.mapIndexed { index, week ->
            val weekStrips = week.strips
            val sortedByTime = weekStrips.sortedBy { it.timestamp }

            // Sent / Received ayrımı
            val sentCount = weekStrips.count { it.senderId == currentUserId }
            val receivedCount = weekStrips.count { it.senderId != currentUserId }

            // Benzersiz şehirler
            val cities = weekStrips.mapNotNull { it.cityName }.distinct().sorted()

            // Arkadaş frekansı
            val (topFriendId, topFriendCount, friendsCount) = computeTopFriend(weekStrips, currentUserId)
            val topFriendName = topFriendId?.let { friendNameCache[it] }

            // En aktif gün
            val (activeDay, activeDayCount) = computeMostActiveDay(weekStrips)
            val activeDayName = activeDay?.let { WeeklySummary.weekdayName(it) }

            // Zaman dağılımı
            val timeDist = computeTimeDistribution(weekStrips)

            // Trend hesapla
            val previousWeekCount = if (index + 1 < weeklyData.size) weeklyData[index + 1].strips.size else null
            val trend = computeTrend(weekStrips.size, previousWeekCount)

            // Öne çıkan fotoğraflar
            val highlight = sortedByTime.firstOrNull()?.imageUrl ?: sortedByTime.lastOrNull()?.imageUrl
            val firstTimestamp = sortedByTime.firstOrNull()?.timestamp
            val lastTimestamp = sortedByTime.lastOrNull()?.timestamp

            // Thumbnail: haftanın son gizli olmayan fotoğrafı
            val thumbnail = weekStrips
                .sortedByDescending { it.timestamp }
                .firstOrNull { !it.isSecret }?.imageUrl
                ?: weekStrips.lastOrNull()?.imageUrl

            WeeklySummary(
                weekNumber = week.key.week,
                year = week.key.year,
                startDate = week.start,
                endDate = week.end,
                photosCount = weekStrips.size,
                sentCount = sentCount,
                receivedCount = receivedCount,
                thumbnailUrl = thumbnail,
                uniqueCities = cities,
                friendsInteractedCount = friendsCount,
                topFriendId = topFriendId,
                topFriendDisplayName = topFriendName,
                topFriendPhotoCount = topFriendCount,
                mostActiveDay = activeDay,
                mostActiveDayName = activeDayName,
                mostActiveDayCount = activeDayCount,
                timeDistribution = timeDist,
                previousWeekPhotosCount = previousWeekCount,
                trend = trend,
                highlightPhotoUrl = highlight,
                firstPhotoTimestamp = firstTimestamp,
                lastPhotoTimestamp = lastTimestamp
            )
        }
    }

    // ─── Alt Hesaplamalar ───────────────────────────────────────────────

    private data class TopFriendResult(
        val topFriendId: String?,
        val topFriendCount: Int,
        val uniqueFriendsCount: Int
    )

    /**
     * En çok etkileşilen arkadaşı bul.
     */
    private fun computeTopFriend(
        strips: List<Strip>,
        currentUserId: String
    ): TopFriendResult {
        val friendCounts = mutableMapOf<String, Int>()

        for (strip in strips) {
            if (strip.senderId == currentUserId) {
                for (receiverId in strip.receiverIds) {
                    if (receiverId != currentUserId) {
                        friendCounts[receiverId] = (friendCounts[receiverId] ?: 0) + 1
                    }
                }
            } else {
                if (strip.senderId != currentUserId) {
                    friendCounts[strip.senderId] = (friendCounts[strip.senderId] ?: 0) + 1
                }
            }
        }

        friendCounts.remove(currentUserId)

        val uniqueFriends = friendCounts.size
        val top = friendCounts.maxByOrNull { it.value }
        return TopFriendResult(top?.key, top?.value ?: 0, uniqueFriends)
    }

    /**
     * Haftanın en aktif gününü bul.
     */
    private fun computeMostActiveDay(strips: List<Strip>): Pair<Int?, Int> {
        val calendar = Calendar.getInstance()
        val grouped = strips.groupBy { strip ->
            calendar.time = strip.timestamp
            calendar.get(Calendar.DAY_OF_WEEK)
        }
        val top = grouped.maxByOrNull { it.value.size }
        return Pair(top?.key, top?.value?.size ?: 0)
    }

    /**
     * Zaman dağılımını hesapla.
     */
    private fun computeTimeDistribution(strips: List<Strip>): TimeDistribution {
        val calendar = Calendar.getInstance()
        var morning = 0; var afternoon = 0; var evening = 0; var night = 0

        for (strip in strips) {
            calendar.time = strip.timestamp
            when (calendar.get(Calendar.HOUR_OF_DAY)) {
                in 6..11 -> morning++
                in 12..16 -> afternoon++
                in 17..20 -> evening++
                else -> night++  // 21-5
            }
        }

        return TimeDistribution(morning, afternoon, evening, night)
    }

    /**
     * Haftalık trend hesapla.
     */
    private fun computeTrend(current: Int, previous: Int?): WeekTrend {
        if (previous == null) return WeekTrend.FirstWeek
        if (previous == 0) return if (current > 0) WeekTrend.Up(100) else WeekTrend.Same

        val diff = current - previous
        if (diff == 0) return WeekTrend.Same

        val pct = kotlin.math.abs(diff * 100 / previous)
        return if (diff > 0) WeekTrend.Up(pct) else WeekTrend.Down(pct)
    }

    // ─── Aylık Özet Hesaplama ───────────────────────────────────────────

    /**
     * Strip listesinden aylık özetler hesaplar.
     */
    fun computeMonthlySummaries(
        strips: List<Strip>,
        currentUserId: String,
        weeklySummaries: List<WeeklySummary> = emptyList(),
        friendNameCache: Map<String, String> = emptyMap()
    ): List<MonthlySummary> {
        val calendar = Calendar.getInstance()
        val now = Date()
        calendar.time = now
        val currentMonth = calendar.get(Calendar.MONTH) + 1
        val currentYear = calendar.get(Calendar.YEAR)

        data class MonthKey(val year: Int, val month: Int)

        val grouped = strips.groupBy { strip ->
            calendar.time = strip.timestamp
            MonthKey(calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH) + 1)
        }

        return grouped.mapNotNull { (key, monthStrips) ->
            // Sadece tamamlanmış ayları göster (mevcut ay hariç)
            if (key.year == currentYear && key.month == currentMonth) return@mapNotNull null

            val totalPhotos = monthStrips.size
            val sentCount = monthStrips.count { it.senderId == currentUserId }
            val receivedCount = monthStrips.count { it.senderId != currentUserId }

            // Benzersiz şehirler
            val cities = monthStrips.mapNotNull { it.cityName }.distinct().sorted()

            // Arkadaş etkileşimi
            val (topFriendId, topFriendCount, friendsCount) = computeTopFriend(monthStrips, currentUserId)
            val topFriendName = topFriendId?.let { friendNameCache[it] }

            // Günlük ortalama
            calendar.set(Calendar.YEAR, key.year)
            calendar.set(Calendar.MONTH, key.month - 1)
            val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
            val avgPerDay = totalPhotos.toDouble() / daysInMonth

            // O aya ait haftalık özetlerden en aktif haftayı bul
            val monthWeeklies = weeklySummaries.filter { summary ->
                calendar.time = summary.startDate
                val summaryMonth = calendar.get(Calendar.MONTH) + 1
                val summaryYear = calendar.get(Calendar.YEAR)
                summaryMonth == key.month && summaryYear == key.year
            }
            val mostActiveWeek = monthWeeklies.maxByOrNull { it.photosCount }

            // Haftalık breakdown
            val weeklyBreakdown = monthWeeklies
                .sortedBy { it.startDate }
                .map { it.photosCount }

            // En yüksek seri
            val streakHighlight = monthWeeklies.maxOfOrNull { it.longestActiveStreak } ?: 0

            // Thumbnail
            val thumbnail = monthStrips
                .sortedByDescending { it.timestamp }
                .firstOrNull { !it.isSecret }?.imageUrl
                ?: monthStrips.lastOrNull()?.imageUrl

            MonthlySummary(
                month = key.month,
                year = key.year,
                totalPhotos = totalPhotos,
                totalSent = sentCount,
                totalReceived = receivedCount,
                uniqueCities = cities,
                uniqueFriendsCount = friendsCount,
                topFriendId = topFriendId,
                topFriendDisplayName = topFriendName,
                topFriendPhotoCount = topFriendCount,
                averagePhotosPerDay = avgPerDay,
                mostActiveWeekNumber = mostActiveWeek?.weekNumber,
                mostActiveWeekCount = mostActiveWeek?.photosCount ?: 0,
                streakHighlight = streakHighlight,
                weeklyBreakdown = weeklyBreakdown,
                thumbnailUrl = thumbnail
            )
        }.sortedWith(compareByDescending<MonthlySummary> { it.year }.thenByDescending { it.month })
    }
}
