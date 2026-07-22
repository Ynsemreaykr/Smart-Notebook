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

      _flashcards = loadedFlashcards
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

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

    for (var i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final ext = file.path.split('.').last;
      final timeStamp = DateTime.now().millisecondsSinceEpoch;
      final targetPath = '${directory.path}/photonote_${noteId}_${timeStamp}_$i.$ext';
      final saved = await file.copy(targetPath);
      newPaths.add(saved.path);
    }

    final updatedNote = existingNote.copyWith(
      imagePaths: newPaths,
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

    if (imageIndex < 0 || imageIndex >= paths.length) return;

    final removedPath = paths.removeAt(imageIndex);
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

    // 2. Delete database entry
    await box.delete(id);

    // 3. Reset selected category if it no longer exists
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

  /// Get direct sub-categories (units) of a parent category path
  List<String> getSubCategories(String parentPath) {
    final trimmedParent = parentPath.trim();
    final prefix = '$trimmedParent / ';
    final set = <String>{};
    for (var cat in _customCategories) {
      if (cat.startsWith(prefix)) {
        final rest = cat.substring(prefix.length);
        final subName = rest.split(' / ').first.trim();
        if (subName.isNotEmpty) {
          set.add(subName);
        }
      }
    }
    final list = set.toList()..sort();
    return list;
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

    // Update all notes with old category or sub-categories
    for (var key in box.keys) {
      if (key == 'categories_list' || key == 'notes_order') continue;
      final data = box.get(key);
      if (data is Map) {
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

    await loadPhotoNotes();
  }

  /// Delete a category / folder and all sub-units and notes inside it
  Future<void> deleteCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final prefix = '$trimmed / ';
    _customCategories.removeWhere((cat) => cat == trimmed || cat.startsWith(prefix));

    final box = Hive.box(_boxName);
    await box.put('categories_list', _customCategories);

    // Delete all notes belonging to this category or its sub-categories
    final keysToDelete = [];
    for (var key in box.keys) {
      if (key == 'categories_list' || key == 'notes_order') continue;
      final data = box.get(key);
      if (data is Map) {
        final note = PhotoNote.fromMap(data);
        final cat = note.category.trim();
        if (cat == trimmed || cat.startsWith(prefix)) {
          // Delete file
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

    for (var key in keysToDelete) {
      await box.delete(key);
    }

    await loadPhotoNotes();
  }

  /// Get list of flashcards for a specific category path
  List<Flashcard> getFlashcardsForCategory(String categoryPath) {
    final trimmed = categoryPath.trim();
    return _flashcards.where((f) => f.category.trim() == trimmed).toList();
  }

  /// Add a new Flashcard (Bilgi Kartı)
  Future<Flashcard> addFlashcard({
    required String frontText,
    required String backText,
    required String category,
    String color = '#14B8A6',
  }) async {
    final id = 'flashcard_${_uuid.v4()}';
    final now = DateTime.now();

    final card = Flashcard(
      id: id,
      frontText: frontText.trim(),
      backText: backText.trim(),
      category: category.trim(),
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
    String? color,
  }) async {
    final box = Hive.box(_boxName);
    final rawData = box.get(id);
    if (rawData == null || rawData is! Map) return;

    final existing = Flashcard.fromMap(rawData);
    final updated = existing.copyWith(
      frontText: frontText?.trim(),
      backText: backText?.trim(),
      color: color,
      updatedAt: DateTime.now(),
    );

    await box.put(id, updated.toMap());
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
