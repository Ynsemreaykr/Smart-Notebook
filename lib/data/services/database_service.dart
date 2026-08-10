import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/book.dart';
import '../../domain/models/page.dart';
import '../../domain/models/event.dart';
import '../../domain/models/note.dart';

class DatabaseService {
  static const String booksBox = 'books';
  static const String pagesBox = 'pages';
  static const String eventsBox = 'events';
  static const String notesBox = 'notes';
  static const String settingsBox = 'settings';
  static const String habitsBox = 'habits';

  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(BookAdapter());
    Hive.registerAdapter(NotePageAdapter());
    Hive.registerAdapter(CalendarEventAdapter());
    Hive.registerAdapter(NoteAdapter());

    // Open boxes safely without hanging
    await _safeOpenBox<Book>(booksBox);
    await _safeOpenBox<NotePage>(pagesBox);
    await _safeOpenBox<CalendarEvent>(eventsBox);
    await _safeOpenBox<Note>(notesBox);
    await _safeOpenBox<Note>('voice_notes');
    await _safeOpenBox('settings');
    await _safeOpenBox(habitsBox);
    await _safeOpenBox('planner_tasks');
    await _safeOpenBox('plans');
    await _safeOpenBox('photo_notes');
  }

  static Future<Box<T>> _safeOpenBox<T>(String name) async {
    try {
      return await Hive.openBox<T>(name).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('Warning: Box $name failed to open normally: $e. Recovering...');
      try {
        if (Hive.isBoxOpen(name)) {
          return Hive.box<T>(name);
        }
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox<T>(name);
      } catch (err) {
        print('Critical: Box $name recovery failed: $err');
        return await Hive.openBox<T>('${name}_safe');
      }
    }
  }

  static Box<Book> getBooksBox() => Hive.box<Book>(booksBox);
  static Box<NotePage> getPagesBox() => Hive.box<NotePage>(pagesBox);
  static Box<CalendarEvent> getEventsBox() => Hive.box<CalendarEvent>(eventsBox);
  static Box<Note> getNotesBox() => Hive.box<Note>(notesBox);
  static Box getHabitsBox() => Hive.box(habitsBox);

  static Future<void> closeAll() async {
    await Hive.close();
  }
}
