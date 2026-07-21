import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'data/services/database_service.dart';
import 'data/services/notification_service.dart';
import 'application/providers/book_provider.dart';
import 'application/providers/page_provider.dart';
import 'application/providers/note_provider.dart';
import 'application/providers/calendar_provider.dart';
import 'application/providers/pdf_provider.dart';
import 'application/providers/theme_provider.dart';
import 'application/providers/habit_provider.dart';
import 'application/providers/timer_provider.dart';
import 'application/providers/task_provider.dart';
import 'application/providers/plan_provider.dart';
import 'application/providers/sync_provider.dart';
import 'application/providers/photo_note_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive database
  await DatabaseService.initialize();

  // Initialize Firebase safely
  bool isFirebaseAvailable = false;
  try {
    await Firebase.initializeApp();
    isFirebaseAvailable = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize notifications
  await NotificationService().initialize();

  // Initialize locale data for Turkish
  await initializeDateFormatting('tr_TR', null);

  // Initialize HomeWidget (required for Android widget communication)
  HomeWidget.setAppGroupId('com.example.smart_notebook');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncProvider()..initialize(isFirebaseAvailable)),
        ChangeNotifierProvider(create: (_) => BookProvider()..loadBooks()),
        ChangeNotifierProvider(create: (_) => PageProvider()),
        ChangeNotifierProvider(create: (_) => NoteProvider()..loadNotes()..loadVoiceNotes()),
        ChangeNotifierProvider(create: (_) => TaskProvider()..loadTasks()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()..loadEvents()),
        ChangeNotifierProvider(create: (_) => PdfProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) {
          final hp = HabitProvider()..loadHabits();
          hp.startUsageTracking();
          return hp;
        }),
        ChangeNotifierProxyProvider<HabitProvider, TimerProvider>(
          create: (context) => TimerProvider(context.read<HabitProvider>()),
          update: (context, habitProvider, timerProvider) => timerProvider ?? TimerProvider(habitProvider),
        ),
        ChangeNotifierProvider(create: (_) => PlanProvider()..loadPlans()),
        ChangeNotifierProvider(create: (_) => PhotoNoteProvider()..loadPhotoNotes()),
      ],
      child: const SmartNotebookApp(),
    ),
  );
}
