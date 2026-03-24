package com.celalbasaran.stripmate.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import com.celalbasaran.stripmate.MainActivity
import com.celalbasaran.stripmate.R

class StripMateWidgetReceiver : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = buildWidgetViews(context)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    companion object {
        fun buildWidgetViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            val prefs = context.getSharedPreferences("widget_prefs", Context.MODE_PRIVATE)
            val imageUrl = prefs.getString("widget_image_url", null)

            if (imageUrl != null) {
                val bitmap = loadBitmap(context, imageUrl)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                    views.setViewVisibility(R.id.widget_image, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.widget_watermark, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty_container, android.view.View.GONE)

                    val cityName = prefs.getString("widget_city_name", null)
                    if (cityName != null) {
                        views.setTextViewText(R.id.widget_city_name, cityName)
                        views.setViewVisibility(R.id.widget_city_name, android.view.View.VISIBLE)
                    }
                    return views
                }
            }

            // Empty state
            views.setViewVisibility(R.id.widget_image, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_watermark, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_city_name, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_empty_container, android.view.View.VISIBLE)
            return views
        }

        private fun loadBitmap(context: Context, url: String): Bitmap? {
            return try {
                val cacheFile = java.io.File(context.cacheDir, "widget_image.jpg")
                if (cacheFile.exists()) {
                    BitmapFactory.decodeFile(cacheFile.absolutePath)
                } else {
                    null
                }
            } catch (_: Exception) {
                null
            }
        }
    }
}
