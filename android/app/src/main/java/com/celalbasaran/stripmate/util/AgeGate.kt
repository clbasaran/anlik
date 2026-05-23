package com.celalbasaran.stripmate.util

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SelectableDates
import java.util.Calendar
import java.util.Date

fun isAtLeastMinimumRegistrationAge(dateOfBirth: Date?, now: Date = Date()): Boolean {
    dateOfBirth ?: return false

    val birthCalendar = Calendar.getInstance().apply { time = dateOfBirth }
    val currentCalendar = Calendar.getInstance().apply { time = now }
    var age = currentCalendar.get(Calendar.YEAR) - birthCalendar.get(Calendar.YEAR)

    if (
        currentCalendar.get(Calendar.MONTH) < birthCalendar.get(Calendar.MONTH) ||
        (
            currentCalendar.get(Calendar.MONTH) == birthCalendar.get(Calendar.MONTH) &&
            currentCalendar.get(Calendar.DAY_OF_MONTH) < birthCalendar.get(Calendar.DAY_OF_MONTH)
        )
    ) {
        age--
    }

    return age >= Constants.MINIMUM_REGISTRATION_AGE
}

fun latestAllowedBirthDate(now: Date = Date()): Date =
    Calendar.getInstance().apply {
        time = now
        add(Calendar.YEAR, -Constants.MINIMUM_REGISTRATION_AGE)
    }.time

fun latestAllowedBirthDateMillis(now: Date = Date()): Long = latestAllowedBirthDate(now).time

@OptIn(ExperimentalMaterial3Api::class)
fun birthDateSelectableDates(latestBirthDateMillis: Long = latestAllowedBirthDateMillis()): SelectableDates {
    val latestYear = Calendar.getInstance().apply { timeInMillis = latestBirthDateMillis }.get(Calendar.YEAR)
    return object : SelectableDates {
        override fun isSelectableDate(utcTimeMillis: Long): Boolean = utcTimeMillis <= latestBirthDateMillis
        override fun isSelectableYear(year: Int): Boolean = year <= latestYear
    }
}
