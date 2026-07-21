import '../../domain/models/note.dart';
import '../services/database_service.dart';

class NoteRepository {
  List<Note> getAllNotes() {
    final box = DatabaseService.getNotesBox();
    final notes = box.values.toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Note? getNoteById(String id) {
    final box = DatabaseService.getNotesBox();
    try {
      return box.values.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addNote(Note note) async {
    final box = DatabaseService.getNotesBox();
    await box.put(note.id, note);
  }

  Future<void> updateNote(Note note) async {
    final box = DatabaseService.getNotesBox();
    await box.put(note.id, note);
  }

  Future<void> deleteNote(String id) async {
    final box = DatabaseService.getNotesBox();
    await box.delete(id);
  }
}
