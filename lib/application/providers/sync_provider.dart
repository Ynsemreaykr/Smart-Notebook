import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
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
  String _imageProgress = '';

  bool get isFirebaseAvailable => _isFirebaseAvailable;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  String get imageProgress => _imageProgress;

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

  /// Sign in with Email + Password
  Future<String?> signInWithEmail(String email, String password) async {
    if (!_isFirebaseAvailable) return "Firebase yapılandırması eksik.";
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      _isSyncing = false;
      notifyListeners();
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      _isSyncing = false;
      final msg = _authErrorMessage(e.code);
      _syncError = msg;
      notifyListeners();
      return msg;
    } catch (e) {
      _isSyncing = false;
      _syncError = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  /// Register a new account with Email + Password
  Future<String?> registerWithEmail(String email, String password) async {
    if (!_isFirebaseAvailable) return "Firebase yapılandırması eksik.";
    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      _isSyncing = false;
      notifyListeners();
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      _isSyncing = false;
      final msg = _authErrorMessage(e.code);
      _syncError = msg;
      notifyListeners();
      return msg;
    } catch (e) {
      _isSyncing = false;
      _syncError = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  /// Send password reset email
  Future<String?> resetPassword(String email) async {
    if (!_isFirebaseAvailable) return "Firebase yapılandırması eksik.";
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // null = success
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e.code);
    } catch (e) {
      return e.toString();
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı hesap bulunamadı.';
      case 'wrong-password':
        return 'Şifre hatalı. Lütfen tekrar deneyin.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'weak-password':
        return 'Şifre çok kısa. En az 6 karakter giriniz.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok. Lütfen kontrol edin.';
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      default:
        return 'Giriş hatası: $code';
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

  /// Returns a consistent, Firestore-safe document ID for a user.
  /// Uses email (normalized) so Google login and Email/Password login
  /// with the same email address share the same backup data.
  String _firestoreDocId(User user) {
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      // Replace '.' and '@' which are invalid in Firestore doc IDs
      return email.toLowerCase().trim()
          .replaceAll('.', '_')
          .replaceAll('@', '_at_');
    }
    return user.uid;
  }

  /// Returns the Firebase Storage path prefix for a user's images.
  String _storagePrefix(User user) {
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      return 'users/${email.toLowerCase().trim()}';
    }
    return 'users/${user.uid}';
  }

  /// Uploads all local photo note images to Firebase Storage.
  /// Returns a map: localPath → storageUrl (download URL).
  Future<Map<String, String>> _uploadImagesToStorage(
      User user, List<Map<String, dynamic>> photoNotes) async {
    final Map<String, String> pathToUrl = {};
    final storage = FirebaseStorage.instance;
    final prefix = _storagePrefix(user);

    // Collect all unique local paths from all photo notes
    final Set<String> allPaths = {};
    for (final n in photoNotes) {
      final paths = n['imagePaths'];
      if (paths is List) {
        for (final p in paths) {
          if (p is String && p.isNotEmpty) allPaths.add(p);
        }
      }
      final single = n['imagePath'];
      if (single is String && single.isNotEmpty) allPaths.add(single);
    }

    int done = 0;
    final total = allPaths.length;

    for (final localPath in allPaths) {
      try {
        final file = File(localPath);
        if (!await file.exists()) continue;

        final filename = localPath.split('/').last.split('\\').last;
        final ref = storage.ref('$prefix/images/$filename');

        // Check if already uploaded (skip to save bandwidth)
        String downloadUrl;
        try {
          downloadUrl = await ref.getDownloadURL();
        } catch (_) {
          // Not uploaded yet, upload now
          await ref.putFile(file);
          downloadUrl = await ref.getDownloadURL();
        }
        pathToUrl[localPath] = downloadUrl;

        done++;
        _imageProgress = 'Görsel $done/$total yükleniyor...';
        notifyListeners();
      } catch (e) {
        debugPrint('Image upload error for $localPath: $e');
      }
    }
    _imageProgress = '';
    notifyListeners();
    return pathToUrl;
  }

  /// Downloads all images from Firebase Storage to local app documents directory.
  /// Returns a map: storageUrl → newLocalPath
  Future<Map<String, String>> _downloadImagesFromStorage(
      User user, List<Map<String, dynamic>> photoNotes) async {
    final Map<String, String> urlToLocal = {};
    final dir = await getApplicationDocumentsDirectory();

    // Collect all unique storage URLs
    final Set<String> allUrls = {};
    for (final n in photoNotes) {
      final paths = n['imagePaths'];
      if (paths is List) {
        for (final p in paths) {
          if (p is String && p.startsWith('http')) allUrls.add(p);
        }
      }
      final single = n['imagePath'];
      if (single is String && single.startsWith('http')) allUrls.add(single);
    }

    int done = 0;
    final total = allUrls.length;

    for (final url in allUrls) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(url);
        final filename = ref.name;
        final localPath = '${dir.path}/$filename';
        final localFile = File(localPath);

        if (!await localFile.exists()) {
          await ref.writeToFile(localFile);
        }
        urlToLocal[url] = localPath;

        done++;
        _imageProgress = 'Görsel $done/$total indiriliyor...';
        notifyListeners();
      } catch (e) {
        debugPrint('Image download error for $url: $e');
      }
    }
    _imageProgress = '';
    notifyListeners();
    return urlToLocal;
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
      // 2. Build raw photo notes list (with local paths first)
      final rawPhotoNotes = photoNotesData.map((item) {
        final val = item['value'];
        if (val is Map) return Map<String, dynamic>.from(val);
        return <String, dynamic>{};
      }).where((m) => m.isNotEmpty).toList();

      // 2b. Upload images to Firebase Storage and replace local paths with URLs
      currentStep = "2b. Görseller Firebase Storage'a Yükleniyor";
      final pathToUrl = await _uploadImagesToStorage(user, rawPhotoNotes);

      // Replace local paths with storage URLs in photoNotesData
      final uploadedPhotoNotesData = photoNotesData.map((item) {
        final val = item['value'];
        if (val is! Map) return item;
        final updated = Map<String, dynamic>.from(val);
        // Replace imagePath
        if (updated['imagePath'] is String) {
          final url = pathToUrl[updated['imagePath']];
          if (url != null) updated['imagePath'] = url;
        }
        // Replace imagePaths list
        if (updated['imagePaths'] is List) {
          updated['imagePaths'] = (updated['imagePaths'] as List).map((p) {
            if (p is String) return pathToUrl[p] ?? p;
            return p;
          }).toList();
        }
        return {'key': item['key'], 'value': updated};
      }).toList();

      // 2. Build JSON payload (with storage URLs instead of local paths)
      final rawPayload = {
        'books': books,
        'pages': pages,
        'events': events,
        'notes': notes,
        'voice_notes': voiceNotes,
        'habits': habits,
        'planner_tasks': plannerTasks,
        'plans': plans,
        'photo_notes': uploadedPhotoNotesData,
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

      // Use email as Firestore document key so Google login and Email login share the same backup
      final String docId = _firestoreDocId(user);
      currentStep = "3. Kullanıcı Doğrulanıyor (${user.email ?? user.uid})";
      // Refresh user auth token to ensure active credentials for Firestore
      try {
        await user.getIdToken(true);
      } catch (tokenErr) {
        debugPrint('Token refresh warning: $tokenErr');
      }


      currentStep = "4. Ana Doküman Oluşturuluyor (Boyut: ${jsonString.length} kr)";
      // 4. Store each 400k chunk as an individual document inside users/{email}/backups/latest/chunks/chunk_X
      const int chunkSize = 400000;
      final int totalChunks = (jsonString.length / chunkSize).ceil();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .collection('backups')
          .doc('latest')
          .set({
        'lastBackupTime': DateTime.now().toIso8601String(),
        'deviceInfo': 'Android App',
        'chunkCount': totalChunks > 0 ? totalChunks : 1,
        'totalSize': jsonString.length,
        'ownerEmail': user.email ?? '',
      });

      if (jsonString.isEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .collection('backups')
            .doc('latest')
            .collection('chunks')
            .doc('chunk_0')
            .set({'data': '{}'});
      } else {
        for (int i = 0; i * chunkSize < jsonString.length; i++) {
          currentStep = "5. Parça ${i + 1}/$totalChunks Sunucuya Yükleniyor";
          int start = i * chunkSize;
          int end = start + chunkSize;
          if (end > jsonString.length) end = jsonString.length;
          final chunkText = jsonString.substring(start, end);

          await FirebaseFirestore.instance
              .collection('users')
              .doc(docId)
              .collection('backups')
              .doc('latest')
              .collection('chunks')
              .doc('chunk_$i')
              .set({'data': chunkText});
        }
      }

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

    String currentStep = "1. Buluttan Veri Çekiliyor";
    try {
      final String docId = _firestoreDocId(user);
      // 1. Fetch backup document from Cloud
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .collection('backups')
          .doc('latest')
          .get();

      if (!doc.exists || doc.data() == null) {
        _isSyncing = false;
        _syncError = "Bulutta kayıtlı yedek bulunamadı. (${user.email ?? user.uid})";
        notifyListeners();
        return false;
      }

      final docMap = doc.data()!;
      final Map<String, dynamic> data;
      if (docMap.containsKey('chunkCount')) {
        final int count = (docMap['chunkCount'] as num).toInt();
        final StringBuffer sb = StringBuffer();

        // Fetch chunk sub-documents
        final chunksSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(docId)
            .collection('backups')
            .doc('latest')
            .collection('chunks')
            .get();

        final Map<String, String> chunkMap = {};
        for (final cDoc in chunksSnap.docs) {
          chunkMap[cDoc.id] = cDoc.data()['data'] as String? ?? '';
        }

        for (int i = 0; i < count; i++) {
          if (chunkMap.containsKey('chunk_$i')) {
            sb.write(chunkMap['chunk_$i']);
          } else if (docMap.containsKey('chunk_$i')) {
            sb.write(docMap['chunk_$i']);
          }
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

      // 10. Photo Notes & Flashcards (Download images from Storage to local storage)
      final photoNotesBox = Hive.isBoxOpen('photo_notes')
          ? Hive.box('photo_notes')
          : await Hive.openBox('photo_notes');
      await photoNotesBox.clear();
      final photoNotesData = data['photo_notes'] as List<dynamic>? ?? [];

      // Collect raw photo note maps for image downloading
      final List<Map<String, dynamic>> rawNotesList = [];
      for (final item in photoNotesData) {
        if (item is Map && item.containsKey('value') && item['value'] is Map) {
          rawNotesList.add(Map<String, dynamic>.from(item['value'] as Map));
        }
      }

      currentStep = "10. Görseller Firebase Storage'dan İndiriliyor";
      final urlToLocal = await _downloadImagesFromStorage(user, rawNotesList);

      for (final item in photoNotesData) {
        if (item is Map && item.containsKey('key') && item.containsKey('value')) {
          final key = item['key'];
          final val = item['value'];
          if (key != null && val != null) {
            if (val is Map) {
              final updatedVal = Map<String, dynamic>.from(val);
              // Replace imagePath URL with local path
              if (updatedVal['imagePath'] is String) {
                final local = urlToLocal[updatedVal['imagePath']];
                if (local != null) updatedVal['imagePath'] = local;
              }
              // Replace imagePaths list URLs with local paths
              if (updatedVal['imagePaths'] is List) {
                updatedVal['imagePaths'] = (updatedVal['imagePaths'] as List).map((p) {
                  if (p is String) return urlToLocal[p] ?? p;
                  return p;
                }).toList();
              }
              await photoNotesBox.put(key, updatedVal);
            } else {
              await photoNotesBox.put(key, val);
            }
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
      _syncError = "[$currentStep]\nGeri yükleme hatası: $e";
      notifyListeners();
      return false;
    }
  }
}
