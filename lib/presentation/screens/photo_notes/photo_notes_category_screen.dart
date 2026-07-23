import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/models/photo_note.dart';
import '../../../domain/models/flashcard.dart';
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
import '../../widgets/flip_card_widget.dart';
import '../../widgets/single_tap_cursor_textfield.dart';
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
  late ScrollController _categoryScrollController;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _categoryScrollController = ScrollController();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _categoryScrollController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final dy = details.globalPosition.dy;
    final screenHeight = MediaQuery.of(context).size.height;
    final topEdge = 160.0;
    final bottomEdge = screenHeight - 160.0;

    if (dy < topEdge) {
      final ratio = ((topEdge - dy) / topEdge).clamp(0.1, 1.0);
      _startAutoScroll(-16.0 * ratio, _categoryScrollController);
    } else if (dy > bottomEdge) {
      final ratio = ((dy - bottomEdge) / 160.0).clamp(0.1, 1.0);
      _startAutoScroll(16.0 * ratio, _categoryScrollController);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(double step, ScrollController controller) {
    if (_autoScrollTimer?.isActive ?? false) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 25), (_) {
      if (!controller.hasClients) {
        _stopAutoScroll();
        return;
      }
      final newOffset = (controller.offset + step).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      controller.jumpTo(newOffset);
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

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
                          isEdit ? 'Ders Notunu Düzenle' : 'Yeni Görsel Not Ekle',
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

                    // Image Picker Box
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: ctx,
                          backgroundColor: AppColors.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.medium)),
                          ),
                          builder: (c) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF14B8A6)),
                                  title: const AppText('Galeriden Seç', styleType: AppTextStyleType.bodyMedium),
                                  onTap: () {
                                    Navigator.pop(c);
                                    pickImage(ImageSource.gallery);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF14B8A6)),
                                  title: const AppText('Fotoğraf Çek', styleType: AppTextStyleType.bodyMedium),
                                  onTap: () {
                                    Navigator.pop(c);
                                    pickImage(ImageSource.camera);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLighter.withOpacity(0.5),
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

                    // Title Input
                    SingleTapCursorTextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Not Başlığı (örn: Türkiye Ovaları Haritası)',
                        prefixIcon: const Icon(Icons.title_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Category Path Info Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_special_rounded, color: Color(0xFF14B8A6), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const AppText('Notun Kaydedileceği Bölüm / Ünite:', styleType: AppTextStyleType.caption, color: Colors.white70),
                                AppText(
                                  categoryController.text.isEmpty ? 'Genel' : categoryController.text,
                                  styleType: AppTextStyleType.bodyMedium,
                                  styleOverride: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Written Note (Optional)
                    SingleTapCursorTextField(
                      controller: noteTextController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Ek Ders Notları / Açıklama (İsteğe Bağlı)',
                        prefixIcon: const Icon(Icons.note_alt_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Color Theme Selector
                    const AppText('Kart Tema Rengi:', styleType: AppTextStyleType.label),
                    AppSpacing.gapHSm,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _presetColors.map((hex) {
                        final color = _parseColor(hex);
                        final isSelected = selectedColor == hex;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedColor = hex;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    AppSpacing.gapHLg,

                    // Save Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                            newImageFile: selectedImage!.path != note.imagePath ? selectedImage : null,
                            category: categoryController.text,
                            color: selectedColor,
                            note: noteTextController.text,
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
                        isEdit ? 'Değişiklikleri Kaydet' : 'Notu Kaydet',
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

  void _showAddEditFlashcardSheet({Flashcard? card, String? defaultGroup}) {
    final frontController = TextEditingController(text: card?.frontText ?? '');
    final backController = TextEditingController(text: card?.backText ?? '');
    final groupController = TextEditingController(text: card?.groupTitle ?? defaultGroup ?? 'Genel Bilgiler');
    String selectedColor = card?.color ?? _presetColors.first;
    bool isEdit = card != null;

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
                          isEdit ? 'Bilgi Kartını Düzenle' : 'Yeni Bilgi Kartı Ekle',
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

                    // Heading Group Input
                    SingleTapCursorTextField(
                      controller: groupController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Kart Başlığı / Konu Grubu (Örn: Askeri Teşkilat)',
                        prefixIcon: const Icon(Icons.topic_rounded, color: Color(0xFF14B8A6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Front Text Input
                    SingleTapCursorTextField(
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

                    // Back Text Input
                    SingleTapCursorTextField(
                      controller: backController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Arka Yüz (Açıklama / Anlamı - Örn: Zırh ve silah temin eder)',
                        prefixIcon: const Icon(Icons.info_outline_rounded, color: Color(0xFF14B8A6)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Color Selector
                    const AppText('Kart Tema Rengi:', styleType: AppTextStyleType.label),
                    AppSpacing.gapHSm,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _presetColors.map((hex) {
                        final color = _parseColor(hex);
                        final isSelected = selectedColor == hex;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedColor = hex;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8, spreadRadius: 2)] : null,
                            ),
                            child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    AppSpacing.gapHLg,

                    // Save Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                      onPressed: () async {
                        if (frontController.text.trim().isEmpty || backController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen ön yüz ve arka yüz bilgilerini doldurun.'),
                              backgroundColor: Colors.amber,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        final grp = groupController.text.trim().isEmpty ? 'Genel Bilgiler' : groupController.text.trim();

                        if (isEdit) {
                          await activeProvider.updateFlashcard(
                            id: card!.id,
                            frontText: frontController.text,
                            backText: backController.text,
                            groupTitle: grp,
                            color: selectedColor,
                          );
                        } else {
                          await activeProvider.addFlashcard(
                            frontText: frontController.text,
                            backText: backController.text,
                            category: widget.category,
                            groupTitle: grp,
                            color: selectedColor,
                          );
                        }
                      },
                      child: AppText(
                        isEdit ? 'Değişiklikleri Kaydet' : 'Bilgi Kartını Kaydet',
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

  void _showAddNewHeadingDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Yeni Kart Başlığı / Konu Grubu Ekle',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Başlık Adı (Örn: Askeri Teşkilat)',
            prefixIcon: Icon(Icons.topic_rounded, color: Color(0xFF14B8A6)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              final title = controller.text.trim();
              Navigator.pop(ctx);
              if (title.isNotEmpty) {
                _showAddEditFlashcardSheet(defaultGroup: title);
              }
            },
            child: AppText('Oluştur ve Kart Ekle', styleType: AppTextStyleType.label, color: const Color(0xFF14B8A6)),
          ),
        ],
      ),
    );
  }

  void _showRenameHeadingDialog(String oldTitle) {
    final controller = TextEditingController(text: oldTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Başlığı Yeniden Adlandır',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Yeni Başlık Adı',
            prefixIcon: Icon(Icons.edit_rounded, color: Color(0xFF14B8A6)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              Navigator.pop(ctx);
              if (newTitle.isNotEmpty && newTitle != oldTitle) {
                context.read<PhotoNoteProvider>().renameFlashcardGroup(
                  oldGroupTitle: oldTitle,
                  newGroupTitle: newTitle,
                  category: widget.category,
                );
              }
            },
            child: AppText('Kaydet', styleType: AppTextStyleType.label, color: const Color(0xFF14B8A6)),
          ),
        ],
      ),
    );
  }

  void _showAddSubCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Yeni Ünite / Alt Klasör Ekle',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText('Ana Klasör: ${widget.category}', styleType: AppTextStyleType.caption, color: const Color(0xFF14B8A6)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ünite / Alt Klasör Adı (örn: 1. Ünite)',
                prefixIcon: Icon(Icons.create_new_folder_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<PhotoNoteProvider>().addSubCategory(widget.category, name);
              }
              Navigator.pop(ctx);
            },
            child: AppText('Ekle', styleType: AppTextStyleType.label, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _showRenameSubCategoryDialog(String subName) {
    final oldFullPath = '${widget.category} / $subName';
    final controller = TextEditingController(text: subName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Üniteyi Düzenle',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Yeni Ünite Adı',
            prefixIcon: Icon(Icons.folder_open_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              final newSubName = controller.text.trim();
              if (newSubName.isNotEmpty && newSubName != subName) {
                final newFullPath = '${widget.category} / $newSubName';
                context.read<PhotoNoteProvider>().renameCategory(oldFullPath, newFullPath);
              }
              Navigator.pop(ctx);
            },
            child: AppText('Kaydet', styleType: AppTextStyleType.label, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubCategory(String subName) {
    final fullPath = '${widget.category} / $subName';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Üniteyi Sil',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: AppText('"$subName" ünitesi ve içindeki tüm görsel notlar silinecektir. Emin misiniz?', styleType: AppTextStyleType.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PhotoNoteProvider>().deleteCategory(fullPath);
            },
            child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  void _showSubCategoryOptions(String subName) {
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
              leading: const Icon(Icons.edit_rounded),
              title: const AppText('Üniteyi Düzenle (Yeniden Adlandır)', styleType: AppTextStyleType.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameSubCategoryDialog(subName);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: AppText('Üniteyi Sil', styleType: AppTextStyleType.bodyMedium, color: AppColors.error),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteSubCategory(subName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFlashcardOptions(Flashcard card) {
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
              title: const AppText('Bilgi Kartını Düzenle', styleType: AppTextStyleType.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditFlashcardSheet(card: card);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: AppText('Bilgi Kartını Sil', styleType: AppTextStyleType.bodyMedium, color: AppColors.error),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteFlashcard(card);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFlashcard(Flashcard card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Bilgi Kartını Sil',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: AppText('"${card.frontText}" bilgi kartı silinecektir. Emin misiniz?', styleType: AppTextStyleType.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PhotoNoteProvider>().deleteFlashcard(card.id);
            },
            child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
          ),
        ],
      ),
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
                leading: const Icon(Icons.sticky_note_2_rounded, color: Color(0xFF14B8A6)),
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
                title: const AppText('Notu Düzenle', styleType: AppTextStyleType.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddEditSheet(note: note);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: AppText('Notu Sil', styleType: AppTextStyleType.bodyMedium, color: AppColors.error),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteNote(note);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteNote(PhotoNote note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Notu Sil',
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

  void _showAddMenu() {
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
              leading: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF14B8A6)),
              title: const AppText('Yeni Görsel Not Kartı Ekle', styleType: AppTextStyleType.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.style_rounded, color: Color(0xFF14B8A6)),
              title: const AppText('Yeni Bilgi Kartı (Flaş Kart) Ekle', styleType: AppTextStyleType.bodyMedium),
              subtitle: const AppText('Ön yüz: Kavram / Soru • Arka yüz: Anlamı / Cevap', styleType: AppTextStyleType.caption),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditFlashcardSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded, color: Color(0xFF14B8A6)),
              title: const AppText('Yeni Kart Başlığı / Konu Grubu Ekle', styleType: AppTextStyleType.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _showAddNewHeadingDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_rounded, color: Color(0xFF14B8A6)),
              title: const AppText('Yeni Ünite / Alt Klasör Ekle', styleType: AppTextStyleType.bodyMedium),
              onTap: () {
                Navigator.pop(ctx);
                _showAddSubCategoryDialog();
              },
            ),
          ],
        ),
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
              icon: const Icon(Icons.style_rounded),
              tooltip: 'Yeni Bilgi Kartı Ekle',
              onPressed: () => _showAddEditFlashcardSheet(),
            ),
            IconButton(
              icon: const Icon(Icons.create_new_folder_rounded),
              tooltip: 'Yeni Ünite / Alt Klasör Ekle',
              onPressed: _showAddSubCategoryDialog,
            ),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_rounded),
              tooltip: 'Yeni Görsel Not Ekle',
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

            final subCategories = provider.getSubCategories(widget.category);
            final notes = provider.photoNotes.where((note) {
              return note.category.trim() == widget.category.trim();
            }).toList();

            final groupedFlashcards = provider.getGroupedFlashcardsForCategory(widget.category);
            final totalFlashcards = provider.getFlashcardsForCategory(widget.category).length;

            if (subCategories.isEmpty && notes.isEmpty && totalFlashcards == 0) {
              return EmptyStateWidget(
                icon: Icons.folder_open_rounded,
                title: 'Henüz İçerik Bulunmuyor',
                subtitle: '"${widget.category}" içinde henüz ünite, görsel not veya bilgi kartı yok. Aşağıdaki butonla ekleme yapabilirsiniz.',
              );
            }

            return CustomScrollView(
              controller: _categoryScrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Sub-Categories / Units Section (If any exist)
                if (subCategories.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppText(
                            'Üniteler (${subCategories.length})',
                            styleType: AppTextStyleType.headingSmall,
                            styleOverride: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF14B8A6)),
                            label: const AppText('Ünite Ekle', styleType: AppTextStyleType.caption, color: Color(0xFF14B8A6)),
                            onPressed: _showAddSubCategoryDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 84,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: subCategories.length,
                        itemBuilder: (context, index) {
                          final subName = subCategories[index];
                          final fullPath = '${widget.category} / $subName';
                          final noteCount = provider.getNoteCountForCategory(fullPath, includeSubCategories: true);

                          return Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: BounceButton(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PhotoNotesCategoryScreen(category: fullPath),
                                  ),
                                );
                              },
                              child: AppCard(
                                margin: EdgeInsets.zero,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                borderColor: const Color(0xFF14B8A6).withOpacity(0.4),
                                shadowColor: const Color(0xFF14B8A6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF14B8A6).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(AppRadius.medium),
                                      ),
                                      child: const Icon(Icons.bookmark_rounded, color: Color(0xFF14B8A6), size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AppText(
                                          subName,
                                          styleType: AppTextStyleType.bodyMedium,
                                          styleOverride: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        AppText(
                                          '$noteCount Not',
                                          styleType: AppTextStyleType.caption,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 6),
                                    Material(
                                      color: Colors.transparent,
                                      child: IconButton(
                                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 18),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        onPressed: () => _showSubCategoryOptions(subName),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // 2. Section Header for Photo Notes
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                          'Görsel Not Kartları (${notes.length})',
                          styleType: AppTextStyleType.headingSmall,
                          styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (notes.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white70),
                            label: const AppText('Görsel Ekle', styleType: AppTextStyleType.caption, color: Colors.white70),
                            onPressed: () => _showAddEditSheet(),
                          ),
                      ],
                    ),
                  ),
                ),

                // Grid of Photo Note Cards
                if (notes.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLighter.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Center(
                          child: AppText(
                            'Bu bölümde henüz doğrudan görsel kartı bulunmuyor.',
                            styleType: AppTextStyleType.bodyMedium,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12.0,
                        mainAxisSpacing: 12.0,
                        childAspectRatio: 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = notes[index];
                          final cardThemeColor = _parseColor(note.color);

                          return FadeSlideEntrance(
                            delay: Duration(milliseconds: 40 * index),
                            child: DragTarget<int>(
                              onWillAcceptWithDetails: (details) => details.data != index,
                              onAcceptWithDetails: (details) {
                                final oldIndex = details.data;
                                final newIndex = index;
                                provider.reorderCategoryNotes(notes, oldIndex, newIndex);
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isHovered = candidateData.isNotEmpty;
                                return LongPressDraggable<int>(
                                  data: index,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    elevation: 8.0,
                                    child: SizedBox(
                                      width: 160,
                                      height: 180,
                                      child: Transform.scale(
                                        scale: 1.05,
                                        child: Opacity(
                                          opacity: 0.9,
                                          child: _buildCardWidget(note, cardThemeColor),
                                        ),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.35,
                                    child: _buildCardWidget(note, cardThemeColor),
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.medium),
                                      border: isHovered
                                          ? Border.all(color: const Color(0xFF14B8A6), width: 3.0)
                                          : null,
                                    ),
                                    child: _buildCardWidget(note, cardThemeColor),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        childCount: notes.length,
                      ),
                    ),
                  ),

                // 3. Grouped Flashcards Section (Bilgi Kartları Grupları)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 24),
                            const SizedBox(width: 8),
                            AppText(
                              'Bilgi Kartları ($totalFlashcards)',
                              styleType: AppTextStyleType.headingSmall,
                              styleOverride: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF14B8A6)),
                          label: const AppText('Kart Ekle', styleType: AppTextStyleType.caption, color: Color(0xFF14B8A6)),
                          onPressed: () => _showAddEditFlashcardSheet(),
                        ),
                      ],
                    ),
                  ),
                ),

                if (groupedFlashcards.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.2), width: 1),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 32),
                            const SizedBox(height: 6),
                            const AppText(
                              'Henüz bilgi kartı eklenmemiş.',
                              styleType: AppTextStyleType.bodyMedium,
                              styleOverride: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            AppText(
                              'Örnek: Ön yüzde "Cebeci", arka yüzde "Zırh ve silah temin eder" şeklinde kartlar oluşturup "Askeri Teşkilat" gibi başlıklar altında gruplayabilirsiniz.',
                              styleType: AppTextStyleType.caption,
                              color: AppColors.textSecondary,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...groupedFlashcards.entries.expand((entry) {
                    final groupTitle = entry.key;
                    final cards = entry.value;

                    return [
                      // Heading Banner Header (Acts as DragTarget to receive dropped flashcards)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: DragTarget<Flashcard>(
                            onWillAcceptWithDetails: (details) => details.data.groupTitle.trim() != groupTitle.trim(),
                            onAcceptWithDetails: (details) async {
                              final movedCard = details.data;
                              await context.read<PhotoNoteProvider>().moveFlashcardToGroup(
                                    flashcardId: movedCard.id,
                                    targetGroupTitle: groupTitle,
                                  );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Kart "$groupTitle" başlığına taşındı'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: const Color(0xFF14B8A6),
                                  ),
                                );
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              final isHovering = candidateData.isNotEmpty;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isHovering
                                      ? const Color(0xFF14B8A6).withOpacity(0.35)
                                      : const Color(0xFF14B8A6).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.medium),
                                  border: Border.all(
                                    color: isHovering
                                        ? const Color(0xFF14B8A6)
                                        : const Color(0xFF14B8A6).withOpacity(0.35),
                                    width: isHovering ? 2.5 : 1,
                                  ),
                                  boxShadow: isHovering
                                      ? [BoxShadow(color: const Color(0xFF14B8A6).withOpacity(0.4), blurRadius: 10, spreadRadius: 2)]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(
                                            isHovering ? Icons.move_to_inbox_rounded : Icons.topic_rounded,
                                            color: const Color(0xFF14B8A6),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: AppText(
                                              isHovering ? '"$groupTitle" grubuna taşı' : groupTitle,
                                              styleType: AppTextStyleType.bodyLarge,
                                              styleOverride: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isHovering ? const Color(0xFF14B8A6) : Colors.white,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF14B8A6).withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: AppText(
                                              '${cards.length} Kart',
                                              styleType: AppTextStyleType.caption,
                                              styleOverride: const TextStyle(color: Colors.white, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          tooltip: 'Başlığı Düzenle',
                                          onPressed: () => _showRenameHeadingDialog(groupTitle),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.add_rounded, color: Color(0xFF14B8A6), size: 22),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                          tooltip: 'Bu Başlığa Kart Ekle',
                                          onPressed: () => _showAddEditFlashcardSheet(defaultGroup: groupTitle),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Grid of cards under this group
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 12.0,
                            childAspectRatio: 1.1,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final card = cards[index];
                              return FadeSlideEntrance(
                                delay: Duration(milliseconds: 40 * index),
                                child: LongPressDraggable<Flashcard>(
                                  data: card,
                                  onDragUpdate: _handleDragUpdate,
                                  onDragEnd: (_) => _stopAutoScroll(),
                                  onDraggableCanceled: (_, __) => _stopAutoScroll(),
                                  feedback: Material(
                                    elevation: 8,
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(AppRadius.medium),
                                    child: SizedBox(
                                      width: (MediaQuery.of(context).size.width - 44) / 2,
                                      height: 140,
                                      child: Opacity(
                                        opacity: 0.9,
                                        child: FlipCardWidget(
                                          flashcard: card,
                                        ),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.25,
                                    child: FlipCardWidget(
                                      flashcard: card,
                                      onOptionsTap: () {},
                                    ),
                                  ),
                                  child: FlipCardWidget(
                                    flashcard: card,
                                    onOptionsTap: () => _showFlashcardOptions(card),
                                  ),
                                ),
                              );
                            },
                            childCount: cards.length,
                          ),
                        ),
                      ),
                    ];
                  }).toList(),

                // Bottom Add New Heading / Topic Group Button (Sayfanın en altında)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF14B8A6),
                        side: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                      ),
                      icon: const Icon(Icons.playlist_add_rounded, size: 22),
                      label: const AppText(
                        'Yeni Kart Başlığı / Konu Grubu Ekle',
                        styleType: AppTextStyleType.label,
                        styleOverride: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF14B8A6)),
                      ),
                      onPressed: () => _showAddNewHeadingDialog(),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF14B8A6),
          foregroundColor: Colors.white,
          onPressed: _showAddMenu,
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
    );
  }

  Widget _buildCardWidget(PhotoNote note, Color cardThemeColor) {
    return BounceButton(
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

                // Multi-Image Dot Indicator Badge at the bottom of the card
                if (note.imagePaths.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(note.imagePaths.length.clamp(1, 6), (i) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
