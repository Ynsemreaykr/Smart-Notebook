import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/services.dart';
import '../../domain/models/photo_note.dart';

class PhotoNoteProvider extends ChangeNotifier {
  static const String _boxName = 'photo_notes';
  static const _launchChannel = MethodChannel('com.example.smart_notebook/launch');
  final Uuid _uuid = const Uuid();

  List<PhotoNote> _photoNotes = [];
  List<String> _customCategories = [];
  bool _isLoading = false;
  String _selectedCategory = 'Tümü';

  List<PhotoNote> get photoNotes => _photoNotes;
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

  /// Load photo notes and categories from Hive
  Future<void> loadPhotoNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      final box = Hive.box(_boxName);
      final List<PhotoNote> loaded = [];

      for (var key in box.keys) {
        if (key == 'categories_list') continue;
        final data = box.get(key);
        if (data is Map) {
          loaded.add(PhotoNote.fromMap(data));
        }
      }

      // Load custom categories
      final savedCats = box.get('categories_list');
      if (savedCats != null) {
        _customCategories = List<String>.from(savedCats);
      } else {
        _customCategories = [];
      }

      // Sort by updatedAt (newest first)
      loaded.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _photoNotes = loaded;
      _updateWidget();
    } catch (e) {
      debugPrint('Error loading photo notes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new photo note
  Future<PhotoNote> addPhotoNote({
    required String title,
    required File imageFile,
    required String category,
    required String color,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // 1. Copy image file to app's local documents directory to keep it permanently
    final directory = await getApplicationDocumentsDirectory();
    final extension = imageFile.path.split('.').last;
    final targetPath = '${directory.path}/photonote_$id.$extension';
    final savedFile = await imageFile.copy(targetPath);

    // 2. Create the photo note object
    final newNote = PhotoNote(
      id: id,
      title: title.isEmpty ? 'Yeni Görsel Not' : title,
      imagePath: savedFile.path,
      category: category.trim(),
      color: color,
      createdAt: now,
      updatedAt: now,
    );

    // 3. Save to Hive
    final box = Hive.box(_boxName);
    await box.put(id, newNote.toMap());

    // 4. Reload notes
    await loadPhotoNotes();
    return newNote;
  }

  /// Update an existing photo note
  Future<void> updatePhotoNote({
    required String id,
    String? title,
    File? newImageFile,
    String? category,
    String? color,
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
      updatedAt: DateTime.now(),
    );

    // 3. Save to Hive
    await box.put(id, updatedNote.toMap());

    // 4. Reload notes
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

  /// Rename an existing category/folder and update all containing notes
  Future<void> renameCategory(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    // Check if new name already exists in categories list (case-insensitive check)
    final exists = _customCategories.any((cat) => cat.toLowerCase() == newTrimmed.toLowerCase() && cat != oldTrimmed);
    if (exists) return;

    // Rename in list
    final index = _customCategories.indexOf(oldTrimmed);
    if (index != -1) {
      _customCategories[index] = newTrimmed;
    } else {
      _customCategories.remove(oldTrimmed);
      _customCategories.add(newTrimmed);
    }

    final box = Hive.box(_boxName);
    await box.put('categories_list', _customCategories);

    // Update all notes with old category
    for (var key in box.keys) {
      if (key == 'categories_list') continue;
      final data = box.get(key);
      if (data is Map) {
        final note = PhotoNote.fromMap(data);
        if (note.category.trim() == oldTrimmed) {
          final updatedNote = note.copyWith(category: newTrimmed);
          await box.put(key, updatedNote.toMap());
        }
      }
    }

    await loadPhotoNotes();
  }

  /// Delete a category / folder and all notes inside it
  Future<void> deleteCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    _customCategories.remove(trimmed);
    final box = Hive.box(_boxName);
    await box.put('categories_list', _customCategories);

    // Delete all notes belonging to this category
    final keysToDelete = [];
    for (var key in box.keys) {
      if (key == 'categories_list') continue;
      final data = box.get(key);
      if (data is Map) {
        final note = PhotoNote.fromMap(data);
        if (note.category.trim() == trimmed) {
          keysToDelete.add(key);
          // Delete image file if it exists
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
    }

    for (var key in keysToDelete) {
      await box.delete(key);
    }

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
