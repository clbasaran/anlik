package com.celalbasaran.stripmate.service.location

import android.annotation.SuppressLint
import android.content.Context
import android.location.Geocoder
import android.os.Build
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume

@Singleton
class LocationRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context
) : LocationRepository {

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    @SuppressLint("MissingPermission")
    override suspend fun fetchLocation(): Pair<Double, Double>? {
        return try {
            withTimeoutOrNull(10_000L) {
                val cancellationTokenSource = CancellationTokenSource()
                val location = fusedLocationClient.getCurrentLocation(
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                    cancellationTokenSource.token
                ).await()

                if (location != null) {
                    Pair(location.latitude, location.longitude)
                } else {
                    // Fallback to last known location
                    val lastLocation = fusedLocationClient.lastLocation.await()
                    if (lastLocation != null) {
                        Pair(lastLocation.latitude, lastLocation.longitude)
                    } else {
                        null
                    }
                }
            }
        } catch (e: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    override suspend fun reverseGeocode(latitude: Double, longitude: Double): String? {
        return try {
            if (!Geocoder.isPresent()) return null

            val geocoder = Geocoder(context, Locale.getDefault())

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Use async API on Android 13+
                suspendCancellableCoroutine { continuation ->
                    geocoder.getFromLocation(latitude, longitude, 1) { addresses ->
                        val address = addresses.firstOrNull()
                        val cityName = address?.locality
                            ?: address?.subAdminArea
                            ?: address?.adminArea
                        continuation.resume(cityName)
                    }
                }
            } else {
                // Use synchronous API on older versions
                val addresses = geocoder.getFromLocation(latitude, longitude, 1)
                val address = addresses?.firstOrNull()
                address?.locality
                    ?: address?.subAdminArea
                    ?: address?.adminArea
            }
        } catch (e: Exception) {
            null
        }
    }
}
