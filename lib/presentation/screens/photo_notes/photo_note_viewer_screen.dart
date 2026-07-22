import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../../domain/models/photo_note.dart';
import '../../../application/providers/photo_note_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../widgets/common/app_text.dart';

class PhotoNoteViewerScreen extends StatefulWidget {
  final String noteId;
  const PhotoNoteViewerScreen({super.key, required this.noteId});

  @override
  State<PhotoNoteViewerScreen> createState() => _PhotoNoteViewerScreenState();
}

class _PhotoNoteViewerScreenState extends State<PhotoNoteViewerScreen> {
  bool _showUI = true;
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1E3A8A);
    }
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails!.localPosition;
      // Zoom in to 2.5x at double tapped position
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  Future<void> _shareImage(PhotoNote note) async {
    try {
      await Share.shareXFiles(
        [XFile(note.imagePath)],
        text: '${note.title} (${note.category})',
        subject: note.title,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paylaşım hatası: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _deleteNote(BuildContext context, PhotoNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Notu Sil',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: AppText('"${note.title}" silinecek. Emin misiniz?', styleType: AppTextStyleType.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close viewer
              context.read<PhotoNoteProvider>().deletePhotoNote(note.id);
            },
            child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  void _showNoteSheet(BuildContext context, PhotoNote note) {
    final noteController = TextEditingController(text: note.note);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: Color(0xFF14B8A6), size: 28),
                        const SizedBox(width: 8),
                        AppText(
                          'Görsel Notları',
                          styleType: AppTextStyleType.headingMedium,
                          styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                AppText(
                  '${note.title} için ek bilgileri ve ders notlarını buraya alabilirsiniz.',
                  styleType: AppTextStyleType.caption,
                  color: AppColors.textSecondary,
                ),
                AppSpacing.gapHMd,

                TextField(
                  controller: noteController,
                  maxLines: 8,
                  minLines: 4,
                  autofocus: note.note.isEmpty,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Örn: Bu haritadaki ovalar 3 bölgeye ayrılır. 1- Bafra Ovası (Samsun), 2- Çarşamba Ovası...',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surfaceLighter,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                AppSpacing.gapHLg,

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await context.read<PhotoNoteProvider>().updatePhotoNoteText(note.id, noteController.text);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Not başarıyla kaydedildi.'),
                          backgroundColor: Color(0xFF14B8A6),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const AppText(
                    'Notu Kaydet',
                    styleType: AppTextStyleType.label,
                    styleOverride: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoNoteProvider>(
      builder: (context, provider, child) {
        final notes = provider.photoNotes;
        final noteIndex = notes.indexWhere((n) => n.id == widget.noteId);
        
        if (noteIndex == -1) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: AppText('Not bulunamadı.', styleType: AppTextStyleType.bodyLarge)),
          );
        }

        final note = notes[noteIndex];
        final cardColor = _parseColor(note.color);
        final formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(note.updatedAt);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Main Interactive Image Viewer
              GestureDetector(
                onTap: _toggleUI,
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _handleDoubleTap,
                child: Center(
                  child: Hero(
                    tag: 'photonote_img_${note.id}',
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 1.0,
                      maxScale: 6.0,
                      child: Image.file(
                        File(note.imagePath),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_rounded, size: 64, color: AppColors.textMuted),
                                AppSpacing.gapHMd,
                                const AppText('Görsel yüklenemedi', styleType: AppTextStyleType.headingSmall, color: Colors.white),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // Top Overlay Bar (AppBar replacement)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                top: _showUI ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  padding: const EdgeInsets.only(top: 40, left: 8, right: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              note.note.isNotEmpty ? Icons.edit_note_rounded : Icons.note_add_rounded,
                              color: note.note.isNotEmpty ? const Color(0xFF14B8A6) : Colors.white,
                              size: 26,
                            ),
                            tooltip: 'Görsel Notları',
                            onPressed: () => _showNoteSheet(context, note),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share_rounded, color: Colors.white),
                            tooltip: 'Paylaş',
                            onPressed: () => _shareImage(note),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            tooltip: 'Sil',
                            onPressed: () => _deleteNote(context, note),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Info Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                bottom: _showUI ? 0 : -220,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.95)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (note.category.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(AppRadius.small),
                            border: Border.all(color: cardColor.withOpacity(0.6), width: 1),
                          ),
                          child: AppText(
                            note.category,
                            styleType: AppTextStyleType.caption,
                            styleOverride: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        AppSpacing.gapHSm,
                      ],
                      AppText(
                        note.title,
                        styleType: AppTextStyleType.headingLarge,
                        styleOverride: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AppSpacing.gapHXs,
                      AppText(
                        'Son Güncelleme: $formattedDate',
                        styleType: AppTextStyleType.bodySmall,
                        color: Colors.white70,
                      ),
                      if (note.note.isNotEmpty) ...[
                        AppSpacing.gapHSm,
                        GestureDetector(
                          onTap: () => _showNoteSheet(context, note),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14B8A6).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                              border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.4), width: 1),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.sticky_note_2_rounded, color: Color(0xFF14B8A6), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppText(
                                    note.note,
                                    styleType: AppTextStyleType.bodySmall,
                                    color: Colors.white,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
