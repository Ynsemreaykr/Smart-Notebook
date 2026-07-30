import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../application/providers/page_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../domain/models/page.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_text.dart';

class ReaderPage {
  final String sectionId;
  final String sectionTitle;
  final String content;
  final String? imagePath;
  final Uint8List? imageBytes;
  final Uint8List? backgroundImageBytes;

  ReaderPage({
    required this.sectionId,
    required this.sectionTitle,
    required this.content,
    this.imagePath,
    this.imageBytes,
    this.backgroundImageBytes,
  });
}

class BookReaderScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final int initialPage;

  const BookReaderScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.initialPage = 0,
  });

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  int _totalPages = 0;

  List<ReaderPage> _flatPages = [];
  List<NotePage> _sections = [];

  // Per-page zoom controllers
  final Map<int, TransformationController> _transformControllers = {};
  bool _isZoomed = false;
  bool _showUI = true;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final ctrl in _transformControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TransformationController _getTransformController(int idx) {
    return _transformControllers.putIfAbsent(idx, () {
      final ctrl = TransformationController();
      ctrl.addListener(() {
        final scale = ctrl.value.getMaxScaleOnAxis();
        final zoomed = scale > 1.05;
        if (zoomed != _isZoomed) {
          setState(() => _isZoomed = zoomed);
        }
      });
      return ctrl;
    });
  }

  void _handleDoubleTap(TapDownDetails details, int idx) {
    final ctrl = _getTransformController(idx);
    final currentScale = ctrl.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      ctrl.value = Matrix4.identity();
      setState(() => _isZoomed = false);
    } else {
      final x = -details.localPosition.dx * 1.5;
      final y = -details.localPosition.dy * 1.5;
      ctrl.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(2.5);
      setState(() => _isZoomed = true);
    }
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) _goToPage(_currentPage + 1);
  }

  void _previousPage() {
    if (_currentPage > 0) _goToPage(_currentPage - 1);
  }

  void _showGoToPageDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Sayfaya Git', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '1 - $_totalPages arası sayfa numarası',
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.numbers, color: Colors.white54),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF14B8A6))),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF14B8A6), width: 2)),
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
          onSubmitted: (value) {
            final page = int.tryParse(value);
            if (page != null && page >= 1 && page <= _totalPages) Navigator.pop(ctx, page - 1);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6), foregroundColor: Colors.white),
            onPressed: () {
              final page = int.tryParse(ctrl.text);
              if (page != null && page >= 1 && page <= _totalPages) Navigator.pop(ctx, page - 1);
            },
            child: const Text('Git'),
          ),
        ],
      ),
    ).then((pageIndex) {
      if (pageIndex != null) _goToPage(pageIndex);
    });
  }

  void _showTOC() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('İçindekiler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(color: Color(0xFF14B8A6), height: 1),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sections.length,
                  itemBuilder: (ctx, index) {
                    final section = _sections[index];
                    return ListTile(
                      leading: const Icon(Icons.bookmark_outline, color: Color(0xFF14B8A6)),
                      title: Text(section.title, style: const TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(ctx);
                        final targetIndex = _flatPages.indexWhere((p) => p.sectionId == section.id);
                        if (targetIndex != -1) _goToPage(targetIndex);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _buildFlatPages(List<NotePage> notePages) {
    _flatPages.clear();
    _sections = notePages;
    for (var notePage in notePages) {
      if (notePage.isAdvanced && notePage.drawingJson != null && notePage.drawingJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(notePage.drawingJson!);
          if (decoded is Map && decoded.containsKey('pages')) {
            final List<dynamic> pagesJson = decoded['pages'];
            for (var p in pagesJson) {
              Uint8List? drawingBytes;
              if (p['imageData'] != null) drawingBytes = base64Decode(p['imageData']);
              Uint8List? bgBytes;
              if (p['backgroundImageBase64'] != null && (p['backgroundImageBase64'] as String).isNotEmpty) {
                bgBytes = base64Decode(p['backgroundImageBase64'] as String);
              }
              _flatPages.add(ReaderPage(
                sectionId: notePage.id,
                sectionTitle: notePage.title,
                content: p['text'] as String? ?? '',
                imageBytes: drawingBytes,
                backgroundImageBytes: bgBytes,
              ));
            }
          } else {
            _flatPages.add(ReaderPage(sectionId: notePage.id, sectionTitle: notePage.title, content: notePage.content, imagePath: notePage.drawingImagePath));
          }
        } catch (e) {
          _flatPages.add(ReaderPage(sectionId: notePage.id, sectionTitle: notePage.title, content: notePage.content, imagePath: notePage.drawingImagePath));
        }
      } else {
        _flatPages.add(ReaderPage(sectionId: notePage.id, sectionTitle: notePage.title, content: notePage.content, imagePath: notePage.drawingImagePath));
      }
    }
    _totalPages = _flatPages.length;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<PageProvider>(
        builder: (context, pageProvider, _) {
          final pages = pageProvider.pages;
          _buildFlatPages(pages);

          if (_flatPages.isEmpty) {
            return Stack(
              children: [
                const Center(child: Text('Bu kitapta sayfa bulunmuyor.', style: TextStyle(color: Colors.grey, fontSize: 16))),
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: _TopBar(
                    title: widget.bookTitle,
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    showUI: true,
                    onBack: () => Navigator.pop(context),
                    onGoToPage: _showGoToPageDialog,
                    onShowTOC: _showTOC,
                  ),
                ),
              ],
            );
          }

          return Stack(
            children: [
              // Full-screen PageView with per-page zoom
              PageView.builder(
                controller: _pageController,
                physics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                itemCount: _flatPages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                    _isZoomed = false;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _flatPages[index];
                  final ctrl = _getTransformController(index);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTap: () => setState(() => _showUI = !_showUI),
                        onDoubleTapDown: (details) => _doubleTapDetails = details,
                        onDoubleTap: () {
                          if (_doubleTapDetails != null) {
                            _handleDoubleTap(_doubleTapDetails!, index);
                          }
                        },
                        child: InteractiveViewer(
                          transformationController: ctrl,
                          minScale: 0.8,
                          maxScale: 5.0,
                          panEnabled: true,
                          scaleEnabled: true,
                          onInteractionUpdate: (details) {
                            final scale = ctrl.value.getMaxScaleOnAxis();
                            final zoomed = scale > 1.05;
                            if (zoomed != _isZoomed) setState(() => _isZoomed = zoomed);
                          },
                          child: _FullScreenPageContent(page: page, pageNumber: index + 1, totalPages: _totalPages),
                        ),
                      );
                    },
                  );
                },
              ),

              // Transparent Top Bar
              Positioned(
                top: 0, left: 0, right: 0,
                child: _TopBar(
                  title: widget.bookTitle,
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  showUI: _showUI,
                  onBack: () => Navigator.pop(context),
                  onGoToPage: _showGoToPageDialog,
                  onShowTOC: _showTOC,
                ),
              ),

              // Transparent Bottom Bar
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _TransparentBottomBar(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  showUI: _showUI,
                  onPrevious: _previousPage,
                  onNext: _nextPage,
                  onGoToPage: _showGoToPageDialog,
                  onShowTOC: _showTOC,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Full screen page content (no padding, edge-to-edge) ───────────────────
class _FullScreenPageContent extends StatelessWidget {
  final ReaderPage page;
  final int pageNumber;
  final int totalPages;

  const _FullScreenPageContent({
    required this.page,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = page.backgroundImageBytes != null;
    final hasDrawing = page.imageBytes != null;
    final hasFilePath = page.imagePath != null && File(page.imagePath!).existsSync();

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (PDF page or drawing background)
          if (hasBg)
            Image.memory(page.backgroundImageBytes!, fit: BoxFit.contain, gaplessPlayback: true),

          // Drawing layer over background
          if (hasBg && hasDrawing)
            IgnorePointer(child: Image.memory(page.imageBytes!, fit: BoxFit.contain)),

          // File-based image (legacy path)
          if (!hasBg && hasFilePath)
            Image.file(File(page.imagePath!), fit: BoxFit.contain),

          // Drawing bytes without background
          if (!hasBg && !hasFilePath && hasDrawing)
            IgnorePointer(child: Image.memory(page.imageBytes!, fit: BoxFit.contain)),

          // Text content (when no image)
          if (!hasBg && !hasFilePath && !hasDrawing)
            Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page.sectionTitle,
                    style: const TextStyle(
                      color: Color(0xFF14B8A6),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF14B8A6), thickness: 0.5),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        page.content.isEmpty ? 'Bu sayfa boş...' : page.content,
                        style: TextStyle(
                          color: page.content.isEmpty ? Colors.white38 : Colors.white,
                          fontSize: 15,
                          height: 1.75,
                          fontStyle: page.content.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Page number badge (bottom center)
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pageNumber / $totalPages',
                  style: const TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Transparent Top Bar ───────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final int currentPage;
  final int totalPages;
  final bool showUI;
  final VoidCallback onBack;
  final VoidCallback onGoToPage;
  final VoidCallback onShowTOC;

  const _TopBar({
    required this.title,
    required this.currentPage,
    required this.totalPages,
    required this.showUI,
    required this.onBack,
    required this.onGoToPage,
    required this.onShowTOC,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: showUI ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !showUI,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.black.withValues(alpha: 0.55),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.menu_book_rounded, color: Color(0xFF14B8A6), size: 22),
                  tooltip: 'İçindekiler',
                  onPressed: onShowTOC,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.format_list_numbered, size: 16, color: Colors.white70),
                  label: const Text('Sayfa', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  onPressed: onGoToPage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Transparent Bottom Bar ────────────────────────────────────────────────
class _TransparentBottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool showUI;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onGoToPage;
  final VoidCallback onShowTOC;

  const _TransparentBottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.showUI,
    required this.onPrevious,
    required this.onNext,
    required this.onGoToPage,
    required this.onShowTOC,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: showUI ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !showUI,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.black.withValues(alpha: 0.55),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous button
                _NavBtn(
                  icon: Icons.chevron_left_rounded,
                  label: 'Geri',
                  enabled: currentPage > 0,
                  onTap: onPrevious,
                ),
                const SizedBox(width: 12),
                // Page indicator
                GestureDetector(
                  onTap: onGoToPage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_stories, size: 16, color: Color(0xFF14B8A6)),
                        const SizedBox(width: 6),
                        Text(
                          'Sayfa ${currentPage + 1} / $totalPages',
                          style: const TextStyle(color: Color(0xFF14B8A6), fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Next button
                _NavBtn(
                  icon: Icons.chevron_right_rounded,
                  label: 'İleri',
                  enabled: currentPage < totalPages - 1,
                  onTap: onNext,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _NavBtn({required this.icon, required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? const Color(0xFF14B8A6) : Colors.white24;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF14B8A6).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label == 'Geri') Icon(icon, size: 20, color: color),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
            if (label == 'İleri') Icon(icon, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}
