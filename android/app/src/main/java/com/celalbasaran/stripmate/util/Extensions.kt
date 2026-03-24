package com.celalbasaran.stripmate.util

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentSnapshot
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// Firestore document extensions

fun DocumentSnapshot.getDateField(field: String): Date? =
    getTimestamp(field)?.toDate()

fun DocumentSnapshot.getStringList(field: String): List<String> {
    @Suppress("UNCHECKED_CAST")
    return get(field) as? List<String> ?: emptyList()
}

fun DocumentSnapshot.getStringMap(field: String): Map<String, String> {
    @Suppress("UNCHECKED_CAST")
    return get(field) as? Map<String, String> ?: emptyMap()
}

fun DocumentSnapshot.getIntField(field: String, default: Int = 0): Int =
    getLong(field)?.toInt() ?: default

fun DocumentSnapshot.getBoolField(field: String, default: Boolean = false): Boolean =
    getBoolean(field) ?: default

// Date formatting

fun Date.toFirestoreTimestamp(): Timestamp = Timestamp(this)

fun Date.formatDate(pattern: String = "dd MMM yyyy"): String {
    val sdf = SimpleDateFormat(pattern, Locale("tr", "TR"))
    return sdf.format(this)
}

fun Date.formatTime(): String {
    val sdf = SimpleDateFormat("HH:mm", Locale("tr", "TR"))
    return sdf.format(this)
}

fun Date.formatDateTime(): String {
    val sdf = SimpleDateFormat("dd MMM yyyy HH:mm", Locale("tr", "TR"))
    return sdf.format(this)
}

fun Date.formatDateShort(): String {
    val sdf = SimpleDateFormat("dd.MM.yyyy", Locale("tr", "TR"))
    return sdf.format(this)
}

fun Date.isToday(): Boolean {
    val todayFormat = SimpleDateFormat("yyyyMMdd", Locale.getDefault())
    return todayFormat.format(this) == todayFormat.format(Date())
}

fun Date.isYesterday(): Boolean {
    val cal = java.util.Calendar.getInstance()
    cal.add(java.util.Calendar.DAY_OF_YEAR, -1)
    val yesterdayFormat = SimpleDateFormat("yyyyMMdd", Locale.getDefault())
    return yesterdayFormat.format(this) == yesterdayFormat.format(cal.time)
}

// String helpers

fun String.isValidEmail(): Boolean {
    return android.util.Patterns.EMAIL_ADDRESS.matcher(this).matches()
}

fun String.isValidUsername(): Boolean {
    if (length < 3 || length > 20) return false
    return matches(Regex("^[a-zA-Z0-9._]+$"))
}

fun String.isValidInviteCode(): Boolean {
    return length == Constants.INVITE_CODE_LENGTH && matches(Regex("^[A-Z0-9]+$"))
}

fun String.truncate(maxLength: Int, ellipsis: String = "..."): String {
    return if (length > maxLength) {
        take(maxLength - ellipsis.length) + ellipsis
    } else {
        this
    }
}

fun String.toInitials(): String {
    return split(" ")
        .filter { it.isNotBlank() }
        .take(2)
        .mapNotNull { it.firstOrNull()?.uppercaseChar() }
        .joinToString("")
}
