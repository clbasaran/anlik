package com.celalbasaran.stripmate.util

import java.util.Date
import java.util.concurrent.TimeUnit

/**
 * Turkish relative time formatter.
 * Examples: "şimdi", "5dk", "3sa", "2g", "1h", "3ay"
 */
object TimeAgo {

    fun format(date: Date): String {
        val now = System.currentTimeMillis()
        val diff = now - date.time

        if (diff < 0) return "şimdi"

        val seconds = TimeUnit.MILLISECONDS.toSeconds(diff)
        val minutes = TimeUnit.MILLISECONDS.toMinutes(diff)
        val hours = TimeUnit.MILLISECONDS.toHours(diff)
        val days = TimeUnit.MILLISECONDS.toDays(diff)

        return when {
            seconds < 60 -> "şimdi"
            minutes < 60 -> "${minutes}dk"
            hours < 24 -> "${hours}sa"
            days < 7 -> "${days}g"
            days < 30 -> "${days / 7}h"
            days < 365 -> "${days / 30}ay"
            else -> "${days / 365}y"
        }
    }

    fun formatLong(date: Date): String {
        val now = System.currentTimeMillis()
        val diff = now - date.time

        if (diff < 0) return "şimdi"

        val seconds = TimeUnit.MILLISECONDS.toSeconds(diff)
        val minutes = TimeUnit.MILLISECONDS.toMinutes(diff)
        val hours = TimeUnit.MILLISECONDS.toHours(diff)
        val days = TimeUnit.MILLISECONDS.toDays(diff)

        return when {
            seconds < 60 -> "şimdi"
            minutes < 60 -> "$minutes dakika önce"
            hours < 24 -> "$hours saat önce"
            days < 7 -> "$days gün önce"
            days < 30 -> "${days / 7} hafta önce"
            days < 365 -> "${days / 30} ay önce"
            else -> "${days / 365} yıl önce"
        }
    }
}
