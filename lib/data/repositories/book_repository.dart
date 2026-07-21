import '../../domain/models/book.dart';
import '../services/database_service.dart';

class BookRepository {
  /// Get all books
  List<Book> getAllBooks() {
    final box = DatabaseService.getBooksBox();
    final books = box.values.toList();
    books.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return books;
  }

  /// Get a book by ID
  Book? getBookById(String id) {
    final box = DatabaseService.getBooksBox();
    try {
      return box.values.firstWhere((book) => book.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Add a new book
  Future<void> addBook(Book book) async {
    final box = DatabaseService.getBooksBox();
    await box.put(book.id, book);
  }

  /// Update an existing book
  Future<void> updateBook(Book book) async {
    final box = DatabaseService.getBooksBox();
    await box.put(book.id, book);
  }

  /// Delete a book
  Future<void> deleteBook(String id) async {
    final box = DatabaseService.getBooksBox();
    await box.delete(id);
  }
}
