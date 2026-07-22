import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/models/photo_note.dart';
import '../../../application/providers/photo_note_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../widgets/common/app_text.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_container.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/fade_slide_entrance.dart';
import '../../widgets/empty_state_widget.dart';
import 'photo_note_viewer_screen.dart';
import 'photo_note_detail_text_screen.dart';

class PhotoNotesCategoryScreen extends StatefulWidget {
  final String category;
  const PhotoNotesCategoryScreen({super.key, required this.category});

  @override
  State<PhotoNotesCategoryScreen> createState() => _PhotoNotesCategoryScreenState();
}

class _PhotoNotesCategoryScreenState extends State<PhotoNotesCategoryScreen> {
  final ImagePicker _picker = ImagePicker();

  final List<String> _presetColors = [
    '#3B82F6', // Blue
    '#EF4444', // Red
    '#10B981', // Green
    '#F59E0B', // Amber
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#06B6D4', // Cyan
    '#6B7280', // Grey
  ];

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1E3A8A);
    }
  }

  void _showAddEditSheet({PhotoNote? note}) {
    final titleController = TextEditingController(text: note?.title ?? '');
    final categoryController = TextEditingController(text: note?.category ?? widget.category);
    final noteTextController = TextEditingController(text: note?.note ?? '');
    String selectedColor = note?.color ?? _presetColors.first;
    File? selectedImage = note != null ? File(note.imagePath) : null;
    bool isEdit = note != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeProvider = Provider.of<PhotoNoteProvider>(ctx, listen: false);

            Future<void> pickImage(ImageSource source) async {
              try {
                final XFile? picked = await _picker.pickImage(
                  source: source,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setModalState(() {
                    selectedImage = File(picked.path);
                  });
                }
              } catch (e) {
                debugPrint('Image pick error: $e');
              }
            }

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
                          isEdit ? 'Notu Düzenle' : 'Yeni Görsel Not Ekle',
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

                    // Image selector box
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppColors.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.medium)),
                          ),
                          builder: (subCtx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.photo_library_rounded),
                                  title: const AppText('Galeriden Seç', styleType: AppTextStyleType.bodyMedium),
                                  onTap: () {
                                    Navigator.pop(subCtx);
                                    pickImage(ImageSource.gallery);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt_rounded),
                                  title: const AppText('Kamera ile Çek', styleType: AppTextStyleType.bodyMedium),
                                  onTap: () {
                                    Navigator.pop(subCtx);
                                    pickImage(ImageSource.camera);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLighter,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: selectedImage != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.medium - 1),
                                    child: Image.file(
                                      selectedImage!,
                                      width: double.infinity,
                                      height: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.medium - 1),
                                      color: Colors.black38,
                                    ),
                                  ),
                                  const Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_rounded, color: Colors.white),
                                        SizedBox(width: 8),
                                        AppText(
                                          'Görseli Değiştir',
                                          styleType: AppTextStyleType.bodyMedium,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, size: 48, color: AppColors.primary),
                                  AppSpacing.gapHSm,
                                  const AppText(
                                    'Ders görselini veya haritasını ekleyin',
                                    styleType: AppTextStyleType.bodyMedium,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Title
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Başlık (örn: Ovalar Haritası)',
                        prefixIcon: const Icon(Icons.title_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Category (Read-only or prefilled)
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Ders / Bölüm',
                        prefixIcon: const Icon(Icons.bookmark_border_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Written Note (Optional)
                    TextField(
                      controller: noteTextController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        labelText: 'Ders Notu / Açıklama (İsteğe bağlı)',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Color Picker
                    const AppText(
                      'Kart Rengi',
                      styleType: AppTextStyleType.bodySmall,
                      styleOverride: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    AppSpacing.gapHSm,
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _presetColors.length,
                        itemBuilder: (context, index) {
                          final colorHex = _presetColors[index];
                          final color = _parseColor(colorHex);
                          final isSelected = selectedColor == colorHex;

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedColor = colorHex;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    AppSpacing.gapHLg,

                    // Save Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                      onPressed: () async {
                        if (selectedImage == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen bir görsel seçin.'),
                              backgroundColor: Colors.amber,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        if (isEdit) {
                          await activeProvider.updatePhotoNote(
                            id: note!.id,
                            title: titleController.text,
                            category: categoryController.text,
                            color: selectedColor,
                            note: noteTextController.text,
                            newImageFile: selectedImage!.path == note.imagePath ? null : selectedImage,
                          );
                        } else {
                          await activeProvider.addPhotoNote(
                            title: titleController.text,
                            imageFile: selectedImage!,
                            category: categoryController.text,
                            color: selectedColor,
                            note: noteTextController.text,
                          );
                        }
                      },
                      child: AppText(
                        isEdit ? 'Güncellemeleri Kaydet' : 'Notu Kaydet',
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
      },
    );
  }

  void _showOptionsDialog(PhotoNote note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.medium)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF14B8A6)),
                title: const AppText('Ders Notu Yaz / Oku', styleType: AppTextStyleType.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoNoteDetailTextScreen(noteId: note.id),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const AppText('Kart Bilgilerini Düzenle', styleType: AppTextStyleType.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddEditSheet(note: note);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: AppText('Sil', styleType: AppTextStyleType.bodyMedium, color: AppColors.error),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(note);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(PhotoNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Sil',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: AppText('"${note.title}" ders notu silinecektir. Bu işlem geri alınamaz.', styleType: AppTextStyleType.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PhotoNoteProvider>().deletePhotoNote(note.id);
            },
            child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppContainer(
      hasGradient: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: AppText(
            widget.category.isEmpty ? 'Genel Notlar' : widget.category,
            styleType: AppTextStyleType.headingLarge,
            styleOverride: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_rounded),
              tooltip: 'Yeni Not Ekle',
              onPressed: () => _showAddEditSheet(),
            ),
            AppSpacing.gapWSm,
          ],
        ),
        body: Consumer<PhotoNoteProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // Filter notes for the active category
            final notes = provider.photoNotes.where((note) {
              if (widget.category == 'Tümü') return true;
              return note.category.trim() == widget.category.trim();
            }).toList();

            return notes.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.add_photo_alternate_rounded,
                    title: 'Görsel Not Bulunmamaktadır',
                    subtitle: '"${widget.category}" bölümüne ait ders görseli veya harita bulunmuyor. Yeni bir not eklemek için sağ üstteki butonu kullanabilirsiniz.',
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double gridHeight = constraints.maxHeight;
                        const double crossAxisSpacing = 12.0;
                        const double mainAxisSpacing = 12.0;
                        const int crossAxisCount = 2;

                        // Calculate aspect ratio so exactly 6 rows can fit
                        final double itemHeight = (gridHeight - (mainAxisSpacing * 5)) / 6.0;
                        final double itemWidth = (constraints.maxWidth - crossAxisSpacing) / 2.0;

                        double childAspectRatio = itemWidth / itemHeight;
                        if (childAspectRatio <= 0 || childAspectRatio > 3.0) {
                          childAspectRatio = 0.72;
                        }

                        return GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: notes.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: crossAxisSpacing,
                            mainAxisSpacing: mainAxisSpacing,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            final cardThemeColor = _parseColor(note.color);

                            return FadeSlideEntrance(
                              delay: Duration(milliseconds: 50 * index),
                              child: BounceButton(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PhotoNoteViewerScreen(noteId: note.id),
                                    ),
                                  );
                                },
                                child: Hero(
                                  tag: 'photonote_img_${note.id}',
                                  child: AppCard(
                                    margin: EdgeInsets.zero,
                                    padding: EdgeInsets.zero,
                                    borderColor: cardThemeColor.withOpacity(0.3),
                                    shadowColor: cardThemeColor,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AppRadius.medium - 1),
                                        gradient: LinearGradient(
                                          colors: [
                                            cardThemeColor.withOpacity(0.95),
                                            cardThemeColor.withOpacity(0.70),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Actions dropdown button on the top-right
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: IconButton(
                                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                                                onPressed: () => _showOptionsDialog(note),
                                                constraints: const BoxConstraints(),
                                                padding: const EdgeInsets.all(6),
                                              ),
                                            ),
                                          ),

                                          // Title centered in the card
                                          Center(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 24.0),
                                              child: AppText(
                                                note.title,
                                                styleType: AppTextStyleType.bodyMedium,
                                                styleOverride: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  height: 1.3,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 4,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => _showAddEditSheet(),
          child: const Icon(Icons.add_photo_alternate_rounded),
        ),
      ),
    );
  }
}
