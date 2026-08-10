import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'flip_card_widget.dart';
import 'move_or_copy_modal.dart';
import '../../application/providers/photo_note_provider.dart';
import '../../domain/models/photo_note.dart';
import '../theme/app_theme.dart';
import '../screens/photo_notes/photo_notes_screen.dart';

class _UnitQuestionItem {
  final PhotoNote note;
  final int imageIndex;
  _UnitQuestionItem(this.note, this.imageIndex);
}

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
  static Offset _position = const Offset(20, 80);
  static Size _windowSize = const Size(340, 420); // Resizable window dimensions
  int _activeTab = 0; // 0: Visual Cards (Folders), 1: Flashcards

  // Visual Cards Navigation State inside Mini Window (Persists during session)
  static String? _selectedCategoryFolder; // e.g. "Coğrafya", "Tarih", "Tümü"
  static String? _selectedSubUnit;        // e.g. "1. Ünite", "2. Ünite"
  static PhotoNote? _selectedPhotoNote;   // Selected note detail view
  static int? _previewImageIndex;          // If non-null, shows full-window image preview inside mini window
  static String _searchQuery = '';

  // Flashcards state
  static String? _selectedFlashcardFolder; // Group/Unit folder for flashcards
  static final Set<String> _flippedCardIds = {};
  static bool _showFlashcardsInMiniWindow = false;
  static int? _flashcardIndexFilter;

  // Image & Section Notes state inside Mini Window
  static final Map<int, String> _localImageNotes = {};
  static final Map<String, TextEditingController> _sectionControllers = {};

  // Unit Questions state
  static List<_UnitQuestionItem>? _activeUnitQuestionList;
  static int? _activeUnitQuestionIndex;
  PageController? _unitQuestionPageController;

  // Mini-window image preview state
  final Map<int, TransformationController> _previewTransformControllers = {};
  PageController? _previewPageController;
  bool _showPreviewUI = true;
  bool _isPreviewZoomed = false;
  int _previewPointerCount = 0;
  TapDownDetails? _previewDoubleTapDetails;

  // Expanded section state inside Mini Window
  static int? _expandedSectionImageIndex;
  static int? _expandedSectionIndex;
  static double _noteOverlayHeight = 120.0; // Draggable height of bottom note overlay
  final List<String> _quickSymbols = ['↑', '↓', '←', '→', '↗', '↘', '•', '⭐', '✔️', '⚠️', '📌', '❓', '⚡', '💡', '✏️', '➕', '➖'];

  List<String> _parseSections(String rawText, {bool keepEmptyIfLocallyTracked = false}) {
    if (rawText.isEmpty) return keepEmptyIfLocallyTracked ? [''] : [];
    return rawText.split('\n---\n');
  }



  void _openFullScreenSectionEditor(BuildContext context, int imageIndex, int sectionIndex, PhotoNote note, PhotoNoteProvider provider) {
    final secKey = imageIndex == -1 ? 'main_note' : '${imageIndex}_0';
    final initialText = imageIndex == -1
        ? note.note
        : (_localImageNotes[imageIndex] ??
            ((imageIndex < note.imageNotes.length && note.imageNotes[imageIndex].isNotEmpty)
                ? note.imageNotes[imageIndex]
                : (imageIndex == 0 ? note.note : '')));
    if (!_sectionControllers.containsKey(secKey)) {
      _sectionControllers[secKey] = TextEditingController(text: initialText);
    } else {
      _sectionControllers[secKey]!.text = initialText;
    }
    setState(() {
      _expandedSectionImageIndex = imageIndex;
      _expandedSectionIndex = sectionIndex;
    });
  }

  Widget _buildExpandedSectionEditorInMiniWindow(PhotoNote note, PhotoNoteProvider provider) {
    final imageIndex = _expandedSectionImageIndex!;
    final secKey = imageIndex == -1 ? 'main_note' : '${imageIndex}_0';
    final initialText = imageIndex == -1
        ? note.note
        : (_localImageNotes[imageIndex] ??
            ((imageIndex < note.imageNotes.length && note.imageNotes[imageIndex].isNotEmpty)
                ? note.imageNotes[imageIndex]
                : (imageIndex == 0 ? note.note : '')));
    if (!_sectionControllers.containsKey(secKey)) {
      _sectionControllers[secKey] = TextEditingController(text: initialText);
    }
    final secController = _sectionControllers[secKey]!;
    final titleText = imageIndex == -1 ? 'Genel Not Düzenle' : 'Görsel ${imageIndex + 1} Notu Düzenle';

    void saveAndClose() {
      final text = secController.text;
      if (imageIndex == -1) {
        provider.updateMainNote(note.id, text);
      } else {
        _localImageNotes[imageIndex] = text;
        provider.updateImageNote(note.id, imageIndex, text);
      }
      setState(() {
        _expandedSectionImageIndex = null;
        _expandedSectionIndex = null;
      });
    }

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
                  behavior: HitTestBehavior.opaque,
                  onTap: saveAndClose,
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
                  onPressed: saveAndClose,
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
                      if (imageIndex == -1) {
                        provider.updateMainNote(note.id, newText);
                      } else {
                        _localImageNotes[imageIndex] = newText;
                        provider.updateImageNote(note.id, imageIndex, newText);
                      }
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
                  hintText: imageIndex == -1 ? 'Genel kart notunuzu yazın...' : 'Görsel ${imageIndex + 1} için ders notunuzu yazın...',
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
                  if (imageIndex == -1) {
                    provider.updateMainNote(note.id, val);
                  } else {
                    _localImageNotes[imageIndex] = val;
                    provider.updateImageNote(note.id, imageIndex, val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }



  TransformationController _getPreviewTransformController(int idx) {
    return _previewTransformControllers.putIfAbsent(idx, () => TransformationController());
  }

  void _handlePreviewDoubleTap(TapDownDetails details, int idx) {
    final ctrl = _getPreviewTransformController(idx);
    final currentScale = ctrl.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      ctrl.value = Matrix4.identity();
      setState(() => _isPreviewZoomed = false);
    } else {
      final x = -details.localPosition.dx * 1.5;
      final y = -details.localPosition.dy * 1.5;
      ctrl.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(2.5);
      setState(() => _isPreviewZoomed = true);
    }
  }

  Widget _buildFullWindowImagePreviewInMiniWindow(PhotoNote note, PhotoNoteProvider provider) {
    final totalImages = note.imagePaths.length;
    final index = (_previewImageIndex ?? 0).clamp(0, totalImages > 0 ? totalImages - 1 : 0);

    // Initialize/reuse PageController for this preview session
    if (_previewPageController == null || !_previewPageController!.hasClients) {
      _previewPageController?.dispose();
      _previewPageController = PageController(initialPage: index);
    }

    final imageNoteText = _localImageNotes[index] ??
        ((index < note.imageNotes.length && note.imageNotes[index].isNotEmpty)
            ? note.imageNotes[index]
            : (index == 0 ? note.note : ''));
    final noteSections = _parseSections(imageNoteText);
    final isQuestion = (index < note.questionFlags.length) ? note.questionFlags[index] : false;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Column(
        children: [
          // Top Header Bar
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _showPreviewUI ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_showPreviewUI,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  border: const Border(bottom: BorderSide(color: Color(0xFF14B8A6), width: 1)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        _selectedPhotoNote = null;
                        _previewImageIndex = null;
                        _showPreviewUI = true;
                        _isPreviewZoomed = false;
                        _previewPageController?.dispose();
                        _previewPageController = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Colors.white),
                      ),
                    ),

                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isQuestion
                            ? '${note.title} • ❓ Soru ${index + 1} / $totalImages'
                            : '${note.title} • Görsel ${index + 1} / $totalImages',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isQuestion ? const Color(0xFFF59E0B) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),

                    // Soru Görseli Butonu
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isQuestion ? Icons.help : Icons.help_outline_rounded,
                        color: isQuestion ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                        size: 18,
                      ),
                      tooltip: '+ Soru Görseli Ekle / İşaretle',
                      onPressed: () {
                        _showAddQuestionOptionsSheet(context, note, index, provider);
                      },
                    ),
                    const SizedBox(width: 3),

                    // Bilgi Kartları Butonu
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 18),
                      tooltip: 'Bilgi Kartları',
                      onPressed: () => _openFlashcardsBottomSheet(context, note, index: index),
                    ),
                    const SizedBox(width: 3),

                    // Notu Düzenle Butonu
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.amber, size: 21),
                      tooltip: 'Görsel Notunu Düzenle',
                      onPressed: () {
                        _openFullScreenSectionEditor(context, index, 0, note, provider);
                      },
                    ),
                    const SizedBox(width: 3),

                    // 3 Nokta Pop-up Menü (+Resim, Görseli Değiştir, Paylaş, Sil)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 19),
                      color: const Color(0xFF1E293B),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onSelected: (val) {
                        if (val == 'move_copy') {
                          showMoveOrCopyCardModal(
                            context: context,
                            note: note,
                            imageIndex: index,
                            onSuccess: () {
                              setState(() {
                                _selectedPhotoNote = null;
                                _previewImageIndex = null;
                              });
                            },
                          );
                        } else if (val == 'add_image') {
                          _pickAndAddExtraImage(note);
                        } else if (val == 'replace_image') {
                          _showReplaceImagePicker(context, note, index);
                        } else if (val == 'share') {
                          Share.share('Görsel Kart: ${note.title}\n${note.note}');
                        } else if (val == 'delete_image') {
                          _confirmDeleteImage(context, note, index, provider);
                        } else if (val == 'delete_card') {
                          _confirmDeleteCard(context, note, provider);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'move_copy',
                          child: Row(
                            children: [
                              Icon(Icons.drive_file_move_rounded, color: Color(0xFFF59E0B), size: 16),
                              SizedBox(width: 8),
                              Text('Başka Üniteye Taşı / Kopyala', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'add_image',
                          child: Row(
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF14B8A6), size: 16),
                              SizedBox(width: 8),
                              Text('+ Görsel Ekle', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'replace_image',
                          child: Row(
                            children: [
                              Icon(Icons.published_with_changes_rounded, color: Color(0xFF38BDF8), size: 16),
                              SizedBox(width: 8),
                              Text('Görseli Değiştir', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share_rounded, color: Colors.white70, size: 16),
                              SizedBox(width: 8),
                              Text('Paylaş', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete_image',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.orangeAccent, size: 16),
                              SizedBox(width: 8),
                              Text('Şu Anki Görseli Sil', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete_card',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 16),
                              SizedBox(width: 8),
                              Text('Tüm Not Kartını Sil', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Zoomable Image with PageView Swipe & Navigation Arrows
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _previewPageController,
                  physics: _isPreviewZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: totalImages,
                  onPageChanged: (page) {
                    setState(() {
                      _previewImageIndex = page;
                      _isPreviewZoomed = false;
                    });
                  },
                  itemBuilder: (context, idx) {
                    final pPath = note.imagePaths[idx];
                    final ctrl = _getPreviewTransformController(idx);
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Listener(
                          onPointerDown: (event) {
                            _previewPointerCount++;
                            if (_previewPointerCount >= 2 && !_isPreviewZoomed) {
                              setState(() => _isPreviewZoomed = true);
                            }
                          },
                          onPointerUp: (event) {
                            _previewPointerCount = (_previewPointerCount > 1) ? _previewPointerCount - 1 : 0;
                            if (_previewPointerCount == 0) {
                              final scale = ctrl.value.getMaxScaleOnAxis();
                              if (scale <= 1.05 && _isPreviewZoomed) {
                                setState(() => _isPreviewZoomed = false);
                              }
                            }
                          },
                          onPointerCancel: (event) {
                            _previewPointerCount = 0;
                            final scale = ctrl.value.getMaxScaleOnAxis();
                            if (scale <= 1.05 && _isPreviewZoomed) {
                              setState(() => _isPreviewZoomed = false);
                            }
                          },
                          child: GestureDetector(
                            onTap: () => setState(() => _showPreviewUI = !_showPreviewUI),
                            onDoubleTapDown: (details) => _previewDoubleTapDetails = details,
                            onDoubleTap: () {
                              if (_previewDoubleTapDetails != null) {
                                _handlePreviewDoubleTap(_previewDoubleTapDetails!, idx);
                              }
                            },
                            child: InteractiveViewer(
                              transformationController: ctrl,
                              minScale: 0.8,
                              maxScale: 5.0,
                              panEnabled: true,
                              scaleEnabled: true,
                              onInteractionUpdate: (details) {
                                final scale = ctrl.value.getMaxScaleOnAxis();
                                final zoomed = scale > 1.05;
                                if (zoomed != _isPreviewZoomed) {
                                  setState(() => _isPreviewZoomed = zoomed);
                                }
                              },
                              child: _buildImageWidget(pPath, fit: BoxFit.contain),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                // Left & Right Navigation Overlay Arrows (If multiple images)
                if (totalImages > 1 && _showPreviewUI) ...[
                  if (index > 0)
                    Positioned(
                      left: 6,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            _previewPageController?.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                    ),
                  if (index < totalImages - 1)
                    Positioned(
                      right: 6,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            _previewPageController?.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 13),
                          ),
                        ),
                      ),
                    ),
                ],

                // Bottom Semi-Transparent Scrollable Note Overlay Panel (Görsele Ait Not Penceresi)
                if (imageNoteText.isNotEmpty || noteSections.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showPreviewUI ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !_showPreviewUI,
                        child: Container(
                          height: _noteOverlayHeight.clamp(60.0, _windowSize.height - 100.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.7), width: 1.3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Drag Handle (Görsel ile metin kutusunun birleştiği çizgi - yukarı/aşağı sürükleyerek boyutlandırma)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragUpdate: (details) {
                                  setState(() {
                                    _noteOverlayHeight = (_noteOverlayHeight - details.delta.dy).clamp(60.0, _windowSize.height - 100.0);
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                    border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.8)),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF14B8A6),
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF14B8A6).withValues(alpha: 0.5),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Scrollable Note Content (Yalnızca okuma alanı, düzenlemek için üst bardaki Düzenle butonuna basılır)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    thickness: 3.5,
                                    radius: const Radius.circular(3),
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (int sIndex = 0; sIndex < noteSections.length; sIndex++) ...[
                                            if (sIndex > 0) const SizedBox(height: 4),
                                            Text(
                                              noteSections[sIndex].isEmpty ? '---' : noteSections[sIndex],
                                              style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.35),
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

  void _showAddQuestionOptionsSheet(BuildContext context, PhotoNote note, int currentImgIndex, PhotoNoteProvider provider) {
    final isQuestion = (currentImgIndex < note.questionFlags.length) ? note.questionFlags[currentImgIndex] : false;
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
              leading: const Icon(Icons.add_a_photo_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Galeriden Yeni Soru Görseli Ekle', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  await provider.addExtraImagesToNote(note.id, [File(picked.path)], isQuestion: true);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF38BDF8)),
              title: const Text('Kameradan Yeni Soru Görseli Çek', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.camera);
                if (picked != null) {
                  await provider.addExtraImagesToNote(note.id, [File(picked.path)], isQuestion: true);
                }
              },
            ),
            ListTile(
              leading: Icon(
                isQuestion ? Icons.help_outline_rounded : Icons.help_outline_rounded,
                color: isQuestion ? Colors.amber : const Color(0xFF14B8A6),
              ),
              title: Text(
                isQuestion ? 'Bu Görselin "Soru" İşaretini Kaldır' : 'Bu Görseli "Soru" Olarak İşaretle',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await provider.toggleQuestionFlag(note.id, currentImgIndex);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteImage(BuildContext context, PhotoNote note, int imageIndex, PhotoNoteProvider provider) {
    final isQuestion = (imageIndex < note.questionFlags.length) ? note.questionFlags[imageIndex] : false;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Icon(
              isQuestion ? Icons.help_outline_rounded : Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Text(
              isQuestion ? 'Soru Görselini Sil' : 'Görseli Sil',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          isQuestion
              ? 'Bu soru görselini ve bağlı çözüm notunu silmek istediğinizden emin misiniz?'
              : 'Bu görseli ve ona ait notları silmek istediğinizden emin misiniz?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.removeImageFromNote(note.id, imageIndex);
              if (_previewImageIndex != null) {
                if (_previewImageIndex! >= note.imagePaths.length - 1) {
                  setState(() {
                    _previewImageIndex = note.imagePaths.length > 1 ? note.imagePaths.length - 2 : null;
                  });
                }
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndAddExtraImage(PhotoNote note) async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty && mounted) {
      final files = images.map((x) => File(x.path)).toList();
      await context.read<PhotoNoteProvider>().addExtraImagesToNote(note.id, files);
    }
  }

  void _confirmDeleteCard(BuildContext context, PhotoNote note, PhotoNoteProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tüm Kartı Sil', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Text('"${note.title}" görsel kartını silmek istediğinize emin misiniz?', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedPhotoNote = null;
                _previewImageIndex = null;
                _previewPageController?.dispose();
                _previewPageController = null;
              });
              provider.deletePhotoNote(note.id);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<_UnitQuestionItem> _getUnitQuestionItems(List<PhotoNote> folderNotes) {
    final list = <_UnitQuestionItem>[];
    for (final note in folderNotes) {
      for (int i = 0; i < note.imagePaths.length; i++) {
        final isQ = (i < note.questionFlags.length) ? note.questionFlags[i] : false;
        if (isQ) {
          list.add(_UnitQuestionItem(note, i));
        }
      }
    }
    return list;
  }

  Widget _buildUnitQuestionSliderInMiniWindow(PhotoNoteProvider provider) {
    if (_activeUnitQuestionList == null || _activeUnitQuestionList!.isEmpty) {
      return const SizedBox();
    }

    final items = _activeUnitQuestionList!;
    final index = (_activeUnitQuestionIndex ?? 0).clamp(0, items.length - 1);
    final currentItem = items[index];
    final note = currentItem.note;
    final imgIndex = currentItem.imageIndex;
    final imageNoteText = (imgIndex < note.imageNotes.length) ? note.imageNotes[imgIndex] : '';

    if (_unitQuestionPageController == null) {
      _unitQuestionPageController = PageController(initialPage: index);
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Column(
        children: [
          // Header
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              border: const Border(bottom: BorderSide(color: Color(0xFFF59E0B), width: 1)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    _activeUnitQuestionList = null;
                    _activeUnitQuestionIndex = null;
                    _unitQuestionPageController?.dispose();
                    _unitQuestionPageController = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFFF59E0B)),
                        SizedBox(width: 4),
                        Text('Üniteye Dön', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '❓ ${note.title} • Soru ${index + 1} / ${items.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  tooltip: 'Soruyu Sil',
                  onPressed: () {
                    _confirmDeleteImage(context, note, imgIndex, provider);
                  },
                ),
              ],
            ),
          ),

          // PageView Image
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _unitQuestionPageController,
                  physics: _isPreviewZoomed
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  itemCount: items.length,
                  onPageChanged: (page) {
                    setState(() {
                      _activeUnitQuestionIndex = page;
                      _isPreviewZoomed = false;
                    });
                  },
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    final path = (item.imageIndex < item.note.imagePaths.length) ? item.note.imagePaths[item.imageIndex] : item.note.imagePath;
                    final tCtrl = _getPreviewTransformController(idx);
                    return Listener(
                      onPointerDown: (event) {
                        _previewPointerCount++;
                        if (_previewPointerCount >= 2 && !_isPreviewZoomed) {
                          setState(() => _isPreviewZoomed = true);
                        }
                      },
                      onPointerUp: (event) {
                        _previewPointerCount = (_previewPointerCount > 1) ? _previewPointerCount - 1 : 0;
                        if (_previewPointerCount == 0) {
                          final scale = tCtrl.value.getMaxScaleOnAxis();
                          if (scale <= 1.05 && _isPreviewZoomed) {
                            setState(() => _isPreviewZoomed = false);
                          }
                        }
                      },
                      onPointerCancel: (event) {
                        _previewPointerCount = 0;
                        final scale = tCtrl.value.getMaxScaleOnAxis();
                        if (scale <= 1.05 && _isPreviewZoomed) {
                          setState(() => _isPreviewZoomed = false);
                        }
                      },
                      child: GestureDetector(
                        onDoubleTapDown: (details) => _previewDoubleTapDetails = details,
                        onDoubleTap: () {
                          if (_previewDoubleTapDetails != null) {
                            _handlePreviewDoubleTap(_previewDoubleTapDetails!, idx);
                          }
                        },
                        child: InteractiveViewer(
                          transformationController: tCtrl,
                          minScale: 0.8,
                          maxScale: 5.0,
                          panEnabled: true,
                          scaleEnabled: true,
                          child: _buildImageWidget(path, fit: BoxFit.contain),
                        ),
                      ),
                    );
                  },
                ),

                // Bottom note overlay
                if (imageNoteText.isNotEmpty)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        imageNoteText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
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

    if (_previewImageIndex != null) {
      _previewPageController = PageController(initialPage: _previewImageIndex!);
    }
    if (_activeUnitQuestionIndex != null && _activeUnitQuestionList != null && _activeUnitQuestionList!.isNotEmpty) {
      _unitQuestionPageController = PageController(initialPage: _activeUnitQuestionIndex!);
    }

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
    for (final ctrl in _previewTransformControllers.values) {
      ctrl.dispose();
    }
    _previewPageController?.dispose();
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

  Widget _buildImageWidget(String path, {BoxFit fit = BoxFit.contain}) {
    if (path.isEmpty) {
      return Container(
        color: AppTheme.darkCardHigh,
        child: Icon(Icons.image_not_supported_rounded, color: AppTheme.textMuted, size: 24),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          color: AppTheme.darkCardHigh,
          child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted, size: 24),
        ),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: fit);
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
    final provider = context.watch<PhotoNoteProvider>();
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
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCardHigh.withValues(alpha: 0.55),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.drag_indicator_rounded, size: 18, color: AppTheme.neonPurple),
                              const Spacer(),
                              // Add folder quick button
                              GestureDetector(
                                onTap: _showAddFolderDialog,
                                child: Tooltip(
                                  message: 'Yeni Bölüm Ekle',
                                  child: Icon(Icons.create_new_folder_rounded, size: 18, color: AppTheme.neonAccent),
                                ),
                              ),
                              const SizedBox(width: 10),
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
                                  child: Icon(Icons.open_in_full_rounded, size: 17, color: AppTheme.neonBlue),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: widget.onClose,
                                child: Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),

                        const SizedBox(height: 4),

                        // Main Content Body (Visual Cards & Per-Image Notes)
                        Expanded(
                          child: (_activeUnitQuestionList != null && _activeUnitQuestionList!.isNotEmpty)
                              ? _buildUnitQuestionSliderInMiniWindow(provider)
                              : (_zoomedImagePath != null
                                  ? _buildZoomedImageView()
                                  : _buildVisualCardsMenu()),
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

    if (_selectedPhotoNote != null) {
      return _buildFullWindowImagePreviewInMiniWindow(_selectedPhotoNote!, provider);
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
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selectedCategoryFolder = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.neonBlue),
                          const SizedBox(width: 4),
                          Text('Dersler', style: TextStyle(fontSize: 12, color: AppTheme.neonBlue, fontWeight: FontWeight.bold)),
                        ],
                      ),
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
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() {
                    if (_selectedSubUnit != null) {
                      _selectedSubUnit = null;
                    } else {
                      _selectedCategoryFolder = null;
                    }
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.neonBlue),
                        const SizedBox(width: 4),
                        Text(
                          _selectedSubUnit != null ? 'Üniteler' : 'Bölümler',
                          style: TextStyle(fontSize: 12, color: AppTheme.neonBlue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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
                Builder(
                  builder: (context) {
                    final unitQuestions = _getUnitQuestionItems(folderNotes);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${folderNotes.length} Not',
                          style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                        ),
                        if (unitQuestions.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _activeUnitQuestionList = unitQuestions;
                                _activeUnitQuestionIndex = 0;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.help_outline_rounded, size: 12, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Sorular (${unitQuestions.length})',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
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
                            onTap: () {
                              setState(() {
                                _selectedPhotoNote = card;
                                _previewImageIndex = 0;
                              });
                            },

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
                                    child: PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert_rounded,
                                        size: 16,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                      color: const Color(0xFF1E293B),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      onSelected: (val) {
                                        if (val == 'move_copy') {
                                          showMoveOrCopyCardModal(
                                            context: context,
                                            note: card,
                                          );
                                        } else if (val == 'delete') {
                                          _confirmDeleteCard(context, card, provider);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'move_copy',
                                          child: Row(
                                            children: [
                                              Icon(Icons.drive_file_move_rounded, color: Color(0xFFF59E0B), size: 16),
                                              SizedBox(width: 8),
                                              Text('Taşı / Kopyala', style: TextStyle(color: Colors.white, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 16),
                                              SizedBox(width: 8),
                                              Text('Kartı Sil', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
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
