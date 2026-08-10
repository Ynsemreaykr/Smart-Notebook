import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../application/providers/photo_note_provider.dart';
import '../../domain/models/photo_note.dart';

enum MoveCopyOperation { move, copy }

/// Shows a bottom sheet modal allowing users to Move or Copy a visual card (or a single image)
/// to another subject category, sub-unit, or existing card.
void showMoveOrCopyCardModal({
  required BuildContext context,
  required PhotoNote note,
  int? imageIndex,
  VoidCallback? onSuccess,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return _MoveOrCopyModalContent(
        note: note,
        imageIndex: imageIndex,
        onSuccess: onSuccess,
      );
    },
  );
}

class _MoveOrCopyModalContent extends StatefulWidget {
  final PhotoNote note;
  final int? imageIndex;
  final VoidCallback? onSuccess;

  const _MoveOrCopyModalContent({
    required this.note,
    this.imageIndex,
    this.onSuccess,
  });

  @override
  State<_MoveOrCopyModalContent> createState() => _MoveOrCopyModalContentState();
}

class _MoveOrCopyModalContentState extends State<_MoveOrCopyModalContent> {
  MoveCopyOperation _operation = MoveCopyOperation.move;
  late String _selectedCategory;
  String? _selectedSubUnit;
  PhotoNote? _selectedTargetNote;
  
  final TextEditingController _newCardTitleCtrl = TextEditingController();
  final TextEditingController _newCategoryCtrl = TextEditingController();
  bool _isCreatingNewCategory = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PhotoNoteProvider>();
    final categories = provider.customCategories;
    
    // Set default selected category to current note category or first category
    final currentCat = widget.note.category.split('/').first.trim();
    if (categories.contains(currentCat)) {
      _selectedCategory = currentCat;
    } else if (categories.isNotEmpty) {
      _selectedCategory = categories.first;
    } else {
      _selectedCategory = 'Tümü';
    }

