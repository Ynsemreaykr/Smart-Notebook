import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/move_or_copy_modal.dart';
import '../../widgets/single_tap_cursor_textfield.dart';
import 'photo_note_detail_text_screen.dart';

class PhotoNoteViewerScreen extends StatefulWidget {
  final String noteId;
  const PhotoNoteViewerScreen({super.key, required this.noteId});

  @override
  State<PhotoNoteViewerScreen> createState() => _PhotoNoteViewerScreenState();
}

class _PhotoNoteViewerScreenState extends State<PhotoNoteViewerScreen> {
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
  bool _isZoomed = false;
  bool _showUI = true; // single-tap toggles top bar + bottom overlay
  int _pointerCount = 0;
  int _currentPage = 0;
  late PageController _pageController;
  final Map<int, TransformationController> _transformControllers = {};
  final ScrollController _verticalScrollController = ScrollController();
  final Map<int, TextEditingController> _imageNoteControllers = {};
  final Set<int> _focusedNoteIndexes = {};
  Timer? _autoScrollTimer;
  final List<String> _quickSymbols = ['↑', '↓', '←', '→', '↗', '↘', '•', '⭐', '✔️', '⚠️', '📌', '❓', '⚡', '💡', '✏️', '➕', '➖'];

  final Map<String, TextEditingController> _sectionControllers = {};
  final Map<int, String> _customAccordionTitles = {};
  String? _activeFocusedSecKey;
  double _noteOverlayHeight = 150.0; // Draggable height of bottom note overlay

