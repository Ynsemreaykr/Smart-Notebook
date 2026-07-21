import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/page.dart';
import '../../data/repositories/page_repository.dart';
import '../../data/services/notification_service.dart';

class PageProvider extends ChangeNotifier {
  final PageRepository _pageRepository = PageRepository();
  final Uuid _uuid = const Uuid();

  List<NotePage> _pages = [];
  String? _currentBookId;
  bool _isLoading = false;

  List<NotePage> get pages => _pages;
  String? get currentBookId => _currentBookId;
  bool get isLoading => _isLoading;

  /// Load all pages for a book
  void loadPages(String bookId) {
    _currentBookId = bookId;
    _isLoading = true;
    notifyListeners();

    _pages = _pageRepository.getPagesByBookId(bookId);

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new page
  Future<NotePage> addPage(String bookId, String title,
      {String content = '', bool isAdvanced = false}) async {
    final now = DateTime.now();
    final orderIndex = _pageRepository.getNextOrderIndex(bookId);
    final page = NotePage(
      id: _uuid.v4(),
      bookId: bookId,
      title: title,
      content: content,
      isAdvanced: isAdvanced,
      orderIndex: orderIndex,
      createdAt: now,
      updatedAt: now,
    );

    await _pageRepository.addPage(page);
    loadPages(bookId);
    return page;
  }

  /// Update a page's content
  Future<void> updatePage(String id, {String? title, String? content, String? drawingImagePath, String? drawingJson, DateTime? reminderTime, String? drawingRect, bool? isAdvanced}) async {
    final page = _pageRepository.getPageById(id);
    if (page != null) {
      final updated = page.copyWith(
        title: title,
        content: content,
        drawingImagePath: drawingImagePath,
        drawingJson: drawingJson,
        updatedAt: DateTime.now(),
        reminderTime: reminderTime,
        drawingRect: drawingRect,
        isAdvanced: isAdvanced,
      );

      // Handle notification scheduling
      if (reminderTime != null) {
        await NotificationService().scheduleNotification(
          id: NotificationService().generateNotificationId(page.id),
          title: "Not Hatırlatıcı: ${updated.title}",
          body: updated.content.length > 50 ? "${updated.content.substring(0, 47)}..." : updated.content,
          scheduledTime: reminderTime,
          payload: "page_${page.id}",
        );
      } else if (page.reminderTime != null) {
        // Cancel if removed
        await NotificationService().cancelNotification(
          NotificationService().generateNotificationId(page.id),
        );
      }

      await _pageRepository.updatePage(updated);
      if (_currentBookId != null) {
        loadPages(_currentBookId!);
      }
    }
  }

  Future<void> setReminder(String id, DateTime? time) async {
    await updatePage(id, reminderTime: time);
  }

  /// Delete a page
  Future<void> deletePage(String id) async {
    final page = _pageRepository.getPageById(id);
    await _pageRepository.deletePage(id);
    if (page != null && _currentBookId != null) {
      loadPages(_currentBookId!);
    }
  }

  /// Get a specific page
  NotePage? getPageById(String id) {
    return _pageRepository.getPageById(id);
  }

  /// Get all pages (for linking from calendar)
  List<NotePage> getAllPages() {
    return _pageRepository.getAllPages();
  }
}
