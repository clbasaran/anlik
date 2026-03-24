package com.celalbasaran.stripmate.service.location

interface LocationRepository {

    suspend fun fetchLocation(): Pair<Double, Double>?

    suspend fun reverseGeocode(latitude: Double, longitude: Double): String?
}
