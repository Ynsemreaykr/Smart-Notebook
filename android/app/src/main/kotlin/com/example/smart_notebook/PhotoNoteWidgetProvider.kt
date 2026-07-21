package com.example.smart_notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PhotoNoteWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_photo_note_layout).apply {
                // Get data from SharedPreferences (saved by Dart via home_widget)
                val title = widgetData.getString("photo_widget_title", "Son Görsel Not")
                val category = widgetData.getString("photo_widget_category", "") ?: ""
                
                setTextViewText(R.id.widget_photo_title, title)
                
                if (category.trim().isNotEmpty()) {
                    setTextViewText(R.id.widget_photo_category, category)
                    setViewVisibility(R.id.widget_photo_category, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_photo_category, View.GONE)
                }

                // Attach pending intent to launch main app and open 'photo_notes' screen on click
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                    putExtra("open_screen", "photo_notes")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
