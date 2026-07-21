import 'dart:io';

class OcrService {
  dynamic get textRecognizer {
    return null;
  }

  /// Extract text from an image file
  Future<String> extractTextFromImage(File imageFile) async {
    try {
      return 'Görselden metin okuma servisi şu anda aktif değil.';
    } catch (e) {
      throw Exception('OCR işlemi başarısız oldu: $e');
    }
  }

  /// Dispose the text recognizer
  void dispose() {}
}
