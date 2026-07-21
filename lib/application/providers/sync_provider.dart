import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../../domain/models/book.dart';
import '../../domain/models/page.dart';
import '../../domain/models/event.dart';
import '../../domain/models/note.dart';
import '../../domain/models/habit.dart';
import '../../domain/models/planner_task.dart';
import '../../domain/models/plan.dart';
import '../../data/services/database_service.dart';

class SyncProvider extends ChangeNotifier {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => GoogleSignIn();

  bool _isFirebaseAvailable = false;
  bool _isSyncing = false;
  String? _syncError;
  DateTime? _lastBackupTime;

  bool get isFirebaseAvailable => _isFirebaseAvailable;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  DateTime? get lastBackupTime => _lastBackupTime;
  User? get currentUser => _isFirebaseAvailable ? _auth.currentUser : null;

  void initialize(bool isFirebaseAvailable) {
    _isFirebaseAvailable = isFirebaseAvailable;
    if (_isFirebaseAvailable) {
      _auth.authStateChanges().listen((user) {
        notifyListeners();
      });
      
      final settingsBox = Hive.box('settings');
      final lastBackup = settingsBox.get('last_backup_time');
      if (lastBackup != null) {
        _lastBackupTime = DateTime.tryParse(lastBackup.toString());
      }
    }
  }

