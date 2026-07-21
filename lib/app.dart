import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'application/providers/theme_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/notes/notes_screen.dart';
import 'presentation/screens/library/library_screen.dart';
import 'application/providers/note_provider.dart';
import 'application/providers/book_provider.dart';
import 'package:flutter/services.dart';
import 'presentation/screens/notes/links_screen.dart';
import 'presentation/screens/planner/planner_screen.dart';
import 'presentation/screens/photo_notes/photo_notes_screen.dart';

class SmartNotebookApp extends StatefulWidget {
  const SmartNotebookApp({super.key});

  @override
  State<SmartNotebookApp> createState() => _SmartNotebookAppState();
}

class _SmartNotebookAppState extends State<SmartNotebookApp> {
  late StreamSubscription _intentDataStreamSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static const _launchChannel = MethodChannel('com.example.smart_notebook/launch');

  @override
  void initState() {
    super.initState();

    // Listen to channel calls for dynamic navigation (e.g. from background)
    _launchChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNavigate') {
        final String? screen = call.arguments as String?;
        if (screen == 'links') {
          _navigateToLinks();
        } else if (screen == 'planner') {
          _navigateToPlanner(0);
        } else if (screen == 'plans') {
          _navigateToPlanner(1);
        } else if (screen == 'notes') {
          _navigateToNotes();
        } else if (screen == 'photo_notes') {
          _navigateToPhotoNotes();
        }
      }
    });

    // Check launch screen parameter (cold start)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLaunchScreen();
    });

    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      _handleSharedMedia(value);
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      _handleSharedMedia(value);
    });
  }

  Future<void> _checkLaunchScreen() async {
    try {
      final String? screen = await _launchChannel.invokeMethod('getLaunchScreen');
      if (screen == 'links') {
        _navigateToLinks();
      } else if (screen == 'planner') {
        _navigateToPlanner(0);
      } else if (screen == 'plans') {
        _navigateToPlanner(1);
      } else if (screen == 'notes') {
        _navigateToNotes();
      } else if (screen == 'photo_notes') {
        _navigateToPhotoNotes();
      }
    } catch (e) {
      debugPrint("Error checking launch screen: $e");
    }
  }

  void _navigateToLinks() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const LinksScreen()),
    );
  }

  void _navigateToPlanner(int tabIndex) {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => PlannerScreen(initialTab: tabIndex)),
    );
  }

  void _navigateToNotes() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotesScreen()),
    );
  }

  void _navigateToPhotoNotes() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const PhotoNotesScreen()),
    );
  }

  void _handleSharedMedia(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    final file = files.first;
    final path = file.path.toLowerCase();
    
    if (file.type == SharedMediaType.text || file.type == SharedMediaType.url) {
      _handleSharedText(file.path);
    } else if (file.type == SharedMediaType.image || path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.webp')) {
      _handleSharedImage(file.path);
    } else if (path.endsWith('.pdf')) {
      _handleSharedPdf(file.path);
    }
  }

  void _handleSharedImage(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    final fileName = path.split('/').last.split('\\').last;
    String title = fileName;
    if (fileName.contains('.')) {
      title = fileName.substring(0, fileName.lastIndexOf('.'));
    }

    try {
      await context.read<BookProvider>().importImage(file, title);
      _navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const LibraryScreen()),
      );
      _showShareSuccess('Görsel başarıyla kitaplığa aktarıldı!');
    } catch (e) {
      debugPrint("Error importing shared image: $e");
    }
  }

  void _handleSharedPdf(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    final fileName = path.split('/').last.split('\\').last;
    String title = fileName;
    if (fileName.contains('.')) {
      title = fileName.substring(0, fileName.lastIndexOf('.'));
    }

    try {
      await context.read<BookProvider>().importPdf(file, title);
      _navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const LibraryScreen()),
      );
      _showShareSuccess('PDF başarıyla kitaplığa aktarıldı!');
    } catch (e) {
      debugPrint("Error importing shared PDF: $e");
    }
  }

  void _handleSharedText(String text) {
    if (text.isEmpty) return;
    
    final lines = text.split('\n');
    final titleLine = lines.first.trim();
    final title = titleLine.length > 30 ? '${titleLine.substring(0, 30)}...' : titleLine;

    context.read<NoteProvider>().addNote(
      title.isEmpty ? 'Paylaşılan Not' : title,
      content: text,
    );

    // Navigate directly to NotesScreen
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotesScreen()),
    );
    _showShareSuccess('Not başarıyla içe aktarıldı!');
  }

  void _showShareSuccess([String message = 'Not başarıyla içe aktarıldı!']) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          title: 'Smart Notebook',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.activeThemeData,
          darkTheme: themeProvider.activeThemeData,
          themeMode: themeProvider.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
