import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:home_widget/home_widget.dart';

/// LinksWidgetService
///
/// Syncs bookmark data from Hive to the Android home screen widget.
///
/// home_widget 0.7.0 on Android stores data in:
///   SharedPreferences file: "HomeWidgetPreferences"
///   Key: "links_widget_data"  (no prefix)
///
/// Format: "Label1||url1::Label2||url2::..."
class LinksWidgetService {
  static const String _androidWidgetClass =
      'com.example.smart_notebook.LinksWidgetProvider';
  static const String _widgetDataKey = 'links_widget_data';

  /// Call this whenever bookmarks are added, edited, or deleted.
  static Future<void> updateWidget() async {
    try {
      final box = Hive.box('settings');
      final List<dynamic>? saved = box.get('bookmark_links');

      String serialized = '';

      if (saved != null && saved.isNotEmpty) {
        final links = saved
            .map((item) => Map<String, String>.from(item as Map))
            .where((link) => link['show_in_widget'] != 'false')
            .toList();

        // Serialize: ALL links as "label||url", separated by "::"
        serialized = links
            .map((link) => '${link['label'] ?? ''}||${link['url'] ?? ''}')
            .join('::');
      }

      // Save to HomeWidgetPreferences (read directly by LinksWidgetProvider.kt)
      await HomeWidget.saveWidgetData<String>(_widgetDataKey, serialized);

      // Trigger AppWidgetManager.updateAppWidget via our custom foreground broadcast channel (bypasses Xiaomi/MIUI battery constraints)
      const channel = MethodChannel('com.example.smart_notebook/launch');
      await channel.invokeMethod('updateWidget');

      debugPrint('[LinksWidget] Updated → $serialized');
    } catch (e) {
      debugPrint('[LinksWidget] Error: $e');
    }
  }
}
