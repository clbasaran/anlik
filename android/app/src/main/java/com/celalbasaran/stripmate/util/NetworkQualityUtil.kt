package com.celalbasaran.stripmate.util

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities

/**
 * Provides adaptive JPEG quality based on current network type and data-saver preference.
 *
 * - WiFi: 92 (high)
 * - Cellular (4G/LTE): 85 (medium)
 * - Cellular (slow / metered): 75 (low)
 * - Data Saver enabled: always 75
 */
object NetworkQualityUtil {

    private const val PREF_DATA_SAVER = "data_saver_mode"

    const val QUALITY_HIGH = 92
    const val QUALITY_MEDIUM = 85
    const val QUALITY_LOW = 75

    /**
     * Returns the recommended JPEG compression quality (0-100) for the current network conditions.
     */
    fun recommendedJpegQuality(context: Context): Int {
        val prefs = context.getSharedPreferences("${context.packageName}_preferences", Context.MODE_PRIVATE)
        if (prefs.getBoolean(PREF_DATA_SAVER, false)) {
            return QUALITY_LOW
        }

        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return QUALITY_HIGH

        val network = cm.activeNetwork ?: return QUALITY_LOW
        val caps = cm.getNetworkCapabilities(network) ?: return QUALITY_LOW

        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> QUALITY_HIGH
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> QUALITY_HIGH
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> {
                // If the network is marked as not metered, treat as fast cellular
                if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)) {
                    QUALITY_MEDIUM
                } else {
                    QUALITY_HIGH
                }
            }
            else -> QUALITY_MEDIUM
        }
    }
}
