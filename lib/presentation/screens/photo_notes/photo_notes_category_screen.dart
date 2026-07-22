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
                    TextField(
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
                    TextField(
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

            if (subCategories.isEmpty && notes.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.folder_open_rounded,
                title: 'Henüz İçerik Bulunmuyor',
                subtitle: '"${widget.category}" içinde henüz alt ünite veya görsel not yok. Üst bardaki butonlardan yeni bir ünite veya not ekleyebilirsiniz.',
              );
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Sub-Categories / Units Section (If any exist)
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

                // Section Header for Photo Notes
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
                      ],
                    ),
                  ),
                ),

                // Grid of Photo Note Cards
                if (notes.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: AppText(
                          'Bu ünitede henüz doğrudan görsel kartı eklenmemiş.',
                          styleType: AppTextStyleType.bodyMedium,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
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
