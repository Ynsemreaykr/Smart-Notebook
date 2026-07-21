import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/event.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/services/notification_service.dart';

class CalendarProvider extends ChangeNotifier {
  final EventRepository _eventRepository = EventRepository();
  final NotificationService _notificationService = NotificationService();
  final Uuid _uuid = const Uuid();

  List<CalendarEvent> _events = [];
  List<CalendarEvent> _selectedDayEvents = [];
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _isLoading = false;

  List<CalendarEvent> get events => _events;
  List<CalendarEvent> get selectedDayEvents => _selectedDayEvents;
  DateTime get selectedDay => _selectedDay;
  DateTime get focusedDay => _focusedDay;
  bool get isLoading => _isLoading;

  /// Load all events
  void loadEvents() {
    _events = _eventRepository.getAllEvents();
    _loadSelectedDayEvents();
    notifyListeners();
  }

  /// Set selected day
  void setSelectedDay(DateTime day) {
    _selectedDay = day;
    _loadSelectedDayEvents();
    notifyListeners();
  }

  /// Set focused day
  void setFocusedDay(DateTime day) {
    _focusedDay = day;
    notifyListeners();
  }

  void _loadSelectedDayEvents() {
    _selectedDayEvents = _eventRepository.getEventsByDate(_selectedDay);
  }

  /// Get events for a specific day (used by table_calendar)
  List<CalendarEvent> getEventsForDay(DateTime day) {
    return _events.where((event) {
      return event.dateTime.year == day.year &&
          event.dateTime.month == day.month &&
          event.dateTime.day == day.day;
    }).toList();
  }

  /// Add a new event
  Future<CalendarEvent> addEvent({
    required String title,
    String description = '',
    required DateTime dateTime,
    String? linkedPageId,
    String? linkedBookId,
    bool hasReminder = false,
    DateTime? reminderTime,
  }) async {
    final event = CalendarEvent(
      id: _uuid.v4(),
      title: title,
      description: description,
      dateTime: dateTime,
      linkedPageId: linkedPageId,
      linkedBookId: linkedBookId,
      hasReminder: hasReminder,
      reminderTime: reminderTime,
    );

    await _eventRepository.addEvent(event);

    // Schedule notification if reminder is set
    if (hasReminder && reminderTime != null) {
      await _scheduleReminder(event);
    }

    loadEvents();
    return event;
  }

  /// Update an event
  Future<void> updateEvent(CalendarEvent event) async {
    await _eventRepository.updateEvent(event);

    // Update notification
    final notifId = _notificationService.generateNotificationId(event.id);
    await _notificationService.cancelNotification(notifId);

    if (event.hasReminder && event.reminderTime != null) {
      await _scheduleReminder(event);
    }

    loadEvents();
  }

  /// Delete an event
  Future<void> deleteEvent(String id) async {
    final notifId = _notificationService.generateNotificationId(id);
    await _notificationService.cancelNotification(notifId);
    await _eventRepository.deleteEvent(id);
    loadEvents();
  }

  /// Schedule a notification for an event
  Future<void> _scheduleReminder(CalendarEvent event) async {
    if (event.reminderTime == null) return;

    await _notificationService.scheduleNotification(
      id: _notificationService.generateNotificationId(event.id),
      title: 'Hatırlatıcı: ${event.title}',
      body: event.description.isNotEmpty
          ? event.description
          : 'Etkinlik zamanı yaklaşıyor!',
      scheduledTime: event.reminderTime!,
      payload: event.id,
    );
  }

  /// Get event by ID
  CalendarEvent? getEventById(String id) {
    return _eventRepository.getEventById(id);
  }
}
