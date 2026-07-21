import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ScannerService {
  final ImagePicker _picker = ImagePicker();

  /// Capture a single image from camera
  Future<File?> captureFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 2560,
      );
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Kameradan fotoğraf çekilemedi: $e');
    }
  }

  /// Pick a single image from gallery
  Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 2560,
      );
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('Galeriden görsel seçilemedi: $e');
    }
  }

  /// Pick multiple images from gallery
  Future<List<File>> pickMultipleFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 2560,
      );
      return images.map((xfile) => File(xfile.path)).toList();
    } catch (e) {
      throw Exception('Galeriden görseller seçilemedi: $e');
    }
  }
}
