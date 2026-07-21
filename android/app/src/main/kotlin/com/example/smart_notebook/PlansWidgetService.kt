package com.example.smart_notebook

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.example.smart_notebook.R

class PlansWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return PlansWidgetFactory(applicationContext)
    }
}

class PlansWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    data class PlanRow(
        val id: String,
        val text: String,
        val percent: String?,
        val hasChildren: Boolean,
        val isExpanded: Boolean,
        val depth: Int
    )

    private var plansList: List<PlanRow> = emptyList()
    private val expandedIds = HashSet<String>()

    private fun loadPlans() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val rawExpanded = prefs.getString("expanded_ids", "") ?: ""
        expandedIds.clear()
        if (rawExpanded.isNotEmpty()) {
            expandedIds.addAll(rawExpanded.split(","))
        }

        val jsonStr = prefs.getString("plans_json", "") ?: ""
        val tempList = ArrayList<PlanRow>()

        if (jsonStr.isNotEmpty()) {
            try {
                val array = org.json.JSONArray(jsonStr)
                for (i in 0 until array.length()) {
                    val planObj = array.getJSONObject(i)
                    val id = planObj.getString("id")
                    val title = planObj.getString("title")
                    val percentVal = planObj.optInt("completionPercent", 0)
                    
                    val itemsArray = planObj.optJSONArray("items") ?: org.json.JSONArray()
                    val hasChildren = itemsArray.length() > 0
                    val isExpanded = expandedIds.contains(id)
                    
                    val status = planObj.optString("status", "todo")
                    val statusLabel = when (status) {
                        "done" -> "Tamamlandı"
                        "doing" -> "Yapılıyor"
                        else -> "Bekliyor"
                    }
                    val percentText = if (hasChildren) {
                        "$statusLabel • %$percentVal"
                    } else {
                        statusLabel
                    }
                    
                    tempList.add(PlanRow(
                        id = id,
                        text = title,
                        percent = percentText,
                        hasChildren = hasChildren,
                        isExpanded = isExpanded,
                        depth = 0
                    ))

                    if (isExpanded && hasChildren) {
                        flattenItems(itemsArray, tempList, depth = 1)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        plansList = tempList
    }

    private fun flattenItems(array: org.json.JSONArray, list: ArrayList<PlanRow>, depth: Int) {
        for (i in 0 until array.length()) {
            val itemObj = array.getJSONObject(i)
            val id = itemObj.getString("id")
            val text = itemObj.getString("text")
            val percentVal = itemObj.optInt("completionPercent", 0)
            
            val subItemsArray = itemObj.optJSONArray("subItems") ?: org.json.JSONArray()
            val hasChildren = subItemsArray.length() > 0
            val isExpanded = expandedIds.contains(id)
            
            val status = itemObj.optString("status", "todo")
            val statusLabel = when (status) {
                "done" -> "Tamamlandı"
                "doing" -> "Yapılıyor"
                else -> "Bekliyor"
            }
            
            val percentText = if (hasChildren) {
                "$statusLabel • %$percentVal"
            } else {
                statusLabel
            }

            list.add(PlanRow(
                id = id,
                text = text,
                percent = percentText,
                hasChildren = hasChildren,
                isExpanded = isExpanded,
                depth = depth
            ))

            if (isExpanded && hasChildren && depth < 3) {
                flattenItems(subItemsArray, list, depth + 1)
            }
        }
    }

    override fun onCreate() {
        loadPlans()
    }

    override fun onDataSetChanged() {
        loadPlans()
    }

    override fun onDestroy() {
        plansList = emptyList()
    }

    override fun getCount(): Int {
        return plansList.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= plansList.size) {
            return RemoteViews(context.packageName, R.layout.widget_plan_item)
        }

        val row = plansList[position]
        val views = RemoteViews(context.packageName, R.layout.widget_plan_item)
        views.setTextViewText(R.id.plan_item_title, row.text)

        // Indentation Spacers visibility
        views.setViewVisibility(R.id.widget_indent_1, if (row.depth == 1) android.view.View.VISIBLE else android.view.View.GONE)
        views.setViewVisibility(R.id.widget_indent_2, if (row.depth == 2) android.view.View.VISIBLE else android.view.View.GONE)
        views.setViewVisibility(R.id.widget_indent_3, if (row.depth >= 3) android.view.View.VISIBLE else android.view.View.GONE)

        // Ok Button (Collapsible Arrow) visibility & state
        if (row.hasChildren) {
            views.setViewVisibility(R.id.plan_item_ok_btn, android.view.View.VISIBLE)
            views.setTextViewText(R.id.plan_item_ok_btn, if (row.isExpanded) "↑" else "↓")
            
            val fillInExpand = Intent().apply {
                putExtra("toggle_id", row.id)
            }
            views.setOnClickFillInIntent(R.id.plan_item_ok_btn, fillInExpand)
        } else {
            views.setViewVisibility(R.id.plan_item_ok_btn, android.view.View.GONE)
        }

        // Completion percent badge
        if (row.percent != null) {
            views.setViewVisibility(R.id.plan_item_percent, android.view.View.VISIBLE)
            views.setTextViewText(R.id.plan_item_percent, row.percent)
        } else {
            views.setViewVisibility(R.id.plan_item_percent, android.view.View.GONE)
        }

        // App Launch intent when clicking title/content area
        val fillInOpen = Intent().apply {
            putExtra("open_app", true)
        }
        views.setOnClickFillInIntent(R.id.plan_item_title, fillInOpen)

        // Accent indicator bar colors (various premium look)
        val accentColors = intArrayOf(
            0xFF7C83E8.toInt(),
            0xFFA855F7.toInt(),
            0xFF2DD4BF.toInt(),
            0xFFF59E0B.toInt(),
            0xFFEF4444.toInt(),
            0xFF06B6D4.toInt()
        )
        val color = accentColors[position % accentColors.size]
        views.setInt(R.id.plan_item_accent, "setBackgroundColor", color)

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
