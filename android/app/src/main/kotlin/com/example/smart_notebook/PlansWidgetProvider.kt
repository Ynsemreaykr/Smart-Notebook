package com.example.smart_notebook

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.example.smart_notebook.R

class PlansWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS_NAME = "HomeWidgetPreferences"
        private const val DATA_KEY = "plans_widget_data"
        const val ACTION_TOGGLE_EXPAND = "com.example.smart_notebook.ACTION_TOGGLE_EXPAND"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE_EXPAND) {
            val toggleId = intent.getStringExtra("toggle_id")
            val openApp = intent.getBooleanExtra("open_app", false)
            val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            
            if (openApp) {
                val appIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                    ?.apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("open_screen", "plans")
                    }
                if (appIntent != null) {
                    context.startActivity(appIntent)
                }
            } else if (!toggleId.isNullOrBlank() && widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val rawExpanded = prefs.getString("expanded_ids", "") ?: ""
                val expandedSet = if (rawExpanded.isNotEmpty()) {
                    rawExpanded.split(",").toMutableSet()
                } else {
                    mutableSetOf()
                }
                
                if (expandedSet.contains(toggleId)) {
                    expandedSet.remove(toggleId)
                } else {
                    expandedSet.add(toggleId)
                }
                
                prefs.edit().putString("expanded_ids", expandedSet.joinToString(",")).apply()
                
                val appWidgetManager = AppWidgetManager.getInstance(context)
                appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
            }
        }
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

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_plans_layout)

        // Read preferences to toggle empty state
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString("plans_json", "") ?: ""
        if (raw.isEmpty() || raw == "[]") {
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setViewVisibility(R.id.widget_list, View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_empty, View.GONE)
            views.setViewVisibility(R.id.widget_list, View.VISIBLE)
        }

        // Set up the RemoteViewsService intent for the ListView
        val serviceIntent = Intent(context, PlansWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_list, serviceIntent)

        // Set up PendingIntent template for item clicks (expand toggle or app launch)
        val clickIntent = Intent(context, PlansWidgetProvider::class.java).apply {
            action = ACTION_TOGGLE_EXPAND
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        }
        val clickPending = PendingIntent.getBroadcast(
            context,
            widgetId,
            clickIntent,
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setPendingIntentTemplate(R.id.widget_list, clickPending)

        // "+" button → open app to plans tab
        val appIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_screen", "plans")
            } ?: Intent()

        val addPending = PendingIntent.getActivity(
            context,
            widgetId + 8000,
            appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_add_btn, addPending)

        appWidgetManager.updateAppWidget(widgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
    }
}
