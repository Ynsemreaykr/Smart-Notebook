import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockHelper {
  static const _channel = MethodChannel('com.example.smart_notebook/launch');

  /// Keeps the screen awake (prevents screen timeout/sleep mode)
  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    try {
      await _channel.invokeMethod('setKeepScreenOn', {'enabled': true});
    } catch (_) {}
  }

  /// Restores default screen timeout
  static Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      await _channel.invokeMethod('setKeepScreenOn', {'enabled': false});
    } catch (_) {}
  }
}
