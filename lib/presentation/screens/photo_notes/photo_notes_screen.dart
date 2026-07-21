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

class PhotoNotesScreen extends StatefulWidget {
  const PhotoNotesScreen({super.key});

  @override
  State<PhotoNotesScreen> createState() => _PhotoNotesScreenState();
}

class _PhotoNotesScreenState extends State<PhotoNotesScreen> {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoNoteProvider>().loadPhotoNotes();
    });
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1E3A8A);
    }
  }

  void _showAddEditSheet({PhotoNote? note}) {
    final titleController = TextEditingController(text: note?.title ?? '');
    final categoryController = TextEditingController(text: note?.category ?? '');
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
            final uniqueCategories = activeProvider.photoNotes
                .map((n) => n.category.trim())
                .where((c) => c.isNotEmpty)
                .toSet()
                .toList();

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
                          isEdit ? 'Görsel Notu Düzenle' : 'Yeni Görsel Not',
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
                        labelText: 'Başlık (örn: Türkiye\'nin Ovaları)',
                        prefixIcon: const Icon(Icons.title_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Category
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Ders / Konu (örn: Coğrafya)',
                        prefixIcon: const Icon(Icons.bookmark_border_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                    ),
                    if (uniqueCategories.isNotEmpty) ...[
                      AppSpacing.gapHXs,
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: uniqueCategories.map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: categoryController.text == cat,
                                labelStyle: TextStyle(
                                  color: categoryController.text == cat ? Colors.white : AppColors.textPrimary,
                                  fontSize: 12,
                                ),
                                selectedColor: AppColors.primary,
                                onSelected: (selected) {
                                  if (selected) {
                                    setModalState(() {
                                      categoryController.text = cat;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    AppSpacing.gapHMd,

                    // Color Picker
                    const AppText(
                      'Kart Teması Rengi',
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
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)]
                                    : null,
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
                              content: Text('Lütfen notunuz için bir görsel seçin.'),
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
                            newImageFile: selectedImage!.path == note.imagePath ? null : selectedImage,
                          );
                        } else {
                          await activeProvider.addPhotoNote(
                            title: titleController.text,
                            imageFile: selectedImage!,
                            category: categoryController.text,
                            color: selectedColor,
                          );
                        }
                      },
                      child: AppText(
                        isEdit ? 'Güncellemeleri Kaydet' : 'Görsel Notu Oluştur',
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
                leading: const Icon(Icons.edit_rounded),
                title: const AppText('Düzenle', styleType: AppTextStyleType.bodyMedium),
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
          'Görsel Notu Sil',
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
          title: const AppText(
            'Görsel Notlarım',
            styleType: AppTextStyleType.headingLarge,
            styleOverride: TextStyle(fontWeight: FontWeight.bold),
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

            final notes = provider.filteredNotes;
            final allCategories = provider.categories;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Horizontal category filter tabs/pills
                if (allCategories.length > 1) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: allCategories.map((category) {
                          final isSelected = provider.selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: AppText(
                                category,
                                styleType: AppTextStyleType.bodySmall,
                                styleOverride: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface.withOpacity(0.6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.medium),
                                side: BorderSide(
                                  color: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.15),
                                ),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  provider.selectedCategory = category;
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                // Grid view of visual flashcards
                Expanded(
                  child: notes.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.add_photo_alternate_rounded,
                          title: 'Görsel Not Bulunmamaktadır',
                          subtitle: 'Sağ üst köşedeki veya aşağıdaki butonu kullanarak derslerinize ait görsel notları (haritalar, şemalar vb.) ekleyebilirsiniz.',
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double gridHeight = constraints.maxHeight;
                              const double crossAxisSpacing = 12.0;
                              const double mainAxisSpacing = 12.0;
                              const int crossAxisCount = 2;

                              // Calculate card aspect ratio so exactly 6 rows can fit on the screen without scrolling
                              // In 6 rows, there are 5 spacings in between.
                              final double itemHeight = (gridHeight - (mainAxisSpacing * 5)) / 6.0;
                              final double itemWidth = (constraints.maxWidth - crossAxisSpacing) / 2.0;

                              double childAspectRatio = itemWidth / itemHeight;
                              // Fallback if height calculations are negative/unreasonable
                              if (childAspectRatio <= 0 || childAspectRatio > 3.0) {
                                childAspectRatio = 0.72; // Standard beautiful ratio
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
                                                // Card overlay category badge
                                                if (note.category.isNotEmpty)
                                                  Positioned(
                                                    top: 8,
                                                    left: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.35),
                                                        borderRadius: BorderRadius.circular(AppRadius.small),
                                                        border: Border.all(color: Colors.white12, width: 0.5),
                                                      ),
                                                      child: AppText(
                                                        note.category,
                                                        styleType: AppTextStyleType.caption,
                                                        styleOverride: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),

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
                        ),
                ),
              ],
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
