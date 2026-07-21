import 'dart:io';
import 'package:share_plus/share_plus.dart';

class ShareService {
  /// Share a PDF file via system share sheet
  Future<void> sharePdfFile(File pdfFile, {String? subject}) async {
    try {
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: subject ?? 'PDF Dokümanı',
        text: 'Smart Notebook ile oluşturuldu',
      );
    } catch (e) {
      throw Exception('Dosya paylaşılamadı: $e');
    }
  }

  /// Share text content
  Future<void> shareText(String text, {String? subject}) async {
    try {
      await Share.share(
        text,
        subject: subject ?? 'Not Paylaşımı',
      );
    } catch (e) {
      throw Exception('Metin paylaşılamadı: $e');
    }
  }
}
