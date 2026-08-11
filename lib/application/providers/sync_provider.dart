import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:device_info_plus/device_info_plus.dart';
import '../../domain/models/book.dart';
import '../../domain/models/page.dart';
import '../../domain/models/event.dart';
import '../../domain/models/note.dart';
import '../../domain/models/photo_note.dart';
import '../../data/services/database_service.dart';
import '../../data/services/google_drive_service.dart';

class SyncProvider extends ChangeNotifier {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '918229000552-jfhosjoh4o6cgtjjem7cdotl912ahi7e.apps.googleusercontent.com',
    scopes: ['email', 'https://www.googleapis.com/auth/drive.file'],
  );
  final GoogleDriveService _driveService = GoogleDriveService();

  bool _isFirebaseAvailable = false;
  bool _isSyncing = false;
  String? _syncError;
  DateTime? _lastBackupTime;
  String? _lastBackupDevice;
  String? _driveFolderId;
  String _imageProgress = '';

  bool get isFirebaseAvailable => _isFirebaseAvailable;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  String get imageProgress => _imageProgress;

  DateTime? get lastBackupTime => _lastBackupTime;
  String? get lastBackupDevice => _lastBackupDevice;
  String? get driveFolderId => _driveFolderId;

  String? get driveFolderUrl {
    if (_driveFolderId != null && _driveFolderId!.isNotEmpty) {
      return 'https://drive.google.com/drive/folders/$_driveFolderId';
    }
    return 'https://drive.google.com/drive/my-drive';
  }

  User? get currentUser => _isFirebaseAvailable ? _auth.currentUser : null;

  Future<String> getDeviceName() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = androidInfo.manufacturer;
        final model = androidInfo.model;
        if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
          return model;
        }
        return '$manufacturer $model';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name.isNotEmpty ? iosInfo.name : iosInfo.model;
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        return winInfo.computerName;
      }
    } catch (e) {
      debugPrint('Device info error: $e');
    }
    return Platform.operatingSystem;
  }

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
      final lastDev = settingsBox.get('last_backup_device');
      if (lastDev != null) {
        _lastBackupDevice = lastDev.toString();
      }
      final fId = settingsBox.get('drive_folder_id');
      if (fId != null) {
        _driveFolderId = fId.toString();
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
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isSyncing = false;
        _syncError = "Google hesabı seçilmedi veya cihaz Play Servisleri isteği iptal etti.";
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
    _syncError = null;
    notifyListeners();
    try {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      await _auth.signOut();
    } catch (e) {
      _syncError = "Çıkış hatası: $e";
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Obtains an authenticated DriveApi instance using current Google account
  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
      googleUser ??= await _googleSignIn.signInSilently();
      if (googleUser == null) {
        googleUser = await _googleSignIn.signIn();
      }
      if (googleUser == null) {
        _syncError = "Google hesabı oturumu bulunamadı. Lütfen Ayarlar'dan 'Google Hesabını Bağla' butonuna tıklayın.";
        debugPrint('[SYNC DRIVE ERROR] googleUser is null');
        return null;
      }

      try {
        final headers = await googleUser.authHeaders;
        final client = GoogleAuthClient(headers);
        return drive.DriveApi(client);
      } catch (authErr) {
        debugPrint('[SYNC DRIVE WARNING] authHeaders failed, requesting drive.file scope: $authErr');
        final constDriveScope = 'https://www.googleapis.com/auth/drive.file';
        final granted = await _googleSignIn.requestScopes([constDriveScope]);
        if (granted) {
          final headers = await googleUser.authHeaders;
          final client = GoogleAuthClient(headers);
          return drive.DriveApi(client);
        } else {
          _syncError = "Google Drive erişim izni verilmedi. Lütfen izni onaylayın.";
          return null;
        }
      }
    } on PlatformException catch (pe) {
      if (pe.code == 'sign_in_failed' || pe.message?.contains('12500') == true) {
        _syncError = "Google İzin Hatası (12500): Lütfen Ayarlar ekranında 'Google Hesabını Bağla' butonuna tekrar basıp oturum açın.";
      } else {
        _syncError = "Google Drive bağlantı hatası (${pe.code}): ${pe.message}";
      }
      debugPrint('[SYNC DRIVE ERROR] PlatformException in Drive API: $pe');
      return null;
    } catch (e) {
      _syncError = "Google Drive bağlantı hatası: $e";
      debugPrint('[SYNC DRIVE ERROR] Failed to obtain Drive API instance: $e');
      return null;
    }
  }

  /// Uploads all local photo note images to Google Drive.
  /// Returns a map: localPath → drive://<fileId>
  Future<Map<String, String>> _uploadImagesToDrive(
      User user, List<Map<String, dynamic>> photoNotes) async {
    final Map<String, String> pathToUrl = {};

    final Set<String> allPaths = {};
    for (final n in photoNotes) {
      final paths = n['imagePaths'];
      if (paths is List) {
        for (final p in paths) {
          if (p is String && p.isNotEmpty && !p.startsWith('drive://') && !p.startsWith('http')) {
            allPaths.add(p);
          }
        }
      }
      final single = n['imagePath'];
      if (single is String && single.isNotEmpty && !single.startsWith('drive://') && !single.startsWith('http')) {
        allPaths.add(single);
      }
    }

    if (allPaths.isEmpty) return pathToUrl;

    drive.DriveApi? driveApi;
    String? folderId;
    try {
      driveApi = await _getDriveApi();
      if (driveApi != null) {
        folderId = await _driveService.getOrCreateFolderId(driveApi);
      }
    } catch (e) {
      debugPrint('[BACKUP WARNING] Drive API init failed, using Firebase Storage fallback: $e');
    }

    int done = 0;
    final total = allPaths.length;
    debugPrint('[BACKUP DEBUG] _uploadImagesToDrive starting: $total total image paths to process.');

    for (final localPath in allPaths) {
      try {
        final file = File(localPath);
        if (!await file.exists()) {
          debugPrint('[BACKUP DEBUG] Local image file does not exist, skipping: $localPath');
          continue;
        }

        String? imageUrl;

        // 1. Upload to Firebase Storage (Universal URL for cross-device sync)
        try {
          final filename = localPath.split('/').last.split('\\').last;
          final ref = FirebaseStorage.instance.ref().child('users/${user.uid}/photo_notes/$filename');
          await ref.putFile(file);
          imageUrl = await ref.getDownloadURL();
          debugPrint('[BACKUP SUCCESS] Uploaded image to Firebase Storage: $localPath -> $imageUrl');
        } catch (storageErr) {
          debugPrint('[BACKUP WARNING] Firebase Storage upload error: $storageErr');
        }

        // 2. Also backup to Google Drive if Drive API is active
        if (driveApi != null && folderId != null) {
          try {
            final driveId = await _driveService.uploadFile(
              driveApi: driveApi,
              file: file,
              folderId: folderId,
            );
            if (driveId != null) {
              debugPrint('[BACKUP SUCCESS] Also uploaded image to Google Drive: ID=$driveId');
              imageUrl ??= 'drive://$driveId';
            }
          } catch (driveErr) {
            debugPrint('[BACKUP WARNING] Google Drive upload error: $driveErr');
          }
        }

        if (imageUrl != null) {
          pathToUrl[localPath] = imageUrl;
        }

        done++;
        _imageProgress = 'Görsel $done/$total yükleniyor...';
        notifyListeners();
      } catch (e) {
        debugPrint('[BACKUP DEBUG ERROR] Image upload failed for $localPath: $e');
      }
    }
    _imageProgress = '';
    notifyListeners();
    return pathToUrl;
  }

  /// Recursively cleans heavy base64 strings (such as canvas thumbnail imageData) from any object or payload.
  /// IMPORTANT: drawingJson and drawing fields are PRESERVED — they contain critical drawing/annotation data.
  /// Only imageData (canvas PNG thumbnails) and raw base64 image strings are stripped.
  dynamic _cleanBase64Data(dynamic obj) {
    if (obj is Map) {
      final map = <String, dynamic>{};
      obj.forEach((k, v) {
        final keyStr = k.toString();
        if (keyStr == 'imageData') return; // Strip canvas PNG thumbnail
        // backgroundImageBase64 is already uploaded to Drive in _uploadPageBackgroundsToDrive.
        // Only strip it here — restore will download from Drive URL.
        if (keyStr == 'backgroundImageBase64') return;
        // PRESERVE drawingJson and drawing — these contain critical drawing/annotation data (points, lines, etc.)
        if (keyStr == 'drawingJson' || keyStr == 'drawing') {
          map[keyStr] = v;
          return;
        }
        // Strip only actual base64 image data strings (not drawingJson or other structured data)
        if (v is String && (v.startsWith('data:image') || v.startsWith('iVBORw0KGgo'))) {
          return; // Strip raw base64 image data string
        }
        map[keyStr] = _cleanBase64Data(v);
      });
      return map;
    } else if (obj is List) {
      return obj.map((item) => _cleanBase64Data(item)).toList();
    } else if (obj is NotePage) {
      return _cleanBase64Data(obj.toJson());
    } else if (obj is Book) {
      return _cleanBase64Data(obj.toJson());
    } else if (obj is Note) {
      return _cleanBase64Data(obj.toJson());
    } else if (obj is PhotoNote) {
      return _cleanBase64Data(obj.toMap());
    } else if (obj != null) {
      try {
        return _cleanBase64Data((obj as dynamic).toJson());
      } catch (_) {
        try {
          return _cleanBase64Data((obj as dynamic).toMap());
        } catch (_) {}
      }
    }
    return obj;
  }

  /// Computes a simple hash of a page's background image for incremental backup.
  /// Returns a short hash string that can be compared to detect changes.
  String _computePageBgHash(String? backgroundImageBase64) {
    if (backgroundImageBase64 == null || backgroundImageBase64.isEmpty) return '';
    // Use first 100 + last 100 chars + length as a fast fingerprint
    final len = backgroundImageBase64.length;
    final prefix = backgroundImageBase64.substring(0, len < 100 ? len : 100);
    final suffix = len > 100 ? backgroundImageBase64.substring(len - 100) : '';
    return '${prefix.hashCode}_${suffix.hashCode}_$len';
  }

  /// Uploads page backgroundImageBase64 fields to Google Drive.
  /// Returns a list of pages with backgroundImageBase64 replaced by backgroundImageUrl (drive://<fileId>) and imageData stripped.
  /// Supports incremental backup: pages whose background hasn't changed since last backup are skipped.
  Future<List<dynamic>> _uploadPageBackgroundsToDrive(
      User user, List<dynamic> pages) async {
    final List<dynamic> result = [];
    int uploaded = 0;
    int skipped = 0;

    // Load previously backed-up page hashes for incremental backup
    final settingsBox = Hive.box('settings');
    final Map<String, String> previousHashes = {};
    final Map<String, String> previousDriveUrls = {};
    try {
      final savedHashes = settingsBox.get('page_bg_hashes');
      if (savedHashes is Map) {
        savedHashes.forEach((k, v) => previousHashes[k.toString()] = v.toString());
      }
      final savedUrls = settingsBox.get('page_bg_drive_urls');
      if (savedUrls is Map) {
        savedUrls.forEach((k, v) => previousDriveUrls[k.toString()] = v.toString());
      }
    } catch (_) {}
    final Map<String, String> newHashes = {};
    final Map<String, String> newDriveUrls = {};

    // ── Önce DriveApi & folderId başlat — loop dışında ──
    drive.DriveApi? driveApi;
    String? folderId;
    try {
      driveApi = await _getDriveApi();
      if (driveApi != null) {
        folderId = await _driveService.getOrCreateFolderId(driveApi);
        if (folderId != null) {
          _driveFolderId = folderId;
          final settingsBox = Hive.box('settings');
          await settingsBox.put('drive_folder_id', _driveFolderId);
        }
        debugPrint('[BACKUP] Page bg Drive init: folderId=$folderId');
      } else {
        debugPrint('[BACKUP WARNING] DriveApi could not be obtained for page backgrounds. '
            'backgroundImageBase64 fields will be KEPT in JSON (no stripping).');
      }
    } catch (initErr) {
      debugPrint('[BACKUP WARNING] Drive init error for page backgrounds: $initErr');
    }

    for (final rawP in pages) {
      Map<String, dynamic> p;
      if (rawP is NotePage) {
        p = rawP.toJson();
      } else if (rawP is Map) {
        p = Map<String, dynamic>.from(rawP);
      } else {
        try {
          p = Map<String, dynamic>.from((rawP as dynamic).toJson());
        } catch (_) {
          try {
            p = Map<String, dynamic>.from((rawP as dynamic).toMap());
          } catch (_) {
            result.add(rawP);
            continue;
          }
        }
      }

      dynamic drawingJson = p['drawingJson'];
      if (drawingJson == null || (drawingJson is String && drawingJson.isEmpty)) {
        result.add(p);
        continue;
      }

      try {
        dynamic decoded;
        if (drawingJson is String) {
          decoded = jsonDecode(drawingJson);
        } else {
          decoded = drawingJson;
        }

        if (decoded is Map && decoded.containsKey('pages') && decoded['pages'] is List) {
          final innerPages = decoded['pages'] as List<dynamic>;
          final updatedInnerPages = await Future.wait(innerPages.map((ip) async {
            if (ip is! Map) return ip;
            final ipMap = Map<String, dynamic>.from(ip);

            final b64 = ipMap['backgroundImageBase64'];
            if (b64 == null || b64 is! String || b64.isEmpty) return ipMap;

            // Drive kullanılamiyorsa base64'u çıkarma — içeriği koruyalım
            if (driveApi == null || folderId == null) {
              debugPrint('[BACKUP] No Drive/folderId — keeping backgroundImageBase64 in JSON.');
              return ipMap; // ← base64'u SİLME, oldugu gibi bırak
            }

            final pageId = p['id']?.toString() ?? 'page_${uploaded}';
            final filename = 'bg_${pageId}.png';

            // Incremental backup: check if this page's background has changed
            final currentHash = _computePageBgHash(b64);
            final previousHash = previousHashes[pageId];
            final previousUrl = previousDriveUrls[pageId];
            if (currentHash == previousHash && previousUrl != null && previousUrl.isNotEmpty) {
              // Background hasn't changed — reuse previous Drive URL
              skipped++;
              debugPrint('[BACKUP SKIP] Page $pageId bg unchanged, reusing Drive URL: $previousUrl');
              ipMap.remove('backgroundImageBase64');
              ipMap['backgroundImageUrl'] = previousUrl;
              newHashes[pageId] = currentHash;
              newDriveUrls[pageId] = previousUrl;
              return ipMap;
            }

            String? driveId;
            try {
              final bytes = base64Decode(b64);
              driveId = await _driveService.uploadBytes(
                driveApi: driveApi!,
                bytes: bytes,
                filename: filename,
                folderId: folderId,
              );
              uploaded++;
              _imageProgress = 'Sayfa görseli $uploaded Drive\'a yükleniyor... ($skipped atlandı)';
              notifyListeners();
            } catch (uploadErr) {
              debugPrint('Page bg Drive upload error: $uploadErr');
              // Yükleme başarısız olursa da base64'u koruyalım (silme)
              return ipMap;
            }

            // Yükleme başarılı: base64 yerine driveUrl yaz
            ipMap.remove('backgroundImageBase64');
            if (driveId != null) {
              ipMap['backgroundImageUrl'] = 'drive://$driveId';
              newHashes[pageId] = currentHash;
              newDriveUrls[pageId] = 'drive://$driveId';
            }
            return ipMap;
          }));
          decoded['pages'] = updatedInnerPages;
        }

        // Sadece Drive'a yüklenen (backgroundImageUrl olan) sayfalar için base64 temizle
        // Yüklenemeyen sayfalar base64 ile korunuyor — burada ekstra temizleme YAPMA
        final updatedPage = Map<String, dynamic>.from(p);
        updatedPage['drawingJson'] = jsonEncode(decoded);
        result.add(updatedPage);
      } catch (e) {
        debugPrint('Page background processing error: $e');
        result.add(p);
      }
    }

    // Save page hashes and Drive URLs for next incremental backup
    try {
      await settingsBox.put('page_bg_hashes', newHashes);
      await settingsBox.put('page_bg_drive_urls', newDriveUrls);
    } catch (e) {
      debugPrint('[BACKUP WARNING] Could not save page hashes: $e');
    }

    debugPrint('[BACKUP] Page backgrounds: $uploaded uploaded, $skipped skipped (unchanged).');
    _imageProgress = '';
    notifyListeners();
    return result;
  }

  /// Downloads all images from Google Drive (or legacy Firebase Storage) to local app documents directory.
  /// Returns a map: driveUri/storageUrl → localPath
  Future<Map<String, String>> _downloadImagesFromDrive(
      User user, List<Map<String, dynamic>> photoNotes) async {
    final Map<String, String> urlToLocal = {};
    final dir = await getApplicationDocumentsDirectory();

    final Set<String> allDriveUris = {};
    final Set<String> allHttpUrls = {};

    for (final n in photoNotes) {
      final paths = n['imagePaths'];
      if (paths is List) {
        for (final p in paths) {
          if (p is String) {
            if (p.startsWith('drive://')) allDriveUris.add(p);
            else if (p.startsWith('http')) allHttpUrls.add(p);
          }
        }
      }
      final single = n['imagePath'];
      if (single is String) {
        if (single.startsWith('drive://')) allDriveUris.add(single);
        else if (single.startsWith('http')) allHttpUrls.add(single);
      }
    }

    int done = 0;
    final total = allDriveUris.length + allHttpUrls.length;

    drive.DriveApi? driveApi;
    if (allDriveUris.isNotEmpty) {
      try {
        driveApi = await _getDriveApi();
      } catch (e) {
        debugPrint('[RESTORE WARNING] Drive API init failed, skipping Drive URIs: $e');
      }
    }

    // 1. Download Drive URIs
    for (final driveUri in allDriveUris) {
      try {
        final driveId = driveUri.replaceAll('drive://', '');
        final localPath = '${dir.path}/drive_$driveId.jpg';
        final localFile = File(localPath);

        if (await localFile.exists()) {
          urlToLocal[driveUri] = localPath;
        } else if (driveApi != null) {
          final success = await _driveService.downloadFile(
            driveApi: driveApi,
            driveFileId: driveId,
            targetLocalFile: localFile,
          );
          if (success) {
            urlToLocal[driveUri] = localPath;
          }
        }

        done++;
        _imageProgress = 'Görsel $done/$total indiriliyor...';
        notifyListeners();
      } catch (e) {
        debugPrint('Image Drive download error for $driveUri: $e');
      }
    }

    // 2. Download Firebase Storage / HTTP URLs
    for (final url in allHttpUrls) {
      try {
        final filename = 'img_${url.hashCode}.jpg';
        final localPath = '${dir.path}/$filename';
        final localFile = File(localPath);

        if (!await localFile.exists()) {
          try {
            final ref = FirebaseStorage.instance.refFromURL(url);
            await ref.writeToFile(localFile);
          } catch (_) {
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              await localFile.writeAsBytes(response.bodyBytes);
            }
          }
        }
        if (await localFile.exists()) {
          urlToLocal[url] = localPath;
        }

        done++;
        _imageProgress = 'Görsel $done/$total indiriliyor...';
        notifyListeners();
      } catch (e) {
        debugPrint('Storage download error for $url: $e');
      }
    }

    _imageProgress = '';
    notifyListeners();
    return urlToLocal;
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
      // 0. Refresh Auth Token to guarantee active credentials
      try {
        await user.getIdToken(true);
        debugPrint('[BACKUP DEBUG] Auth token refreshed successfully for UID=${user.uid}');
      } catch (tokenErr) {
        debugPrint('[BACKUP DEBUG WARNING] Token refresh error: $tokenErr');
      }

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
        if (val is PhotoNote) return val.toMap();
        if (val is Map) return Map<String, dynamic>.from(val);
        try {
          return Map<String, dynamic>.from((val as dynamic).toMap());
        } catch (_) {}
        return <String, dynamic>{};
      }).where((m) => m.isNotEmpty).toList();

      currentStep = "2b. Görseller Google Drive'a Yükleniyor";
      Map<String, String> pathToUrl = {};
      try {
        pathToUrl = await _uploadImagesToDrive(user, rawPhotoNotes);
      } catch (imgErr) {
        debugPrint('[BACKUP WARNING] Image Drive upload failed, proceeding with text backup: $imgErr');
      }

      // Replace local paths with storage URLs in photoNotesData
      final uploadedPhotoNotesData = photoNotesData.map((item) {
        final val = item['value'];
        Map<String, dynamic> updated;
        if (val is PhotoNote) {
          updated = val.toMap();
        } else if (val is Map) {
          updated = Map<String, dynamic>.from(val);
        } else {
          try {
            updated = Map<String, dynamic>.from((val as dynamic).toMap());
          } catch (_) {
            return item;
          }
        }
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

      // 2c. Upload page backgroundImageBase64 to Google Drive (strip from JSON to reduce size)
      currentStep = "2c. Sayfa Görselleri Google Drive'a Yükleniyor";
      final pagesWithUrls = await _uploadPageBackgroundsToDrive(user, pages);

      // 2. Build JSON payload (with storage URLs instead of local paths)
      final rawPayload = {
        'books': books,
        'pages': pagesWithUrls,
        'events': events,
        'notes': notes,
        'voice_notes': voiceNotes,
        'habits': habits,
        'planner_tasks': plannerTasks,
        'plans': plans,
        'photo_notes': uploadedPhotoNotesData,
        'settings': settings,
        'lastBackupTime': DateTime.now().toIso8601String(),
        'lastBackupDevice': await getDeviceName(),
        'deviceInfo': await getDeviceName(),
      };

      // 2d. Clean ALL heavy base64 strings from rawPayload recursively
      final cleanedPayload = _cleanBase64Data(rawPayload);

      // 3. Serialize to pure JSON string with custom encoder fallback
      final jsonString = jsonEncode(cleanedPayload, toEncodable: (nonEncodable) {
        if (nonEncodable is DateTime) return nonEncodable.toIso8601String();
        try {
          return (nonEncodable as dynamic).toJson();
        } catch (_) {}
        try {
          return (nonEncodable as dynamic).toMap();
        } catch (_) {}
        return nonEncodable.toString();
      });

      // 4. Compress JSON string using GZIP for 90% size reduction & speed
      currentStep = "4. Yedek Paketi Sıkıştırılıyor (GZIP)";
      final jsonBytes = utf8.encode(jsonString);
      final compressedBytes = Uint8List.fromList(gzip.encode(jsonBytes));
      final double mbSize = compressedBytes.length / (1024 * 1024);
      debugPrint('[BACKUP DEBUG] GZIP compression: ${jsonBytes.length} chars -> ${compressedBytes.length} bytes (${mbSize.toStringAsFixed(2)} MB)');

      // 5. Save cleaned JSON to Firestore with multi-candidate doc IDs and collections
      currentStep = "5. Bulut Depolamasına Yazılıyor (Firestore)";
      final candidateDocIds = [
        user.uid,
        if (user.email != null && user.email!.isNotEmpty) ...[
          user.email!.toLowerCase().trim().replaceAll('.', '_').replaceAll('@', '_at_'),
          user.email!,
        ],
      ];

      final candidateCols = ['users', 'user_backups', 'backups'];

      bool writeSuccess = false;
      String? lastFsErr;

      final currentDevice = await getDeviceName();
      _lastBackupDevice = currentDevice;
      _lastBackupTime = DateTime.now();
      await settingsBox.put('last_backup_device', _lastBackupDevice);
      await settingsBox.put('last_backup_time', _lastBackupTime!.toIso8601String());

      for (final col in candidateCols) {
        for (final docId in candidateDocIds) {
          try {
            await FirebaseFirestore.instance.collection(col).doc(docId).set({
              'email': user.email ?? '',
              'json_data': jsonString,
              'lastBackupTime': _lastBackupTime!.toIso8601String(),
              'lastBackupDevice': currentDevice,
              'uid': user.uid,
              'totalSize': jsonString.length,
              'compressedSize': compressedBytes.length,
            }, SetOptions(merge: true));

            writeSuccess = true;
            debugPrint('[BACKUP DEBUG SUCCESS] Saved backup directly to $col/$docId (${jsonString.length} chars)');
            break;
          } catch (fsErr) {
            lastFsErr = fsErr.toString();
            debugPrint('[BACKUP DEBUG] Write candidate $col/$docId failed: $fsErr');
          }
        }
        if (writeSuccess) break;
      }

      if (!writeSuccess) {
        _isSyncing = false;
        _syncError = "Yedekleme Buluta Yazılamadı!\n\nFirestore Hata: $lastFsErr\n(UID: ${user.uid})";
        notifyListeners();
        return false;
      }

      debugPrint('[BACKUP DEBUG SUCCESS] Backup completed cleanly at ${DateTime.now()}!');
      _lastBackupTime = DateTime.now();
      await settingsBox.put('last_backup_time', _lastBackupTime!.toIso8601String());

      _isSyncing = false;
      notifyListeners();
      return true;
    } on FirebaseException catch (fe) {
      debugPrint('[BACKUP DEBUG CATCH] FirebaseException at [$currentStep]: Code=[${fe.code}] Message=[${fe.message}] Plugin=[${fe.plugin}] Details=[$fe]');
      _isSyncing = false;
      _syncError = "[$currentStep]\nFirebase Hata: [${fe.code}]\n${fe.message ?? fe.toString()}\n(UID: ${user.uid})";
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('[BACKUP DEBUG CATCH] General Exception at [$currentStep]: Error=$e\n$stack');
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
      // 0. Refresh Auth Token to guarantee active credentials
      try {
        await user.getIdToken(true);
        debugPrint('[RESTORE DEBUG] Auth token refreshed successfully for UID=${user.uid}');
      } catch (tokenErr) {
        debugPrint('[RESTORE DEBUG WARNING] Token refresh error: $tokenErr');
      }

      DocumentSnapshot<Map<String, dynamic>>? docSnap;

      final candidateCols = ['users', 'user_backups', 'backups'];
      final candidateDocIds = [
        user.uid,
        if (user.email != null && user.email!.isNotEmpty) ...[
          user.email!.toLowerCase().trim().replaceAll('.', '_').replaceAll('@', '_at_'),
          user.email!,
        ],
      ];

      // 1. Try reading top-level doc across collections & candidate IDs
      for (final col in candidateCols) {
        for (final candidateId in candidateDocIds) {
          currentStep = "1. Buluttan Veri Aranıyor ($col/$candidateId)";
          try {
            final ds = await FirebaseFirestore.instance.collection(col).doc(candidateId).get();
            if (ds.exists && ds.data() != null && ds.data()!['json_data'] != null) {
              docSnap = ds;
              debugPrint('[RESTORE DEBUG SUCCESS] Found backup doc at $col/$candidateId');
              break;
            }
          } catch (directErr) {
            debugPrint('[RESTORE DEBUG WARNING] Direct doc read failed ($col/$candidateId): $directErr');
          }
        }
        if (docSnap != null) break;
      }

      // 2. Fallback: Query users collection by email for cross-device phone <-> tablet sync
      if (docSnap == null && user.email != null && user.email!.isNotEmpty) {
        currentStep = "1. E-posta İle Yedek Aranıyor (${user.email})";
        for (final col in candidateCols) {
          try {
            final q = await FirebaseFirestore.instance
                .collection(col)
                .where('email', isEqualTo: user.email)
                .get();
            for (final d in q.docs) {
              if (d.data()['json_data'] != null) {
                docSnap = d;
                debugPrint('[RESTORE DEBUG SUCCESS] Found backup doc by email at $col/${d.id}');
                break;
              }
            }
          } catch (emailQueryErr) {
            debugPrint('[RESTORE DEBUG WARNING] Email query failed ($col): $emailQueryErr');
          }
          if (docSnap != null) break;
        }
      }

      if (docSnap == null || !docSnap.exists || docSnap.data() == null || docSnap.data()!['json_data'] == null) {
        _isSyncing = false;
        _syncError = "Bulutta henüz kaydedilmiş bir yedek bulunamadı.\nLütfen önce verilerinizin olduğu cihazdan 'Yedekle' butonuna basınız. (${user.email ?? user.uid})";
        notifyListeners();
        return false;
      }

      final docMap = docSnap.data()!;
      final jsonText = docMap['json_data'] as String;
      final Map<String, dynamic> data = jsonDecode(jsonText) as Map<String, dynamic>;

      // 2. Books
      final booksBox = DatabaseService.getBooksBox();
      await booksBox.clear();
      final booksData = data['books'] as List<dynamic>? ?? [];
      for (final b in booksData) {
        if (b is Map) {
          try {
            final book = Book.fromJson(Map<dynamic, dynamic>.from(b));
            if (book.id.isNotEmpty) {
              await booksBox.put(book.id, book);
              debugPrint('[RESTORE SUCCESS] Restored book: ${book.title} (ID: ${book.id})');
            }
          } catch (e) {
            debugPrint('[RESTORE ERROR] Could not restore book: $e');
          }
        }
      }

      // 3. Pages (restore backgroundImageUrl → backgroundImageBase64)
      final pagesBox = DatabaseService.getPagesBox();
      await pagesBox.clear();
      final pagesData = data['pages'] as List<dynamic>? ?? [];

      // Drive API'yi bir kez başlat — her sayfa için tekrar açmak yerine
      drive.DriveApi? restoreDriveApi;
      try {
        restoreDriveApi = await _getDriveApi();
        debugPrint('[RESTORE] DriveApi init for page backgrounds: ${restoreDriveApi != null ? "OK" : "FAILED"}');
      } catch (e) {
        debugPrint('[RESTORE WARNING] DriveApi init error: $e');
      }

      for (final p in pagesData) {
        if (p is Map) {
          final pageMap = Map<String, dynamic>.from(p);
          // Restore backgroundImageUrl → backgroundImageBase64 in drawingJson
          if (pageMap['drawingJson'] is String) {
            try {
              final dj = jsonDecode(pageMap['drawingJson'] as String);
              if (dj is Map && dj.containsKey('pages')) {
                final innerPages = dj['pages'] as List<dynamic>;
                bool changed = false;
                final restored = await Future.wait(innerPages.map((ip) async {
                  if (ip is! Map) return ip;
                  final ipMap = Map<String, dynamic>.from(ip);
                  final url = ipMap['backgroundImageUrl'];

                  // Zaten base64 varsa dokunma
                  if (ipMap.containsKey('backgroundImageBase64')) return ipMap;

                  if (url == null || url is! String || url.isEmpty) return ipMap;
                  try {
                    final tmpDir = await getApplicationDocumentsDirectory();
                    if (url.startsWith('drive://')) {
                      final driveId = url.replaceAll('drive://', '');
                      final tmpFile = File('${tmpDir.path}/tmp_bg_drive_$driveId.png');
                      if (restoreDriveApi != null) {
                        final ok = await _driveService.downloadFile(
                          driveApi: restoreDriveApi!,
                          driveFileId: driveId,
                          targetLocalFile: tmpFile,
                        );
                        if (ok && await tmpFile.exists()) {
                          final bytes = await tmpFile.readAsBytes();
                          ipMap['backgroundImageBase64'] = base64Encode(bytes);
                          ipMap.remove('backgroundImageUrl');
                          changed = true;
                          debugPrint('[RESTORE] Page bg restored from Drive: $driveId');
                        } else {
                          debugPrint('[RESTORE WARNING] Page bg download failed/missing: $driveId');
                        }
                      } else {
                        debugPrint('[RESTORE WARNING] No DriveApi for page bg: $driveId');
                      }
                    } else if (url.startsWith('http')) {
                      final ref = FirebaseStorage.instance.refFromURL(url);
                      final tmpFile = File('${tmpDir.path}/tmp_bg_${ref.name}');
                      if (!await tmpFile.exists()) {
                        await ref.writeToFile(tmpFile);
                      }
                      if (await tmpFile.exists()) {
                        final bytes = await tmpFile.readAsBytes();
                        ipMap['backgroundImageBase64'] = base64Encode(bytes);
                        ipMap.remove('backgroundImageUrl');
                        changed = true;
                      }
                    }
                  } catch (e) {
                    debugPrint('Page bg restore error: $e');
                  }
                  return ipMap;
                }));

                // changed olsun olmasın, drawingJson'u daima güncelle
                final djMap = Map<String, dynamic>.from(dj);
                djMap['pages'] = restored;
                pageMap['drawingJson'] = jsonEncode(djMap);
              }
            } catch (e) {
              debugPrint('drawingJson parse error during restore: $e');

            }
          }
          try {
            final page = NotePage.fromJson(pageMap);
            if (page.id.isNotEmpty) {
              await pagesBox.put(page.id, page);
            }
          } catch (e) {
            debugPrint('[RESTORE ERROR] Could not restore NotePage: $e');
          }
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

      currentStep = "10. Görseller Google Drive'dan İndiriliyor";
      Map<String, String> urlToLocal = {};
      try {
        urlToLocal = await _downloadImagesFromDrive(user, rawNotesList);
      } catch (imgErr) {
        debugPrint('[RESTORE WARNING] Image Drive download failed, proceeding with text restore: $imgErr');
      }

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

      // Update backup local timestamp & device
      if (data['lastBackupTime'] != null) {
        _lastBackupTime = DateTime.tryParse(data['lastBackupTime'].toString());
        if (_lastBackupTime != null) {
          await settingsBox.put('last_backup_time', _lastBackupTime!.toIso8601String());
        }
      }
      final backupDev = data['lastBackupDevice'] ?? data['deviceInfo'];
      if (backupDev != null) {
        _lastBackupDevice = backupDev.toString();
        await settingsBox.put('last_backup_device', _lastBackupDevice);
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
