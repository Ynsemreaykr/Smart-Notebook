package com.example.smart_notebook

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class LinksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return LinksWidgetFactory(applicationContext)
    }
}

class LinksWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var linksList: List<Pair<String, String>> = emptyList()

    private fun loadLinks() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("links_widget_data", "") ?: ""
        linksList = if (raw.isNotEmpty()) {
            raw.split("::").mapNotNull { entry ->
                val parts = entry.split("||")
                if (parts.size >= 2 && parts[0].isNotBlank()) {
                    Pair(parts[0].trim(), parts[1].trim())
                } else null
            }
        } else {
            emptyList()
        }
    }

    override fun onCreate() {
        loadLinks()
    }

    override fun onDataSetChanged() {
        // Called when notifyAppWidgetViewDataChanged is triggered
        loadLinks()
    }

    override fun onDestroy() {
        linksList = emptyList()
    }

    override fun getCount(): Int {
        return linksList.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= linksList.size) {
            return RemoteViews(context.packageName, R.layout.widget_link_item)
        }

        val (label, url) = linksList[position]
        val views = RemoteViews(context.packageName, R.layout.widget_link_item)
        views.setTextViewText(R.id.link_item_label, label)

        // Set click fill-in intent. When clicked, it passes URL back to the Provider.
        val formattedUrl = if (url.startsWith("http")) url else "https://$url"
        val fillInIntent = Intent().apply {
            putExtra("url", formattedUrl)
        }
        views.setOnClickFillInIntent(R.id.link_item_label, fillInIntent)
        views.setOnClickFillInIntent(R.id.link_item_accent, fillInIntent)

        // Different colors for items to look premium
        val accentColors = intArrayOf(
            0xFF7C83E8.toInt(),
            0xFFA855F7.toInt(),
            0xFF2DD4BF.toInt(),
            0xFFF59E0B.toInt(),
            0xFFEF4444.toInt(),
            0xFF06B6D4.toInt(),
            0xFF10B981.toInt(),
            0xFFF43F5E.toInt(),
            0xFF8B5CF6.toInt(),
            0xFFEC4899.toInt()
        )
        val color = accentColors[position % accentColors.size]
        views.setInt(R.id.link_item_accent, "setBackgroundColor", color)

        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }
}
