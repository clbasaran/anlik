package com.celalbasaran.stripmate.data.model

enum class CollageAspectRatio(val label: String, val width: Float, val height: Float) {
    PORTRAIT("9:16", 1080f, 1920f),
    INSTAGRAM("4:5", 1080f, 1350f),
    SQUARE("1:1", 1080f, 1080f);

    val ratio: Float get() = width / height
}

enum class CollageLayout(val photoCount: Int, val label: String) {
    // 2-photo
    TWO_HORIZONTAL(2, "Yatay 2li"),
    TWO_VERTICAL(2, "Dikey 2li"),
    TWO_DIAGONAL(2, "Capraz"),
    TWO_LEFT_WIDE(2, "Sol Genis"),

    // 3-photo
    THREE_LEFT_LARGE(3, "Sol Buyuk"),
    THREE_TOP_LARGE(3, "Ust Buyuk"),
    THREE_RIGHT_LARGE(3, "Sag Buyuk"),
    THREE_BOTTOM_LARGE(3, "Alt Buyuk"),
    THREE_EQUAL_ROWS(3, "3 Satir"),
    THREE_EQUAL_COLS(3, "3 Sutun"),

    // 4-photo
    FOUR_GRID(4, "4lu Izgara"),
    FOUR_TOP_ROW(4, "Ust Buyuk"),
    FOUR_BOTTOM_ROW(4, "Alt Buyuk"),
    FOUR_LEFT_COL(4, "Sol Buyuk"),
    FOUR_CENTER_FOCUS(4, "Merkez");

    companion object {
        fun layoutsFor(count: Int): List<CollageLayout> =
            entries.filter { it.photoCount == count }
    }
}

/**
 * Per-photo pan/zoom transform for interactive collage editing.
 * offset is normalized (-1..1 range), scale >= 1.0.
 */
data class PhotoTransform(
    val offsetX: Float = 0f,  // normalized pan offset (-1..1)
    val offsetY: Float = 0f,
    val scale: Float = 1f     // pinch-to-zoom (1.0 = aspect fill)
)

enum class CollageBackground {
    BLACK,
    WHITE,
    BLUR_FILL
}

enum class CollageCornerStyle {
    SHARP,
    ROUNDED
}
