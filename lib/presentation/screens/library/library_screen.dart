import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/providers/book_provider.dart';
import '../../../application/providers/page_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../data/repositories/page_repository.dart';
import '../../../domain/models/book.dart';
import '../../theme/app_theme.dart';
import '../../widgets/book_card.dart';
import '../../widgets/folder_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/fade_slide_entrance.dart';
import '../../widgets/file_picker_helper.dart';
import '../../widgets/floating_book_shortcut.dart';
import '../notebook/page_editor_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final PageRepository _pageRepository = PageRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  
  // For floating book shortcut
  Book? _shortcutBook;
  static bool _showShortcut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().loadBooks();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _createNewBook() async {
    final book = await context.read<BookProvider>().addBook();
    if (!mounted) return;

    final pageProvider = context.read<PageProvider>();
    final newPage = await pageProvider.addPage(book.id, 'Sayfa 1', isAdvanced: true);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PageEditorScreen(
          pageId: newPage.id,
          bookId: book.id,
        ),
      ),
    ).then((_) {
      if (mounted) context.read<BookProvider>().loadBooks();
    });
  }

  void _openBook(Book book) async {
    final pageProvider = context.read<PageProvider>();
    pageProvider.loadPages(book.id);
    final pages = pageProvider.pages;

    if (!mounted) return;

    if (pages.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PageEditorScreen(
            pageId: pages.first.id,
            bookId: book.id,
          ),
        ),
      ).then((_) {
        if (mounted) context.read<BookProvider>().loadBooks();
      });
    } else {
      final newPage = await pageProvider.addPage(book.id, 'Sayfa 1', isAdvanced: true);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PageEditorScreen(
              pageId: newPage.id,
              bookId: book.id,
            ),
          ),
        ).then((_) {
          if (mounted) context.read<BookProvider>().loadBooks();
        });
      }
    }
  }

  void _showRenameDialog(String bookId, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kitabı Yeniden Adlandır'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Yeni kitap adı',
            prefixIcon: Icon(Icons.edit),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ).then((newTitle) {
      if (!mounted) return;
      if (newTitle != null && newTitle.isNotEmpty) {
        context.read<BookProvider>().renameBook(bookId, newTitle);
      }
    });
  }

  void _showDeleteConfirmation(String bookId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kitabı Sil'),
        content: Text(
          '"$title" kitabı ve tüm sayfaları silinecek.\nBu işlem geri alınamaz. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<BookProvider>().deleteBook(bookId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📁 Yeni Klasör Oluştur'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Klasör adı (Örn: Coğrafya)',
            prefixIcon: Icon(Icons.create_new_folder_rounded, color: Color(0xFFF59E0B)),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    ).then((folderName) {
      if (folderName != null && folderName.isNotEmpty) {
        setState(() {
          _selectedCategory = folderName;
        });
      }
    });
  }

  void _showMoveBookToCategoryDialog(Book book) {
    final categories = context.read<BookProvider>().categories;
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${book.title}" Klasöre Taşı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bir klasör seçin veya yeni klasör adı yazın:'),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              decoration: const InputDecoration(
                hintText: 'Yeni Klasör Adı (Örn: Coğrafya)',
                prefixIcon: Icon(Icons.folder_open_rounded, color: Color(0xFFF59E0B)),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            if (categories.isNotEmpty) ...[
              const Text('Mevcut Klasörler:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.folder_off_rounded, size: 16),
                    label: const Text('Klasörsüz (Çıkar)'),
                    onPressed: () {
                      context.read<BookProvider>().setBookCategory(book.id, '');
                      Navigator.pop(ctx);
                    },
                  ),
                  ...categories.map((cat) => ActionChip(
                    avatar: const Icon(Icons.folder_special_rounded, size: 16, color: Color(0xFFF59E0B)),
                    label: Text(cat),
                    backgroundColor: book.category == cat ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : null,
                    onPressed: () {
                      context.read<BookProvider>().setBookCategory(book.id, cat);
                      Navigator.pop(ctx);
                    },
                  )),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textCtrl.text.trim().isNotEmpty) {
                context.read<BookProvider>().setBookCategory(book.id, textCtrl.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Taşı'),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$oldName Klasörünü Yeniden Adlandır'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Yeni klasör adı',
            prefixIcon: Icon(Icons.folder_special_rounded, color: Color(0xFFF59E0B)),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(ctx, controller.text.trim());
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ).then((newName) {
      if (!mounted) return;
      if (newName != null && newName.isNotEmpty && newName != oldName) {
        context.read<BookProvider>().renameCategory(oldName, newName);
        if (_selectedCategory == oldName) {
          setState(() {
            _selectedCategory = newName;
          });
        }
      }
    });
  }

  void _showDeleteFolderDialog(String folderName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$folderName Klasörünü Kaldır'),
        content: Text(
          '"$folderName" klasörü kaldırılacak.\nİçindeki kitaplar silinmeyecek, ana kütüphaneye çıkarılacaktır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<BookProvider>().deleteCategory(folderName);
              if (_selectedCategory == folderName) {
                setState(() {
                  _selectedCategory = null;
                });
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Klasörü Kaldır'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📚 Kütüphanem Hakkında'),
        content: const SingleChildScrollView(
          child: Text(
            'Kütüphanem modülü, ders defterlerinizi, çizim sayfalarınızı ve cihazınızdan içe aktardığınız PDF veya görsel dokümanları saklayıp yönetebileceğiniz ana dijital arşivinizdir.\n\n'
            'Nasıl Kullanılır?\n'
            '1. Kitap Oluştur: Yeni bir çizim defteri oluşturun ve sayfalar ekleyin.\n'
            '2. Belgeleri Düzenle: Defterlerinize tıklayarak çizim tahtasını açın, kalemlerle yazın veya silin.\n'
            '3. İçe Aktar: PDF/Görsel dosyaları defter sayfaları olarak kütüphanenize entegre edin.',
            style: TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showImportBottomSheet() {
    FilePickerHelper.show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedCategory == null ? '📚 Kitaplık' : '📁 $_selectedCategory'),
        leading: _selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => setState(() => _selectedCategory = null),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_rounded, color: Color(0xFFF59E0B)),
            tooltip: 'Yeni Klasör',
            onPressed: _showCreateFolderDialog,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Bilgi',
            onPressed: _showInfoDialog,
          ),
          IconButton(
            icon: const Icon(Icons.file_open_rounded),
            tooltip: 'İçe Aktar',
            onPressed: _showImportBottomSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkCard, AppTheme.darkBg],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Kitap veya klasör ara...',
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          })
                      : null,
                  filled: true,
                  fillColor: AppTheme.darkCard,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: AppTheme.neonBlue, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),
            if (_selectedCategory != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selectedCategory = null),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFF59E0B), size: 16),
                            SizedBox(width: 4),
                            Text('Tüm Klasörler', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Colors.white38)),
                    const SizedBox(width: 8),
                    const Icon(Icons.folder_special_rounded, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$_selectedCategory Klasörü',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
            child: Consumer<BookProvider>(
              builder: (context, bookProvider, _) {
                if (bookProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final double screenWidth = MediaQuery.of(context).size.width;
                final int crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2);
                final allBooks = bookProvider.books;

                // Category folder view
                if (_selectedCategory != null) {
                  final folderBooks = allBooks
                      .where((b) => b.category == _selectedCategory && b.title.toLowerCase().contains(_searchQuery))
                      .toList();

                  if (folderBooks.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.folder_open_rounded,
                      title: 'Klasör Boş',
                      subtitle: '"$_selectedCategory" klasöründe henüz kitap yok.',
                      actionLabel: 'Klasörden Çık',
                      onAction: () => setState(() => _selectedCategory = null),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: folderBooks.length,
                    itemBuilder: (context, index) {
                      final book = folderBooks[index];
                      final pageCount = _pageRepository.getPagesByBookId(book.id).length;

                      return FadeSlideEntrance(
                        delay: Duration(milliseconds: index * 50),
                        child: GestureDetector(
                          onLongPress: () {
                            setState(() {
                              _shortcutBook = book;
                              _showShortcut = true;
                            });
                          },
                          child: BookCard(
                            book: book,
                            pageCount: pageCount,
                            onTap: () => _openBook(book),
                            onRename: () => _showRenameDialog(book.id, book.title),
                            onDelete: () => _showDeleteConfirmation(book.id, book.title),
                            onMoveToCategory: () => _showMoveBookToCategoryDialog(book),
                          ),
                        ),
                      );
                    },
                  );
                }

                // Main view: Folders + Standalone Books
                final allCategories = bookProvider.categories;
                final matchingCategories = allCategories.where((cat) => cat.toLowerCase().contains(_searchQuery)).toList();
                final uncategorizedBooks = allBooks.where((b) => b.category.isEmpty && b.title.toLowerCase().contains(_searchQuery)).toList();

                final totalItems = matchingCategories.length + uncategorizedBooks.length;

                if (totalItems == 0) {
                  return EmptyStateWidget(
                    icon: Icons.library_books,
                    title: _searchQuery.isEmpty ? 'Henüz kitap yok' : 'Sonuç bulunamadı',
                    subtitle: _searchQuery.isEmpty ? 'İlk kitabınızı veya klasörünüzü oluşturarak başlayın' : 'Farklı bir arama yapın',
                    actionLabel: _searchQuery.isEmpty ? 'Kitap Oluştur' : null,
                    onAction: _searchQuery.isEmpty ? _createNewBook : null,
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    // Render Folder Cards first
                    if (index < matchingCategories.length) {
                      final catName = matchingCategories[index];
                      final count = allBooks.where((b) => b.category == catName).length;

                      return FadeSlideEntrance(
                        delay: Duration(milliseconds: index * 50),
                        child: FolderCard(
                          categoryName: catName,
                          bookCount: count,
                          onTap: () => setState(() => _selectedCategory = catName),
                          onRename: () => _showRenameFolderDialog(catName),
                          onDelete: () => _showDeleteFolderDialog(catName),
                        ),
                      );
                    }

                    // Render Standalone Book Cards next
                    final bookIndex = index - matchingCategories.length;
                    final book = uncategorizedBooks[bookIndex];
                    final pageCount = _pageRepository.getPagesByBookId(book.id).length;

                    return FadeSlideEntrance(
                      delay: Duration(milliseconds: index * 50),
                      child: GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _shortcutBook = book;
                            _showShortcut = true;
                          });
                        },
                        child: BookCard(
                          book: book,
                          pageCount: pageCount,
                          onTap: () => _openBook(book),
                          onRename: () => _showRenameDialog(book.id, book.title),
                          onDelete: () => _showDeleteConfirmation(book.id, book.title),
                          onMoveToCategory: () => _showMoveBookToCategoryDialog(book),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
          // Floating book shortcut overlay
          if (_showShortcut && _shortcutBook != null)
            FloatingBookShortcut(
              bookTitle: _shortcutBook!.title,
              onClose: () => setState(() => _showShortcut = false),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // PDF / Görsel Aktar butonu
          FloatingActionButton.extended(
            heroTag: 'library_import_fab',
            onPressed: _showImportBottomSheet,
            backgroundColor: AppTheme.darkCard,
            elevation: 4,
            icon: Icon(Icons.upload_file_rounded, color: AppTheme.neonPurple),
            label: Text(
              'PDF Aktar',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          // Yeni Kitap butonu
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppTheme.primaryGlow(intensity: 0.6),
            ),
            child: FloatingActionButton(
              heroTag: 'library_fab',
              onPressed: _createNewBook,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
