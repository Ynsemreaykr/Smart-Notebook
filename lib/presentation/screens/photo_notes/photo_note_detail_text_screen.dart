import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../domain/models/photo_note.dart';
import '../../../application/providers/photo_note_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../widgets/common/app_text.dart';
import '../../../widgets/common/app_container.dart';
import '../../../widgets/common/app_card.dart';

class PhotoNoteDetailTextScreen extends StatefulWidget {
  final String noteId;
  const PhotoNoteDetailTextScreen({super.key, required this.noteId});

  @override
  State<PhotoNoteDetailTextScreen> createState() => _PhotoNoteDetailTextScreenState();
}

class _PhotoNoteDetailTextScreenState extends State<PhotoNoteDetailTextScreen> {
  late TextEditingController _textController;
  Timer? _debounceTimer;
  bool _isSaving = false;

  final List<String> _quickSymbols = ['↑', '↓', '←', '→', '↗', '↘', '•', '⭐', '✔️', '⚠️'];

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    final provider = context.read<PhotoNoteProvider>();
    final noteIndex = provider.photoNotes.indexWhere((n) => n.id == widget.noteId);
    final initialNote = noteIndex != -1 ? provider.photoNotes[noteIndex].note : '';
    _textController = TextEditingController(text: initialNote);
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _debounceTimer?.cancel();
    _saveNoteImmediate();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveNoteImmediate();
    });
  }

  Future<void> _saveNoteImmediate() async {
    if (!mounted) return;
    try {
      final provider = context.read<PhotoNoteProvider>();
      final noteIndex = provider.photoNotes.indexWhere((n) => n.id == widget.noteId);
      if (noteIndex != -1) {
        await provider.updatePhotoNoteText(widget.noteId, _textController.text);
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _insertSymbol(String symbol) {
    final text = _textController.text;
    final selection = _textController.selection;
    int start = selection.start;
    int end = selection.end;

    if (start < 0 || start > text.length) start = text.length;
    if (end < 0 || end > text.length) end = text.length;

    final newText = text.replaceRange(start, end, symbol);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );

    _saveNoteImmediate();
  }

  void _indentCurrentLine({bool reverse = false}) {
    final text = _textController.text;
    final selection = _textController.selection;
    int cursorStart = selection.start;
    int cursorEnd = selection.end;

    if (cursorStart < 0) cursorStart = text.length;
    if (cursorEnd < 0) cursorEnd = text.length;

    final minPos = cursorStart < cursorEnd ? cursorStart : cursorEnd;
    final maxPos = cursorStart > cursorEnd ? cursorStart : cursorEnd;

    // Find start of the first line in selection
    int firstLineStart = text.lastIndexOf('\n', minPos > 0 ? minPos - 1 : 0);
    firstLineStart = firstLineStart == -1 ? 0 : firstLineStart + 1;

    // Find end of the last line in selection
    int lastLineEnd = text.indexOf('\n', maxPos);
    if (lastLineEnd == -1) lastLineEnd = text.length;

    // Process all lines in the selection range
    final selectedChunk = text.substring(firstLineStart, lastLineEnd);
    final lines = selectedChunk.split('\n');

    int addedTotal = 0;
    int firstLineAdded = 0;
    List<String> modifiedLines = [];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (!reverse) {
        // Indent: Add 4 spaces
        modifiedLines.add('    $line');
        addedTotal += 4;
        if (i == 0) firstLineAdded = 4;
      } else {
        // Outdent: Remove up to 4 leading spaces
        int spacesToRemove = 0;
        while (spacesToRemove < 4 && spacesToRemove < line.length && line[spacesToRemove] == ' ') {
          spacesToRemove++;
        }
        modifiedLines.add(line.substring(spacesToRemove));
        addedTotal -= spacesToRemove;
        if (i == 0) firstLineAdded = -spacesToRemove;
      }
    }

    final newChunk = modifiedLines.join('\n');
    final newText = text.replaceRange(firstLineStart, lastLineEnd, newChunk);

    int newCursorStart = cursorStart + firstLineAdded;
    int newCursorEnd = cursorEnd + addedTotal;

    if (newCursorStart < 0) newCursorStart = 0;
    if (newCursorEnd < 0) newCursorEnd = 0;
    if (newCursorStart > newText.length) newCursorStart = newText.length;
    if (newCursorEnd > newText.length) newCursorEnd = newText.length;

    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: newCursorStart,
        extentOffset: newCursorEnd,
      ),
    );

    _saveNoteImmediate();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1E3A8A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoNoteProvider>(
      builder: (context, provider, child) {
        final notes = provider.photoNotes;
        final noteIndex = notes.indexWhere((n) => n.id == widget.noteId);

        if (noteIndex == -1) {
          return AppContainer(
            hasGradient: true,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(title: const Text('Not Bulunamadı')),
              body: const Center(
                child: AppText('İlgili görsel not bulunamadı.', styleType: AppTextStyleType.bodyLarge),
              ),
            ),
          );
        }

        final note = notes[noteIndex];
        final cardColor = _parseColor(note.color);

        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            _saveNoteImmediate();
          },
          child: AppContainer(
            hasGradient: true,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () {
                    _saveNoteImmediate();
                    Navigator.pop(context);
                  },
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      note.title,
                      styleType: AppTextStyleType.headingMedium,
                      styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppText(
                      'Görsel Ders Notu • ${note.category.isEmpty ? 'Genel' : note.category}',
                      styleType: AppTextStyleType.caption,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF14B8A6),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14B8A6).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(AppRadius.small),
                                  border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.5), width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_done_rounded, size: 14, color: Color(0xFF14B8A6)),
                                    SizedBox(width: 4),
                                    AppText(
                                      'Kaydedildi',
                                      styleType: AppTextStyleType.caption,
                                      styleOverride: TextStyle(
                                        color: Color(0xFF14B8A6),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
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
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Visual Card Info Header (Shows which photo note card this belongs to)
                    AppCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.all(12.0),
                      borderColor: cardColor.withOpacity(0.4),
                      shadowColor: cardColor,
                      child: Row(
                        children: [
                          // Image Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.small),
                            child: Image.file(
                              File(note.imagePath),
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 52,
                                height: 52,
                                color: cardColor,
                                child: const Icon(Icons.image_not_supported_rounded, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title and info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.collections_bookmark_rounded, size: 16, color: Color(0xFF14B8A6)),
                                    const SizedBox(width: 4),
                                    AppText(
                                      note.category.isEmpty ? 'Genel' : note.category,
                                      styleType: AppTextStyleType.caption,
                                      styleOverride: const TextStyle(
                                        color: Color(0xFF14B8A6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                AppText(
                                  note.title,
                                  styleType: AppTextStyleType.bodyLarge,
                                  styleOverride: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                AppText(
                                  'Bu görsel için ek ders notları ve açıklamalar',
                                  styleType: AppTextStyleType.caption,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Quick Toolbar (Indent + Symbols)
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: AppColors.surfaceLighter, width: 1),
                      ),
                      child: Row(
                        children: [
                          // Indent Increase Button (Girinti İçeri)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: const Icon(Icons.format_indent_increase_rounded, color: Color(0xFF14B8A6), size: 22),
                            tooltip: 'Satırı İçeri Al (Girinti)',
                            onPressed: () => _indentCurrentLine(reverse: false),
                          ),
                          // Indent Decrease Button (Girinti Dışarı)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: const Icon(Icons.format_indent_decrease_rounded, color: Colors.white70, size: 22),
                            tooltip: 'Satırı Dışarı Al (Girintiyi Kaldır)',
                            onPressed: () => _indentCurrentLine(reverse: true),
                          ),
                          const VerticalDivider(color: Colors.white24, width: 12, indent: 6, endIndent: 6),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _quickSymbols.length,
                              itemBuilder: (context, index) {
                                final sym = _quickSymbols[index];
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _insertSymbol(sym),
                                      borderRadius: BorderRadius.circular(AppRadius.small),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLighter,
                                          borderRadius: BorderRadius.circular(AppRadius.small),
                                          border: Border.all(
                                            color: const Color(0xFF14B8A6).withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          sym,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapHMd,

                    // Main Text Area Container
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(color: AppColors.surfaceLighter, width: 1.5),
                        ),
                        child: TextField(
                          controller: _textController,
                          textCapitalization: TextCapitalization.sentences,
                          autofocus: false, // DO NOT open keyboard automatically until tapped!
                          maxLines: null,
                          expands: true,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                          decoration: InputDecoration(
                            hintText: 'Örn:\nDelta ovası oluşumunu kolaylaştırır:\n    az gelgit\n    çok alüvyon\n    enine kıyı\n\nNot almak için ekrana dokunabilirsiniz.',
                            hintStyle: TextStyle(color: AppColors.textMuted.withOpacity(0.6), fontSize: 14, height: 1.5),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
