package com.example.smart_notebook

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class PhotoNoteWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return PhotoNoteWidgetFactory(applicationContext)
    }
}

class PhotoNoteWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var photoNotesList: List<PhotoNoteDataEntry> = emptyList()

    private fun loadPhotoNotes() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("photo_notes_widget_data", "") ?: ""
        
        photoNotesList = if (raw.isNotEmpty()) {
            raw.split("::").mapNotNull { entry ->
                val parts = entry.split("||")
                if (parts.size >= 4 && parts[0].isNotBlank()) {
                    PhotoNoteDataEntry(
                        id = parts[0].trim(),
                        title = parts[1].trim(),
                        category = parts[2].trim(),
                        color = parts[3].trim()
                    )
                } else null
            }
        } else {
            emptyList()
        }
    }

    override fun onCreate() {
        loadPhotoNotes()
    }

    override fun onDataSetChanged() {
        loadPhotoNotes()
    }

    override fun onDestroy() {
        photoNotesList = emptyList()
    }

    override fun getCount(): Int {
        return photoNotesList.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= photoNotesList.size) {
            return RemoteViews(context.packageName, R.layout.widget_photo_note_item)
        }

        val note = photoNotesList[position]
        val views = RemoteViews(context.packageName, R.layout.widget_photo_note_item).apply {
            setTextViewText(R.id.photo_item_title, note.title)
            
            if (note.category.isNotEmpty()) {
                setTextViewText(R.id.photo_item_category, note.category)
                setViewVisibility(R.id.photo_item_category, android.view.View.VISIBLE)
            } else {
                setViewVisibility(R.id.photo_item_category, android.view.View.GONE)
            }

            // Parse hex color and set background of left accent indicator
            val parsedColor = try {
                Color.parseColor(note.color)
            } catch (e: Exception) {
                Color.parseColor("#14B8A6") // Fallback teal
            }
            setInt(R.id.photo_item_accent, "setBackgroundColor", parsedColor)

            // Setup click fill-in intent passing the note_id
            val fillInIntent = Intent().apply {
                putExtra("note_id", note.id)
            }
            setOnClickFillInIntent(R.id.photo_item_title, fillInIntent)
            setOnClickFillInIntent(R.id.photo_item_root, fillInIntent)
        }

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

data class PhotoNoteDataEntry(
    val id: String,
    val title: String,
    val category: String,
    val color: String
)
