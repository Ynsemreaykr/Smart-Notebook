import '../../domain/models/event.dart';
import '../services/database_service.dart';

class EventRepository {
  /// Get all events
  List<CalendarEvent> getAllEvents() {
    final box = DatabaseService.getEventsBox();
    final events = box.values.toList();
    events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return events;
  }

  /// Get events for a specific date
  List<CalendarEvent> getEventsByDate(DateTime date) {
    final box = DatabaseService.getEventsBox();
    return box.values.where((event) {
      return event.dateTime.year == date.year &&
          event.dateTime.month == date.month &&
          event.dateTime.day == date.day;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// Get a single event by ID
  CalendarEvent? getEventById(String id) {
    final box = DatabaseService.getEventsBox();
    try {
      return box.values.firstWhere((event) => event.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Add a new event
  Future<void> addEvent(CalendarEvent event) async {
    final box = DatabaseService.getEventsBox();
    await box.put(event.id, event);
  }

  /// Update an existing event
  Future<void> updateEvent(CalendarEvent event) async {
    final box = DatabaseService.getEventsBox();
    await box.put(event.id, event);
  }

  /// Delete an event
  Future<void> deleteEvent(String id) async {
    final box = DatabaseService.getEventsBox();
    await box.delete(id);
  }

  /// Get events linked to a specific page
  List<CalendarEvent> getEventsForPage(String pageId) {
    final box = DatabaseService.getEventsBox();
    return box.values
        .where((event) => event.linkedPageId == pageId)
        .toList();
  }
}
