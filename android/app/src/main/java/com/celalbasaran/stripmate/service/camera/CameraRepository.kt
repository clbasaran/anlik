package com.celalbasaran.stripmate.service.camera

import android.graphics.Bitmap
import android.net.Uri

interface CameraRepository {

    fun resizeAndCompress(bitmap: Bitmap, maxDimension: Int = 1080, quality: Int = 75): ByteArray

    fun fixOrientation(bitmap: Bitmap, uri: Uri): Bitmap
}