    _newCardTitleCtrl.text = widget.note.title;
  }

  @override
  void dispose() {
    _newCardTitleCtrl.dispose();
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PhotoNoteProvider>();
    final categories = provider.customCategories;
    final subCategories = provider.getSubCategories(_selectedCategory);
    
    final categoryFilter = _selectedSubUnit != null ? '$_selectedCategory / $_selectedSubUnit' : _selectedCategory;
    final availableTargetNotes = _selectedCategory == 'Tümü'
        ? provider.photoNotes.where((n) => n.id != widget.note.id).toList()
        : provider.photoNotes
            .where((n) => (n.category.trim() == categoryFilter.trim() || n.category.startsWith('$categoryFilter / ')) && n.id != widget.note.id)
            .toList();

    final previewIndex = widget.imageIndex ?? 0;
    final previewPath = (previewIndex < widget.note.imagePaths.length)
        ? widget.note.imagePaths[previewIndex]
        : widget.note.imagePath;

    final isSingleImage = widget.imageIndex != null;
    final opText = _operation == MoveCopyOperation.move ? 'Taşı' : 'Kopyala';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Row(
              children: [
                const Icon(Icons.drive_file_move_rounded, color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSingleImage ? 'Görseli Başka Üniteye $opText' : 'Görsel Kartı Başka Üniteye $opText',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Image Preview Box
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6), width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPreviewImage(previewPath),
              ),
            ),
            const SizedBox(height: 14),

            // Operation Mode Segmented Selector (Taşı vs Kopyala)
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _operation = MoveCopyOperation.move),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _operation == MoveCopyOperation.move ? const Color(0xFFF59E0B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.drive_file_move_rounded, size: 16, color: _operation == MoveCopyOperation.move ? Colors.black : Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              '🚚 Taşı',
                              style: TextStyle(
                                color: _operation == MoveCopyOperation.move ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _operation = MoveCopyOperation.copy),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _operation == MoveCopyOperation.copy ? const Color(0xFF14B8A6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded, size: 16, color: _operation == MoveCopyOperation.copy ? Colors.black : Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              '📋 Kopyala',
                              style: TextStyle(
                                color: _operation == MoveCopyOperation.copy ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Ders / Klasör Selection
            Row(
              children: [
                const Icon(Icons.folder_open_rounded, color: Color(0xFF0EA5E9), size: 18),
                const SizedBox(width: 8),
                const Text('Ders / Klasör:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.5)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: categories.contains(_selectedCategory) ? _selectedCategory : (categories.isNotEmpty ? categories.first : 'Tümü'),
                        dropdownColor: const Color(0xFF1E293B),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: [
                          ...categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
                          const DropdownMenuItem(value: '__new__', child: Text('+ Yeni Ders Ekle...', style: TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.bold))),
                        ],
                        onChanged: (val) {
                          if (val == '__new__') {
                            setState(() => _isCreatingNewCategory = true);
                          } else if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              _selectedSubUnit = null;
                              _selectedTargetNote = null;
                              _isCreatingNewCategory = false;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // If creating new category, show TextField
            if (_isCreatingNewCategory) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _newCategoryCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Yeni Ders Adı (örn: Coğrafya)',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.black26,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF14B8A6))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5)),
                ),
              ),
            ],

            // Sub-Unit dropdown if available
            if (subCategories.isNotEmpty && !_isCreatingNewCategory) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.account_tree_rounded, color: Color(0xFF0EA5E9), size: 18),
                  const SizedBox(width: 8),
                  const Text('Ünite:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedSubUnit,
                          dropdownColor: const Color(0xFF1E293B),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          hint: const Text('Tüm Üniteler', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Tüm Üniteler')),
                            ...subCategories.map((sub) => DropdownMenuItem<String?>(value: sub, child: Text(sub))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedSubUnit = val;
                              _selectedTargetNote = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Görsel Kart Destination Dropdown
            Row(
              children: [
                const Icon(Icons.style_rounded, color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 8),
                const Text('Görsel Kart:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PhotoNote?>(
                        value: _selectedTargetNote,
                        dropdownColor: const Color(0xFF1E293B),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: [
                          const DropdownMenuItem<PhotoNote?>(
                            value: null,
                            child: Text(
                              '+ Yeni Görsel Kart Oluştur',
                              style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...availableTargetNotes.map((n) => DropdownMenuItem<PhotoNote?>(
                                value: n,
                                child: Text(n.title.isEmpty ? 'İsimsiz Kart' : n.title, overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedTargetNote = val;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // If creating new card, show TextField for title
            if (_selectedTargetNote == null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _newCardTitleCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Yeni Kart Başlığı (Örn: Dağlar Soru Bankası)',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.black26,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.2)),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Confirm Button
            ElevatedButton(
              onPressed: _isSaving ? null : _handleExecuteOperation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _operation == MoveCopyOperation.move ? const Color(0xFFF59E0B) : const Color(0xFF14B8A6),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_operation == MoveCopyOperation.move ? Icons.drive_file_move_rounded : Icons.copy_rounded, color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          isSingleImage ? 'Görseli $opText' : 'Görsel Kartı $opText',
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewImage(String path) {
    if (path.isEmpty) {
      return const Center(child: Icon(Icons.image_not_supported_rounded, color: Colors.white38, size: 30));
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 30));
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.contain);
    }
    return const Center(child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 30));
  }

  Future<void> _handleExecuteOperation() async {
    setState(() => _isSaving = true);
    final provider = context.read<PhotoNoteProvider>();

    try {
      // 1. Resolve Target Category
      String targetCategory = _selectedCategory;
      if (_isCreatingNewCategory && _newCategoryCtrl.text.trim().isNotEmpty) {
        targetCategory = _newCategoryCtrl.text.trim();
        await provider.addCategory(targetCategory);
      }
      if (_selectedSubUnit != null && _selectedSubUnit!.isNotEmpty) {
        targetCategory = '$targetCategory / $_selectedSubUnit';
      }

      final isMove = _operation == MoveCopyOperation.move;
      final isSingleImage = widget.imageIndex != null;

      if (isSingleImage) {
        final imgIndex = widget.imageIndex!;
        final srcImagePath = (imgIndex < widget.note.imagePaths.length) ? widget.note.imagePaths[imgIndex] : widget.note.imagePath;
        final srcImageNote = (imgIndex < widget.note.imageNotes.length) ? widget.note.imageNotes[imgIndex] : widget.note.note;
        final isQuestion = (imgIndex < widget.note.questionFlags.length) ? widget.note.questionFlags[imgIndex] : false;
        final srcFile = File(srcImagePath);

        if (_selectedTargetNote == null) {
          // Create new card for this image
          final newTitle = _newCardTitleCtrl.text.trim().isEmpty ? widget.note.title : _newCardTitleCtrl.text.trim();
          await provider.addPhotoNote(
            title: newTitle,
            imageFile: srcFile,
            category: targetCategory,
            note: srcImageNote,
            color: widget.note.color,
          );
        } else {
          // Append image to existing card
          await provider.addExtraImagesToNote(_selectedTargetNote!.id, [srcFile], isQuestion: isQuestion);
        }

        if (isMove) {
          await provider.removeImageFromNote(widget.note.id, imgIndex);
        }
      } else {
        // Move or Copy whole PhotoNote card
        if (_selectedTargetNote == null) {
          final newTitle = _newCardTitleCtrl.text.trim().isEmpty ? widget.note.title : _newCardTitleCtrl.text.trim();
          if (isMove) {
            await provider.updatePhotoNote(
              id: widget.note.id,
              category: targetCategory,
              title: newTitle,
            );
          } else {
            // Copy whole card
            final srcFile = File(widget.note.imagePath);
            final newNote = await provider.addPhotoNote(
              title: newTitle,
              imageFile: srcFile,
              category: targetCategory,
              note: widget.note.note,
              color: widget.note.color,
            );
            // Append extra images if multiple
            if (widget.note.imagePaths.length > 1) {
              final extraFiles = widget.note.imagePaths.skip(1).map((p) => File(p)).toList();
              await provider.addExtraImagesToNote(newNote.id, extraFiles);
            }
          }
        } else {
          // Append all images of whole card to selected target note
          final allFiles = widget.note.imagePaths.map((p) => File(p)).toList();
          await provider.addExtraImagesToNote(_selectedTargetNote!.id, allFiles);
          if (isMove) {
            await provider.deletePhotoNote(widget.note.id);
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        final actionName = isMove ? 'taşındı' : 'kopyalandı';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Görsel kart başarıyla $actionName.'),
            backgroundColor: isMove ? const Color(0xFFF59E0B) : const Color(0xFF14B8A6),
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      debugPrint('Error in move/copy operation: $e');
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
