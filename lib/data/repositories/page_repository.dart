import '../../domain/models/page.dart';
import '../services/database_service.dart';

class PageRepository {
  /// Get all pages for a specific book, ordered by orderIndex
  List<NotePage> getPagesByBookId(String bookId) {
    final box = DatabaseService.getPagesBox();
    final pages =
        box.values.where((page) => page.bookId == bookId).toList();
    pages.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return pages;
  }

  /// Get a single page by ID
  NotePage? getPageById(String id) {
    final box = DatabaseService.getPagesBox();
    try {
      return box.values.firstWhere((page) => page.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get the next order index for a book
  int getNextOrderIndex(String bookId) {
    final pages = getPagesByBookId(bookId);
    if (pages.isEmpty) return 0;
    return pages.last.orderIndex + 1;
  }

  /// Add a new page
  Future<void> addPage(NotePage page) async {
    final box = DatabaseService.getPagesBox();
    await box.put(page.id, page);
  }

  /// Update an existing page
  Future<void> updatePage(NotePage page) async {
    final box = DatabaseService.getPagesBox();
    await box.put(page.id, page);
  }

  /// Delete a page
  Future<void> deletePage(String id) async {
    final box = DatabaseService.getPagesBox();
    await box.delete(id);
  }

  /// Delete all pages for a book
  Future<void> deletePagesByBookId(String bookId) async {
    final box = DatabaseService.getPagesBox();
    final keys = box.keys.where((key) {
      final page = box.get(key);
      return page != null && page.bookId == bookId;
    }).toList();

    for (final key in keys) {
      await box.delete(key);
    }
  }

  /// Get all pages (for linking purposes)
  List<NotePage> getAllPages() {
    final box = DatabaseService.getPagesBox();
    return box.values.toList();
  }
}
