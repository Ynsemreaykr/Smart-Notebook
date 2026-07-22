import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/models/photo_note.dart';
import '../../../domain/models/flashcard.dart';
import '../../../application/providers/photo_note_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/wakelock_helper.dart';
import '../../../widgets/common/app_text.dart';
import '../../widgets/flip_card_widget.dart';
import 'photo_note_detail_text_screen.dart';

class PhotoNoteViewerScreen extends StatefulWidget {
  final String noteId;
  const PhotoNoteViewerScreen({super.key, required this.noteId});

  @override
  State<PhotoNoteViewerScreen> createState() => _PhotoNoteViewerScreenState();
}

class _PhotoNoteViewerScreenState extends State<PhotoNoteViewerScreen> {
  bool _showUI = true;
  bool _isZoomed = false;
  int _currentPage = 0;
  late PageController _pageController;
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _transformationController.addListener(_onTransformationChanged);
    WakelockHelper.enable();
  }

  @override
  void dispose() {
    WakelockHelper.disable();
    _transformationController.removeListener(_onTransformationChanged);
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomedNow = scale > 1.05;
    if (isZoomedNow != _isZoomed) {
      setState(() {
        _isZoomed = isZoomedNow;
      });
    }
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
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  Future<void> _shareImage(PhotoNote note) async {
    try {
      final currentImagePath = _currentPage < note.imagePaths.length
          ? note.imagePaths[_currentPage]
          : note.imagePath;
      await Share.shareXFiles(
        [XFile(currentImagePath)],
        text: '${note.title} (${note.category}) - Görsel ${_currentPage + 1}/${note.imagePaths.length}',
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

  Future<void> _pickAndAddExtraImage(PhotoNote note) async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.medium)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF14B8A6)),
              title: const AppText('Galeriden Ek Görseller Seç', styleType: AppTextStyleType.bodyMedium),
              onTap: () async {
                Navigator.pop(ctx);
                final List<XFile> images = await picker.pickMultiImage();
                if (images.isNotEmpty && mounted) {
                  final files = images.map((x) => File(x.path)).toList();
                  await context.read<PhotoNoteProvider>().addExtraImagesToNote(note.id, files);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${files.length} yeni görsel eklendi.'),
                        backgroundColor: const Color(0xFF14B8A6),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF14B8A6)),
              title: const AppText('Kamera ile Fotoğraf Çek', styleType: AppTextStyleType.bodyMedium),
              onTap: () async {
                Navigator.pop(ctx);
                final XFile? photo = await picker.pickImage(source: ImageSource.camera);
                if (photo != null && mounted) {
                  await context.read<PhotoNoteProvider>().addExtraImagesToNote(note.id, [File(photo.path)]);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Fotoğraf not kartına eklendi.'),
                        backgroundColor: Color(0xFF14B8A6),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNote(BuildContext context, PhotoNote note) {
    if (note.imagePaths.length > 1) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const AppText(
            'Görsel Sil',
            styleType: AppTextStyleType.headingMedium,
            styleOverride: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: AppText('Bu kartta ${note.imagePaths.length} adet görsel var. Ne yapmak istersiniz?', styleType: AppTextStyleType.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await context.read<PhotoNoteProvider>().removeImageFromNote(note.id, _currentPage);
                if (_currentPage > 0) {
                  setState(() {
                    _currentPage--;
                  });
                }
              },
              child: const AppText('Şu Anki Görseli Sil', styleType: AppTextStyleType.label, color: Colors.amber),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
                context.read<PhotoNoteProvider>().deletePhotoNote(note.id);
              },
              child: AppText('Tüm Notu Sil', styleType: AppTextStyleType.label, color: AppColors.error),
            ),
          ],
        ),
      );
    } else {
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
                Navigator.pop(ctx);
                Navigator.pop(context);
                context.read<PhotoNoteProvider>().deletePhotoNote(note.id);
              },
              child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
            ),
          ],
        ),
      );
    }
  }

  void _openNoteTextScreen(BuildContext context, PhotoNote note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoNoteDetailTextScreen(noteId: note.id),
      ),
    );
  }

  void _openFlashcardsSheet(BuildContext context, PhotoNote note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (ctx) {
        return Consumer<PhotoNoteProvider>(
          builder: (context, provider, child) {
            final noteFlashcards = provider.getFlashcardsForNote(note.id);

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    'Görsele Özel Bilgi Kartları (${noteFlashcards.length})',
                                    styleType: AppTextStyleType.headingMedium,
                                    styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  AppText(
                                    note.title,
                                    styleType: AppTextStyleType.caption,
                                    color: AppColors.textSecondary,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const AppText('Bu Görsele Yeni Bilgi Kartı Ekle', styleType: AppTextStyleType.label, color: Colors.white),
                    onPressed: () {
                      _showAddEditFlashcardDialogForNote(context, note);
                    },
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: noteFlashcards.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.style_rounded, size: 48, color: Color(0xFF14B8A6)),
                                const SizedBox(height: 12),
                                const AppText(
                                  'Henüz bu görsele özel bilgi kartı eklenmemiş.',
                                  styleType: AppTextStyleType.bodyMedium,
                                  styleOverride: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                AppText(
                                  'Örnek: Ön yüz: "Cebeci", Arka yüz: "Zırh ve silah temin eder" şeklinde kartlar ekleyebilirsiniz.',
                                  styleType: AppTextStyleType.caption,
                                  color: AppColors.textSecondary,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: noteFlashcards.length,
                            itemBuilder: (context, index) {
                              final card = noteFlashcards[index];
                              return FlipCardWidget(
                                flashcard: card,
                                onOptionsTap: () => _showNoteFlashcardOptions(context, card, note),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddEditFlashcardDialogForNote(BuildContext context, PhotoNote note, {Flashcard? card}) {
    final frontController = TextEditingController(text: card?.frontText ?? '');
    final backController = TextEditingController(text: card?.backText ?? '');
    bool isEdit = card != null;

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
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppText(
                      isEdit ? 'Bilgi Kartını Düzenle' : 'Görsele Özel Bilgi Kartı Ekle',
                      styleType: AppTextStyleType.headingMedium,
                      styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                AppSpacing.gapHMd,
                TextField(
                  controller: frontController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Ön Yüz (Kavram / Soru - Örn: Cebeci)',
                    prefixIcon: const Icon(Icons.style_rounded, color: Color(0xFF14B8A6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                  ),
                ),
                AppSpacing.gapHMd,
                TextField(
                  controller: backController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Arka Yüz (Açıklama / Anlamı - Örn: Zırh ve silah temin eder)',
                    prefixIcon: const Icon(Icons.info_outline_rounded, color: Color(0xFF14B8A6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                  ),
                ),
                AppSpacing.gapHLg,
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                  ),
                  onPressed: () async {
                    if (frontController.text.trim().isEmpty || backController.text.trim().isEmpty) {
                      return;
                    }
                    Navigator.pop(ctx);
                    if (isEdit) {
                      await context.read<PhotoNoteProvider>().updateFlashcard(
                        id: card!.id,
                        frontText: frontController.text,
                        backText: backController.text,
                      );
                    } else {
                      await context.read<PhotoNoteProvider>().addFlashcard(
                        frontText: frontController.text,
                        backText: backController.text,
                        category: note.category,
                        noteId: note.id,
                        color: note.color,
                      );
                    }
                  },
                  child: AppText(
                    isEdit ? 'Kaydet' : 'Bilgi Kartını Kaydet',
                    styleType: AppTextStyleType.label,
                    styleOverride: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
                AppSpacing.gapHMd,
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoteFlashcardOptions(BuildContext context, Flashcard card, PhotoNote note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.medium)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFF14B8A6)),
              title: const AppText('Kartı Düzenle', styleType: AppTextStyleType.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditFlashcardDialogForNote(context, note, card: card);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: AppText('Kartı Sil', styleType: AppTextStyleType.bodyMedium, color: AppColors.error),
              onTap: () {
                Navigator.pop(ctx);
                context.read<PhotoNoteProvider>().deleteFlashcard(card.id);
              },
            ),
          ],
        ),
      ),
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
        final totalImages = note.imagePaths.length;
        final noteFlashcards = provider.getFlashcardsForNote(note.id);

        if (_currentPage >= totalImages) {
          _currentPage = totalImages > 0 ? totalImages - 1 : 0;
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Main Swipeable Multi-Image Gallery PageView
              GestureDetector(
                onTap: _toggleUI,
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _handleDoubleTap,
                child: PageView.builder(
                  controller: _pageController,
                  physics: _isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: totalImages,
                  onPageChanged: (idx) {
                    setState(() {
                      _currentPage = idx;
                      _isZoomed = false;
                      _transformationController.value = Matrix4.identity();
                    });
                  },
                  itemBuilder: (context, index) {
                    final imgPath = note.imagePaths[index];
                    return Center(
                      child: Hero(
                        tag: index == 0 ? 'photonote_img_${note.id}' : 'photonote_img_${note.id}_$index',
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          clipBehavior: Clip.none,
                          panEnabled: true,
                          scaleEnabled: true,
                          minScale: 1.0,
                          maxScale: 6.0,
                          child: Image.file(
                            File(imgPath),
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
                    );
                  },
                ),
              ),

              // Top Overlay Bar (AppBar replacement)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                top: _showUI ? 0 : -140,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                              icon: const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 26),
                              tooltip: 'Ek Görsel Ekle',
                              onPressed: () => _pickAndAddExtraImage(note),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.style_rounded,
                                color: noteFlashcards.isNotEmpty ? const Color(0xFF14B8A6) : Colors.white,
                                size: 26,
                              ),
                              tooltip: 'Görsele Özel Bilgi Kartları',
                              onPressed: () => _openFlashcardsSheet(context, note),
                            ),
                            IconButton(
                              icon: Icon(
                                note.note.isNotEmpty ? Icons.edit_note_rounded : Icons.note_add_rounded,
                                color: note.note.isNotEmpty ? const Color(0xFF14B8A6) : Colors.white,
                                size: 28,
                              ),
                              tooltip: 'Görsel Notları',
                              onPressed: () => _openNoteTextScreen(context, note),
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
              ),

              // Bottom Info Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                bottom: _showUI ? 0 : -240,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
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
                      // Dots Indicator for Multi-Image Gallery
                      if (totalImages > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(totalImages, (index) {
                            final isSelected = _currentPage == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: isSelected ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF14B8A6) : Colors.white38,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        AppSpacing.gapHSm,
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (note.category.isNotEmpty)
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
                          if (totalImages > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B8A6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(AppRadius.small),
                                border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.5), width: 1),
                              ),
                              child: AppText(
                                '${_currentPage + 1} / $totalImages Görsel',
                                styleType: AppTextStyleType.caption,
                                styleOverride: const TextStyle(
                                  color: Color(0xFF14B8A6),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      AppSpacing.gapHSm,

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
                          onTap: () => _openNoteTextScreen(context, note),
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
