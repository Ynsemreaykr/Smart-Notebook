import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/models/photo_note.dart';
import '../../../application/providers/photo_note_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../widgets/common/app_text.dart';
import '../../../widgets/common/app_container.dart';
import '../../../widgets/common/app_card.dart';

class PhotoNoteDetailTextScreen extends StatefulWidget {
  final String noteId;
  const PhotoNoteDetailTextScreen({super.key, required this.noteId});

  @override
  State<PhotoNoteDetailTextScreen> createState() => _PhotoNoteDetailTextScreenState();
}

class _PhotoNoteDetailTextScreenState extends State<PhotoNoteDetailTextScreen> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PhotoNoteProvider>();
    final noteIndex = provider.photoNotes.indexWhere((n) => n.id == widget.noteId);
    final initialNote = noteIndex != -1 ? provider.photoNotes[noteIndex].note : '';
    _textController = TextEditingController(text: initialNote);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1E3A8A);
    }
  }

  Future<void> _saveNote(PhotoNote note) async {
    // Unfocus keyboard if open
    FocusScope.of(context).unfocus();
    
    await context.read<PhotoNoteProvider>().updatePhotoNoteText(note.id, _textController.text);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ders notları başarıyla kaydedildi.'),
          backgroundColor: Color(0xFF14B8A6),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoNoteProvider>(
      builder: (context, provider, child) {
        final notes = provider.photoNotes;
        final noteIndex = notes.indexWhere((n) => n.id == widget.noteId);

        if (noteIndex == -1) {
          return AppContainer(
            hasGradient: true,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(title: const Text('Not Bulunamadı')),
              body: const Center(
                child: AppText('İlgili görsel not bulunamadı.', styleType: AppTextStyleType.bodyLarge),
              ),
            ),
          );
        }

        final note = notes[noteIndex];
        final cardColor = _parseColor(note.color);

        return AppContainer(
          hasGradient: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    note.title,
                    styleType: AppTextStyleType.headingMedium,
                    styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppText(
                    'Görsel Ders Notu • ${note.category.isEmpty ? 'Genel' : note.category}',
                    styleType: AppTextStyleType.caption,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.save_rounded, color: Color(0xFF14B8A6)),
                  tooltip: 'Notu Kaydet',
                  onPressed: () => _saveNote(note),
                ),
                AppSpacing.gapWSm,
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Visual Card Info Header (Shows which photo note card this belongs to)
                  AppCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(12.0),
                    borderColor: cardColor.withOpacity(0.4),
                    shadowColor: cardColor,
                    child: Row(
                      children: [
                        // Image Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.small),
                          child: Image.file(
                            File(note.imagePath),
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 52,
                              height: 52,
                              color: cardColor,
                              child: const Icon(Icons.image_not_supported_rounded, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title and info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.collections_bookmark_rounded, size: 16, color: Color(0xFF14B8A6)),
                                  const SizedBox(width: 4),
                                  AppText(
                                    note.category.isEmpty ? 'Genel' : note.category,
                                    styleType: AppTextStyleType.caption,
                                    styleOverride: const TextStyle(
                                      color: Color(0xFF14B8A6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              AppText(
                                note.title,
                                styleType: AppTextStyleType.bodyLarge,
                                styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              AppText(
                                'Bu görsel için ek ders notları ve açıklamalar',
                                styleType: AppTextStyleType.caption,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.gapHMd,

                  // Main Text Area Container
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: AppColors.surfaceLighter, width: 1.5),
                      ),
                      child: TextField(
                        controller: _textController,
                        autofocus: false, // DO NOT open keyboard automatically until tapped!
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                        decoration: InputDecoration(
                          hintText: 'Örn:\n• Bu haritadaki bafra ovası Karadeniz bölgesindedir.\n• Çarşamba ovası Yeşilırmak deltasında yer alır...\n\nNot almak için ekrana dokunabilirsiniz.',
                          hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.6), fontSize: 14, height: 1.5),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapHMd,

                  // Save Action Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                    ),
                    onPressed: () => _saveNote(note),
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
          ),
        );
      },
    );
  }
}
