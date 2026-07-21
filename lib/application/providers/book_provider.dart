import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';
import '../../domain/models/book.dart';
import '../../domain/models/page.dart';
import '../../data/repositories/book_repository.dart';
import '../../data/repositories/page_repository.dart';

class BookProvider extends ChangeNotifier {
  final BookRepository _bookRepository = BookRepository();
  final PageRepository _pageRepository = PageRepository();
  final Uuid _uuid = const Uuid();

  List<Book> _books = [];
  bool _isLoading = false;

  List<Book> get books => _books;
  bool get isLoading => _isLoading;

  /// Load all books
  void loadBooks() {
    _isLoading = true;
    notifyListeners();

    _books = _bookRepository.getAllBooks();

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new book
  Future<Book> addBook([String? title, String? coverColor]) async {
    final now = DateTime.now();
    String finalTitle = title ?? 'Yeni Kitap';
    if (title == null) {
      int count = 1;
      finalTitle = 'Yeni Kitap';
      while (_books.any((b) => b.title == finalTitle)) {
        finalTitle = 'Yeni Kitap $count';
        count++;
      }
    }
    final book = Book(
      id: _uuid.v4(),
      title: finalTitle,
      createdAt: now,
      updatedAt: now,
      coverColor: coverColor ?? _getRandomColor(),
    );

    await _bookRepository.addBook(book);
    loadBooks();
    return book;
  }

  /// Rename a book
  Future<void> renameBook(String id, String newTitle) async {
    final book = _bookRepository.getBookById(id);
    if (book != null) {
      final updated = Book(
        id: book.id,
        title: newTitle,
        createdAt: book.createdAt,
        updatedAt: DateTime.now(),
        coverColor: book.coverColor,
      );
      await _bookRepository.updateBook(updated);
      loadBooks();
    }
  }

  /// Delete a book and all its pages
  Future<void> deleteBook(String id) async {
    await _pageRepository.deletePagesByBookId(id);
    await _bookRepository.deleteBook(id);
    loadBooks();
  }

  /// Get a book by ID
  Book? getBookById(String id) {
    return _bookRepository.getBookById(id);
  }

  String _getRandomColor() {
    final colors = [
      '#4A90D9',
      '#E74C3C',
      '#2ECC71',
      '#F39C12',
      '#9B59B6',
      '#1ABC9C',
      '#E67E22',
      '#3498DB',
      '#E91E63',
      '#00BCD4',
    ];
    colors.shuffle();
    return colors.first;
  }

  /// Import an image as a new Book with one notebook page
  Future<Book> importImage(File file, [String? title]) async {
    final now = DateTime.now();
    final bookTitle = title ?? 'Görsel Kitap';
    
    // 1. Create the Book
    final book = await addBook(bookTitle);
    
    // 2. Read image bytes and convert to base64
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    
    // 3. Create a NotePage with backgroundImageBase64
    final pageId = _uuid.v4();
    final pageData = {
      'text': '',
      'drawing': [],
      'fontSize': 16.0,
      'isBold': false,
      'isItalic': false,
      'imageOverlays': [],
      'textBoxOverlays': [],
      'backgroundImageBase64': b64,
    };
    
    final drawingJson = jsonEncode({
      'pages': [pageData]
    });
    
    final notePage = NotePage(
      id: pageId,
      bookId: book.id,
      title: 'Sayfa 1',
      content: '1 Alt Sayfa',
      isAdvanced: true,
      orderIndex: 0,
      createdAt: now,
      updatedAt: now,
      drawingJson: drawingJson,
    );
    
    await _pageRepository.addPage(notePage);
    loadBooks();
    return book;
  }

  /// Import a PDF as a new Book containing a notebook page for each PDF page
  Future<Book> importPdf(File file, [String? title]) async {
    final now = DateTime.now();
    final bookTitle = title ?? 'PDF Kitap';
    
    // 1. Create the Book
    final book = await addBook(bookTitle);
    
    // 2. Read PDF bytes
    final bytes = await file.readAsBytes();
    
    // 3. Rasterize PDF pages using Printing.raster
    int pageIndex = 0;
    try {
      await for (final page in Printing.raster(bytes, dpi: 150)) {
        final pngBytes = await page.toPng();
        final b64 = base64Encode(pngBytes);
        
        final pageId = _uuid.v4();
        // Her PDF sayfası backgroundImageBase64 olarak kaydedilir
        // Böylece çizim editoründe arka plan olarak görünür
        final pageData = {
          'text': '',
          'drawing': [],
          'fontSize': 16.0,
          'isBold': false,
          'isItalic': false,
          'imageOverlays': [],
          'textBoxOverlays': [],
          'backgroundImageBase64': b64,
        };
        
        final drawingJson = jsonEncode({
          'pages': [pageData]
        });
        
        final notePage = NotePage(
          id: pageId,
          bookId: book.id,
          title: 'Sayfa ${pageIndex + 1}',
          content: '1 Alt Sayfa',
          isAdvanced: true,
          orderIndex: pageIndex,
          createdAt: now,
          updatedAt: now,
          drawingJson: drawingJson,
        );
        
        await _pageRepository.addPage(notePage);
        pageIndex++;
      }
    } catch (e) {
      debugPrint("Error rasterizing PDF: $e");
    }
    
    loadBooks();
    return book;
  }
}
