package com.celalbasaran.stripmate

import android.graphics.Bitmap
import com.celalbasaran.stripmate.data.model.CollageAspectRatio
import com.celalbasaran.stripmate.data.model.CollageLayout
import com.celalbasaran.stripmate.util.CollageBuilder
import org.junit.Assert.*
import org.junit.Test

class CollageBuilderTest {

    @Test
    fun `getCells returns correct count for each layout`() {
        for (layout in CollageLayout.entries) {
            val cells = CollageBuilder.getCells(layout, 4f)
            assertEquals("Layout ${layout.name} should have ${layout.photoCount} cells",
                layout.photoCount, cells.size)
        }
    }

    @Test
    fun `getCells respects aspect ratio dimensions`() {
        for (ratio in CollageAspectRatio.entries) {
            val cells = CollageBuilder.getCells(CollageLayout.TWO_HORIZONTAL, 0f, ratio)
            for (cell in cells) {
                assertTrue("Cell left ${cell.left} should be >= 0", cell.left >= 0f)
                assertTrue("Cell top ${cell.top} should be >= 0", cell.top >= 0f)
                assertTrue("Cell right ${cell.right} should be <= ${ratio.width}", cell.right <= ratio.width + 1f)
                assertTrue("Cell bottom ${cell.bottom} should be <= ${ratio.height}", cell.bottom <= ratio.height + 1f)
            }
        }
    }

    @Test
    fun `layoutsFor returns only matching photo count`() {
        for (count in 2..4) {
            val layouts = CollageLayout.layoutsFor(count)
            assertTrue(layouts.isNotEmpty())
            assertTrue(layouts.all { it.photoCount == count })
        }
    }

    @Test
    fun `layoutsFor returns empty for invalid count`() {
        val layouts = CollageLayout.layoutsFor(5)
        assertTrue(layouts.isEmpty())
    }
}