  /// Sign in with Google Account
  Future<bool> signInWithGoogle() async {
    if (!_isFirebaseAvailable) {
      _syncError = "Firebase yapılandırması eksik.";
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSyncing = false;
      _syncError = "Giriş hatası: $e";
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (!_isFirebaseAvailable) return;
    _isSyncing = true;
    notifyListeners();
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      _syncError = "Çıkış hatası: $e";
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Backup local data to Cloud Firestore under users/{uid}/backups/latest
  Future<bool> backupToCloud() async {
    final user = currentUser;
    if (user == null || !_isFirebaseAvailable) {
      _syncError = "Giriş yapılmış bir Google hesabı bulunamadı.";
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      // 1. Fetch all local data from Hive Boxes
      final books = DatabaseService.getBooksBox().values.toList();
      final pages = DatabaseService.getPagesBox().values.toList();
      final events = DatabaseService.getEventsBox().values.toList();
      final notes = DatabaseService.getNotesBox().values.toList();
      
      final voiceNotesBox = Hive.box<Note>('voice_notes');
      final voiceNotes = voiceNotesBox.values.toList();
      
      final habitsBox = DatabaseService.getHabitsBox();
      final habits = habitsBox.values.toList();
      
      final plannerTasksBox = Hive.box('planner_tasks');
      final plannerTasks = plannerTasksBox.values.toList();
      
      final plansBox = Hive.box('plans');
      final plans = plansBox.values.toList();

      final settingsBox = Hive.box('settings');
      final settings = <String, dynamic>{};
      for (final key in settingsBox.keys) {
        settings[key.toString()] = settingsBox.get(key);
      }

      // 2. Build JSON payload
      final backupData = {
        'books': books.map((e) => e.toJson()).toList(),
        'pages': pages.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
        'voice_notes': voiceNotes.map((e) => e.toJson()).toList(),
        'habits': habits.map((e) {
          if (e is Habit) return e.toJson();
          if (e is Map) return Map<String, dynamic>.from(e);
          return e;
        }).toList(),
        'planner_tasks': plannerTasks.map((e) {
          if (e is PlannerTask) return e.toJson();
          if (e is Map) return Map<String, dynamic>.from(e);
          return e;
        }).toList(),
        'plans': plans.map((e) {
          if (e is Plan) return e.toJson();
          if (e is Map) return Map<String, dynamic>.from(e);
          return e;
        }).toList(),
        'settings': settings,
        'lastBackupTime': DateTime.now().toIso8601String(),
        'deviceInfo': 'Android App',
      };

      // 3. Write data to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .doc('latest')
          .set(backupData);

      _lastBackupTime = DateTime.now();
      await settingsBox.put('last_backup_time', _lastBackupTime!.toIso8601String());

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSyncing = false;
      _syncError = "Yedekleme hatası: $e";
      notifyListeners();
      return false;
    }
  }

  /// Restore data from Firestore latest backup and save to Hive
  Future<bool> restoreFromCloud() async {
    final user = currentUser;
    if (user == null || !_isFirebaseAvailable) {
      _syncError = "Giriş yapılmış bir Google hesabı bulunamadı.";
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();

    try {
      // 1. Fetch backup document from Cloud
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .doc('latest')
          .get();

      if (!doc.exists || doc.data() == null) {
        _isSyncing = false;
        _syncError = "Bulutta kayıtlı yedek bulunamadı.";
        notifyListeners();
        return false;
      }

      final data = doc.data()!;

      // 2. Clear current Hive boxes and populate them
      
      // Books
      final booksBox = DatabaseService.getBooksBox();
      await booksBox.clear();
      final booksData = data['books'] as List<dynamic>? ?? [];
      for (final b in booksData) {
        if (b is Map) {
          final book = Book.fromJson(b);
          await booksBox.put(book.id, book);
        }
      }

      // Pages
      final pagesBox = DatabaseService.getPagesBox();
      await pagesBox.clear();
      final pagesData = data['pages'] as List<dynamic>? ?? [];
      for (final p in pagesData) {
        if (p is Map) {
          final page = NotePage.fromJson(p);
          await pagesBox.put(page.id, page);
        }
      }

      // Events
      final eventsBox = DatabaseService.getEventsBox();
      await eventsBox.clear();
      final eventsData = data['events'] as List<dynamic>? ?? [];
      for (final ev in eventsData) {
        if (ev is Map) {
          final event = CalendarEvent.fromJson(ev);
          await eventsBox.put(event.id, event);
        }
      }

      // Notes
      final notesBox = DatabaseService.getNotesBox();
      await notesBox.clear();
      final notesData = data['notes'] as List<dynamic>? ?? [];
      for (final n in notesData) {
        if (n is Map) {
          final note = Note.fromJson(n);
          await notesBox.put(note.id, note);
        }
      }

      // Voice Notes
      final voiceNotesBox = Hive.box<Note>('voice_notes');
      await voiceNotesBox.clear();
      final voiceNotesData = data['voice_notes'] as List<dynamic>? ?? [];
      for (final vn in voiceNotesData) {
        if (vn is Map) {
          final note = Note.fromJson(vn);
          await voiceNotesBox.put(note.id, note);
        }
      }

      // Habits
      final habitsBox = DatabaseService.getHabitsBox();
      await habitsBox.clear();
      final habitsData = data['habits'] as List<dynamic>? ?? [];
      for (final h in habitsData) {
        if (h is Map) {
          final habit = Habit.fromJson(h);
          await habitsBox.put(habit.id, habit.toJson());
        }
      }

      // Planner Tasks
      final plannerTasksBox = Hive.box('planner_tasks');
      await plannerTasksBox.clear();
      final plannerTasksData = data['planner_tasks'] as List<dynamic>? ?? [];
      for (final pt in plannerTasksData) {
        if (pt is Map) {
          final task = PlannerTask.fromJson(pt);
          await plannerTasksBox.put(task.id, task.toJson());
        }
      }

      // Plans
      final plansBox = Hive.box('plans');
      await plansBox.clear();
      final plansData = data['plans'] as List<dynamic>? ?? [];
      for (final pl in plansData) {
        if (pl is Map) {
          final plan = Plan.fromJson(pl);
          await plansBox.put(plan.id, plan.toJson());
        }
      }

      // Settings
      final settingsBox = Hive.box('settings');
      final settingsData = data['settings'] as Map<dynamic, dynamic>? ?? {};
      for (final key in settingsData.keys) {
        await settingsBox.put(key, settingsData[key]);
      }

      // Update backup local timestamp
      if (data['lastBackupTime'] != null) {
        _lastBackupTime = DateTime.tryParse(data['lastBackupTime'].toString());
        if (_lastBackupTime != null) {
          await settingsBox.put('last_backup_time', _lastBackupTime!.toIso8601String());
        }
      }

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSyncing = false;
      _syncError = "Geri yükleme hatası: $e";
      notifyListeners();
      return false;
    }
  }
}
