package com.example.smart_notebook

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class PhotoNoteWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return PhotoNoteWidgetFactory(applicationContext)
    }
}

class PhotoNoteWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var photoNotesList: List<PhotoNoteWidgetRow> = emptyList()

    private fun loadPhotoNotes() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("photo_notes_widget_data", "") ?: ""
        
        val tempNotes = if (raw.isNotEmpty()) {
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

        // Group notes by category
        val grouped = LinkedHashMap<String, MutableList<PhotoNoteDataEntry>>()
        for (note in tempNotes) {
            val cat = if (note.category.isBlank()) "Genel" else note.category
            grouped.putIfAbsent(cat, ArrayList())
            grouped[cat]!!.add(note)
        }

        // Flatten grouped map into structured rows (Always Expanded)
        val flattened = ArrayList<PhotoNoteWidgetRow>()
        for ((category, notes) in grouped) {
            // Add Category Header
            val headerColor = notes.firstOrNull()?.color ?: "#14B8A6"
            flattened.add(PhotoNoteWidgetRow(
                isHeader = true,
                title = "📁 $category",
                noteId = null,
                color = headerColor
            ))
            
            // Add child notes under this category
            for (note in notes) {
                flattened.add(PhotoNoteWidgetRow(
                    isHeader = false,
                    title = "📄 ${note.title}",
                    noteId = note.id,
                    color = note.color
                ))
            }
        }

        photoNotesList = flattened
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

        val row = photoNotesList[position]
        val views = RemoteViews(context.packageName, R.layout.widget_photo_note_item).apply {
            setTextViewText(R.id.photo_item_title, row.title)
            
            // Always hide category subtext as it is grouped under headers
            setViewVisibility(R.id.photo_item_category, View.GONE)

            val parsedColor = try {
                Color.parseColor(row.color)
            } catch (e: Exception) {
                Color.parseColor("#14B8A6")
            }
            setInt(R.id.photo_item_accent, "setBackgroundColor", parsedColor)

            if (row.isHeader) {
                // Header style: No indent, bold Indigo text
                setViewVisibility(R.id.photo_item_indent, View.GONE)
                setTextColor(R.id.photo_item_title, Color.parseColor("#818CF8"))
                
                // Clicking header launches the main Görsel Notlar screen
                val fillInIntent = Intent().apply {
                    putExtra("note_id", "") // empty opens screen
                }
                setOnClickFillInIntent(R.id.photo_item_title, fillInIntent)
                setOnClickFillInIntent(R.id.photo_item_root, fillInIntent)
            } else {
                // Child style: Indented, white text
                setViewVisibility(R.id.photo_item_indent, View.VISIBLE)
                setTextColor(R.id.photo_item_title, Color.parseColor("#FFFFFF"))
                
                // Clicking item opens the specific photo note
                val fillInIntent = Intent().apply {
                    putExtra("note_id", row.noteId)
                }
                setOnClickFillInIntent(R.id.photo_item_title, fillInIntent)
                setOnClickFillInIntent(R.id.photo_item_root, fillInIntent)
            }
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

data class PhotoNoteWidgetRow(
    val isHeader: Boolean,
    val title: String,
    val noteId: String?,
    val color: String
)
