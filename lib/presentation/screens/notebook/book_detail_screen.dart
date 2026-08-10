import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/providers/book_provider.dart';
import '../../../application/providers/page_provider.dart';
import '../../../application/providers/pdf_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/page.dart';
import '../../widgets/page_tile.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/floating_book_shortcut.dart';
import 'page_editor_screen.dart';
import 'book_reader_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedPageIds = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  static bool _showShortcut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PageProvider>().loadPages(widget.bookId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Book? get _book {
    try {
      return context.read<BookProvider>().books.firstWhere((b) => b.id == widget.bookId);
    } catch (_) {
      return null;
    }
  }

  void _addNewPage() {
    context.read<PageProvider>().addPage(widget.bookId, 'Yeni Sayfa', isAdvanced: true).then((page) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PageEditorScreen(pageId: page.id, bookId: widget.bookId),
        ),
      ).then((_) {
        context.read<PageProvider>().loadPages(widget.bookId);
      });
    });
  }

  void _exportFullBook() async {
    final book = _book;
    if (book == null) return;

    final pages = context.read<PageProvider>().pages;
    if (pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kitapta sayfa bulunmuyor.')));
      return;
    }

    await _generateAndSharePdf(book.title, pages);
  }
  
  void _exportSelectedPages() async {
    final book = _book;
    if (book == null || _selectedPageIds.isEmpty) return;

    final allPages = context.read<PageProvider>().pages;
    final selectedPages = allPages.where((p) => _selectedPageIds.contains(p.id)).toList();
    
    // Sort selected pages by their original order
    selectedPages.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    await _generateAndSharePdf('${book.title} (Seçili Kısım)', selectedPages);
    
    setState(() {
      _isSelectionMode = false;
      _selectedPageIds.clear();
    });
  }
  
  void _exportSinglePage(NotePage page) async {
    await _generateAndSharePdf(page.title, [page]);
  }

  Future<void> _generateAndSharePdf(String title, List<NotePage> pages) async {
    if (!mounted) return;
    
    final pdfProvider = context.read<PdfProvider>();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('PDF formatına dönüştürülüyor...')),
          ],
        ),
        duration: const Duration(minutes: 5),
        action: SnackBarAction(
          label: '✕ İptal',
          textColor: Colors.redAccent,
          onPressed: () {
            pdfProvider.cancelPdfGeneration();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );

    final pdf = await pdfProvider.generateBookPdf(title, pages);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (pdf != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF formatına dönüştürüldü!'),
          backgroundColor: Colors.green.shade700,
          action: SnackBarAction(
            label: 'Paylaş',
            textColor: Colors.white,
            onPressed: () => pdfProvider.sharePdf(subject: title),
          ),
        ),
      );
    } else if (pdfProvider.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF oluşturma iptal edildi.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pdfProvider.error ?? 'PDF formatına dönüştürülemedi.'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _openReader({int initialPage = 0}) {
    final book = _book;
    if (book == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookReaderScreen(
          bookId: widget.bookId,
          bookTitle: book.title,
          initialPage: initialPage,
        ),
      ),
    );
  }

  void _setReminder(NotePage page) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Hatırlatıcı Seçenekleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('1 Saat Sonra'),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveReminder(page.id, DateTime.now().add(const Duration(hours: 1)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('1 Gün Sonra'),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveReminder(page.id, DateTime.now().add(const Duration(days: 1)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar),
                title: const Text('Özel Zaman Seç...'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCustomReminder(page);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _pickCustomReminder(NotePage page) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: page.reminderTime ?? DateTime.now().add(const Duration(minutes: 5)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(page.reminderTime ?? DateTime.now().add(const Duration(minutes: 5))),
        initialEntryMode: TimePickerEntryMode.dial,
      );
      if (pickedTime != null && mounted) {
        final reminderDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        _saveReminder(page.id, reminderDateTime);
      }
    }
  }

  void _saveReminder(String pageId, DateTime dt) async {
    await context.read<PageProvider>().setReminder(pageId, dt);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hatırlatıcı kuruldu: ${dt.toString().substring(0, 16)}')),
      );
    }
  }

  void _confirmDeletePage(String pageId, String pageTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Sayfayı Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '"$pageTitle" sayfasını silmek istiyor musunuz?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PageProvider>().deletePage(pageId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(String pageId) {
    setState(() {
      if (_selectedPageIds.contains(pageId)) {
        _selectedPageIds.remove(pageId);
        if (_selectedPageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPageIds.add(pageId);
      }
    });
  }

  void _editBookTitle(Book? book) {
    if (book == null) return;
    final ctrl = TextEditingController(text: book.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kitap Adını Değiştir'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Yeni kitap adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<BookProvider>().renameBook(book.id, ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final book = _book;
    final pageProvider = context.watch<PageProvider>();

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedPageIds.clear();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _isSelectionMode 
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedPageIds.clear();
                  });
                },
              )
            : const BackButton(),
          title: _isSelectionMode
              ? Text('${_selectedPageIds.length} Seçildi')
              : GestureDetector(
                  onTap: () => _editBookTitle(book),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(book?.title ?? 'Kitap'),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 18, color: Colors.white70),
                    ],
                  ),
                ),
          actions: [
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Tümünü Seç',
                onPressed: () {
                  setState(() {
                    if (_selectedPageIds.length == pageProvider.pages.length) {
                      _selectedPageIds.clear();
                      _isSelectionMode = false;
                    } else {
                      _selectedPageIds.addAll(pageProvider.pages.map((e) => e.id));
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Seçili Olanları PDF Yap',
                onPressed: _selectedPageIds.isEmpty ? null : _exportSelectedPages,
              ),
            ] else ...[
              IconButton(
                icon: Icon(
                  Icons.bookmark_rounded,
                  color: _showShortcut ? Colors.amber : null,
                ),
                tooltip: 'Hızlı Erişim',
                onPressed: () => setState(() => _showShortcut = !_showShortcut),
              ),
              IconButton(
                icon: const Icon(Icons.auto_stories),
                tooltip: 'Kitabı Oku',
                onPressed: () => _openReader(),
              ),
            ]
          ],
        ),
        body: Stack(
          children: [
            pageProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : pageProvider.pages.isEmpty
                ? EmptyStateWidget(
                    icon: Icons.article_outlined,
                    title: 'Henüz sayfa yok',
                    subtitle: 'Bu kitaba sayfalar ekleyerek başlayın',
                    actionLabel: 'Sayfa Ekle',
                    onAction: _addNewPage,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Action buttons only visible when not in selection mode
                      if (!_isSelectionMode)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: BounceButton(
                                  onTap: () => _openReader(),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openReader(),
                                    icon: const Icon(Icons.auto_stories),
                                    label: const Text('Kitabı Oku'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: BounceButton(
                                  onTap: _exportFullBook,
                                  child: OutlinedButton.icon(
                                    onPressed: _exportFullBook,
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text('PDF Paylaş'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Search Bar
                      if (!_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Sayfalar içinde ara...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty 
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                          ),
                        ),
                      // Table of Contents header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.list_alt,
                              color: Theme.of(context).primaryColor,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'İçindekiler',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const Spacer(),
                            if (_isSelectionMode)
                              Text(
                                'Çoklu Seçim',
                                style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
                              )
                            else
                              Text(
                                '${pageProvider.pages.length} sayfa',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Pages list
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: pageProvider.pages.where((p) => p.title.toLowerCase().contains(_searchQuery)).length,
                          itemBuilder: (context, index) {
                            final filteredPages = pageProvider.pages.where((p) => p.title.toLowerCase().contains(_searchQuery)).toList();
                            final page = filteredPages[index];
                            final originalIndex = pageProvider.pages.indexOf(page);
                            return PageTile(
                              page: page,
                              index: originalIndex,
                              isSelected: _selectedPageIds.contains(page.id),
                              isSelectionMode: _isSelectionMode,
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(page.id);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PageEditorScreen(pageId: page.id),
                                    ),
                                  ).then((_) {
                                    context.read<PageProvider>().loadPages(widget.bookId);
                                  });
                                }
                              },
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selectedPageIds.add(page.id);
                                  });
                                }
                              },
                              onDelete: () {
                                _confirmDeletePage(page.id, page.title);
                              },
                              onShareAsPdf: () {
                                _exportSinglePage(page);
                              },
                              onSetReminder: () {
                                _setReminder(page);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
            // FloatingBookShortcut overlay
            if (_showShortcut)
              FloatingBookShortcut(
                bookTitle: _book?.title ?? 'Kitap',
                onClose: () => setState(() => _showShortcut = false),
              ),
          ],
        ),
        floatingActionButton: _isSelectionMode 
          ? null 
          : BounceButton(
              onTap: _addNewPage,
              child: FloatingActionButton(
                heroTag: 'book_detail_fab',
                onPressed: _addNewPage,
                child: const Icon(Icons.add),
              ),
            ),
      ),
    );
  }
}
