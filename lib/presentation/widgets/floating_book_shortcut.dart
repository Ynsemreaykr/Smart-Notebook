import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
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
  String? _selectedSubUnit;        // e.g. "1. Ünite", "2. Ünite"
  PhotoNote? _selectedPhotoNote;   // Selected note detail view
  int? _previewImageIndex;          // If non-null, shows full-window image preview inside mini window
  String _searchQuery = '';

  // Flashcards state
  String? _selectedFlashcardFolder; // Group/Unit folder for flashcards
  final Set<String> _flippedCardIds = {};
  bool _showFlashcardsInMiniWindow = false;
  int? _flashcardIndexFilter;

  // Image & Section Notes state inside Mini Window
  final Map<int, String> _localImageNotes = {};
  final Map<String, TextEditingController> _sectionControllers = {};

  // Expanded section state inside Mini Window
  int? _expandedSectionImageIndex;
  int? _expandedSectionIndex;
  final List<String> _quickSymbols = ['↑', '↓', '←', '→', '↗', '↘', '•', '⭐', '✔️', '⚠️', '📌', '❓', '⚡', '💡', '✏️', '➕', '➖'];

  List<String> _parseSections(String rawText, {bool keepEmptyIfLocallyTracked = false}) {
    if (rawText.isEmpty) return keepEmptyIfLocallyTracked ? [''] : [];
    return rawText.split('\n---\n');
  }

  void _addNoteSection(int imageIndex, PhotoNote note, PhotoNoteProvider provider) {
    final currentText = _localImageNotes[imageIndex] ??
        ((imageIndex < note.imageNotes.length) ? note.imageNotes[imageIndex] : '');
    final sections = _parseSections(currentText, keepEmptyIfLocallyTracked: false);

    if (sections.isEmpty) {
      sections.add('');
    } else if (sections.last.trim().isNotEmpty) {
      sections.add('');
    }

    final newSecIndex = sections.length - 1;
    final secKey = '${imageIndex}_$newSecIndex';
    final updatedText = sections.join('\n---\n');

    _localImageNotes[imageIndex] = updatedText;
    if (!_sectionControllers.containsKey(secKey)) {
      _sectionControllers[secKey] = TextEditingController(text: sections[newSecIndex]);
    }

    setState(() {});
    provider.updateImageNote(note.id, imageIndex, updatedText);
  }

  void _confirmAndRemoveNoteSection(BuildContext context, int imageIndex, int sectionIndex, PhotoNote note, PhotoNoteProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Text(
              'Not Bölümünü Sil',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        content: Text(
          'Not Bölümü ${sectionIndex + 1}\'i silmek istediğinize emin misiniz?',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _removeNoteSection(imageIndex, sectionIndex, note, provider);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _removeNoteSection(int imageIndex, int sectionIndex, PhotoNote note, PhotoNoteProvider provider) {
    final currentText = _localImageNotes[imageIndex] ??
        ((imageIndex < note.imageNotes.length) ? note.imageNotes[imageIndex] : '');
    final isTracked = _localImageNotes.containsKey(imageIndex);
    final sections = _parseSections(currentText, keepEmptyIfLocallyTracked: isTracked);

    if (sectionIndex >= 0 && sectionIndex < sections.length) {
      sections.removeAt(sectionIndex);
      _sectionControllers.remove('${imageIndex}_$sectionIndex');

      if (sections.isEmpty) {
        _localImageNotes.remove(imageIndex);
        setState(() {});
        provider.updateImageNote(note.id, imageIndex, '');
      } else {
        final updatedText = sections.join('\n---\n');
        _localImageNotes[imageIndex] = updatedText;
        setState(() {});
        provider.updateImageNote(note.id, imageIndex, updatedText);
      }
    }
  }

  void _updateSectionText(int imageIndex, int sectionIndex, String newSectionText, PhotoNote note, PhotoNoteProvider provider) {
    if (imageIndex == -1) {
      provider.updateMainNote(note.id, newSectionText);
      return;
    }

    final currentText = _localImageNotes[imageIndex] ??
        ((imageIndex < note.imageNotes.length) ? note.imageNotes[imageIndex] : '');
    final isTracked = _localImageNotes.containsKey(imageIndex);
    final sections = _parseSections(currentText, keepEmptyIfLocallyTracked: isTracked);

    if (sectionIndex >= 0 && sectionIndex < sections.length) {
      sections[sectionIndex] = newSectionText;
      final updatedText = sections.join('\n---\n');
      _localImageNotes[imageIndex] = updatedText;
      provider.updateImageNote(note.id, imageIndex, updatedText);
    }
  }

  void _insertSymbolToSection(int imageIndex, int sectionIndex, String symbol, PhotoNote note, PhotoNoteProvider provider) {
    final key = imageIndex == -1 ? 'main_note' : '${imageIndex}_$sectionIndex';
    final controller = _sectionControllers[key];
    if (controller == null) return;

    final text = controller.text;
    final selection = controller.selection;
    int start = selection.start;
    int end = selection.end;

    if (start < 0 || start > text.length) start = text.length;
    if (end < 0 || end > text.length) end = text.length;

    final newText = text.replaceRange(start, end, symbol);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );

    _updateSectionText(imageIndex, sectionIndex, newText, note, provider);
  }

  void _openFullScreenSectionEditor(BuildContext context, int imageIndex, int sectionIndex, PhotoNote note, PhotoNoteProvider provider) {
    setState(() {
      _expandedSectionImageIndex = imageIndex;
      _expandedSectionIndex = sectionIndex;
    });
  }

  Widget _buildExpandedSectionEditorInMiniWindow(PhotoNote note, PhotoNoteProvider provider) {
    final imageIndex = _expandedSectionImageIndex!;
    final sectionIndex = _expandedSectionIndex!;
    final secKey = imageIndex == -1 ? 'main_note' : '${imageIndex}_$sectionIndex';
    if (!_sectionControllers.containsKey(secKey)) {
      _sectionControllers[secKey] = TextEditingController(
        text: imageIndex == -1 ? note.note : '',
      );
    }
    final secController = _sectionControllers[secKey]!;
    final titleText = imageIndex == -1 ? 'Genel Not' : 'Not Bölümü ${sectionIndex + 1}';

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Top Header Bar inside Mini Window
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Color(0xFF14B8A6), width: 1)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    _updateSectionText(imageIndex, sectionIndex, secController.text, note, provider);
                    setState(() {
                      _expandedSectionImageIndex = null;
                      _expandedSectionIndex = null;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 14, color: AppTheme.neonBlue),
                      const SizedBox(width: 2),
                      Text('Geri', style: TextStyle(fontSize: 11, color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.check_rounded, color: Color(0xFF14B8A6), size: 18),
                  tooltip: 'Tamam',
                  onPressed: () {
                    _updateSectionText(imageIndex, sectionIndex, secController.text, note, provider);
                    setState(() {
                      _expandedSectionImageIndex = null;
                      _expandedSectionIndex = null;
                    });
                  },
                ),
              ],
            ),
          ),

          // Quick Symbols Toolbar
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Color(0xFF14B8A6), width: 0.8)),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickSymbols.length,
              itemBuilder: (context, qIndex) {
                final sym = _quickSymbols[qIndex];
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () {
                      final text = secController.text;
                      final selection = secController.selection;
                      int start = selection.start;
                      int end = selection.end;
                      if (start < 0 || start > text.length) start = text.length;
                      if (end < 0 || end > text.length) end = text.length;

                      final newText = text.replaceRange(start, end, sym);
                      secController.value = TextEditingValue(
                        text: newText,
                        selection: TextSelection.collapsed(offset: start + sym.length),
                      );
                      _updateSectionText(imageIndex, sectionIndex, newText, note, provider);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        sym,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Expanded TextField filling mini window
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: TextField(
                controller: secController,
                maxLines: null,
                expands: true,
                autofocus: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Not bölümü ${sectionIndex + 1} için notunuzu yazın...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 10),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: const EdgeInsets.all(8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.2),
                  ),
                ),
                onChanged: (val) {
                  _updateSectionText(imageIndex, sectionIndex, val, note, provider);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextImageOrCard(List<PhotoNote> folderNotes, PhotoNote currentNote, int currentImgIndex) {
    final totalImages = currentNote.imagePaths.length;
    if (currentImgIndex < totalImages - 1) {
      setState(() => _previewImageIndex = currentImgIndex + 1);
      return;
    }

    final cardIndex = folderNotes.indexWhere((n) => n.id == currentNote.id);
    if (cardIndex != -1 && cardIndex < folderNotes.length - 1) {
      final nextCard = folderNotes[cardIndex + 1];
      setState(() {
        _selectedPhotoNote = nextCard;
        _previewImageIndex = 0;
      });
    }
  }

  void _prevImageOrCard(List<PhotoNote> folderNotes, PhotoNote currentNote, int currentImgIndex) {
    if (currentImgIndex > 0) {
      setState(() => _previewImageIndex = currentImgIndex - 1);
      return;
    }

    final cardIndex = folderNotes.indexWhere((n) => n.id == currentNote.id);
    if (cardIndex > 0) {
      final prevCard = folderNotes[cardIndex - 1];
      setState(() {
        _selectedPhotoNote = prevCard;
        _previewImageIndex = prevCard.imagePaths.length > 0 ? prevCard.imagePaths.length - 1 : 0;
      });
    }
  }

  Widget _buildFullWindowImagePreviewInMiniWindow(PhotoNote note, PhotoNoteProvider provider) {
    final index = _previewImageIndex ?? 0;
    final totalImages = note.imagePaths.length;
    final imgPath = (index < totalImages) ? note.imagePaths[index] : note.imagePath;

    final categoryFilter = _selectedSubUnit != null
        ? '$_selectedCategoryFolder / $_selectedSubUnit'
        : _selectedCategoryFolder;
    final folderNotes = (_selectedCategoryFolder == null || _selectedCategoryFolder == 'Tümü')
        ? provider.photoNotes
        : provider.photoNotes.where((n) => n.category.trim() == categoryFilter?.trim() || n.category.startsWith('$categoryFilter / ')).toList();

    final imageNoteText = _localImageNotes[index] ??
        ((index < note.imageNotes.length && note.imageNotes[index].isNotEmpty)
            ? note.imageNotes[index]
            : '');

    final noteSections = _parseSections(imageNoteText);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Column(
        children: [
          // Top Header Bar inside Mini Window matching user screenshot
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              border: const Border(bottom: BorderSide(color: Color(0xFF14B8A6), width: 1)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _previewImageIndex = null),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 14, color: AppTheme.neonBlue),
                      const SizedBox(width: 2),
                      Text('Geri', style: TextStyle(fontSize: 11, color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${note.title} • Görsel ${index + 1} / $totalImages',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                // Kart / Bilgi Kartları Sembolü
                IconButton(
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 17),
                  tooltip: 'Bilgi Kartları',
                  onPressed: () => _openFlashcardsBottomSheet(context, note, index: index),
                ),
                const SizedBox(width: 2),
                // Kalem / Edit Note Icon
                IconButton(
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.amber, size: 18),
                  tooltip: 'Notu Düzenle (=✏️)',
                  onPressed: () {
                    _addNoteSection(index, note, provider);
                    _openFullScreenSectionEditor(context, index, 0, note, provider);
                  },
                ),
              ],
            ),
          ),

          // Main Zoomable Image & Swipe Gestures & Saydam Note Overlay
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! < -150) {
                        _nextImageOrCard(folderNotes, note, index);
                      } else if (details.primaryVelocity! > 150) {
                        _prevImageOrCard(folderNotes, note, index);
                      }
                    }
                  },
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 3.5,
                      child: _buildImageWidget(imgPath),
                    ),
                  ),
                ),

                // Left Navigation Button
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.white60, size: 28),
                      onPressed: () => _prevImageOrCard(folderNotes, note, index),
                    ),
                  ),
                ),

                // Right Navigation Button
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.white60, size: 28),
                      onPressed: () => _nextImageOrCard(folderNotes, note, index),
                    ),
                  ),
                ),

                // Bottom Semi-Transparent Scrollable Note Panel (Without "Not Bölümü" headers)
                if (imageNoteText.isNotEmpty || noteSections.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.6), width: 1.2),
                      ),
                      child: Scrollbar(
                        thumbVisibility: true,
                        thickness: 3,
                        radius: const Radius.circular(3),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      _openFullScreenSectionEditor(context, index, 0, note, provider);
                                    },
                                    child: const Text('Düzenle =✏️', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              for (int sIndex = 0; sIndex < noteSections.length; sIndex++) ...[
                                if (sIndex > 0) const SizedBox(height: 4),
                                Text(
                                  noteSections[sIndex].isEmpty ? '---' : noteSections[sIndex],
                                  style: const TextStyle(color: Colors.white, fontSize: 10.5, height: 1.35),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFlashcardsBottomSheet(BuildContext context, PhotoNote note, {int? index}) {
    setState(() {
      _showFlashcardsInMiniWindow = true;
      _flashcardIndexFilter = index;
    });
  }

  Widget _buildFlashcardsInMiniWindow(PhotoNote note, PhotoNoteProvider provider) {
    final index = _flashcardIndexFilter;
    final allCards = provider.getFlashcardsForNote(note.id);
    final targetGroup = (index != null) ? 'Görsel ${index + 1} Kartları' : null;
    final noteFlashcards = (index == null)
        ? allCards
        : allCards.where((f) {
            final g = f.groupTitle.trim();
            return g == targetGroup!.trim() || g == 'Görsel ${index + 1}' || g == 'Görsel ${index + 1} Kartları';
          }).toList();

    final titleText = (index == null)
        ? "Sayfadaki Tüm Bilgi Kartları (${noteFlashcards.length})"
        : "Görsel ${index + 1} Bilgi Kartları (${noteFlashcards.length})";

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showFlashcardsInMiniWindow = false),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 14, color: AppTheme.neonBlue),
                    const SizedBox(width: 2),
                    Text('Geri', style: TextStyle(fontSize: 11, color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: noteFlashcards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.style_rounded, size: 32, color: Colors.white24),
                        const SizedBox(height: 6),
                        Text('Henüz bilgi kartı eklenmedi.', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                      ],
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    thickness: 4,
                    radius: const Radius.circular(4),
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: noteFlashcards.length,
                      itemBuilder: (context, fcIndex) {
                        final card = noteFlashcards[fcIndex];
                        return FlipCardWidget(flashcard: card);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Image Zoom State
  String? _zoomedImagePath;
  bool _showMiniNoteSection = true;
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
      return Image.file(file, fit: BoxFit.fitWidth, width: double.infinity);
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

  /// Visual Cards Menu (Level 1: Folders, Level 1.5: Subunits, Level 2: 2-Column Cards Grid, Level 3: Card Details)
  Widget _buildVisualCardsMenu() {
    final provider = context.watch<PhotoNoteProvider>();

    if (_showFlashcardsInMiniWindow && _selectedPhotoNote != null) {
      return _buildFlashcardsInMiniWindow(_selectedPhotoNote!, provider);
    }

    if (_expandedSectionImageIndex != null && _expandedSectionIndex != null && _selectedPhotoNote != null) {
      return _buildExpandedSectionEditorInMiniWindow(_selectedPhotoNote!, provider);
    }

    if (_previewImageIndex != null && _selectedPhotoNote != null) {
      return _buildFullWindowImagePreviewInMiniWindow(_selectedPhotoNote!, provider);
    }

    // Level 3: Card Detail Preview with Vertical Scroll & Per-Image Notes
    if (_selectedPhotoNote != null) {
      final note = _selectedPhotoNote!;
      final totalImages = note.imagePaths.length;

      if (_expandedSectionImageIndex != null && _expandedSectionIndex != null) {
        return _buildExpandedSectionEditorInMiniWindow(note, provider);
      }

      return Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          children: [
            // Top Action Bar matching PhotoNoteViewerScreen
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedPhotoNote = null),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 14, color: AppTheme.neonBlue),
                      const SizedBox(width: 2),
                      Text('Geri', style: TextStyle(fontSize: 10, color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                // + Resim
                IconButton(
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF38BDF8), size: 15),
                  tooltip: '+ Resim Ekle',
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      await provider.addExtraImagesToNote(note.id, [File(picked.path)]);
                    }
                  },
                ),
                // + Kartlar (Bilgi Kartları)
                IconButton(
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 15),
                  tooltip: 'Bilgi Kartları',
                  onPressed: () => _openFlashcardsBottomSheet(context, note, index: null),
                ),
                // + Not (Genel Not)
                IconButton(
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.note_add_rounded, color: Colors.amber, size: 15),
                  tooltip: '+ Genel Not',
                  onPressed: () {
                    _openFullScreenSectionEditor(context, -1, 0, note, provider);
                  },
                ),
                // Paylaş
                IconButton(
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 14),
                  tooltip: 'Paylaş',
                  onPressed: () {
                    Share.share('Görsel Kart: ${note.title}\n${note.note}');
                  },
                ),
                // Sil
                IconButton(
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 14),
                  tooltip: 'Kartı Sil',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Kartı Sil', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        content: Text('"${note.title}" görsel kartını silmek istediğinize emin misiniz?', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white60))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() => _selectedPhotoNote = null);
                              provider.deletePhotoNote(note.id);
                            },
                            child: const Text('Sil', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 4,
                radius: const Radius.circular(4),
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: totalImages,
                  itemBuilder: (context, index) {
                    final imgPath = note.imagePaths[index];
                    final allNoteFlashcards = provider.getFlashcardsForNote(note.id);
                    final targetGroup = 'Görsel ${index + 1} Kartları';
                    final noteFlashcards = allNoteFlashcards.where((f) {
                      final g = f.groupTitle.trim();
                      return g == targetGroup || g == 'Görsel ${index + 1}' || g == 'Görsel ${index + 1} Kartları';
                    }).toList();
                    final imageNoteText = _localImageNotes[index] ??
                        ((index < note.imageNotes.length && note.imageNotes[index].isNotEmpty)
                            ? note.imageNotes[index]
                            : '');

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
                          // Image (Tap opens Tam Ekran in mini window with note overlay)
                          GestureDetector(
                            onTap: () => setState(() => _previewImageIndex = index),
                            onDoubleTap: () => setState(() => _previewImageIndex = index),
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
                                            onTap: () => _addNoteSection(index, note, provider),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF14B8A6).withValues(alpha: 0.85),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.add_rounded, size: 9, color: Colors.white),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    '+ Not',
                                                    style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
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
                                          GestureDetector(
                                            onTap: () => setState(() => _previewImageIndex = index),
                                            child: Container(
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
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Per-Image Multi-Section Note Area
                          Builder(
                            builder: (context) {
                              final isTracked = _localImageNotes.containsKey(index);
                              final noteSections = _parseSections(imageNoteText, keepEmptyIfLocallyTracked: isTracked);
                              if (noteSections.isEmpty) return const SizedBox.shrink();

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F172A),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (int sIndex = 0; sIndex < noteSections.length; sIndex++) ...[
                                      Builder(
                                        builder: (context) {
                                          final secKey = '${index}_$sIndex';
                                          final secText = noteSections[sIndex];

                                          if (!_sectionControllers.containsKey(secKey)) {
                                            _sectionControllers[secKey] = TextEditingController(text: secText);
                                          } else if (_sectionControllers[secKey]!.text != secText) {
                                            _sectionControllers[secKey]!.text = secText;
                                          }

                                          final secController = _sectionControllers[secKey]!;

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.04),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.edit_note_rounded, color: Color(0xFF14B8A6), size: 12),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Not Bölümü ${sIndex + 1}',
                                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14B8A6), fontSize: 10),
                                                        ),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        IconButton(
                                                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                                          padding: EdgeInsets.zero,
                                                          icon: const Icon(Icons.add_rounded, color: Color(0xFF14B8A6), size: 12),
                                                          tooltip: 'Yeni Not Bölümü Ekle',
                                                          onPressed: () => _addNoteSection(index, note, provider),
                                                        ),
                                                        const SizedBox(width: 2),
                                                        IconButton(
                                                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                                          padding: EdgeInsets.zero,
                                                          icon: const Icon(Icons.open_in_full_rounded, color: Color(0xFF14B8A6), size: 12),
                                                          tooltip: 'Tam Ekran Not Al',
                                                          onPressed: () => _openFullScreenSectionEditor(context, index, sIndex, note, provider),
                                                        ),
                                                        const SizedBox(width: 2),
                                                        IconButton(
                                                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                                          padding: EdgeInsets.zero,
                                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 12),
                                                          tooltip: 'Bu Not Bölümünü Sil',
                                                          onPressed: () => _confirmAndRemoveNoteSection(context, index, sIndex, note, provider),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),

                                                // Quick Symbols Toolbar directly on top of Note Box
                                                SizedBox(
                                                  height: 24,
                                                  child: ListView.builder(
                                                    scrollDirection: Axis.horizontal,
                                                    itemCount: _quickSymbols.length,
                                                    itemBuilder: (context, qIndex) {
                                                      final sym = _quickSymbols[qIndex];
                                                      return Padding(
                                                        padding: const EdgeInsets.only(right: 3),
                                                        child: InkWell(
                                                          onTap: () => _insertSymbolToSection(index, sIndex, sym, note, provider),
                                                          borderRadius: BorderRadius.circular(4),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF14B8A6).withValues(alpha: 0.18),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              sym,
                                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(height: 4),

                                                TextField(
                                                  controller: secController,
                                                  maxLines: null,
                                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                                  decoration: InputDecoration(
                                                    hintText: 'Not bölümü ${sIndex + 1}...',
                                                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 9),
                                                    isDense: true,
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                    filled: true,
                                                    fillColor: Colors.black26,
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(4),
                                                      borderSide: BorderSide.none,
                                                    ),
                                                  ),
                                                  onChanged: (val) {
                                                    _updateSectionText(index, sIndex, val, note, provider);
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),

                          // Bilgi Kartları Trigger Button (Opens Modal Bottom Sheet)
                          GestureDetector(
                            onTap: () => _openFlashcardsBottomSheet(context, note, index: index),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                                border: Border(top: BorderSide(color: const Color(0xFF14B8A6).withValues(alpha: 0.3))),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Bilgi Kartları (${noteFlashcards.length} Kart)",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF14B8A6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Row(
                                    children: [
                                      Text('Aç', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)),
                                      SizedBox(width: 2),
                                      Icon(Icons.keyboard_arrow_right_rounded, size: 14, color: Colors.white70),
                                    ],
                                  ),
                                ],
                              ),
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
      final subCategories = provider.getSubCategories(folderName);

      // Level 1.5: Sub-Categories / Üniteler List
      if (subCategories.isNotEmpty && _selectedSubUnit == null) {
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
                        Text('Dersler', style: TextStyle(fontSize: 11, color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
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
                    '${subCategories.length} Ünite',
                    style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(4),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: subCategories.length,
                  itemBuilder: (context, index) {
                    final subName = subCategories[index];
                    final fullPath = '$folderName / $subName';
                    final noteCount = provider.getNoteCountForCategory(fullPath, includeSubCategories: true);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedSubUnit = subName),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF0EA5E9)),
                            const SizedBox(height: 4),
                            Text(
                              subName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              '$noteCount Görsel Kart',
                              style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }

      final categoryFilter = _selectedSubUnit != null ? '$folderName / $_selectedSubUnit' : folderName;
      final folderNotes = folderName == 'Tümü'
          ? provider.photoNotes
          : provider.photoNotes.where((n) => n.category.trim() == categoryFilter.trim() || n.category.startsWith('$categoryFilter / ')).toList();

      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    if (_selectedSubUnit != null) {
                      _selectedSubUnit = null;
                    } else {
                      _selectedCategoryFolder = null;
                    }
                  }),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 14, color: AppTheme.neonBlue),
                      const SizedBox(width: 2),
                      Text(
                        _selectedSubUnit != null ? 'Üniteler' : 'Bölümler',
                        style: TextStyle(fontSize: 11, color: AppTheme.neonBlue, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(_getCategoryIcon(folderName), size: 14, color: _getCategoryColor(folderName)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _selectedSubUnit != null ? '$folderName / $_selectedSubUnit' : folderName,
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
                            onTap: () => setState(() {
                              _selectedPhotoNote = card;
                              _previewImageIndex = 0;
                            }),
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
