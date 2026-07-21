import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/models/page.dart';
import '../../data/services/pdf_service.dart';
import '../../data/services/share_service.dart';

class PdfProvider extends ChangeNotifier {
  final PdfService _pdfService = PdfService();
  final ShareService _shareService = ShareService();

  bool _isGenerating = false;
  bool _isSharing = false;
  String? _error;
  File? _lastGeneratedPdf;
  bool _isCancelled = false;

  bool get isGenerating => _isGenerating;
  bool get isSharing => _isSharing;
  String? get error => _error;
  File? get lastGeneratedPdf => _lastGeneratedPdf;
  bool get isCancelled => _isCancelled;

  void cancelPdfGeneration() {
    _isCancelled = true;
    _isGenerating = false;
    notifyListeners();
  }

  /// Generate PDF from full book
  Future<File?> generateBookPdf(
    String bookTitle,
    List<NotePage> pages,
  ) async {
    if (pages.isEmpty) {
      _error = 'Kitapta sayfa bulunmuyor.';
      notifyListeners();
      return null;
    }

    try {
      _isGenerating = true;
      _isCancelled = false;
      _error = null;
      notifyListeners();

      _lastGeneratedPdf = await _pdfService.generatePdfFromBook(
        bookTitle,
        pages,
        isCancelled: () => _isCancelled,
      );

      if (_isCancelled) {
        _isGenerating = false;
        notifyListeners();
        return null;
      }

      _isGenerating = false;
      notifyListeners();
      return _lastGeneratedPdf;
    } catch (e) {
      _isGenerating = false;
      if (e.toString().contains('Cancelled')) {
        _error = 'PDF oluşturma iptal edildi.';
      } else {
        _error = 'PDF oluşturulamadı: $e';
      }
      notifyListeners();
      return null;
    }
  }

  /// Generate PDF from selected pages
  Future<File?> generateSelectedPagesPdf(
    String bookTitle,
    List<NotePage> selectedPages,
  ) async {
    if (selectedPages.isEmpty) {
      _error = 'Lütfen en az bir sayfa seçin.';
      notifyListeners();
      return null;
    }

    try {
      _isGenerating = true;
      _isCancelled = false;
      _error = null;
      notifyListeners();

      _lastGeneratedPdf = await _pdfService.generatePdfFromSelectedPages(
        bookTitle,
        selectedPages,
        isCancelled: () => _isCancelled,
      );

      if (_isCancelled) {
        _isGenerating = false;
        notifyListeners();
        return null;
      }

      _isGenerating = false;
      notifyListeners();
      return _lastGeneratedPdf;
    } catch (e) {
      _isGenerating = false;
      if (e.toString().contains('Cancelled')) {
        _error = 'PDF oluşturma iptal edildi.';
      } else {
        _error = 'PDF oluşturulamadı: $e';
      }
      notifyListeners();
      return null;
    }
  }

  /// Share the last generated PDF
  Future<void> sharePdf({String? subject}) async {
    if (_lastGeneratedPdf == null) {
      _error = 'Paylaşılacak PDF bulunamadı.';
      notifyListeners();
      return;
    }

    try {
      _isSharing = true;
      _error = null;
      notifyListeners();

      await _shareService.sharePdfFile(_lastGeneratedPdf!, subject: subject);

      _isSharing = false;
      notifyListeners();
    } catch (e) {
      _isSharing = false;
      _error = 'Paylaşım başarısız: $e';
      notifyListeners();
    }
  }

  /// Share a specific PDF file
  Future<void> sharePdfFile(File pdfFile, {String? subject}) async {
    try {
      _isSharing = true;
      _error = null;
      notifyListeners();

      await _shareService.sharePdfFile(pdfFile, subject: subject);

      _isSharing = false;
      notifyListeners();
    } catch (e) {
      _isSharing = false;
      _error = 'Paylaşım başarısız: $e';
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
