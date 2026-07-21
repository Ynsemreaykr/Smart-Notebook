package com.example.smart_notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PhotoNoteWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val DATA_KEY = "photo_notes_widget_data"
        const val ACTION_OPEN_PHOTO_NOTE = "com.example.smart_notebook.ACTION_OPEN_PHOTO_NOTE"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { widgetId ->
            updateWidget(context, appWidgetManager, widgetId)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_OPEN_PHOTO_NOTE) {
            val noteId = intent.getStringExtra("note_id")
            if (!noteId.isNullOrBlank()) {
                // Launch MainActivity and navigate directly to the specific photo note viewer
                val appIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("open_screen", "photo_note_view:$noteId")
                    }
                if (appIntent != null) {
                    context.startActivity(appIntent)
                }
            }
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_photo_note_layout)

        // Show/hide empty state
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(DATA_KEY, "") ?: ""
        if (raw.isEmpty()) {
            views.setViewVisibility(R.id.widget_photo_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_photo_list, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_photo_empty, View.GONE)
            views.setViewVisibility(R.id.widget_photo_list, View.VISIBLE)
        }

        // Set up the RemoteViewsService intent for the ListView
        val serviceIntent = Intent(context, PhotoNoteWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_photo_list, serviceIntent)

        // Set up PendingIntent template for list items
        val clickIntent = Intent(context, PhotoNoteWidgetProvider::class.java).apply {
            action = ACTION_OPEN_PHOTO_NOTE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        }
        
        val clickPending = PendingIntent.getBroadcast(
            context,
            widgetId,
            clickIntent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setPendingIntentTemplate(R.id.widget_photo_list, clickPending)

        // "+" button opens the Görsel Notlar listing screen
        val addIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_screen", "photo_notes")
            } ?: Intent()

        val addPending = PendingIntent.getActivity(
            context,
            widgetId + 8000,
            addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_add_btn, addPending)

        appWidgetManager.updateAppWidget(widgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_photo_list)
    }
}
