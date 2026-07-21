import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/services/ocr_service.dart';

class OcrProvider extends ChangeNotifier {
  final OcrService _ocrService = OcrService();

  String _extractedText = '';
  bool _isProcessing = false;
  String? _error;

  String get extractedText => _extractedText;
  bool get isProcessing => _isProcessing;
  String? get error => _error;

  /// Extract text from an image file
  Future<void> extractText(File imageFile) async {
    try {
      _isProcessing = true;
      _error = null;
      _extractedText = '';
      notifyListeners();

      _extractedText = await _ocrService.extractTextFromImage(imageFile);

      if (_extractedText.isEmpty) {
        _error = 'Görselde metin bulunamadı.';
      }

      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _isProcessing = false;
      _error = 'OCR işlemi başarısız: $e';
      _extractedText = '';
      notifyListeners();
    }
  }

  /// Clear the extracted text
  void clearText() {
    _extractedText = '';
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }
}
