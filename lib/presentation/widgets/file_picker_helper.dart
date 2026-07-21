import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../application/providers/book_provider.dart';
import '../theme/app_theme.dart';

class FilePickerHelper {
  static void show({required BuildContext context}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return const _FilePickerSheet();
      },
    );
  }
}

class _FilePickerSheet extends StatefulWidget {
  const _FilePickerSheet();

  @override
  State<_FilePickerSheet> createState() => _FilePickerSheetState();
}

class _FilePickerSheetState extends State<_FilePickerSheet> {
  bool _isImporting = false;
  String _statusMessage = '';

  Future<void> _importPdfFromDevice() async {
    setState(() {
      _isImporting = true;
      _statusMessage = 'Dosya seçiliyor...';
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      final picked = result.files.first;
      final filePath = picked.path;

      if (filePath == null) {
        _showError('Hata', 'Dosya yolu alınamadı.');
        setState(() => _isImporting = false);
        return;
      }

      final file = File(filePath);
      String title = picked.name;
      if (title.toLowerCase().endsWith('.pdf')) {
        title = title.substring(0, title.length - 4);
      }

      setState(() => _statusMessage = 'PDF sayfaları işleniyor...');

      if (!mounted) return;
      final bookProvider = context.read<BookProvider>();
      await bookProvider.importPdf(file, title);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" başarıyla kitaplığa aktarıldı!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      _showError('PDF Aktarım Hatası', e.toString());
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _importImageFromGallery() async {
    setState(() {
      _isImporting = true;
      _statusMessage = 'Görsel seçiliyor...';
    });

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (picked == null) {
      setState(() => _isImporting = false);
      return;
    }

    try {
      final file = File(picked.path);
      String title = picked.name;
      if (title.contains('.')) {
        title = title.substring(0, title.lastIndexOf('.'));
      }

      setState(() => _statusMessage = 'Görsel aktarılıyor...');
      if (!mounted) return;
      final bookProvider = context.read<BookProvider>();
      await bookProvider.importImage(file, title);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" başarıyla içeri aktarıldı!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      _showError('Aktarım Hatası', e.toString());
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showError(String title, String message) {
    setState(() => _isImporting = false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: _isImporting
            ? SizedBox(
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.neonBlue),
                      const SizedBox(height: 20),
                      Text(
                        _statusMessage,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bu işlem PDF boyutuna göre biraz sürebilir...',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Dosya İçe Aktar',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cihazınızdan PDF veya görsel seçin — otomatik kitaplığa kaydedilir.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // PDF seç butonu
                  _ImportOptionTile(
                    icon: Icons.picture_as_pdf_rounded,
                    iconColor: const Color(0xFFFF6B6B),
                    bgColor: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                    title: 'PDF İçe Aktar',
                    subtitle: 'Cihaz hafızasından PDF dosyası seçin\nHer sayfa ayrı bir çizim sayfasına dönüşür',
                    onTap: _importPdfFromDevice,
                  ),

                  const SizedBox(height: 12),

                  // Görsel seç butonu
                  _ImportOptionTile(
                    icon: Icons.image_rounded,
                    iconColor: AppTheme.neonBlue,
                    bgColor: AppTheme.neonBlue.withValues(alpha: 0.12),
                    title: 'Görsel İçe Aktar',
                    subtitle: 'Galeri veya kameradan fotoğraf seçin\nÜzerine çizim ve not ekleyebilirsiniz',
                    onTap: _importImageFromGallery,
                  ),

                  const SizedBox(height: 20),

                  // Bilgi notu
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.neonAccent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.neonAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.neonAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'İçe aktarılan belgeler kitaplığınıza yeni bir kitap olarak kaydedilir. Üzerine kalemle çizim ve not ekleyebilirsiniz.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ImportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.textMuted.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
          ],
        ),
      ),
    );
  }
}
