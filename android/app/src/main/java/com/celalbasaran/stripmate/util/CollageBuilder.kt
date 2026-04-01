package com.celalbasaran.stripmate.util

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import com.celalbasaran.stripmate.data.model.CollageAspectRatio
import com.celalbasaran.stripmate.data.model.CollageBackground
import com.celalbasaran.stripmate.data.model.CollageCornerStyle
import com.celalbasaran.stripmate.data.model.CollageLayout
import com.celalbasaran.stripmate.data.model.PhotoTransform

object CollageBuilder {

    fun build(
        images: List<Bitmap>,
        layout: CollageLayout,
        gap: Float = 4f,
        background: CollageBackground = CollageBackground.BLACK,
        cornerStyle: CollageCornerStyle = CollageCornerStyle.ROUNDED,
        aspectRatio: CollageAspectRatio = CollageAspectRatio.PORTRAIT,
        transforms: Map<Int, PhotoTransform> = emptyMap()
    ): Bitmap {
        val outputW = aspectRatio.width.toInt()
        val outputH = aspectRatio.height.toInt()
        val downscaled = images.map { downscaleToMax(it, outputH) }
        val radius = if (cornerStyle == CollageCornerStyle.ROUNDED) 24f else 0f

        val output = Bitmap.createBitmap(outputW, outputH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)

        when (background) {
            CollageBackground.BLACK -> canvas.drawColor(android.graphics.Color.BLACK)
            CollageBackground.WHITE -> canvas.drawColor(android.graphics.Color.WHITE)
            CollageBackground.BLUR_FILL -> {
                if (downscaled.isNotEmpty()) {
                    val blurred = stackBlur(downscaled[0], 30)
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
                    drawImageInRect(canvas, blurred, RectF(0f, 0f, outputW.toFloat(), outputH.toFloat()), paint)
                    blurred.recycle()
                } else {
                    canvas.drawColor(android.graphics.Color.BLACK)
                }
            }
        }

        val cells = getCells(layout, gap, aspectRatio)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

        for (i in cells.indices) {
            if (i >= downscaled.size) break
            val rect = cells[i]
            val transform = transforms[i] ?: PhotoTransform()
            drawImageInCell(canvas, downscaled[i], rect, radius, paint, transform)
        }

        return output
    }

