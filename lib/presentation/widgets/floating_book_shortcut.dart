import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'flip_card_widget.dart';
import '../../application/providers/photo_note_provider.dart';
import '../../domain/models/photo_note.dart';
import '../theme/app_theme.dart';
import '../screens/photo_notes/photo_notes_screen.dart';

/// A floating, draggable mini replica of the Visual Cards (Görsel Kartlar) menu.
/// Directly displays subject folders (Coğrafya, Tarih, Biyoloji, etc.)
/// and allows browsing visual notes & flashcards inside a mini window while reading a book.
class FloatingBookShortcut extends StatefulWidget {
  final String bookTitle;
  final VoidCallback onClose;

  const FloatingBookShortcut({
    super.key,
    required this.bookTitle,
    required this.onClose,
  });

  @override
  State<FloatingBookShortcut> createState() => _FloatingBookShortcutState();
}

class _FloatingBookShortcutState extends State<FloatingBookShortcut>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 80);
  Size _windowSize = const Size(340, 420); // Resizable window dimensions
  int _activeTab = 0; // 0: Visual Cards (Folders), 1: Flashcards

  // Visual Cards Navigation State inside Mini Window
  String? _selectedCategoryFolder; // e.g. "Coğrafya", "Tarih", "Tümü"
  PhotoNote? _selectedPhotoNote;   // Selected note detail view
  String _searchQuery = '';

  // Flashcards state
  String? _selectedFlashcardFolder; // Group/Unit folder for flashcards
  final Set<String> _flippedCardIds = {};

  // Image Zoom State
  String? _zoomedImagePath;
  bool _showMiniNoteSection = true;
  final Set<int> _expandedVKartIndices = {};
  final TransformationController _zoomTransformationController = TransformationController();
  TapDownDetails? _zoomDoubleTapDetails;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  void _handleZoomDoubleTap() {
    if (_zoomTransformationController.value != Matrix4.identity()) {
      _zoomTransformationController.value = Matrix4.identity();
    } else {
      final position = _zoomDoubleTapDetails?.localPosition ?? Offset.zero;
      _zoomTransformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.2, -position.dy * 1.2)
        ..scale(2.2);
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PhotoNoteProvider>().loadPhotoNotes();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _zoomTransformationController.dispose();
    super.dispose();
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
      return AppTheme.neonBlue;
    } else {
      return const Color(0xFF14B8A6); // Teal
    }
  }

  Widget _buildImageWidget(String path) {
    if (path.isEmpty) {
      return Container(
        color: AppTheme.darkCardHigh,
        child: Icon(Icons.image_not_supported_rounded, color: AppTheme.textMuted, size: 24),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: AppTheme.darkCardHigh,
          child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted, size: 24),
        ),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return Container(
      color: AppTheme.darkCardHigh,
      child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted, size: 24),
    );
  }

  void _showAddFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: Text(
          'Yeni Bölüm / Ders Ekle',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Ders Adı (örn: Coğrafya)',
            hintStyle: TextStyle(color: AppTheme.textMuted),
            prefixIcon: Icon(Icons.folder_open_rounded, color: AppTheme.neonBlue),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<PhotoNoteProvider>().addCategory(name);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonBlue),
            child: const Text('Ekle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double width = _windowSize.width.clamp(260.0, screenSize.width - 10.0);
    final double height = _windowSize.height.clamp(280.0, screenSize.height - 40.0);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withValues(alpha: 0.93),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.neonPurple.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonPurple.withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Header / Drag Handle & Actions (Draggable Only From Here)
                      GestureDetector(
                        onPanUpdate: (details) {
                          final size = MediaQuery.of(context).size;
                          setState(() {
                            _position = Offset(
                              (_position.dx + details.delta.dx).clamp(5.0, size.width - width - 5.0),
                              (_position.dy + details.delta.dy).clamp(30.0, size.height - height - 30.0),
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCardHigh.withValues(alpha: 0.55),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.drag_indicator_rounded, size: 16, color: AppTheme.neonPurple),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.bookTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              // Add folder quick button
                              GestureDetector(
                                onTap: _showAddFolderDialog,
                                child: Tooltip(
                                  message: 'Yeni Bölüm Ekle',
                                  child: Icon(Icons.create_new_folder_rounded, size: 15, color: AppTheme.neonAccent),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Fullscreen Action
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const PhotoNotesScreen()),
                                  );
                                },
                                child: Tooltip(
                                  message: 'Tam Ekran Aç',
                                  child: Icon(Icons.open_in_full_rounded, size: 14, color: AppTheme.neonBlue),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: widget.onClose,
                                child: Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),

                        const SizedBox(height: 4),

                        // Main Content Body (Visual Cards & Per-Image Notes)
                        Expanded(
                          child: _zoomedImagePath != null
                              ? _buildZoomedImageView()
                              : _buildVisualCardsMenu(),
                        ),
                      ],
                    ),

                    // Resizable Handle at Bottom-Right Corner
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _windowSize = Size(
                              (_windowSize.width + details.delta.dx).clamp(260.0, screenSize.width - 10.0),
                              (_windowSize.height + details.delta.dy).clamp(280.0, screenSize.height - 40.0),
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Icon(
                            Icons.south_east_rounded,
                            size: 14,
                            color: AppTheme.neonPurple,
                          ),
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
    }

  /// Zoomable & Scrollable Full-Mini-Window Image View
  Widget _buildZoomedImageView() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neonBlue.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              transformationController: _zoomTransformationController,
              minScale: 0.5,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(40),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTapDown: (details) => _zoomDoubleTapDetails = details,
                onDoubleTap: _handleZoomDoubleTap,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: _buildImageWidget(_zoomedImagePath!),
                ),
              ),
            ),
          ),
          // Close Zoom Overlay Button
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => setState(() => _zoomedImagePath = null),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '🔍 İki parmakla yakınlaştırın / sürükleyin',
                style: TextStyle(fontSize: 9, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imgPath, int index, int totalImages, PhotoNote note) {
    final imageNoteText = (index < note.imageNotes.length && note.imageNotes[index].isNotEmpty)
        ? note.imageNotes[index]
        : (index == 0 ? note.note : '');

    bool showNoteOverlay = true;

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setOverlayState) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  // Full Screen Zoomable & Pannable Image X
                  GestureDetector(
                    onTap: () {
                      setOverlayState(() {
                        showNoteOverlay = !showNoteOverlay;
                      });
                    },
                    child: Center(
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.file(
                          File(imgPath),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),

                  // Top Header Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${note.title} • Görsel ${index + 1} / $totalImages',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Semi-Transparent Note Overlay OVER Image X (Arka plan X görseli)
                  if (showNoteOverlay && imageNoteText.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.edit_note_rounded, color: Color(0xFF14B8A6), size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Görsel ${index + 1} İçin Not',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14B8A6), fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                imageNoteText,
                                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                              ),
                            ],
                          ),
                        ),
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

  void _showReplaceImagePicker(BuildContext context, PhotoNote note, int imageIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF14B8A6)),
              title: const Text('Galeriden Yeni Görsel Seç', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  await context.read<PhotoNoteProvider>().replaceImageInNote(note.id, imageIndex, File(picked.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF38BDF8)),
              title: const Text('Kameradan Yeni Fotoğraf Çek', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.camera);
                if (picked != null) {
                  await context.read<PhotoNoteProvider>().replaceImageInNote(note.id, imageIndex, File(picked.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Visual Cards Menu (Level 1: Folders, Level 2: 2-Column Cards Grid, Level 3: Card Details)
  Widget _buildVisualCardsMenu() {
    final provider = context.watch<PhotoNoteProvider>();

    // Level 3: Card Detail Preview with Vertical Scroll & Per-Image Notes
    if (_selectedPhotoNote != null) {
      final note = _selectedPhotoNote!;
      final totalImages = note.imagePaths.length;

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedPhotoNote = null),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 14, color: AppTheme.neonBlue),
                      const SizedBox(width: 2),
                      Text('Geri', style: TextStyle(fontSize: 11, color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 4,
                radius: const Radius.circular(4),
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: totalImages,
                  itemBuilder: (context, index) {
                    final allNoteFlashcards = provider.getFlashcardsForNote(note.id);
                    final targetGroup = 'Görsel ${index + 1} Kartları';
                    final noteFlashcards = allNoteFlashcards.where((f) {
                      final g = f.groupTitle.trim();
                      return g == targetGroup || g == 'Görsel ${index + 1}' || g == 'Görsel ${index + 1} Kartları';
                    }).toList();
                    final imageNoteText = (index < note.imageNotes.length && note.imageNotes[index].isNotEmpty)
                        ? note.imageNotes[index]
                        : (index == 0 ? note.note : '');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image (Tap opens Tam Ekran with note overlay)
                          GestureDetector(
                            onTap: () => _showFullScreenImage(context, imgPath, index, totalImages, note),
                            onDoubleTap: () => _showFullScreenImage(context, imgPath, index, totalImages, note),
                            child: ClipRRect(
                              child: Container(
                                width: double.infinity,
                                color: Colors.black26,
                                child: Stack(
                                  children: [
                                    _buildImageWidget(imgPath),
                                    Positioned(
                                      top: 4, right: 4,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _showReplaceImagePicker(context, note, index),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.7),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.6)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.published_with_changes_rounded, size: 9, color: Color(0xFF14B8A6)),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'Görseli Değiştir',
                                                    style: TextStyle(fontSize: 8, color: Color(0xFF14B8A6), fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.zoom_in_rounded, size: 9, color: Colors.white),
                                                SizedBox(width: 2),
                                                Text('Tam Ekran', style: TextStyle(fontSize: 8, color: Colors.white70)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Per-Image Note Sections
                          Builder(
                            builder: (context) {
                              if (imageNoteText.trim().isEmpty) return const SizedBox.shrink();
                              final sections = imageNoteText.split('\n---\n');
                              if (sections.isEmpty) return const SizedBox.shrink();

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.black26,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (int sIndex = 0; sIndex < sections.length; sIndex++) ...[
                                      Text(
                                        'Not Bölümü ${sIndex + 1}: ${sections[sIndex]}',
                                        style: TextStyle(fontSize: 9, color: AppTheme.textSecondary, height: 1.3),
                                      ),
                                      if (sIndex < sections.length - 1)
                                        const SizedBox(height: 3),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),

                          // Collapsible Bilgi Kartları (v sembollü akordiyon buton)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_expandedVKartIndices.contains(index)) {
                                  _expandedVKartIndices.remove(index);
                                } else {
                                  _expandedVKartIndices.add(index);
                                }
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.neonPurple.withValues(alpha: 0.15),
                                border: Border(top: BorderSide(color: AppTheme.neonPurple.withValues(alpha: 0.3))),
                                borderRadius: BorderRadius.vertical(
                                  bottom: _expandedVKartIndices.contains(index) ? Radius.zero : const Radius.circular(10),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _expandedVKartIndices.contains(index)
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: AppTheme.neonPurple,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Bilgi Kartları (${noteFlashcards.length} Kart)",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.neonPurple,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.style_rounded, size: 12, color: AppTheme.neonPurple),
                                ],
                              ),
                            ),
                          ),
                          if (_expandedVKartIndices.contains(index))
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                                border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.4)),
                              ),
                              child: noteFlashcards.isEmpty
                                  ? Text('Henüz bilgi kartı eklenmemiş.', style: TextStyle(fontSize: 10, color: AppTheme.textMuted))
                                  : GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 6,
                                        mainAxisSpacing: 6,
                                        childAspectRatio: 1.2,
                                      ),
                                      itemCount: noteFlashcards.length,
                                      itemBuilder: (context, fcIndex) {
                                        final card = noteFlashcards[fcIndex];
                                        return FlipCardWidget(
                                          flashcard: card,
                                        );
                                      },
                                    ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Level 2: Inside a specific Folder (e.g. Coğrafya)
    if (_selectedCategoryFolder != null) {
      final folderName = _selectedCategoryFolder!;
      final folderNotes = folderName == 'Tümü'
          ? provider.photoNotes
          : provider.photoNotes.where((n) => n.category.trim() == folderName.trim() || n.category.startsWith('$folderName / ')).toList();

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedCategoryFolder = null),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 14, color: AppTheme.neonBlue),
                      const SizedBox(width: 2),
                      Text('Bölümler', style: TextStyle(fontSize: 11, color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(_getCategoryIcon(folderName), size: 14, color: _getCategoryColor(folderName)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    folderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                Text(
                  '${folderNotes.length} Not',
                  style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: folderNotes.isEmpty
                  ? Center(
                      child: Text(
                        '"$folderName" bölümünde henüz görsel kart yok.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      thickness: 4,
                      radius: const Radius.circular(4),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(4),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.92,
                        ),
                        itemCount: folderNotes.length,
                        itemBuilder: (context, index) {
                          final card = folderNotes[index];
                          return GestureDetector(
                            onTap: () => setState(() => _selectedPhotoNote = card),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Icon(
                                      Icons.more_vert_rounded,
                                      size: 16,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: Text(
                                        card.title.isEmpty ? 'Görsel Kart ${index + 1}' : card.title,
                                        textAlign: TextAlign.center,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    // Level 1: Folders / Subject Categories View (Coğrafya, Tarih, Biyoloji, vs.)
    final folders = provider.topLevelCategories;
    final allFolders = folders;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        children: [
          // Search box
          Container(
            height: 28,
            margin: const EdgeInsets.only(bottom: 6),
            child: TextField(
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Bölümlerde ara...',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                prefixIcon: Icon(Icons.search_rounded, size: 14, color: AppTheme.textMuted),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Folders Grid
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              thickness: 4,
              radius: const Radius.circular(4),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.3,
                ),
                itemCount: allFolders.where((f) => f.toLowerCase().contains(_searchQuery)).length,
                itemBuilder: (context, index) {
                final filtered = allFolders.where((f) => f.toLowerCase().contains(_searchQuery)).toList();
                final folderName = filtered[index];

                final color = _getCategoryColor(folderName);
                final icon = _getCategoryIcon(folderName);

                final noteCount = folderName == 'Tümü'
                    ? provider.photoNotes.length
                    : provider.photoNotes.where((n) => n.category.trim() == folderName.trim() || n.category.startsWith('$folderName / ')).length;

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryFolder = folderName),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(icon, size: 14, color: color),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: color.withValues(alpha: 0.6)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          folderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '$noteCount Kart',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ),
        ],
      ),
    );
  }

  /// Flashcards Study View (2-Level Folders & Centered Text Cards)
  Widget _buildFlashcardsView() {
    final flashcards = context.watch<PhotoNoteProvider>().flashcards;

    if (flashcards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style_outlined, size: 30, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 4),
            Text('Henüz bilgi kartı yok', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    // Level 2: Inside a specific Flashcards Folder/Unit
    if (_selectedFlashcardFolder != null) {
      final folderName = _selectedFlashcardFolder!;
      final folderCards = folderName == 'Tümü'
          ? flashcards
          : flashcards.where((c) => c.groupTitle.trim() == folderName.trim()).toList();

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedFlashcardFolder = null),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 14, color: AppTheme.neonAccent),
                      const SizedBox(width: 2),
                      Text('Üniteler', style: TextStyle(fontSize: 11, color: AppTheme.neonAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(_getCategoryIcon(folderName), size: 14, color: _getCategoryColor(folderName)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    folderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                Text(
                  '${folderCards.length} Kart',
                  style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: folderCards.isEmpty
                  ? Center(
                      child: Text(
                        '"$folderName" ünitesinde henüz bilgi kartı yok.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    )
                  : Scrollbar(
                      thumbVisibility: true,
                      thickness: 4,
                      radius: const Radius.circular(4),
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: 1.05,
                        ),
                        itemCount: folderCards.length,
                        itemBuilder: (context, index) {
                          final card = folderCards[index];
                          final isCardFlipped = _flippedCardIds.contains(card.id);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isCardFlipped) {
                                  _flippedCardIds.remove(card.id);
                                } else {
                                  _flippedCardIds.add(card.id);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isCardFlipped
                                      ? [AppTheme.neonAccent.withValues(alpha: 0.2), AppTheme.darkCardHigh]
                                      : [AppTheme.neonBlue.withValues(alpha: 0.2), AppTheme.darkCardHigh],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCardFlipped ? AppTheme.neonAccent.withValues(alpha: 0.5) : AppTheme.neonBlue.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isCardFlipped ? 'CEVAP' : 'SORU',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: isCardFlipped ? AppTheme.neonAccent : AppTheme.neonBlue,
                                        ),
                                      ),
                                      Icon(
                                        isCardFlipped ? Icons.flip_to_back_rounded : Icons.flip_to_front_rounded,
                                        size: 10,
                                        color: isCardFlipped ? AppTheme.neonAccent : AppTheme.neonBlue,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Expanded(
                                    child: Center(
                                      child: SingleChildScrollView(
                                        physics: const BouncingScrollPhysics(),
                                        child: Text(
                                          isCardFlipped ? card.backText : card.frontText,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    // Level 1: Flashcard Units / Folders View
    final groups = flashcards.map((c) => c.groupTitle.trim()).where((g) => g.isNotEmpty).toSet().toList();
    final allGroups = ['Tümü', ...groups];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        children: [
          // Search box
          Container(
            height: 28,
            margin: const EdgeInsets.only(bottom: 6),
            child: TextField(
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Ünitelerde ara...',
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                prefixIcon: Icon(Icons.search_rounded, size: 14, color: AppTheme.textMuted),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Folders Grid
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              thickness: 4,
              radius: const Radius.circular(4),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.3,
                ),
                itemCount: allGroups.where((g) => g.toLowerCase().contains(_searchQuery)).length,
                itemBuilder: (context, index) {
                  final filtered = allGroups.where((g) => g.toLowerCase().contains(_searchQuery)).toList();
                  final groupName = filtered[index];

                  final color = _getCategoryColor(groupName);
                  final icon = _getCategoryIcon(groupName);

                  final noteCount = groupName == 'Tümü'
                      ? flashcards.length
                      : flashcards.where((c) => c.groupTitle.trim() == groupName.trim()).length;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedFlashcardFolder = groupName),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withValues(alpha: 0.2), AppTheme.darkCardHigh],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 22, color: color),
                          const SizedBox(height: 4),
                          Text(
                            groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '$noteCount Kart',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
