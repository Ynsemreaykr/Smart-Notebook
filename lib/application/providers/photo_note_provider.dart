import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/services.dart';
import '../../domain/models/photo_note.dart';
import '../../domain/models/flashcard.dart';

class PhotoNoteProvider extends ChangeNotifier {
  static const String _boxName = 'photo_notes';
  static const _launchChannel = MethodChannel('com.example.smart_notebook/launch');
  final Uuid _uuid = const Uuid();

  List<PhotoNote> _photoNotes = [];
  List<Flashcard> _flashcards = [];
  List<String> _customCategories = [];
  bool _isLoading = false;
  String _selectedCategory = 'Tümü';

  List<PhotoNote> get photoNotes => _photoNotes;
  List<Flashcard> get flashcards => _flashcards;
  List<String> get customCategories => _customCategories;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  /// Get list of all categories
  List<String> get allCategories {
    final list = _customCategories.toList()..sort();
    return list;
  }

  /// Get list of filtered photo notes based on selected category
  List<PhotoNote> get filteredNotes {
    if (_selectedCategory == 'Tümü' || _selectedCategory.isEmpty) {
      return _photoNotes;
    }
    return _photoNotes.where((note) => note.category == _selectedCategory).toList();
  }

  /// Get list of all unique categories present in photo notes
  List<String> get categories {
    final list = _customCategories.toList()..sort();
    return list;
  }

  set selectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Load photo notes, flashcards, and categories from Hive
  Future<void> loadPhotoNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = Hive.box(_boxName);
      final Map<String, PhotoNote> loadedMap = {};
      final List<Flashcard> loadedFlashcards = [];

      for (var key in box.keys) {
        if (key == 'categories_list' || key == 'notes_order') continue;
        final data = box.get(key);
        if (data is Map) {
          if (data.containsKey('frontText')) {
            loadedFlashcards.add(Flashcard.fromMap(data));
          } else if (data.containsKey('imagePath')) {
            final note = PhotoNote.fromMap(data);
            loadedMap[note.id] = note;
          }
        }
      }

      // Sort flashcards by saved order if available
      final savedFlashcardOrder = box.get('flashcards_order');
      final Map<String, Flashcard> flashcardsMap = {for (var f in loadedFlashcards) f.id: f};
      final List<Flashcard> sortedFlashcards = [];

      if (savedFlashcardOrder is List) {
        for (var id in savedFlashcardOrder) {
          if (flashcardsMap.containsKey(id)) {
            sortedFlashcards.add(flashcardsMap.remove(id)!);
          }
        }
      }
      final remainingFlashcards = flashcardsMap.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      sortedFlashcards.addAll(remainingFlashcards);
      _flashcards = sortedFlashcards;

      // Load custom categories
      final savedCats = box.get('categories_list');
      if (savedCats != null) {
        _customCategories = List<String>.from(savedCats);
      } else {
        _customCategories = [];
      }

      // Load saved order if available
      final savedOrder = box.get('notes_order');
      final List<PhotoNote> sortedNotes = [];

      if (savedOrder is List) {
        for (var id in savedOrder) {
          if (loadedMap.containsKey(id)) {
            sortedNotes.add(loadedMap.remove(id)!);
          }
        }
      }

      // Add any remaining notes sorted by updatedAt (newest first)
      final remaining = loadedMap.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      sortedNotes.addAll(remaining);

