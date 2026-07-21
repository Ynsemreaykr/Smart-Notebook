import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../../domain/models/note.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/services/notification_service.dart';
import 'package:home_widget/home_widget.dart';

class NoteProvider extends ChangeNotifier {
  final NoteRepository _noteRepository = NoteRepository();
  final Uuid _uuid = const Uuid();

  List<Note> _notes = [];
  bool _isLoading = false;

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;

  void loadNotes() {
    _isLoading = true;
    notifyListeners();
    final allNotes = _noteRepository.getAllNotes();
    allNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _notes = allNotes;
    _isLoading = false;
    notifyListeners();
    _updateWidget();
  }

  Future<void> _updateWidget() async {
    try {
      if (_notes.isNotEmpty) {
        final latestNote = _notes.first;
        await HomeWidget.saveWidgetData<String>('widget_title', latestNote.title);
        await HomeWidget.saveWidgetData<String>('widget_content', latestNote.content);
      } else {
        await HomeWidget.saveWidgetData<String>('widget_title', 'Smart Notebook');
        await HomeWidget.saveWidgetData<String>('widget_content', 'Henüz not yok.');
      }
      await HomeWidget.updateWidget(
        name: 'NoteWidgetProvider',
        iOSName: 'NoteWidgetProvider',
      );
    } catch (e) {
      debugPrint('Widget update error: $e');
    }
  }

  Future<Note> addNote(String title, {String content = '', String? color}) async {
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      color: color ?? _getRandomColor(),
    );
    await _noteRepository.addNote(note);
    loadNotes();
    return note;
  }

  Future<void> updateNote(String id, {String? title, String? content, DateTime? reminderTime}) async {
    final note = _noteRepository.getNoteById(id);
    if (note != null) {
      final updated = Note(
        id: note.id,
        title: title ?? note.title,
        content: content ?? note.content,
        createdAt: note.createdAt,
        updatedAt: DateTime.now(),
        color: note.color,
        reminderTime: reminderTime ?? note.reminderTime,
      );

      // Handle notification scheduling
      if (reminderTime != null) {
        await NotificationService().scheduleNotification(
          id: NotificationService().generateNotificationId(note.id),
          title: "Not Hatırlatıcı: ${updated.title}",
          body: updated.content.length > 50 ? "${updated.content.substring(0, 47)}..." : updated.content,
          scheduledTime: reminderTime,
          payload: "note_${note.id}",
        );
      } else if (reminderTime == null && note.reminderTime != null) {
        // Only cancel if specifically removing (optional logic, usually setReminder is used)
      }

      await _noteRepository.updateNote(updated);
      loadNotes();
    }
  }

  Future<void> setReminder(String id, DateTime? time) async {
    final note = _noteRepository.getNoteById(id);
    if (note != null) {
      if (time == null) {
        await NotificationService().cancelNotification(NotificationService().generateNotificationId(note.id));
      }
      await updateNote(id, reminderTime: time);
    }
  }

  Future<void> deleteNote(String id) async {
    await _noteRepository.deleteNote(id);
    loadNotes();
  }

  Note? getNoteById(String id) => _noteRepository.getNoteById(id);

  // --- Voice Notes Section (Kept separate from regular notes) ---
  List<Note> _voiceNotes = [];
  List<Note> get voiceNotes => _voiceNotes;

  Future<void> loadVoiceNotes() async {
    try {
      final box = Hive.box<Note>('voice_notes');
      final allVoiceNotes = box.values.toList();
      allVoiceNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _voiceNotes = allVoiceNotes;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading voice notes: $e');
    }
  }

  Future<Note> addVoiceNote(String title, {required String content}) async {
    final now = DateTime.now();
    final voiceNote = Note(
      id: _uuid.v4(),
      title: title.isEmpty ? 'Ses Kaydı - ${now.hour}:${now.minute}' : title,
      content: content,
      createdAt: now,
      updatedAt: now,
      color: '#9C27B0', // Purple theme color for voice notes
    );
    final box = Hive.box<Note>('voice_notes');
    await box.put(voiceNote.id, voiceNote);
    await loadVoiceNotes();
    return voiceNote;
  }

  Future<void> deleteVoiceNote(String id) async {
    final box = Hive.box<Note>('voice_notes');
    await box.delete(id);
    await loadVoiceNotes();
  }

  String _getRandomColor() {
    final colors = [
      '#FF9800', '#4CAF50', '#2196F3', '#9C27B0',
      '#F44336', '#00BCD4', '#FF5722', '#607D8B',
      '#E91E63', '#3F51B5',
    ];
    colors.shuffle();
    return colors.first;
  }
}
