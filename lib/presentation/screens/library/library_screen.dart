import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../application/providers/book_provider.dart';
import '../../../application/providers/page_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../data/repositories/page_repository.dart';
import '../../../domain/models/book.dart';
import '../../theme/app_theme.dart';
import '../../widgets/book_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/fade_slide_entrance.dart';
import '../../widgets/file_picker_helper.dart';
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

  void _createNewBook() {
    context.read<BookProvider>().addBook().then((book) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${book.title}" oluşturuldu.'),
            action: SnackBarAction(
              label: 'Yeniden Adlandır',
              onPressed: () => _showRenameDialog(book.id, book.title),
            ),
          ),
        );
      }
    });
  }

  void _openBook(Book book) async {
    final pageProvider = context.read<PageProvider>();
    await pageProvider.loadPages(book.id);
    final pages = pageProvider.pages;

    if (!mounted) return;

    if (pages.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PageEditorScreen(pageId: pages.first.id),
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
            builder: (_) => PageEditorScreen(pageId: newPage.id),
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
        title: const Text('📚 Kitaplık'),
        actions: [
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
      body: Container(
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
                  hintText: 'Kitap ara...',
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
            Expanded(
            child: Consumer<BookProvider>(
              builder: (context, bookProvider, _) {
                if (bookProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredBooks = bookProvider.books.where((b) => b.title.toLowerCase().contains(_searchQuery)).toList();

                if (filteredBooks.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.library_books,
                    title: _searchQuery.isEmpty ? 'Henüz kitap yok' : 'Sonuç bulunamadı',
                    subtitle: _searchQuery.isEmpty ? 'İlk kitabınızı oluşturarak başlayın' : 'Farklı bir arama yapın',
                    actionLabel: _searchQuery.isEmpty ? 'Kitap Oluştur' : null,
                    onAction: _searchQuery.isEmpty ? _createNewBook : null,
                  );
                }

                final double screenWidth = MediaQuery.of(context).size.width;
                final int crossAxisCount = screenWidth > 900 ? 4 : (screenWidth > 600 ? 3 : 2);

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredBooks.length,
                  itemBuilder: (context, index) {
                    final book = filteredBooks[index];
                    final pageCount =
                        _pageRepository.getPagesByBookId(book.id).length;

                    return FadeSlideEntrance(
                      delay: Duration(milliseconds: index * 50),
                      child: BookCard(
                        book: book,
                        pageCount: pageCount,
                        onTap: () => _openBook(book),
                        onRename: () => _showRenameDialog(book.id, book.title),
                        onDelete: () => _showDeleteConfirmation(book.id, book.title),
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