    fun getCells(
        layout: CollageLayout,
        gap: Float = 4f,
        aspectRatio: CollageAspectRatio = CollageAspectRatio.PORTRAIT
    ): List<RectF> {
        val w = aspectRatio.width
        val h = aspectRatio.height
        val g = gap

        return when (layout) {
            // ── 2-photo ────────────────────────────────
            CollageLayout.TWO_HORIZONTAL -> {
                val cellW = (w - g) / 2f
                listOf(
                    RectF(0f, 0f, cellW, h),
                    RectF(cellW + g, 0f, w, h)
                )
            }
            CollageLayout.TWO_VERTICAL -> {
                val cellH = (h - g) / 2f
                listOf(
                    RectF(0f, 0f, w, cellH),
                    RectF(0f, cellH + g, w, h)
                )
            }
            CollageLayout.TWO_DIAGONAL -> {
                val splitX = w * 0.55f
                val splitY = h * 0.55f
                listOf(
                    RectF(0f, 0f, splitX - g / 2f, splitY - g / 2f),
                    RectF(splitX + g / 2f, splitY + g / 2f, w, h)
                )
            }
            CollageLayout.TWO_LEFT_WIDE -> {
                val leftW = (w - g) * 0.7f
                listOf(
                    RectF(0f, 0f, leftW, h),
                    RectF(leftW + g, 0f, w, h)
                )
            }

            // ── 3-photo ────────────────────────────────
            CollageLayout.THREE_LEFT_LARGE -> {
                val leftW = (w - g) * 0.6f
                val rightH = (h - g) / 2f
                listOf(
                    RectF(0f, 0f, leftW, h),
                    RectF(leftW + g, 0f, w, rightH),
                    RectF(leftW + g, rightH + g, w, h)
                )
            }
            CollageLayout.THREE_TOP_LARGE -> {
                val topH = (h - g) * 0.6f
                val cellW = (w - g) / 2f
                listOf(
                    RectF(0f, 0f, w, topH),
                    RectF(0f, topH + g, cellW, h),
                    RectF(cellW + g, topH + g, w, h)
                )
            }
            CollageLayout.THREE_RIGHT_LARGE -> {
                val rightW = (w - g) * 0.6f
                val leftW = w - rightW - g
                val leftH = (h - g) / 2f
                listOf(
                    RectF(0f, 0f, leftW, leftH),
                    RectF(0f, leftH + g, leftW, h),
                    RectF(leftW + g, 0f, w, h)
                )
            }
            CollageLayout.THREE_BOTTOM_LARGE -> {
                val bottomH = (h - g) * 0.6f
                val topH = h - bottomH - g
                val cellW = (w - g) / 2f
                listOf(
                    RectF(0f, 0f, cellW, topH),
                    RectF(cellW + g, 0f, w, topH),
                    RectF(0f, topH + g, w, h)
                )
            }
            CollageLayout.THREE_EQUAL_ROWS -> {
                val cellH = (h - 2f * g) / 3f
                listOf(
                    RectF(0f, 0f, w, cellH),
                    RectF(0f, cellH + g, w, 2f * cellH + g),
                    RectF(0f, 2f * (cellH + g), w, h)
                )
            }
            CollageLayout.THREE_EQUAL_COLS -> {
                val cellW = (w - 2f * g) / 3f
                listOf(
                    RectF(0f, 0f, cellW, h),
                    RectF(cellW + g, 0f, 2f * cellW + g, h),
                    RectF(2f * (cellW + g), 0f, w, h)
                )
            }

            // ── 4-photo ────────────────────────────────
            CollageLayout.FOUR_GRID -> {
                val cellW = (w - g) / 2f
                val cellH = (h - g) / 2f
                listOf(
                    RectF(0f, 0f, cellW, cellH),
                    RectF(cellW + g, 0f, w, cellH),
                    RectF(0f, cellH + g, cellW, h),
                    RectF(cellW + g, cellH + g, w, h)
                )
            }
            CollageLayout.FOUR_TOP_ROW -> {
                val topH = (h - g) * 0.6f
                val bottomH = h - topH - g
                val cellW = (w - 2f * g) / 3f
                listOf(
                    RectF(0f, 0f, w, topH),
                    RectF(0f, topH + g, cellW, h),
                    RectF(cellW + g, topH + g, 2f * cellW + g, h),
                    RectF(2f * (cellW + g), topH + g, w, h)
                )
            }
            CollageLayout.FOUR_BOTTOM_ROW -> {
                val bottomH = (h - g) * 0.6f
                val topH = h - bottomH - g
                val cellW = (w - 2f * g) / 3f
                listOf(
                    RectF(0f, 0f, cellW, topH),
                    RectF(cellW + g, 0f, 2f * cellW + g, topH),
                    RectF(2f * (cellW + g), 0f, w, topH),
                    RectF(0f, topH + g, w, h)
                )
            }
            CollageLayout.FOUR_LEFT_COL -> {
                val leftW = (w - g) * 0.6f
                val rightW = w - leftW - g
                val cellH = (h - 2f * g) / 3f
                listOf(
                    RectF(0f, 0f, leftW, h),
                    RectF(leftW + g, 0f, w, cellH),
                    RectF(leftW + g, cellH + g, w, 2f * cellH + g),
                    RectF(leftW + g, 2f * (cellH + g), w, h)
                )
            }
            CollageLayout.FOUR_CENTER_FOCUS -> {
                val sideH = (h - 2f * g) * 0.25f
                val centerH = (h - 2f * g) * 0.5f
                val cellW = (w - g) / 2f
                listOf(
                    RectF(0f, 0f, cellW, sideH),
                    RectF(cellW + g, 0f, w, sideH),
                    RectF(0f, sideH + g, w, sideH + g + centerH),
                    RectF(0f, sideH + centerH + 2f * g, w, h)
                )
            }
        }
    }

    private fun drawImageInCell(canvas: Canvas, bitmap: Bitmap, rect: RectF, cornerRadius: Float, paint: Paint, transform: PhotoTransform = PhotoTransform()) {
        canvas.save()
        val path = Path()
        if (cornerRadius > 0f) {
            path.addRoundRect(rect, cornerRadius, cornerRadius, Path.Direction.CW)
        } else {
            path.addRect(rect, Path.Direction.CW)
        }
        canvas.clipPath(path)
        drawImageInRect(canvas, bitmap, rect, paint, transform)
        canvas.restore()
    }

    /** Draws bitmap aspect-fill into the given rect, applying pan/zoom transform. */
    private fun drawImageInRect(canvas: Canvas, bitmap: Bitmap, rect: RectF, paint: Paint, transform: PhotoTransform = PhotoTransform()) {
        val cellWidth = rect.width()
        val cellHeight = rect.height()

        val bmpRatio = bitmap.width.toFloat() / bitmap.height.toFloat()
        val cellRatio = cellWidth / cellHeight

        // Calculate aspect-fill draw rect
        var drawW: Float
        var drawH: Float
        if (bmpRatio > cellRatio) {
            drawH = cellHeight
            drawW = drawH * bmpRatio
        } else {
            drawW = cellWidth
            drawH = drawW / bmpRatio
        }

        // Apply user's zoom
        if (transform.scale > 1f) {
            drawW *= transform.scale
            drawH *= transform.scale
        }

        var drawLeft = rect.centerX() - drawW / 2f
        var drawTop = rect.centerY() - drawH / 2f

        // Apply user's pan offset (normalized)
        val overflowX = (drawW - cellWidth) / 2f
        val overflowY = (drawH - cellHeight) / 2f
        drawLeft += transform.offsetX * overflowX
        drawTop += transform.offsetY * overflowY

        val dstRect = android.graphics.Rect(
            drawLeft.toInt(),
            drawTop.toInt(),
            (drawLeft + drawW).toInt(),
            (drawTop + drawH).toInt()
        )
        val srcRect = android.graphics.Rect(0, 0, bitmap.width, bitmap.height)
        canvas.drawBitmap(bitmap, srcRect, dstRect, paint)
    }

