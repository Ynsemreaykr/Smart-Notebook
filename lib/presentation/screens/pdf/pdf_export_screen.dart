import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/providers/page_provider.dart';
import '../../../application/providers/pdf_provider.dart';
import '../../../application/providers/book_provider.dart';
import '../../../domain/models/page.dart';
import '../../widgets/bounce_button.dart';

class PdfExportScreen extends StatefulWidget {
  final String bookId;
  const PdfExportScreen({super.key, required this.bookId});

  @override
  State<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends State<PdfExportScreen> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PageProvider>().loadPages(widget.bookId);
    });
  }

  void _toggleAll(List<NotePage> pages) {
    setState(() {
      if (_selectedIds.length == pages.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(pages.map((p) => p.id));
      }
    });
  }

  void _exportSelected() async {
    final pages = context.read<PageProvider>().pages;
    final selected = pages.where((p) => _selectedIds.contains(p.id)).toList();
    final book = context.read<BookProvider>().getBookById(widget.bookId);
    if (book == null || selected.isEmpty) return;

    final pdfProvider = context.read<PdfProvider>();
    final pdf = await pdfProvider.generateSelectedPagesPdf(book.title, selected);

    if (pdf != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF oluşturuldu! (${selected.length} sayfa)'),
          action: SnackBarAction(label: 'Paylaş', onPressed: () => pdfProvider.sharePdf(subject: book.title)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Export'),
        actions: [
          Consumer<PageProvider>(
            builder: (_, pp, __) => TextButton(
              onPressed: () => _toggleAll(pp.pages),
              child: Text(
                _selectedIds.length == pp.pages.length ? 'Hiçbirini Seçme' : 'Tümünü Seç',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      body: Consumer2<PageProvider, PdfProvider>(
        builder: (context, pageProvider, pdfProvider, _) {
          if (pageProvider.pages.isEmpty) {
            return const Center(child: Text('Bu kitapta sayfa bulunmuyor.'));
          }

          return Column(
            children: [
              // Info bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('PDF\'e eklemek istediğiniz sayfaları seçin', style: TextStyle(color: Colors.grey.shade700, fontSize: 14))),
                    Text('${_selectedIds.length}/${pageProvider.pages.length}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  ],
                ),
              ),
              // Pages list
              Expanded(
                child: ListView.builder(
                  itemCount: pageProvider.pages.length,
                  itemBuilder: (ctx, i) {
                    final page = pageProvider.pages[i];
                    final isSelected = _selectedIds.contains(page.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) {
                        setState(() {
                          if (isSelected) {
                            _selectedIds.remove(page.id);
                          } else {
                            _selectedIds.add(page.id);
                          }
                        });
                      },
                      title: Text(page.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        page.content.isEmpty ? 'Boş sayfa' : (page.content.length > 80 ? '${page.content.substring(0, 80)}...' : page.content),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      secondary: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: isSelected 
                            ? Theme.of(context).primaryColor.withValues(alpha: 0.1) 
                            : (Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white.withValues(alpha: 0.03) 
                                : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).disabledColor
                            ),
                          ),
                        ),
                      ),
                      activeColor: Theme.of(context).primaryColor,
                      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    );
                  },
                ),
              ),
              // Export button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: BounceButton(
                    onTap: _selectedIds.isEmpty || pdfProvider.isGenerating ? null : _exportSelected,
                    child: ElevatedButton.icon(
                      onPressed: _selectedIds.isEmpty || pdfProvider.isGenerating ? null : _exportSelected,
                      icon: pdfProvider.isGenerating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(pdfProvider.isGenerating ? 'Oluşturuluyor...' : 'Seçilenleri PDF Yap (${_selectedIds.length})'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