  void _editAccordionTitle(int index) {
    final currentTitle = _customAccordionTitles[index] ?? 'Bilgi Kartları';
    final controller = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Bilgi Kartları Başlığını Değiştir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Başlık girin (Örn: Dağlar Soru Kartları)',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6)),
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                setState(() {
                  _customAccordionTitles[index] = newTitle;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openFullScreenSectionEditor(BuildContext context, int imageIndex, int sectionIndex, PhotoNote note, PhotoNoteProvider provider) {
    final secKey = '${imageIndex}_$sectionIndex';

    // Load existing section text for this image/section
    final currentRawText = _localImageNotes[imageIndex] ??
        ((imageIndex < note.imageNotes.length) ? note.imageNotes[imageIndex] : '');
    final sections = _parseSections(currentRawText);
    final existingText = (sectionIndex < sections.length) ? sections[sectionIndex] : '';

    // Reuse or create controller with existing text
    final secController = _sectionControllers.putIfAbsent(
      secKey,
      () => TextEditingController(text: existingText),
    );
    // If controller already existed but text differs (e.g. external update), sync it
    if (secController.text != existingText && _sectionControllers.containsKey(secKey) == false) {
      secController.text = existingText;
      secController.selection = TextSelection.collapsed(offset: existingText.length);
    }

    final searchController = TextEditingController();
    final searchFocusNode = FocusNode();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tam Ekran Not',
      pageBuilder: (ctx, anim1, anim2) {
        bool isSearching = false;
        List<int> matches = [];
        int currentMatchIndex = -1;

        void highlightMatch(StateSetter setDialogState) {
          if (matches.isEmpty || currentMatchIndex < 0 || currentMatchIndex >= matches.length) return;
          final start = matches[currentMatchIndex];
          final queryLen = searchController.text.length;
          secController.selection = TextSelection(
            baseOffset: start,
            extentOffset: start + queryLen,
          );
        }

        void performSearch(String query, StateSetter setDialogState) {
          if (query.trim().isEmpty) {
            setDialogState(() {
              matches = [];
              currentMatchIndex = -1;
            });
            return;
          }
          final fullText = secController.text.toLowerCase();
          final q = query.toLowerCase();
          final list = <int>[];
          int start = 0;
          while (start < fullText.length) {
            final idx = fullText.indexOf(q, start);
            if (idx == -1) break;
            list.add(idx);
            start = idx + q.length;
          }
          setDialogState(() {
            matches = list;
            if (list.isNotEmpty) {
              currentMatchIndex = 0;
              highlightMatch(setDialogState);
            } else {
              currentMatchIndex = -1;
            }
          });
        }

        void toggleSearch(StateSetter setDialogState) {
          setDialogState(() {
            isSearching = !isSearching;
            if (!isSearching) {
              searchController.clear();
              matches = [];
              currentMatchIndex = -1;
            }
          });
          if (isSearching) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              searchFocusNode.requestFocus();
              if (searchController.text.isNotEmpty) {
                searchController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: searchController.text.length,
                );
                performSearch(searchController.text, setDialogState);
              }
            });
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matchCount = matches.length;
            final currentPos = currentMatchIndex >= 0 ? currentMatchIndex + 1 : 0;

            return CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => toggleSearch(setDialogState),
                const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () => toggleSearch(setDialogState),
              },
              child: Focus(
                autofocus: true,
                child: Scaffold(
                  backgroundColor: const Color(0xFF0F172A),
                  appBar: AppBar(
                    backgroundColor: const Color(0xFF1E293B),
                    elevation: 2,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () {
                        _updateSectionText(imageIndex, sectionIndex, secController.text, note, provider);
                        Navigator.pop(ctx);
                      },
                    ),
                    title: Text(
                      'Not Bölümü ${sectionIndex + 1} (Tam Ekran)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    actions: [
                      // Not İçi Arama Butonu (Ctrl+F)
                      IconButton(
                        icon: Icon(
                          isSearching ? Icons.search_off_rounded : Icons.search_rounded,
                          color: isSearching ? const Color(0xFF14B8A6) : Colors.white70,
                          size: 22,
                        ),
                        tooltip: 'Not İçi Ara (Ctrl+F)',
                        onPressed: () => toggleSearch(setDialogState),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.check_rounded, color: Color(0xFF14B8A6), size: 20),
                        label: const Text('Tamam', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () {
                          _updateSectionText(imageIndex, sectionIndex, secController.text, note, provider);
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  body: Column(
                    children: [
                      // Arama Çubuğu
                      if (isSearching)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                            border: Border(bottom: BorderSide(color: Color(0xFF14B8A6), width: 1.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded, color: Color(0xFF14B8A6), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  focusNode: searchFocusNode,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: const InputDecoration(
                                    hintText: 'Not içinde ara... (Ctrl+F)',
                                    hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                                  ),
                                  onChanged: (val) => performSearch(val, setDialogState),
                                ),
                              ),
                              if (searchController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    matchCount > 0 ? '$currentPos/$matchCount' : '0/0',
                                    style: TextStyle(
                                      color: matchCount > 0 ? const Color(0xFF14B8A6) : Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70, size: 22),
                                tooltip: 'Önceki Eşleşme',
                                onPressed: matchCount > 0
                                    ? () {
                                        setDialogState(() {
                                          currentMatchIndex = (currentMatchIndex - 1 + matches.length) % matches.length;
                                          highlightMatch(setDialogState);
                                        });
                                      }
                                    : null,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 22),
                                tooltip: 'Sonraki Eşleşme',
                                onPressed: matchCount > 0
                                    ? () {
                                        setDialogState(() {
                                          currentMatchIndex = (currentMatchIndex + 1) % matches.length;
                                          highlightMatch(setDialogState);
                                        });
                                      }
                                    : null,
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                tooltip: 'Aramayı Kapat',
                                onPressed: () => toggleSearch(setDialogState),
                              ),
                            ],
                          ),
                        ),

                      // Özel Karakterler Barı (Special Characters Toolbar)
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E293B),
                          border: Border(bottom: BorderSide(color: Color(0xFF14B8A6), width: 1.2)),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _quickSymbols.length,
                          itemBuilder: (context, qIndex) {
                            final sym = _quickSymbols[qIndex];
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
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
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    sym,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Full Screen Main TextField
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: secController,
                            maxLines: null,
                            expands: true,
                            autofocus: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                            decoration: InputDecoration(
                              hintText: 'Not bölümü ${sectionIndex + 1} için notunuzu rahatça buraya yazın...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                              filled: true,
                              fillColor: Colors.black26,
                              contentPadding: const EdgeInsets.all(16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.white12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _insertSymbolToActiveField(String symbol, PhotoNote note, PhotoNoteProvider provider) {
    if (_activeFocusedSecKey == null) return;
    final parts = _activeFocusedSecKey!.split('_');
    if (parts.length != 2) return;
    final imageIndex = int.tryParse(parts[0]);
    final sectionIndex = int.tryParse(parts[1]);
    if (imageIndex == null || sectionIndex == null) return;

    _insertSymbolToSection(imageIndex, sectionIndex, symbol, note, provider);
  }

  final Map<int, String> _localImageNotes = {};

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

    setState(() {
      _activeFocusedSecKey = secKey;
      _focusedNoteIndexes.add(secKey.hashCode);
    });

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
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text(
              'Not Bölümünü Sil',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Not Bölümü ${sectionIndex + 1}\'i silmek istediğinize emin misiniz?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
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

  void _insertSymbolToSection(int imageIndex, int sectionIndex, String symbol, PhotoNote note, PhotoNoteProvider provider) {
    final key = '${imageIndex}_$sectionIndex';
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

  void _updateSectionText(int imageIndex, int sectionIndex, String newSectionText, PhotoNote note, PhotoNoteProvider provider) {
    final currentText = _localImageNotes[imageIndex] ??
        ((imageIndex < note.imageNotes.length) ? note.imageNotes[imageIndex] : '');
    final sections = _parseSections(currentText);
    while (sections.length <= sectionIndex) {
      sections.add('');
    }
    sections[sectionIndex] = newSectionText;
    final updatedText = sections.join('\n---\n');
    _localImageNotes[imageIndex] = updatedText;
    provider.updateImageNote(note.id, imageIndex, updatedText);
  }

  void _startAutoScroll(double step, ScrollController controller) {
    if (_autoScrollTimer?.isActive ?? false) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WakelockHelper.enable();
  }

  TransformationController _getTransformController(int page) {
    return _transformControllers.putIfAbsent(page, () {
      final ctrl = TransformationController();
      ctrl.addListener(_onTransformationChanged);
      return ctrl;
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    WakelockHelper.disable();
    for (final ctrl in _transformControllers.values) {
      ctrl.removeListener(_onTransformationChanged);
      ctrl.dispose();
    }
    _pageController.dispose();
    _verticalScrollController.dispose();
    for (final c in _imageNoteControllers.values) {
      c.dispose();
    }
    for (final c in _sectionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTransformationChanged() {
    // Check the current page's controller
    final ctrl = _transformControllers[_currentPage];
    if (ctrl == null) return;
    final scale = ctrl.value.getMaxScaleOnAxis();
    final isZoomedNow = scale > 1.05;
    if (isZoomedNow != _isZoomed) {
      setState(() {
        _isZoomed = isZoomedNow;
      });
    }
  }

  void _handleDoubleTap(TapDownDetails details, int pageIndex, BoxConstraints constraints) {
    final ctrl = _getTransformController(pageIndex);
    final currentScale = ctrl.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      // Already zoomed → reset to fit
      ctrl.value = Matrix4.identity();
    } else {
      // Zoom in 2.5x centered on the tap point
      final position = details.localPosition;
      final x = -position.dx * 1.5;
      final y = -position.dy * 1.5;
      final zoomed = Matrix4.identity()
        ..translate(x, y)
        ..scale(2.5);
      ctrl.value = zoomed;
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1E3A8A);
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
    final sheetScrollController = ScrollController();
    void handleSheetDragUpdate(DragUpdateDetails details) {
      final dy = details.globalPosition.dy;
      final screenHeight = MediaQuery.of(context).size.height;
      final sheetTop = screenHeight * 0.20 + 130;
      final sheetBottom = screenHeight - 80;

      if (dy < sheetTop) {
        final ratio = ((sheetTop - dy) / 130).clamp(0.12, 1.0);
        _startAutoScroll(-28.0 * ratio, sheetScrollController);
      } else if (dy > sheetBottom) {
        final ratio = ((dy - sheetBottom) / 80).clamp(0.12, 1.0);
        _startAutoScroll(28.0 * ratio, sheetScrollController);
      } else {
        _stopAutoScroll();
      }
    }

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
            final groupedMap = provider.getGroupedFlashcardsForNote(note.id);
            final totalCards = provider.getFlashcardsForNote(note.id).length;

            return Container(
              height: MediaQuery.of(context).size.height * 0.80,
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
                                    'Görsele Özel Bilgi Kartları ($totalCards)',
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

                  Expanded(
                    child: groupedMap.isEmpty
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
                        : ListView(
                            controller: sheetScrollController,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              ...groupedMap.entries.expand((entry) {
                                final groupTitle = entry.key;
                                final cards = entry.value;

                                return [
                                  // Heading Header Row (Acts as DragTarget to receive dropped flashcards)
                                  DragTarget<Flashcard>(
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
                                        margin: const EdgeInsets.only(top: 12, bottom: 8),
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
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: AppText(
                                                      isHovering ? '"$groupTitle" grubuna taşı' : groupTitle,
                                                      styleType: AppTextStyleType.bodyMedium,
                                                      styleOverride: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: isHovering ? const Color(0xFF14B8A6) : Colors.white,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  AppText(
                                                    '${cards.length} Kart',
                                                    styleType: AppTextStyleType.caption,
                                                    color: Colors.white70,
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
                                                  onPressed: () => _showRenameHeadingDialogForNote(context, note, groupTitle),
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(Icons.add_rounded, color: Color(0xFF14B8A6), size: 22),
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.all(4),
                                                  tooltip: 'Bu Başlığa Kart Ekle',
                                                  onPressed: () => _showAddEditFlashcardDialogForNote(context, note, defaultGroup: groupTitle),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),

                                  // Grid of cards under this heading
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.1,
                                    ),
                                    itemCount: cards.length,
                                    itemBuilder: (context, index) {
                                      final card = cards[index];
                                      return LongPressDraggable<Flashcard>(
                                        data: card,
                                        onDragUpdate: handleSheetDragUpdate,
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
                                          onOptionsTap: () => _showNoteFlashcardOptions(context, card, note),
                                        ),
                                      );
                                    },
                                  ),
                                ];
                              }),
                            ],
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Bottom Add New Heading / Card Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF14B8A6),
                      side: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.medium)),
                    ),
                    icon: const Icon(Icons.playlist_add_rounded, size: 22),
                    label: const AppText(
                      'Yeni Kart Başlığı / Konu Grubu Ekle',
                      styleType: AppTextStyleType.label,
                      styleOverride: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF14B8A6)),
                    ),
                    onPressed: () => _showAddEditFlashcardDialogForNote(context, note),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openFlashcardsBottomSheet(BuildContext context, PhotoNote note, {int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allCards = context.watch<PhotoNoteProvider>().getFlashcardsForNote(note.id);
            final targetGroup = (index != null) ? (_customAccordionTitles[index] ?? 'Görsel ${index + 1} Kartları') : null;
            final noteFlashcards = (index == null)
                ? allCards
                : allCards.where((f) {
                    final g = f.groupTitle.trim();
                    return g == targetGroup!.trim() || g == 'Görsel ${index + 1}' || g == 'Görsel ${index + 1} Kartları';
                  }).toList();

            final headerTitle = (index == null)
                ? "Sayfadaki Tüm Bilgi Kartları (${noteFlashcards.length})"
                : "Görsel ${index + 1} Bilgi Kartları (${noteFlashcards.length})";

            final groupHeaderTitle = (index == null)
                ? 'Sayfadaki Tüm Görseller'
                : (_customAccordionTitles[index] ?? 'Görsel ${index + 1} Kartları');

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black54, blurRadius: 16, spreadRadius: 4),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headerTitle,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                              ),
                              Text(
                                note.title,
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Content Body
                  Expanded(
                    child: noteFlashcards.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.style_outlined, color: Colors.white38, size: 48),
                                const SizedBox(height: 12),
                                const Text('Henüz bilgi kartı eklenmedi.', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF14B8A6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                  label: const Text('İlk Kartı Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openFlashcardsSheet(context, note);
                                  },
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Group Header Card
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5), width: 1.2),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.folder_rounded, color: Color(0xFF14B8A6), size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            groupHeaderTitle,
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${noteFlashcards.length} Kart',
                                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _editAccordionTitle(index ?? 0);
                                            },
                                          ),
                                          IconButton(
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.add_rounded, color: Color(0xFF14B8A6), size: 20),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              _openFlashcardsSheet(context, note);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // 2-Column Cards Grid
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 1.2,
                                  ),
                                  itemCount: noteFlashcards.length,
                                  itemBuilder: (context, fcIndex) {
                                    final card = noteFlashcards[fcIndex];
                                    return FlipCardWidget(
                                      flashcard: card,
                                      onOptionsTap: () {
                                        Navigator.pop(ctx);
                                        _showNoteFlashcardOptions(context, card, note);
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Bottom Action Button "+ Yeni Kart Başlığı / Konu Grubu Ekle"
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF14B8A6),
                        side: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.playlist_add_rounded, size: 22),
                      label: const Text(
                        'Yeni Kart Başlığı / Konu Grubu Ekle',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openFlashcardsSheet(context, note);
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

  void _showRenameHeadingDialogForNote(BuildContext context, PhotoNote note, String oldTitle) {
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
        content: SingleTapCursorTextField(
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
                  category: note.category,
                  noteId: note.id,
                );
              }
            },
            child: AppText('Kaydet', styleType: AppTextStyleType.label, color: const Color(0xFF14B8A6)),
          ),
        ],
      ),
    );
  }

  void _showAddEditFlashcardDialogForNote(BuildContext context, PhotoNote note, {Flashcard? card, String? defaultGroup}) {
    final frontController = TextEditingController(text: card?.frontText ?? '');
    final backController = TextEditingController(text: card?.backText ?? '');
    final groupController = TextEditingController(text: card?.groupTitle ?? defaultGroup ?? 'Genel Bilgiler');
    String selectedColor = card?.color ?? note.color;
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

                    // Color Selector for Image Flashcard
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
                        final grp = groupController.text.trim().isEmpty ? 'Genel Bilgiler' : groupController.text.trim();
                        if (isEdit) {
                          await context.read<PhotoNoteProvider>().updateFlashcard(
                            id: card!.id,
                            frontText: frontController.text,
                            backText: backController.text,
                            groupTitle: grp,
                            color: selectedColor,
                          );
                        } else {
                          await context.read<PhotoNoteProvider>().addFlashcard(
                            frontText: frontController.text,
                            backText: backController.text,
                            category: note.category,
                            noteId: note.id,
                            groupTitle: grp,
                            color: selectedColor,
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

  void _showFlashcardsBottomSheet(BuildContext context, PhotoNote note, {int? cardIndex}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer<PhotoNoteProvider>(
          builder: (context, provider, child) {
            final allCards = provider.getFlashcardsForNote(note.id);
            final targetGroup = (cardIndex != null) ? 'Görsel ${cardIndex + 1} Kartları' : null;
            final noteFlashcards = (cardIndex == null)
                ? allCards
                : allCards.where((f) {
                    final g = f.groupTitle.trim();
                    return g == targetGroup || g == 'Görsel ${cardIndex + 1}' || g == 'Görsel ${cardIndex + 1} Kartları';
                  }).toList();

            final titleText = cardIndex != null
                ? '${note.title} • Görsel ${cardIndex + 1} Bilgi Kartları'
                : '${note.title} • Bilgi Kartları';

            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          titleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF14B8A6), size: 22),
                        tooltip: 'Yeni Bilgi Kartı Ekle',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddEditFlashcardDialogForNote(
                            context,
                            note,
                            defaultGroup: cardIndex != null ? 'Görsel ${cardIndex + 1} Kartları' : null,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: noteFlashcards.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.style_rounded, size: 36, color: Colors.white24),
                                const SizedBox(height: 8),
                                Text('Henüz bilgi kartı eklenmedi.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6)),
                                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                  label: const Text('Bilgi Kartı Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showAddEditFlashcardDialogForNote(
                                      context,
                                      note,
                                      defaultGroup: cardIndex != null ? 'Görsel ${cardIndex + 1} Kartları' : null,
                                    );
                                  },
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: noteFlashcards.length,
                            itemBuilder: (context, fIndex) {
                              final fCard = noteFlashcards[fIndex];
                              return GestureDetector(
                                onTap: () => _showNoteFlashcardOptions(context, fCard, note),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fCard.frontText,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                       const Spacer(),
                                       const Divider(color: Colors.white12, height: 8),
                                       Text(
                                         fCard.backText,
                                         maxLines: 2,
                                         overflow: TextOverflow.ellipsis,
                                         style: const TextStyle(color: Colors.white70, fontSize: 10),
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
          },
        );
      },
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

  void _deleteNoteWithConfirmation(BuildContext context, PhotoNote note, int imageIndex, PhotoNoteProvider provider) {
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
              if (note.imagePaths.length <= 1) {
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
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
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(child: AppText('Not bulunamadı.', styleType: AppTextStyleType.bodyLarge)),
          );
        }

        final note = notes[noteIndex];
        final folderNotes = note.category.isEmpty
            ? provider.photoNotes
            : provider.photoNotes.where((n) => n.category.trim() == note.category.trim() || n.category.startsWith('${note.category} / ')).toList();

        final totalImages = note.imagePaths.length;
        final currentImgIndex = (_currentPage < totalImages) ? _currentPage : 0;

        final imageNoteText = (currentImgIndex < note.imageNotes.length && note.imageNotes[currentImgIndex].isNotEmpty)
            ? note.imageNotes[currentImgIndex]
            : (currentImgIndex == 0 ? note.note : '');
        final overlaySections = _parseSections(imageNoteText);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Full Screen Zoomable & Pannable Image PageView with Swipe Gestures
              PageView.builder(
                controller: _pageController,
                // Disable swipe when zoomed so InteractiveViewer can pan freely
                physics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                itemCount: totalImages,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, idx) {
                  final pPath = note.imagePaths[idx];
                  final ctrl = _getTransformController(idx);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Listener(
                        onPointerDown: (event) {
                          _pointerCount++;
                          if (_pointerCount >= 2 && !_isZoomed) {
                            setState(() => _isZoomed = true);
                          }
                        },
                        onPointerUp: (event) {
                          _pointerCount = (_pointerCount > 1) ? _pointerCount - 1 : 0;
                          if (_pointerCount == 0) {
                            final ctrl = _transformControllers[_currentPage];
                            final scale = ctrl?.value.getMaxScaleOnAxis() ?? 1.0;
                            if (scale <= 1.05 && _isZoomed) {
                              setState(() => _isZoomed = false);
                            }
                          }
                        },
                        onPointerCancel: (event) {
                          _pointerCount = 0;
                          final ctrl = _transformControllers[_currentPage];
                          final scale = ctrl?.value.getMaxScaleOnAxis() ?? 1.0;
                          if (scale <= 1.05 && _isZoomed) {
                            setState(() => _isZoomed = false);
                          }
                        },
                        child: GestureDetector(
                          onTap: () => setState(() => _showUI = !_showUI),
                          onDoubleTapDown: (details) => _handleDoubleTap(details, idx, constraints),
                          onDoubleTap: () {}, // required to trigger onDoubleTapDown
                          child: InteractiveViewer(
                            transformationController: ctrl,
                            minScale: 0.8,
                            maxScale: 5.0,
                            panEnabled: true,
                            scaleEnabled: true,
                            child: Image.file(
                              File(pPath),
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // Top Header Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showUI ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showUI,
                    child: SafeArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: Colors.black.withValues(alpha: 0.6),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (context) {
                                final isQuestion = (currentImgIndex < note.questionFlags.length) ? note.questionFlags[currentImgIndex] : false;
                                return Expanded(
                                  child: Text(
                                    isQuestion
                                        ? '${note.title} • ❓ Soru ${currentImgIndex + 1} / $totalImages'
                                        : '${note.title} • Görsel ${currentImgIndex + 1} / $totalImages',
                                    style: TextStyle(
                                      color: isQuestion ? const Color(0xFFF59E0B) : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                            Builder(
                              builder: (context) {
                                final isQuestion = (currentImgIndex < note.questionFlags.length) ? note.questionFlags[currentImgIndex] : false;
                                return IconButton(
                                  icon: Icon(
                                    isQuestion ? Icons.help : Icons.help_outline_rounded,
                                    color: isQuestion ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                                    size: 22,
                                  ),
                                  tooltip: '+ Soru Görseli Ekle / İşaretle',
                                  onPressed: () {
                                    _showAddQuestionOptionsSheet(context, note, currentImgIndex, provider);
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            // Bilgi Kartları Icon
                            IconButton(
                              icon: const Icon(Icons.style_rounded, color: Color(0xFF14B8A6), size: 22),
                              tooltip: 'Bilgi Kartları',
                              onPressed: () {
                                _showFlashcardsBottomSheet(context, note, cardIndex: currentImgIndex);
                              },
                            ),
                            const SizedBox(width: 4),
                            // Kalem / Edit Note Icon
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded, color: Colors.amber, size: 24),
                              tooltip: 'Notu Düzenle',
                              onPressed: () {
                                _openFullScreenSectionEditor(context, currentImgIndex, 0, note, provider);
                              },
                            ),
                            const SizedBox(width: 4),
                            // Action menu for +Resim, Görseli Değiştir, Paylaş, Sil
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                              color: const Color(0xFF1E293B),
                              onSelected: (val) {
                                if (val == 'move_copy') {
                                  showMoveOrCopyCardModal(
                                    context: context,
                                    note: note,
                                    imageIndex: currentImgIndex,
                                  );
                                } else if (val == 'add_image') {
                                  _pickAndAddExtraImage(note);
                                } else if (val == 'replace_image') {
                                  _showReplaceImagePicker(context, note, currentImgIndex);
                                } else if (val == 'share') {
                                  _shareImage(note);
                                } else if (val == 'delete') {
                                  _deleteNoteWithConfirmation(context, note, currentImgIndex, provider);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'move_copy',
                                  child: Row(
                                    children: [
                                      Icon(Icons.drive_file_move_rounded, color: Color(0xFFF59E0B), size: 18),
                                      SizedBox(width: 8),
                                      Text('Başka Üniteye Taşı / Kopyala', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'add_image',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF14B8A6), size: 18),
                                      SizedBox(width: 8),
                                      Text('+ Görsel Ekle', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'replace_image',
                                  child: Row(
                                    children: [
                                      Icon(Icons.published_with_changes_rounded, color: Color(0xFF38BDF8), size: 18),
                                      SizedBox(width: 8),
                                      Text('Görseli Değiştir', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Row(
                                    children: [
                                      Icon(Icons.share_rounded, color: Colors.white70, size: 18),
                                      SizedBox(width: 8),
                                      Text('Paylaş', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      SizedBox(width: 8),
                                      Text('Kartı Sil', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
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
                ),
              ),

              // Bottom Semi-Transparent Scrollable Note Overlay Panel (Görsele Ait Not Penceresi)
              if (imageNoteText.isNotEmpty || overlaySections.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showUI ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_showUI,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          height: _noteOverlayHeight.clamp(80.0, MediaQuery.of(context).size.height * 0.75),
                          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.7), width: 1.3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 4)),
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
                                    _noteOverlayHeight = (_noteOverlayHeight - details.delta.dy)
                                        .clamp(80.0, MediaQuery.of(context).size.height * 0.75);
                                  });
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                    border: const Border(bottom: BorderSide(color: Colors.white10, width: 0.8)),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 44,
                                      height: 4.5,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF14B8A6),
                                        borderRadius: BorderRadius.circular(2.5),
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
                                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
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
                                          for (int sIndex = 0; sIndex < overlaySections.length; sIndex++) ...[
                                            if (sIndex > 0) const SizedBox(height: 6),
                                            Text(
                                              overlaySections[sIndex].isEmpty ? '---' : overlaySections[sIndex],
                                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
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
                ),

            ],
          ),
        );
      },
    );
  }
}
