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

    // Open boxes
    await Hive.openBox<Book>(booksBox);
    await Hive.openBox<NotePage>(pagesBox);
    await Hive.openBox<CalendarEvent>(eventsBox);
    await Hive.openBox<Note>(notesBox);
    await Hive.openBox<Note>('voice_notes');
    await Hive.openBox('settings');
    await Hive.openBox(habitsBox);
    await Hive.openBox('planner_tasks');
    await Hive.openBox('plans');
    await Hive.openBox('photo_notes');
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
