import 'dart:convert';
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

  /// Helper method to recursively convert any Hive object, map, or list into a 100% Firestore-safe primitive data structure
  dynamic _sanitizeKeys(dynamic input) {
    if (input is Map) {
      final Map<String, dynamic> result = {};
      input.forEach((k, v) {
        String cleanKey = k.toString()
            .replaceAll('.', '_')
            .replaceAll('/', '_')
            .replaceAll('[', '_')
            .replaceAll(']', '_')
            .replaceAll('~', '_')
            .replaceAll('*', '_');
        if (cleanKey.isEmpty) cleanKey = 'empty_key';
        result[cleanKey] = _sanitizeKeys(v);
      });
      return result;
    } else if (input is List) {
      return input.map((e) => _sanitizeKeys(e)).toList();
    }
    return input;
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

    String currentStep = "Başlatılıyor";

    try {
      currentStep = "1. Hive Kutuları Okunuyor";
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

      final photoNotesBox = Hive.isBoxOpen('photo_notes')
          ? Hive.box('photo_notes')
          : await Hive.openBox('photo_notes');
      final photoNotesData = photoNotesBox.keys.map((k) {
        return {
          'key': k.toString(),
          'value': photoNotesBox.get(k),
        };
      }).toList();

      final settingsBox = Hive.box('settings');
      final settings = <String, dynamic>{};
      for (final key in settingsBox.keys) {
        settings[key.toString()] = settingsBox.get(key);
      }

      currentStep = "2. JSON Paketine Dönüştürülüyor";
      // 2. Build JSON payload
      final rawPayload = {
        'books': books,
        'pages': pages,
        'events': events,
        'notes': notes,
        'voice_notes': voiceNotes,
        'habits': habits,
        'planner_tasks': plannerTasks,
        'plans': plans,
        'photo_notes': photoNotesData,
        'settings': settings,
        'lastBackupTime': DateTime.now().toIso8601String(),
        'deviceInfo': 'Android App',
      };

      // 3. Serialize to pure JSON string with custom encoder fallback
      final jsonString = jsonEncode(rawPayload, toEncodable: (nonEncodable) {
        if (nonEncodable is DateTime) return nonEncodable.toIso8601String();
        try {
          return (nonEncodable as dynamic).toJson();
        } catch (_) {}
        try {
          return (nonEncodable as dynamic).toMap();
        } catch (_) {}
        return nonEncodable.toString();
      });

      currentStep = "3. Kullanıcı Kimliği Doğrulanıyor (UID: ${user.uid})";
      // Refresh user auth token to ensure active credentials for Firestore
      try {
        await user.getIdToken(true);
      } catch (tokenErr) {
        debugPrint('Token refresh warning: $tokenErr');
      }

      currentStep = "4. Firestore'a Gönderiliyor (Boyut: ${jsonString.length} kr)";
      // 4. Chunk jsonString into safe 500k character blocks so Firestore 1MB limit per field is never hit
      const int chunkSize = 500000;
      final int totalChunks = (jsonString.length / chunkSize).ceil();
      final Map<String, dynamic> firestoreMap = {
        'lastBackupTime': DateTime.now().toIso8601String(),
        'deviceInfo': 'Android App',
        'chunkCount': totalChunks > 0 ? totalChunks : 1,
      };

      if (jsonString.isEmpty) {
        firestoreMap['chunk_0'] = '{}';
      } else {
        for (int i = 0; i * chunkSize < jsonString.length; i++) {
          int end = (i + 1) * chunkSize;
          if (end > jsonString.length) end = jsonString.length;
          firestoreMap['chunk_$i'] = jsonString.substring(i * chunkSize, end);
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('backups')
          .doc('latest')
          .set(firestoreMap);

      _lastBackupTime = DateTime.now();
      await settingsBox.put('last_backup_time', _lastBackupTime!.toIso8601String());

      _isSyncing = false;
      notifyListeners();
      return true;
    } on FirebaseException catch (fe) {
      debugPrint('Backup FirebaseException: [$currentStep] ${fe.code} - ${fe.message}');
      _isSyncing = false;
      _syncError = "[$currentStep]\nFirebase Hata: [${fe.code}]\n${fe.message ?? fe.toString()}";
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('Backup Error: [$currentStep] $e\n$stack');
      _isSyncing = false;
      _syncError = "[$currentStep]\nHata: $e";
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

      final docMap = doc.data()!;
      final Map<String, dynamic> data;
      if (docMap.containsKey('chunkCount')) {
        final int count = (docMap['chunkCount'] as num).toInt();
        final StringBuffer sb = StringBuffer();
        for (int i = 0; i < count; i++) {
          sb.write(docMap['chunk_$i'] ?? '');
        }
        data = jsonDecode(sb.toString()) as Map<String, dynamic>;
      } else if (docMap.containsKey('json_data') && docMap['json_data'] is String) {
        data = jsonDecode(docMap['json_data'] as String) as Map<String, dynamic>;
      } else {
        data = docMap;
      }

      // 2. Books
      final booksBox = DatabaseService.getBooksBox();
      await booksBox.clear();
      final booksData = data['books'] as List<dynamic>? ?? [];
      for (final b in booksData) {
        if (b is Map) {
          final book = Book.fromJson(Map<String, dynamic>.from(b));
          await booksBox.put(book.id, book);
        }
      }

      // 3. Pages
      final pagesBox = DatabaseService.getPagesBox();
      await pagesBox.clear();
      final pagesData = data['pages'] as List<dynamic>? ?? [];
      for (final p in pagesData) {
        if (p is Map) {
          final page = NotePage.fromJson(Map<String, dynamic>.from(p));
          await pagesBox.put(page.id, page);
        }
      }

      // 4. Events
      final eventsBox = DatabaseService.getEventsBox();
      await eventsBox.clear();
      final eventsData = data['events'] as List<dynamic>? ?? [];
      for (final ev in eventsData) {
        if (ev is Map) {
          final event = CalendarEvent.fromJson(Map<String, dynamic>.from(ev));
          await eventsBox.put(event.id, event);
        }
      }

      // 5. Notes
      final notesBox = DatabaseService.getNotesBox();
      await notesBox.clear();
      final notesData = data['notes'] as List<dynamic>? ?? [];
      for (final n in notesData) {
        if (n is Map) {
          final note = Note.fromJson(Map<String, dynamic>.from(n));
          await notesBox.put(note.id, note);
        }
      }

      // 6. Voice Notes
      final voiceNotesBox = Hive.box<Note>('voice_notes');
      await voiceNotesBox.clear();
      final voiceNotesData = data['voice_notes'] as List<dynamic>? ?? [];
      for (final vn in voiceNotesData) {
        if (vn is Map) {
          final note = Note.fromJson(Map<String, dynamic>.from(vn));
          await voiceNotesBox.put(note.id, note);
        }
      }

      // 7. Habits
      final habitsBox = DatabaseService.getHabitsBox();
      await habitsBox.clear();
      final habitsData = data['habits'] as List<dynamic>? ?? [];
      for (final h in habitsData) {
        if (h is Map) {
          final map = Map<String, dynamic>.from(h);
          if (map.containsKey('id')) {
            await habitsBox.put(map['id'], map);
          }
        }
      }

      // 8. Planner Tasks
      final plannerTasksBox = Hive.box('planner_tasks');
      await plannerTasksBox.clear();
      final plannerTasksData = data['planner_tasks'] as List<dynamic>? ?? [];
      for (final pt in plannerTasksData) {
        if (pt is Map) {
          final map = Map<String, dynamic>.from(pt);
          if (map.containsKey('id')) {
            await plannerTasksBox.put(map['id'], map);
          }
        }
      }

      // 9. Plans
      final plansBox = Hive.box('plans');
      await plansBox.clear();
      final plansData = data['plans'] as List<dynamic>? ?? [];
      for (final pl in plansData) {
        if (pl is Map) {
          final map = Map<String, dynamic>.from(pl);
          if (map.containsKey('id')) {
            await plansBox.put(map['id'], map);
          }
        }
      }

      // 10. Photo Notes & Flashcards
      final photoNotesBox = Hive.isBoxOpen('photo_notes')
          ? Hive.box('photo_notes')
          : await Hive.openBox('photo_notes');
      await photoNotesBox.clear();
      final photoNotesData = data['photo_notes'] as List<dynamic>? ?? [];
      for (final item in photoNotesData) {
        if (item is Map && item.containsKey('key') && item.containsKey('value')) {
          final key = item['key'];
          final val = item['value'];
          if (key != null && val != null) {
            await photoNotesBox.put(key, val);
          }
        }
      }

      // 11. Settings
      final settingsBox = Hive.box('settings');
      final settingsData = data['settings'] as Map<dynamic, dynamic>? ?? {};
      for (final key in settingsData.keys) {
        await settingsBox.put(key.toString(), settingsData[key]);
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
