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
import 'photo_notes_category_screen.dart';

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

  IconData _getCategoryIcon(String category) {
    final catLower = category.toLowerCase().trim();
    if (catLower.contains('coğrafya') || catLower.contains('cografya') || catLower.contains('yer')) {
      return Icons.map_rounded;
    } else if (catLower.contains('tarih') || catLower.contains('kronoloji')) {
      return Icons.history_edu_rounded;
    } else if (catLower.contains('biyoloji') || catLower.contains('tıp') || catLower.contains('canlı')) {
      return Icons.biotech_rounded;
    } else if (catLower.contains('matematik') || catLower.contains('geometri') || catLower.contains('formül')) {
      return Icons.calculate_rounded;
    } else if (catLower.contains('fizik') || catLower.contains('kimya') || catLower.contains('fen') || catLower.contains('deney')) {
      return Icons.science_rounded;
    } else if (catLower.contains('edebiyat') || catLower.contains('türkçe') || catLower.contains('dil')) {
      return Icons.menu_book_rounded;
    } else if (catLower.contains('tümü') || catLower.contains('hepsi')) {
      return Icons.grid_view_rounded;
    } else {
      return Icons.folder_open_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    final catLower = category.toLowerCase().trim();
    if (catLower.contains('coğrafya') || catLower.contains('cografya')) {
      return const Color(0xFF0EA5E9); // Sky blue
    } else if (catLower.contains('tarih')) {
      return const Color(0xFFD97706); // Amber
    } else if (catLower.contains('biyoloji')) {
      return const Color(0xFF10B981); // Emerald
    } else if (catLower.contains('matematik')) {
      return const Color(0xFFEC4899); // Pink
    } else if (catLower.contains('fizik') || catLower.contains('kimya')) {
      return const Color(0xFF8B5CF6); // Purple
    } else if (catLower.contains('edebiyat') || catLower.contains('türkçe')) {
      return const Color(0xFFF43F5E); // Rose
    } else if (catLower.contains('tümü')) {
      return AppColors.primary;
    } else {
      return const Color(0xFF14B8A6); // Teal default
    }
  }

  void _showAddEditSheet() {
    final titleController = TextEditingController();
    final categories = context.read<PhotoNoteProvider>().customCategories;
    String selectedCategory = categories.isNotEmpty ? categories.first : '';
    String selectedColor = _presetColors.first;
    File? selectedImage;

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
            final uniqueCategories = activeProvider.customCategories;

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
                        const AppText(
                          'Yeni Görsel Not',
                          styleType: AppTextStyleType.headingMedium,
                          styleOverride: TextStyle(fontWeight: FontWeight.bold),
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

                    // Category Dropdown
                    if (uniqueCategories.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.error),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: AppText(
                                'Lütfen önce ana ekrandan yeni bir bölüm klasörü oluşturun.',
                                styleType: AppTextStyleType.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value: selectedCategory.isEmpty || !uniqueCategories.contains(selectedCategory)
                            ? uniqueCategories.first
                            : selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Ders / Bölüm Seçin',
                          prefixIcon: const Icon(Icons.bookmark_border_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                        ),
                        items: uniqueCategories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedCategory = val;
                            });
                          }
                        },
                      ),
                    ],
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

                        if (selectedCategory.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen önce bir bölüm oluşturun.'),
                              backgroundColor: Colors.amber,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        await activeProvider.addPhotoNote(
                          title: titleController.text,
                          imageFile: selectedImage!,
                          category: selectedCategory,
                          color: selectedColor,
                        );
                      },
                      child: const AppText(
                        'Notu Kaydet',
                        styleType: AppTextStyleType.label,
                        styleOverride: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Yeni Bölüm Ekle',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Bölüm Adı (örn: Coğrafya)',
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
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<PhotoNoteProvider>().addCategory(name);
              }
              Navigator.pop(ctx);
            },
            child: AppText('Ekle', styleType: AppTextStyleType.label, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(String folderName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Bölümü Sil',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: AppText(
          '"$folderName" bölümü ve içindeki tüm görsel notlar silinecektir. Bu işlem geri alınamaz.',
          styleType: AppTextStyleType.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PhotoNoteProvider>().deleteCategory(folderName);
            },
            child: AppText('Sil', styleType: AppTextStyleType.label, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  void _showRenameCategoryDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const AppText(
          'Bölümü Düzenle',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Yeni Bölüm Adı',
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
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                context.read<PhotoNoteProvider>().renameCategory(oldName, newName);
              }
              Navigator.pop(ctx);
            },
            child: AppText('Kaydet', styleType: AppTextStyleType.label, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  void _showFolderOptions(String folderName) {
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
                title: const AppText('Bölümü Düzenle (Yeniden Adlandır)', styleType: AppTextStyleType.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameCategoryDialog(folderName);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: AppText('Bölümü Sil', styleType: AppTextStyleType.bodyMedium, color: AppColors.error),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteCategory(folderName);
                },
              ),
            ],
          ),
        );
      },
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
            'Görsel Not Bölümleri',
            styleType: AppTextStyleType.headingLarge,
            styleOverride: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.create_new_folder_rounded),
              tooltip: 'Yeni Bölüm Ekle',
              onPressed: _showAddCategoryDialog,
            ),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_rounded),
              tooltip: 'Yeni Not Ekle',
              onPressed: _showAddEditSheet,
            ),
            AppSpacing.gapWSm,
          ],
        ),
        body: Consumer<PhotoNoteProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final allNotes = provider.photoNotes;
            final folders = provider.allCategories;

            if (folders.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.folder_open_rounded,
                title: 'Bölüm Bulunmamaktadır',
                subtitle: 'Görsel ders notlarınızı sınıflandırmak için lütfen üst bardaki klasör ekleme butonunu kullanarak ilk bölüm klasörünüzü oluşturun.',
              );
            }

            // Group notes by category
            final Map<String, List<PhotoNote>> categoriesMap = {};
            for (var note in allNotes) {
              final cat = note.category.trim().isEmpty ? 'Genel' : note.category.trim();
              categoriesMap.putIfAbsent(cat, () => []).add(note);
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 1.15,
              ),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folderName = folders[index];
                
                // Determine number of notes in this folder
                final noteCount = categoriesMap[folderName]?.length ?? 0;

                final folderColor = _getCategoryColor(folderName);
                final folderIcon = _getCategoryIcon(folderName);

                return FadeSlideEntrance(
                  delay: Duration(milliseconds: 50 * index),
                  child: BounceButton(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhotoNotesCategoryScreen(category: folderName),
                        ),
                      );
                    },
                    child: AppCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(16.0),
                      borderColor: folderColor.withOpacity(0.35),
                      shadowColor: folderColor,
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Folder Icon Header
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: folderColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(AppRadius.medium),
                                  border: Border.all(color: folderColor.withOpacity(0.3), width: 1),
                                ),
                                child: Icon(
                                  folderIcon,
                                  color: folderColor,
                                  size: 26,
                                ),
                              ),
                              const Spacer(),
                              
                              // Folder Title
                              AppText(
                                folderName,
                                styleType: AppTextStyleType.bodyLarge,
                                styleOverride: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              
                              // Count badge
                              AppText(
                                '$noteCount Görsel Kart',
                                styleType: AppTextStyleType.caption,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => _showFolderOptions(folderName),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: _showAddEditSheet,
          child: const Icon(Icons.add_photo_alternate_rounded),
        ),
      ),
    );
  }
}
