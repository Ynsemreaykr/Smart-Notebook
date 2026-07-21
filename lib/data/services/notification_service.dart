import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions on Android 13+
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap — can be extended with navigation
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Schedule a notification at a specific time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    // If scheduled time is in the past, don't schedule
    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint('Scheduled time is in the past, skipping notification.');
      return;
    }

    final androidDetails = const AndroidNotificationDetails(
      'smart_notebook_reminders',
      'Hatırlatıcılar',
      channelDescription: 'Smart Notebook etkinlik hatırlatıcıları',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
    );

    final details = NotificationDetails(android: androidDetails);

    // Use zonedSchedule for exact timing
    final delay = scheduledTime.difference(DateTime.now());

    // Use a simpler approach: schedule with Future.delayed and show
    Future.delayed(delay, () async {
      await _notifications.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
    });
  }

  /// Show an immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = const AndroidNotificationDetails(
      'smart_notebook_reminders',
      'Hatırlatıcılar',
      channelDescription: 'Smart Notebook etkinlik hatırlatıcıları',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(id, title, body, details, payload: payload);
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Generate a unique notification ID from event ID
  int generateNotificationId(String eventId) {
    return eventId.hashCode.abs() % 2147483647;
  }
}
