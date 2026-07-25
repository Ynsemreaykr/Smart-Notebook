import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Authenticated HTTP Client wrapper for Google Sign In
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleDriveService {
  static const String _folderName = 'SmartNotebook_Backups';

  /// Obtains an authenticated DriveApi instance using current GoogleSignInAccount
  Future<drive.DriveApi?> getDriveApi(GoogleSignInAccount googleUser) async {
    try {
      final headers = await googleUser.authHeaders;
      final client = GoogleAuthClient(headers);
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('[DRIVE SERVICE ERROR] Failed to get DriveApi: $e');
      return null;
    }
  }

  /// Finds existing backup folder or creates a new one in user's Drive
  Future<String?> getOrCreateFolderId(drive.DriveApi driveApi) async {
    try {
      final query = "mimeType = 'application/vnd.google-apps.folder' and name = '$_folderName' and trashed = false";
      drive.FileList fileList;
      try {
        fileList = await driveApi.files.list(q: query);
      } catch (listErr) {
        debugPrint('[DRIVE SERVICE WARNING] files.list failed: $listErr');
        fileList = drive.FileList(files: []);
      }

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final folderId = fileList.files!.first.id;
        debugPrint('[DRIVE SERVICE] Found existing folder: $folderId');
        return folderId;
      }

      // Create folder if it doesn't exist
      final folderToCreate = drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder';

      final createdFolder = await driveApi.files.create(folderToCreate);
      debugPrint('[DRIVE SERVICE] Created new backup folder: ${createdFolder.id}');
      return createdFolder.id;
    } catch (e) {
      debugPrint('[DRIVE SERVICE ERROR] getOrCreateFolderId failed: $e');
      rethrow;
    }
  }

  /// Uploads a local file to Google Drive and returns its Drive file ID
  Future<String?> uploadFile({
    required drive.DriveApi driveApi,
    required File file,
    String? folderId,
    String? customMimeType,
  }) async {
    try {
      if (!await file.exists()) {
        debugPrint('[DRIVE SERVICE WARNING] Local file does not exist: ${file.path}');
        return null;
      }

      final filename = file.path.split('/').last.split('\\').last;

      // Overwrite existing file with same name if present in folder
      if (folderId != null) {
        try {
          final query = "'$folderId' in parents and name = '$filename' and trashed = false";
          final existing = await driveApi.files.list(q: query);
          if (existing.files != null && existing.files!.isNotEmpty) {
            final existingId = existing.files!.first.id!;
            final length = await file.length();
            final stream = file.openRead();
            final media = drive.Media(stream, length);
            final updated = await driveApi.files.update(
              drive.File(),
              existingId,
              uploadMedia: media,
            );
            debugPrint('[DRIVE SERVICE OVERWRITE] Updated existing file: $filename -> ID: ${updated.id}');
            return updated.id;
          }
        } catch (e) {
          debugPrint('[DRIVE SERVICE WARNING] Check existing file failed: $e');
        }
      }

      final driveFile = drive.File()
        ..name = filename
        ..parents = folderId != null ? [folderId] : null;

      final length = await file.length();
      final stream = file.openRead();
      final media = drive.Media(stream, length);

      final result = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );

      debugPrint('[DRIVE SERVICE SUCCESS] Uploaded file: $filename -> ID: ${result.id}');
      return result.id;
    } catch (e) {
      debugPrint('[DRIVE SERVICE ERROR] Upload file failed for ${file.path}: $e');
      return null;
    }
  }

  /// Uploads raw bytes (e.g. PNG background image) to Google Drive and returns its Drive file ID
  Future<String?> uploadBytes({
    required drive.DriveApi driveApi,
    required Uint8List bytes,
    required String filename,
    String mimeType = 'image/png',
    String? folderId,
  }) async {
    try {
      if (folderId != null) {
        try {
          final query = "'$folderId' in parents and name = '$filename' and trashed = false";
          final existing = await driveApi.files.list(q: query);
          if (existing.files != null && existing.files!.isNotEmpty) {
            final existingId = existing.files!.first.id!;
            final stream = Stream.value(bytes);
            final media = drive.Media(stream, bytes.length, contentType: mimeType);
            final updated = await driveApi.files.update(
              drive.File(),
              existingId,
              uploadMedia: media,
            );
            debugPrint('[DRIVE SERVICE OVERWRITE] Updated existing bytes file: $filename -> ID: ${updated.id}');
            return updated.id;
          }
        } catch (e) {
          debugPrint('[DRIVE SERVICE WARNING] Check existing bytes file failed: $e');
        }
      }

      final driveFile = drive.File()
        ..name = filename
        ..parents = folderId != null ? [folderId] : null;

      final stream = Stream.value(bytes);
      final media = drive.Media(stream, bytes.length, contentType: mimeType);

      final result = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
      );

      debugPrint('[DRIVE SERVICE SUCCESS] Uploaded bytes: $filename -> ID: ${result.id}');
      return result.id;
    } catch (e) {
      debugPrint('[DRIVE SERVICE ERROR] Upload bytes failed for $filename: $e');
      return null;
    }
  }

  /// Downloads a file from Google Drive by its fileId and saves it to localFile
  Future<bool> downloadFile({
    required drive.DriveApi driveApi,
    required String driveFileId,
    required File targetLocalFile,
  }) async {
    try {
      if (await targetLocalFile.exists()) {
        // File already downloaded locally
        return true;
      }

      final drive.Media media = await driveApi.files.get(
        driveFileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final parentDir = targetLocalFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final sink = targetLocalFile.openWrite();
      await media.stream.pipe(sink);
      await sink.close();

      debugPrint('[DRIVE SERVICE SUCCESS] Downloaded fileId: $driveFileId to ${targetLocalFile.path}');
      return true;
    } catch (e) {
      debugPrint('[DRIVE SERVICE ERROR] Download failed for fileId $driveFileId: $e');
      return false;
    }
  }
}
