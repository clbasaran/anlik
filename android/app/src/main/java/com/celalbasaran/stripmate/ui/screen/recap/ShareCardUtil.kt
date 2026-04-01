package com.celalbasaran.stripmate.ui.screen.recap

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.view.View
import android.view.ViewGroup
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.ComposeView
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream

/**
 * Haftalik ozet paylasim kartini bitmap olarak capture edip
 * Instagram Stories veya genel paylasim akisiyla gonderir.
 */
object ShareCardUtil {

    private const val INSTAGRAM_PACKAGE = "com.instagram.android"
    private const val INSTAGRAM_STORIES_ACTION = "com.instagram.share.ADD_TO_STORY"

    /**
     * Composable icerigi bitmap olarak capture eder.
     * ComposeView kullanarak offscreen render yapar.
     */
    fun captureComposable(
        activity: Activity,
        width: Int = 1080,
        height: Int = 1920,
        content: @Composable () -> Unit
    ): Bitmap? {
        return try {
            val composeView = ComposeView(activity).apply {
                setContent { content() }
            }

            // Measure & layout
            val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
            val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
            composeView.measure(widthSpec, heightSpec)
            composeView.layout(0, 0, width, height)

            // Draw to bitmap
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            composeView.draw(canvas)

            bitmap
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Bitmap'i gecici dosyaya kaydeder ve URI doner.
     */
    fun saveBitmapToCache(context: Context, bitmap: Bitmap, fileName: String = "share_card.png"): Uri? {
        return try {
            val cacheDir = File(context.cacheDir, "share_cards")
            if (!cacheDir.exists()) cacheDir.mkdirs()

            val file = File(cacheDir, fileName)
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }

            FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Instagram Stories'a dogrudan paylasim yapar.
     * Instagram yuklu degilse genel paylasim intent'ine duser.
     */
    fun shareToInstagramStories(context: Context, imageUri: Uri) {
        val intent = Intent(INSTAGRAM_STORIES_ACTION).apply {
            setDataAndType(imageUri, "image/png")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            setPackage(INSTAGRAM_PACKAGE)
            putExtra("source_application", context.packageName)
        }

        if (intent.resolveActivity(context.packageManager) != null) {
            context.startActivity(intent)
        } else {
            // Instagram yuklu degil, genel paylasim
            shareGeneric(context, imageUri)
        }
    }

    /**
     * Genel paylasim Intent'i olusturur (herhangi bir uygulama ile).
     */
    fun shareGeneric(context: Context, imageUri: Uri) {
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, imageUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(
            Intent.createChooser(shareIntent, "Haftal\u0131k \u00F6zeti payla\u015F")
        )
    }

    /**
     * Instagram'in yuklu olup olmadigini kontrol eder.
     */
    fun isInstagramInstalled(context: Context): Boolean {
        return try {
            context.packageManager.getPackageInfo(INSTAGRAM_PACKAGE, 0)
            true
        } catch (_: Exception) {
            false
        }
    }
}