    /** Downscale a bitmap so its largest dimension is at most maxDim. */
    private fun downscaleToMax(bitmap: Bitmap, maxDim: Int): Bitmap {
        val maxSide = maxOf(bitmap.width, bitmap.height)
        if (maxSide <= maxDim) return bitmap

        val scale = maxDim.toFloat() / maxSide.toFloat()
        val newW = (bitmap.width * scale).toInt()
        val newH = (bitmap.height * scale).toInt()
        return Bitmap.createScaledBitmap(bitmap, newW, newH, true)
    }

    /**
     * Simple stack blur implementation for BLUR_FILL background.
     */
    fun stackBlur(source: Bitmap, radius: Int): Bitmap {
        if (radius < 1) return source.copy(Bitmap.Config.ARGB_8888, true)

        val scale = 0.25f
        val smallW = (source.width * scale).toInt().coerceAtLeast(1)
        val smallH = (source.height * scale).toInt().coerceAtLeast(1)
        val small = Bitmap.createScaledBitmap(source, smallW, smallH, true)

        val w = small.width
        val h = small.height
        val pixels = IntArray(w * h)
        small.getPixels(pixels, 0, w, 0, 0, w, h)

        val r = radius.coerceAtMost(w / 2).coerceAtMost(h / 2).coerceAtLeast(1)

        // Horizontal pass
        val temp = IntArray(w * h)
        for (y in 0 until h) {
            var rSum = 0L; var gSum = 0L; var bSum = 0L
            val rowStart = y * w
            for (x in -r..r) {
                val clampedX = x.coerceIn(0, w - 1)
                val pixel = pixels[rowStart + clampedX]
                rSum += (pixel shr 16) and 0xFF
                gSum += (pixel shr 8) and 0xFF
                bSum += pixel and 0xFF
            }
            val windowSize = (2 * r + 1)
            for (x in 0 until w) {
                temp[rowStart + x] = (0xFF shl 24) or
                        (((rSum / windowSize).toInt().coerceIn(0, 255)) shl 16) or
                        (((gSum / windowSize).toInt().coerceIn(0, 255)) shl 8) or
                        ((bSum / windowSize).toInt().coerceIn(0, 255))
                val addX = (x + r + 1).coerceAtMost(w - 1)
                val removeX = (x - r).coerceAtLeast(0)
                val addPixel = pixels[rowStart + addX]
                val removePixel = pixels[rowStart + removeX]
                rSum += ((addPixel shr 16) and 0xFF) - ((removePixel shr 16) and 0xFF)
                gSum += ((addPixel shr 8) and 0xFF) - ((removePixel shr 8) and 0xFF)
                bSum += (addPixel and 0xFF) - (removePixel and 0xFF)
            }
        }

        // Vertical pass
        val result = IntArray(w * h)
        for (x in 0 until w) {
            var rSum = 0L; var gSum = 0L; var bSum = 0L
            for (y in -r..r) {
                val clampedY = y.coerceIn(0, h - 1)
                val pixel = temp[clampedY * w + x]
                rSum += (pixel shr 16) and 0xFF
                gSum += (pixel shr 8) and 0xFF
                bSum += pixel and 0xFF
            }
            val windowSize = (2 * r + 1)
            for (y in 0 until h) {
                result[y * w + x] = (0xFF shl 24) or
                        (((rSum / windowSize).toInt().coerceIn(0, 255)) shl 16) or
                        (((gSum / windowSize).toInt().coerceIn(0, 255)) shl 8) or
                        ((bSum / windowSize).toInt().coerceIn(0, 255))
                val addY = (y + r + 1).coerceAtMost(h - 1)
                val removeY = (y - r).coerceAtLeast(0)
                val addPixel = temp[addY * w + x]
                val removePixel = temp[removeY * w + x]
                rSum += ((addPixel shr 16) and 0xFF) - ((removePixel shr 16) and 0xFF)
                gSum += ((addPixel shr 8) and 0xFF) - ((removePixel shr 8) and 0xFF)
                bSum += (addPixel and 0xFF) - (removePixel and 0xFF)
            }
        }

        small.setPixels(result, 0, w, 0, 0, w, h)

        val output = Bitmap.createScaledBitmap(small, source.width, source.height, true)
        if (small !== output) small.recycle()
        return output
    }
}