      _photoNotes = sortedNotes;
      _updateWidget();
    } catch (e) {
      debugPrint('Error loading photo notes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reorder filtered notes within a specific category
  Future<void> reorderCategoryNotes(List<PhotoNote> categoryNotes, int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= categoryNotes.length) return;
    if (newIndex < 0 || newIndex >= categoryNotes.length) return;
    if (oldIndex == newIndex) return;

    final item = categoryNotes.removeAt(oldIndex);
    categoryNotes.insert(newIndex, item);

    // Rebuild main _photoNotes list maintaining category order
    final updatedList = <PhotoNote>[];
    int catIdx = 0;
    for (var note in _photoNotes) {
      if (categoryNotes.any((n) => n.id == note.id)) {
        if (catIdx < categoryNotes.length) {
          updatedList.add(categoryNotes[catIdx++]);
        }
      } else {
        updatedList.add(note);
      }
    }

    _photoNotes = updatedList;

    // Save order list in Hive
    final box = Hive.box(_boxName);
    final orderList = _photoNotes.map((n) => n.id).toList();
    await box.put('notes_order', orderList);

    _updateWidget();
    notifyListeners();
  }

  /// Add a new photo note
  Future<PhotoNote> addPhotoNote({
    required String title,
    required File imageFile,
    List<File>? extraImageFiles,
    required String category,
    required String color,
    String note = '',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final directory = await getApplicationDocumentsDirectory();
    final extension = imageFile.path.split('.').last;
    final targetPath = '${directory.path}/photonote_$id.$extension';
    final savedFile = await imageFile.copy(targetPath);

    final List<String> allPaths = [savedFile.path];
    if (extraImageFiles != null) {
      for (int i = 0; i < extraImageFiles.length; i++) {
        final file = extraImageFiles[i];
        final ext = file.path.split('.').last;
        final extraPath = '${directory.path}/photonote_${id}_extra_$i.$ext';
        final savedExtra = await file.copy(extraPath);
        allPaths.add(savedExtra.path);
      }
    }

    final newNote = PhotoNote(
      id: id,
      title: title.isEmpty ? 'Yeni Görsel Not' : title,
      imagePath: savedFile.path,
      imagePaths: allPaths,
      category: category.trim(),
      color: color,
      note: note.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final box = Hive.box(_boxName);
    await box.put(id, newNote.toMap());
    await loadPhotoNotes();
    return newNote;
  }

  /// Add extra images to an existing photo note
  Future<void> addExtraImagesToNote(String noteId, List<File> imageFiles) async {
    if (imageFiles.isEmpty) return;

    final box = Hive.box(_boxName);
    final rawData = box.get(noteId);
    if (rawData == null || rawData is! Map) return;

    final existingNote = PhotoNote.fromMap(rawData);
    final directory = await getApplicationDocumentsDirectory();
    final List<String> newPaths = List<String>.from(existingNote.imagePaths);
    final List<String> newNotes = List<String>.from(existingNote.imageNotes);

    for (var i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final ext = file.path.split('.').last;
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${directory.path}/photonote_${noteId}_${timeStamp}_$i.$ext';
      final saved = await file.copy(targetPath);
      newPaths.add(saved.path);
      newNotes.add('');
    }

    final updatedNote = existingNote.copyWith(
      imagePaths: newPaths,
      imageNotes: newNotes,
      updatedAt: DateTime.now(),
    );

    await box.put(noteId, updatedNote.toMap());
    await loadPhotoNotes();
  }

  /// Remove a specific image at imageIndex from a photo note
  Future<void> removeImageFromNote(String noteId, int imageIndex) async {
    final box = Hive.box(_boxName);
    final rawData = box.get(noteId);
    if (rawData == null || rawData is! Map) return;

    final existingNote = PhotoNote.fromMap(rawData);
    final paths = List<String>.from(existingNote.imagePaths);
    final notes = List<String>.from(existingNote.imageNotes);

    if (imageIndex < 0 || imageIndex >= paths.length) return;

    final removedPath = paths.removeAt(imageIndex);
    if (imageIndex < notes.length) {
      notes.removeAt(imageIndex);
    }
    try {
      final file = File(removedPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting sub-image: $e');
    }

    if (paths.isEmpty) {
      await deletePhotoNote(noteId);
      return;
    }

    final updatedNote = existingNote.copyWith(
      imagePath: paths.first,
      imagePaths: paths,
      imageNotes: notes,
      updatedAt: DateTime.now(),
    );

    await box.put(noteId, updatedNote.toMap());
    await loadPhotoNotes();
  }

  /// Update note text for a specific image index in a photo note
  Future<void> updateImageNote(String noteId, int imageIndex, String noteText) async {
    final box = Hive.box(_boxName);
    final rawData = box.get(noteId);
    if (rawData == null || rawData is! Map) return;

    final existingNote = PhotoNote.fromMap(rawData);
    final notes = List<String>.from(existingNote.imageNotes);

    while (notes.length < existingNote.imagePaths.length) {
      notes.add('');
    }

    if (imageIndex >= 0 && imageIndex < notes.length) {
      notes[imageIndex] = noteText.trim();
    }

    final updatedNote = existingNote.copyWith(
      imageNotes: notes,
      note: imageIndex == 0 ? noteText.trim() : existingNote.note,
      updatedAt: DateTime.now(),
    );

    await box.put(noteId, updatedNote.toMap());
    await loadPhotoNotes();
  }

  /// Update an existing photo note
  Future<void> updatePhotoNote({
    required String id,
    String? title,
    File? newImageFile,
    String? category,
    String? color,
    String? note,
  }) async {
    final box = Hive.box(_boxName);
    final rawData = box.get(id);
    if (rawData == null || rawData is! Map) return;

    final existingNote = PhotoNote.fromMap(rawData);
    String imagePath = existingNote.imagePath;

    // 1. If a new image is provided, delete the old one and save the new one
    if (newImageFile != null) {
      // Delete old file
      try {
        final oldFile = File(existingNote.imagePath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting old image: $e');
      }

      // Copy new file
      final directory = await getApplicationDocumentsDirectory();
      final extension = newImageFile.path.split('.').last;
      final targetPath = '${directory.path}/photonote_$id.$extension';
      final savedFile = await newImageFile.copy(targetPath);
      imagePath = savedFile.path;
    }

    // 2. Create updated note object
    final updatedNote = existingNote.copyWith(
      title: title,
      imagePath: imagePath,
      category: category?.trim(),
      color: color,
      note: note?.trim(),
      updatedAt: DateTime.now(),
    );

    // 3. Save to Hive
    await box.put(id, updatedNote.toMap());

    // 4. Reload notes
    await loadPhotoNotes();
  }

  /// Quick update for written note text of a photo note
  Future<void> updatePhotoNoteText(String id, String textNote) async {
    final box = Hive.box(_boxName);
    final rawData = box.get(id);
    if (rawData == null || rawData is! Map) return;

    final existingNote = PhotoNote.fromMap(rawData);
    final updatedNote = existingNote.copyWith(
      note: textNote.trim(),
      updatedAt: DateTime.now(),
    );

    await box.put(id, updatedNote.toMap());
    await loadPhotoNotes();
  }

  /// Delete a photo note and its corresponding image file
  Future<void> deletePhotoNote(String id) async {
    final box = Hive.box(_boxName);
    final rawData = box.get(id);
    if (rawData == null || rawData is! Map) return;

    final note = PhotoNote.fromMap(rawData);

    // 1. Delete image file from device storage
    try {
      final file = File(note.imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting image file: $e');
    }

    // 2. Delete database entry for note
    await box.delete(id);

    // 3. Delete any linked flashcards for this note
    final cardKeysToDelete = [];
    for (var key in box.keys) {
      if (key == 'categories_list' || key == 'notes_order') continue;
      final data = box.get(key);
      if (data is Map && data.containsKey('frontText')) {
        final card = Flashcard.fromMap(data);
        if (card.noteId == id) {
          cardKeysToDelete.add(key);
        }
      }
    }
    for (var key in cardKeysToDelete) {
      await box.delete(key);
    }

    // 4. Reset selected category if it no longer exists
    final remainingNotes = _photoNotes.where((n) => n.id != id).toList();
    final categoriesSet = remainingNotes.map((n) => n.category.trim()).toSet();
    if (_selectedCategory != 'Tümü' && !categoriesSet.contains(_selectedCategory)) {
      _selectedCategory = 'Tümü';
    }

    // 4. Reload notes
    await loadPhotoNotes();
  }

  /// Update Android Home Widget data
  Future<void> _updateWidget() async {
    try {
      // Serialize all photo notes: id||title||category||color
      final rawData = _photoNotes.map((note) {
        final categoryText = note.category.isEmpty ? ' ' : note.category;
        final colorText = note.color.isEmpty ? '#14B8A6' : note.color;
        return '${note.id}||${note.title}||$categoryText||$colorText';
      }).join('::');

      await HomeWidget.saveWidgetData<String>('photo_notes_widget_data', rawData);

      await HomeWidget.updateWidget(
        name: 'PhotoNoteWidgetProvider',
        iOSName: 'PhotoNoteWidgetProvider',
      );
      
      // Force instant update on Xiaomi/MIUI via foreground broadcast channel
      await _launchChannel.invokeMethod('updatePhotoWidget');
    } catch (e) {
      debugPrint('Error updating photo note widget: $e');
    }
  }

  /// Add an empty category / folder
  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final exists = _customCategories.any((cat) => cat.toLowerCase() == trimmed.toLowerCase());
    if (!exists) {
      _customCategories.add(trimmed);
      final box = Hive.box(_boxName);
      await box.put('categories_list', _customCategories);
      notifyListeners();
      await _updateWidget();
    }
  }

  /// Get top-level categories (categories without ' / ' separator or base subjects)
  List<String> get topLevelCategories {
    final set = <String>{};
    for (var cat in _customCategories) {
      final parts = cat.split(' / ');
      if (parts.first.trim().isNotEmpty) {
        set.add(parts.first.trim());
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Get direct sub-categories (units) of a parent category path preserving custom order
  List<String> getSubCategories(String parentPath) {
    final trimmedParent = parentPath.trim();
    final prefix = '$trimmedParent / ';
    final list = <String>[];
    for (var cat in _customCategories) {
      if (cat.startsWith(prefix)) {
        final rest = cat.substring(prefix.length);
        final subName = rest.split(' / ').first.trim();
        if (subName.isNotEmpty && !list.contains(subName)) {
          list.add(subName);
        }
      }
    }
    return list;
  }

  /// Reorder direct sub-categories (units) under a parent category path
  Future<void> reorderSubCategories(String parentPath, int oldIndex, int newIndex) async {
    final subCats = getSubCategories(parentPath);
    if (oldIndex < 0 || oldIndex >= subCats.length) return;
    if (newIndex < 0 || newIndex >= subCats.length) return;
    if (oldIndex == newIndex) return;

    final moved = subCats.removeAt(oldIndex);
    subCats.insert(newIndex, moved);

    final prefix = '${parentPath.trim()} / ';
    final Map<String, List<String>> subGroupMap = {};

    for (var cat in _customCategories) {
      if (cat.startsWith(prefix)) {
        final rest = cat.substring(prefix.length);
        final subName = rest.split(' / ').first.trim();
        subGroupMap.putIfAbsent(subName, () => []).add(cat);
      }
    }

    final updatedCategories = <String>[];
    for (var cat in _customCategories) {
      if (!cat.startsWith(prefix)) {
        updatedCategories.add(cat);
      }
    }

    for (var subName in subCats) {
      final list = subGroupMap[subName];
      if (list != null) {
        updatedCategories.addAll(list);
      }
    }

    _customCategories = updatedCategories;
    final box = Hive.box(_boxName);
    await box.put('categories_list', _customCategories);
    notifyListeners();
  }


  /// Add a sub-category / unit under a parent path
  Future<void> addSubCategory(String parentPath, String subCategoryName) async {
    final name = subCategoryName.trim();
    if (name.isEmpty) return;
    final fullPath = '$parentPath / $name';
    await addCategory(fullPath);
  }

  /// Get count of notes under a category path
  int getNoteCountForCategory(String categoryPath, {bool includeSubCategories = true}) {
    final trimmed = categoryPath.trim();
    if (includeSubCategories) {
      final prefix = '$trimmed / ';
      return _photoNotes.where((n) => n.category.trim() == trimmed || n.category.trim().startsWith(prefix)).length;
    } else {
      return _photoNotes.where((n) => n.category.trim() == trimmed).length;
    }
  }

  /// Rename an existing category/folder (including all its sub-units and notes)
  Future<void> renameCategory(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    final oldPrefix = '$oldTrimmed / ';
    final List<String> updatedCatList = [];

    for (var cat in _customCategories) {
      if (cat == oldTrimmed) {
        updatedCatList.add(newTrimmed);
      } else if (cat.startsWith(oldPrefix)) {
        final rest = cat.substring(oldPrefix.length);
        updatedCatList.add('$newTrimmed / $rest');
      } else {
        updatedCatList.add(cat);
      }
    }

    _customCategories = updatedCatList;
    final box = Hive.box(_boxName);
    await box.put('categories_list', _customCategories);

    // Update all notes and flashcards with old category or sub-categories
    for (var key in box.keys) {
      if (key == 'categories_list' || key == 'notes_order') continue;
      final data = box.get(key);
      if (data is Map) {
        if (data.containsKey('frontText')) {
          final card = Flashcard.fromMap(data);
          final cat = card.category.trim();
          if (cat == oldTrimmed) {
            final updatedCard = card.copyWith(category: newTrimmed);
            await box.put(key, updatedCard.toMap());
          } else if (cat.startsWith(oldPrefix)) {
            final rest = cat.substring(oldPrefix.length);
            final updatedCard = card.copyWith(category: '$newTrimmed / $rest');
            await box.put(key, updatedCard.toMap());
          }
        } else if (data.containsKey('imagePath')) {
          final note = PhotoNote.fromMap(data);
          final cat = note.category.trim();
          if (cat == oldTrimmed) {
            final updatedNote = note.copyWith(category: newTrimmed);
            await box.put(key, updatedNote.toMap());
          } else if (cat.startsWith(oldPrefix)) {
            final rest = cat.substring(oldPrefix.length);
            final updatedNote = note.copyWith(category: '$newTrimmed / $rest');
            await box.put(key, updatedNote.toMap());
          }
        }
      }
    }

    await loadPhotoNotes();
  }

  /// Delete a category / folder and all sub-units, notes, and flashcards inside it
  Future<void> deleteCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final prefix = '$trimmed / ';
    _customCategories.removeWhere((cat) => cat == trimmed || cat.startsWith(prefix));

    final box = Hive.box(_boxName);
    await box.put('categories_list', _customCategories);

    // Delete all notes and flashcards belonging to this category or its sub-categories
    final keysToDelete = [];
    for (var key in box.keys) {
      if (key == 'categories_list' || key == 'notes_order') continue;
      final data = box.get(key);
      if (data is Map) {
        if (data.containsKey('frontText')) {
          final card = Flashcard.fromMap(data);
          final cat = card.category.trim();
          if (cat == trimmed || cat.startsWith(prefix)) {
            keysToDelete.add(key);
          }
        } else if (data.containsKey('imagePath')) {
          final note = PhotoNote.fromMap(data);
          final cat = note.category.trim();
          if (cat == trimmed || cat.startsWith(prefix)) {
            try {
              final file = File(note.imagePath);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              debugPrint('Error deleting note file: $e');
            }
            keysToDelete.add(key);
          }
        }
      }
    }

    for (var key in keysToDelete) {
      await box.delete(key);
    }

    await loadPhotoNotes();
  }

  /// Get list of flashcards for a specific category path (only category-wide flashcards, excluding note-specific ones)
  List<Flashcard> getFlashcardsForCategory(String categoryPath) {
    final trimmed = categoryPath.trim();
    return _flashcards
        .where((f) => f.category.trim() == trimmed && (f.noteId == null || f.noteId!.trim().isEmpty))
        .toList();
  }

  /// Get list of flashcards linked specifically to a PhotoNote
  List<Flashcard> getFlashcardsForNote(String noteId) {
    return _flashcards.where((f) => f.noteId == noteId).toList();
  }

  /// Get flashcards grouped by heading/groupTitle for a category in saved group order
  Map<String, List<Flashcard>> getGroupedFlashcardsForCategory(String categoryPath) {
    final cards = getFlashcardsForCategory(categoryPath);
    final Map<String, List<Flashcard>> map = {};
    for (var card in cards) {
      final group = card.groupTitle.trim().isEmpty ? 'Genel Bilgiler' : card.groupTitle.trim();
      map.putIfAbsent(group, () => []).add(card);
    }

    final box = Hive.box(_boxName);
    final savedGroupOrder = box.get('groups_order_$categoryPath');
    if (savedGroupOrder is List) {
      final Map<String, List<Flashcard>> orderedMap = {};
      for (var g in savedGroupOrder) {
        final gStr = g.toString();
        if (map.containsKey(gStr)) {
          orderedMap[gStr] = map.remove(gStr)!;
        }
      }
      orderedMap.addAll(map);
      return orderedMap;
    }
    return map;
  }

  /// Reorder flashcard group headers for a category
  Future<void> reorderFlashcardGroups(String categoryPath, int oldIndex, int newIndex) async {
    final map = getGroupedFlashcardsForCategory(categoryPath);
    final groupKeys = map.keys.toList();
    if (oldIndex < 0 || oldIndex >= groupKeys.length) return;
    if (newIndex < 0 || newIndex >= groupKeys.length) return;
    if (oldIndex == newIndex) return;

    final moved = groupKeys.removeAt(oldIndex);
    groupKeys.insert(newIndex, moved);

    final box = Hive.box(_boxName);
    await box.put('groups_order_$categoryPath', groupKeys);
    notifyListeners();
  }

  /// Reorder flashcards list order in provider & Hive
  Future<void> reorderFlashcards(List<Flashcard> cards, int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= cards.length) return;
    if (newIndex < 0 || newIndex >= cards.length) return;
    if (oldIndex == newIndex) return;

    final item = cards.removeAt(oldIndex);
    cards.insert(newIndex, item);

    final updated = <Flashcard>[];
    int idx = 0;
    for (var card in _flashcards) {
      if (cards.any((c) => c.id == card.id)) {
        if (idx < cards.length) {
          updated.add(cards[idx++]);
        }
      } else {
        updated.add(card);
      }
    }
    _flashcards = updated;

    final box = Hive.box(_boxName);
    final orderList = _flashcards.map((f) => f.id).toList();
    await box.put('flashcards_order', orderList);
    notifyListeners();
  }


  /// Get flashcards grouped by heading/groupTitle for a specific PhotoNote
  Map<String, List<Flashcard>> getGroupedFlashcardsForNote(String noteId) {
    final cards = getFlashcardsForNote(noteId);
    final Map<String, List<Flashcard>> map = {};
    for (var card in cards) {
      final group = card.groupTitle.trim().isEmpty ? 'Genel Bilgiler' : card.groupTitle.trim();
      map.putIfAbsent(group, () => []).add(card);
    }
    return map;
  }

  /// Add a new Flashcard (Bilgi Kartı)
  Future<Flashcard> addFlashcard({
    required String frontText,
    required String backText,
    required String category,
    String? noteId,
    String groupTitle = 'Genel Bilgiler',
    String color = '#14B8A6',
  }) async {
    final id = 'flashcard_${_uuid.v4()}';
    final now = DateTime.now();

    final card = Flashcard(
      id: id,
      frontText: frontText.trim(),
      backText: backText.trim(),
      category: category.trim(),
      noteId: noteId,
      groupTitle: groupTitle.trim().isEmpty ? 'Genel Bilgiler' : groupTitle.trim(),
      color: color,
      createdAt: now,
      updatedAt: now,
    );

    final box = Hive.box(_boxName);
    await box.put(id, card.toMap());
    await loadPhotoNotes();
    return card;
  }

  /// Update an existing Flashcard (Bilgi Kartı)
  Future<void> updateFlashcard({
    required String id,
    String? frontText,
    String? backText,
    String? groupTitle,
    String? color,
  }) async {
    final box = Hive.box(_boxName);
    final rawData = box.get(id);
    if (rawData == null || rawData is! Map) return;

    final existing = Flashcard.fromMap(rawData);
    final updated = existing.copyWith(
      frontText: frontText?.trim(),
      backText: backText?.trim(),
      groupTitle: groupTitle?.trim(),
      color: color,
      updatedAt: DateTime.now(),
    );

    await box.put(id, updated.toMap());
    await loadPhotoNotes();
  }

  /// Move a Flashcard to a different group heading
  Future<void> moveFlashcardToGroup({
    required String flashcardId,
    required String targetGroupTitle,
  }) async {
    final box = Hive.box(_boxName);
    final rawData = box.get(flashcardId);
    if (rawData == null || rawData is! Map) return;

    final existing = Flashcard.fromMap(rawData);
    final newTitle = targetGroupTitle.trim().isEmpty ? 'Genel Bilgiler' : targetGroupTitle.trim();
    if (existing.groupTitle.trim() == newTitle) return;

    final updated = existing.copyWith(
      groupTitle: newTitle,
      updatedAt: DateTime.now(),
    );

    await box.put(flashcardId, updated.toMap());
    await loadPhotoNotes();
  }

  /// Rename a group heading for flashcards in a category/note
  Future<void> renameFlashcardGroup({
    required String oldGroupTitle,
    required String newGroupTitle,
    required String category,
    String? noteId,
  }) async {
    final box = Hive.box(_boxName);
    final targetCards = _flashcards.where((f) {
      final matchCat = f.category.trim() == category.trim();
      final matchNote = (noteId == null || noteId.trim().isEmpty)
          ? (f.noteId == null || f.noteId!.trim().isEmpty)
          : f.noteId == noteId;
      final fGroup = f.groupTitle.trim().isEmpty ? 'Genel Bilgiler' : f.groupTitle.trim();
      final matchGroup = fGroup == oldGroupTitle.trim();
      return matchCat && matchNote && matchGroup;
    }).toList();

    for (var card in targetCards) {
      final updated = card.copyWith(
        groupTitle: newGroupTitle.trim().isEmpty ? 'Genel Bilgiler' : newGroupTitle.trim(),
        updatedAt: DateTime.now(),
      );
      await box.put(card.id, updated.toMap());
    }
    await loadPhotoNotes();
  }

  /// Delete a Flashcard (Bilgi Kartı)
  Future<void> deleteFlashcard(String id) async {
    final box = Hive.box(_boxName);
    await box.delete(id);
    await loadPhotoNotes();
  }

  /// Clear all photo notes and custom categories completely
  Future<void> clearAllNotes() async {
    final box = Hive.box(_boxName);
    
    // Delete all local image files
    for (var key in box.keys) {
      if (key == 'categories_list') continue;
      final data = box.get(key);
      if (data is Map) {
        final note = PhotoNote.fromMap(data);
        try {
          final file = File(note.imagePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting note image: $e');
        }
      }
    }
    
    // Clear entire database box
    await box.clear();
    _photoNotes = [];
    _customCategories = [];
    
    // Reinitialize empty category list
    await box.put('categories_list', []);
    
    await loadPhotoNotes();
  }
}
