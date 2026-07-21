package com.example.smart_notebook

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.smart_notebook/launch"
    private var methodChannel: MethodChannel? = null
    private var openScreenExtra: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.hasExtra("open_screen")) {
            val screen = intent.getStringExtra("open_screen")
            if (methodChannel != null) {
                // If Flutter is active, send it immediately
                methodChannel?.invokeMethod("onNavigate", screen)
            } else {
                // Otherwise store it for later retrieval
                openScreenExtra = screen
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchScreen" -> {
                    val screen = openScreenExtra
                    openScreenExtra = null // Consume it
                    result.success(screen)
                }
                "updateWidget" -> {
                    val intent = Intent(applicationContext, LinksWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val thisWidget = android.content.ComponentName(applicationContext, LinksWidgetProvider::class.java)
                        val ids = appWidgetManager.getAppWidgetIds(thisWidget)
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                        // Add foreground flag to guarantee instant updates on Xiaomi / MIUI
                        addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
                    }
                    sendBroadcast(intent)
                    result.success(null)
                }
                "updatePlansWidget" -> {
                    val intent = Intent(applicationContext, PlansWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val thisWidget = android.content.ComponentName(applicationContext, PlansWidgetProvider::class.java)
                        val ids = appWidgetManager.getAppWidgetIds(thisWidget)
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                        addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
                    }
                    sendBroadcast(intent)
                    result.success(null)
                }
                "updatePhotoWidget" -> {
                    val intent = Intent(applicationContext, PhotoNoteWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val thisWidget = android.content.ComponentName(applicationContext, PhotoNoteWidgetProvider::class.java)
                        val ids = appWidgetManager.getAppWidgetIds(thisWidget)
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                        addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
                    }
                    sendBroadcast(intent)
                    result.success(null)
                }
                "updateNoteWidget" -> {
                    val intent = Intent(applicationContext, NoteWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                        val thisWidget = android.content.ComponentName(applicationContext, NoteWidgetProvider::class.java)
                        val ids = appWidgetManager.getAppWidgetIds(thisWidget)
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                        addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
                    }
                    sendBroadcast(intent)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Check if there was a pending screen extra when engine is configured
        openScreenExtra?.let { screen ->
            methodChannel?.invokeMethod("onNavigate", screen)
            openScreenExtra = null
        }
    }
}
