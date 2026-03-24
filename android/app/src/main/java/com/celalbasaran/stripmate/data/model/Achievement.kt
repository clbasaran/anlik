package com.celalbasaran.stripmate.data.model

import java.util.Date

data class Achievement(
    val id: String,
    val title: String,
    val description: String,
    val emoji: String,
    val category: AchievementCategory,
    val requirement: Int
) {
    companion object {
        val ALL_ACHIEVEMENTS: List<Achievement> = listOf(
            // Photo milestones
            Achievement("first_photo", "ilk an", "ilk fotoğrafını gönder", "\uD83D\uDCF8", AchievementCategory.PHOTOS, 1),
            Achievement("photos_10", "anları biriktiren", "10 fotoğraf gönder", "\uD83C\uDF9E\uFE0F", AchievementCategory.PHOTOS, 10),
            Achievement("photos_50", "fotoğraf tutkunu", "50 fotoğraf gönder", "\uD83C\uDF1F", AchievementCategory.PHOTOS, 50),
            Achievement("photos_100", "yüz an", "100 fotoğraf gönder", "\uD83D\uDC8E", AchievementCategory.PHOTOS, 100),
            Achievement("photos_500", "efsane", "500 fotoğraf gönder", "\uD83D\uDC51", AchievementCategory.PHOTOS, 500),

            // Streak milestones
            Achievement("streak_7", "bir hafta", "7 günlük seri yakala", "\uD83D\uDD25", AchievementCategory.STREAKS, 7),
            Achievement("streak_30", "bir ay", "30 günlük seri yakala", "\u26A1", AchievementCategory.STREAKS, 30),
            Achievement("streak_100", "yüz gün", "100 günlük seri yakala", "\uD83C\uDFC6", AchievementCategory.STREAKS, 100),
            Achievement("streak_365", "bir yıl", "365 günlük seri yakala", "\uD83D\uDCAB", AchievementCategory.STREAKS, 365),

            // Social milestones
            Achievement("first_friend", "ilk bağlantı", "ilk arkadaşını ekle", "\uD83E\uDD1D", AchievementCategory.SOCIAL, 1),
            Achievement("friends_5", "beşli", "5 arkadaş edin", "\uD83D\uDC65", AchievementCategory.SOCIAL, 5),
            Achievement("friends_10", "popüler", "10 arkadaş edin", "\uD83C\uDF10", AchievementCategory.SOCIAL, 10),
            Achievement("friends_25", "sosyal kelebek", "25 arkadaş edin", "\uD83E\uDD8B", AchievementCategory.SOCIAL, 25),
            Achievement("first_comment", "ilk yorum", "ilk yorumunu yaz", "\uD83D\uDCAC", AchievementCategory.SOCIAL, 1),
            Achievement("reaction_50", "tepki makinesi", "50 reaksiyon ver", "\uD83C\uDFAD", AchievementCategory.SOCIAL, 50),
            Achievement("dm_100", "sohbet ustası", "100 DM gönder", "\u2709\uFE0F", AchievementCategory.SOCIAL, 100),

            // Explorer milestones
            Achievement("cities_3", "gezgin", "3 farklı şehirden fotoğraf gönder", "\uD83D\uDDFA\uFE0F", AchievementCategory.EXPLORER, 3),
            Achievement("cities_10", "kaşif", "10 farklı şehirden fotoğraf gönder", "\uD83E\uDDED", AchievementCategory.EXPLORER, 10),
            Achievement("daily_prompt_7", "görev canavarı", "7 günlük görev tamamla", "\u2705", AchievementCategory.EXPLORER, 7),
            Achievement("daily_prompt_30", "görev ustası", "30 günlük görev tamamla", "\uD83C\uDFAF", AchievementCategory.EXPLORER, 30),
            Achievement("night_owl", "gece kuşu", "gece yarısından sonra fotoğraf gönder", "\uD83E\uDD89", AchievementCategory.EXPLORER, 1),
            Achievement("early_bird", "erken kuş", "sabah 7'den önce fotoğraf gönder", "\uD83D\uDC26", AchievementCategory.EXPLORER, 1),
            Achievement("memory_lane", "anı yolu", "'Bugün Geçen Yıl' anısını görüntüle", "\uD83D\uDD70\uFE0F", AchievementCategory.EXPLORER, 1)
        )

        fun findById(id: String): Achievement? =
            ALL_ACHIEVEMENTS.firstOrNull { it.id == id }
    }
}

enum class AchievementCategory(val displayName: String) {
    PHOTOS("fotoğraf"),
    STREAKS("seri"),
    SOCIAL("sosyal"),
    EXPLORER("kaşif")
}

data class UserAchievement(
    val achievementId: String = "",
    val unlockedAt: Date = Date()
)
