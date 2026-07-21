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
import '../../../widgets/common/app_container.dart';
import '../../../widgets/common/app_text.dart';
import '../../widgets/bounce_button.dart';

class ReaderPage {
  final String sectionId;
  final String sectionTitle;
  final String content;
  final String? imagePath;
  final Uint8List? imageBytes;
  /// PDF/görsel arka plan resmi (base64)
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

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _goToPage(_currentPage + 1);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _goToPage(_currentPage - 1);
    }
  }

  void _showGoToPageDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText(
          'Sayfaya Git',
          styleType: AppTextStyleType.headingMedium,
          styleOverride: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: '1 - $_totalPages arası sayfa numarası',
            prefixIcon: const Icon(Icons.numbers),
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
          onSubmitted: (value) {
            final page = int.tryParse(value);
            if (page != null && page >= 1 && page <= _totalPages) {
              Navigator.pop(ctx, page - 1);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: AppText('İptal', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            onPressed: () {
              final page = int.tryParse(ctrl.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                Navigator.pop(ctx, page - 1);
              }
            },
            child: const AppText('Git', styleType: AppTextStyleType.label, color: Colors.white),
          ),
        ],
      ),
    ).then((pageIndex) {
      if (pageIndex != null) {
        _goToPage(pageIndex);
      }
    });
  }

  void _showTOC() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: AppText(
                  'İçindekiler',
                  styleType: AppTextStyleType.headingMedium,
                  styleOverride: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _sections.length,
                  itemBuilder: (ctx, index) {
                    final section = _sections[index];
                    return ListTile(
                      leading: Icon(Icons.bookmark_outline, color: AppColors.glow),
                      title: AppText(section.title, styleType: AppTextStyleType.bodyMedium),
                      onTap: () {
                        Navigator.pop(ctx);
                        final targetIndex = _flatPages.indexWhere((p) => p.sectionId == section.id);
                        if (targetIndex != -1) {
                          _goToPage(targetIndex);
                        }
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
              // Çizim üzeri render edilmiş görsel (imageData)
              Uint8List? drawingBytes;
              if (p['imageData'] != null) {
                drawingBytes = base64Decode(p['imageData']);
              }
              // PDF/görsel arka planı
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
    return AppContainer(
      hasGradient: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: AppText(
            widget.bookTitle,
            styleType: AppTextStyleType.headingMedium,
            styleOverride: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: FilledButton.icon(
                icon: const Icon(Icons.format_list_numbered, size: 18),
                label: const AppText('Sayfaya Git', styleType: AppTextStyleType.label),
                onPressed: _showGoToPageDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        body: Consumer<PageProvider>(
          builder: (context, pageProvider, _) {
            final pages = pageProvider.pages;
            _buildFlatPages(pages);
  
            if (_flatPages.isEmpty) {
              return const Center(
                child: AppText(
                  'Bu kitapta sayfa bulunmuyor.',
                  styleType: AppTextStyleType.bodyLarge,
                  color: Colors.grey,
                ),
              );
            }
  
            return Column(
              children: [
                // Book page area
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _flatPages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      return _BookPage(
                        page: _flatPages[index],
                        pageNumber: index + 1,
                        totalPages: _flatPages.length,
                      );
                    },
                  ),
                ),
                // Bottom navigation bar
                _BottomBar(
                  currentPage: _currentPage,
                  totalPages: _totalPages,
                  onPrevious: _previousPage,
                  onNext: _nextPage,
                  onGoToPage: _showGoToPageDialog,
                  onShowTOC: _showTOC,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Individual book page with paper-like styling and zoom support
class _BookPage extends StatefulWidget {
  final ReaderPage page;
  final int pageNumber;
  final int totalPages;

  const _BookPage({
    required this.page,
    required this.pageNumber,
    required this.totalPages,
  });

  @override
  State<_BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<_BookPage> with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _animController;
  Animation<Matrix4>? _resetAnimation;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_resetAnimation != null) {
          _transformController.value = _resetAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      // Zoom sıfırla
      _resetAnimation = Matrix4Tween(
        begin: _transformController.value,
        end: Matrix4.identity(),
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
      _animController.forward(from: 0);
    } else {
      // 2x zoom yap
      _resetAnimation = Matrix4Tween(
        begin: Matrix4.identity(),
        end: Matrix4.identity()..scale(2.0),
      ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
      _animController.forward(from: 0);
    }
  }

  ReaderPage get page => widget.page;
  int get pageNumber => widget.pageNumber;
  int get totalPages => widget.totalPages;

  @override
  Widget build(BuildContext context) {
    final hasBg = page.backgroundImageBytes != null;

    // Sayfa içeriği
    final pageContent = Container(
      decoration: BoxDecoration(
        color: hasBg ? Colors.white : const Color(0xFFFFFFF8),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(3, 3),
          ),
          BoxShadow(
            color: Colors.brown.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(-1, 0),
          ),
        ],
        border: Border.all(color: Colors.brown.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Arka plan varsa tam sayfa kapla
            if (hasBg)
              Positioned.fill(
                child: Image.memory(
                  page.backgroundImageBytes!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                ),
              ),
            // Arka plan yoksa normal sayfa düzeni
            if (!hasBg)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Başlık
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.brown.withOpacity(0.12)),
                      ),
                    ),
                    child: AppText(
                      page.sectionTitle,
                      styleType: AppTextStyleType.headingMedium,
                      styleOverride: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                          child: page.content.isNotEmpty
                              ? AppText(
                                  page.content,
                                  styleType: AppTextStyleType.bodyLarge,
                                  styleOverride: TextStyle(
                                    height: 1.75,
                                    color: Colors.brown.shade900,
                                  ),
                                )
                              : (page.imagePath == null && page.imageBytes == null)
                                  ? AppText(
                                      'Bu sayfa boş...',
                                      styleType: AppTextStyleType.bodyLarge,
                                      styleOverride: TextStyle(
                                        height: 1.75,
                                        color: Colors.grey.shade400,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                        ),
                        if (page.imagePath != null && File(page.imagePath!).existsSync())
                          IgnorePointer(
                            child: Image.file(
                              File(page.imagePath!),
                              fit: BoxFit.fill,
                            ),
                          ),
                        if (page.imageBytes != null)
                          IgnorePointer(
                            child: Image.memory(
                              page.imageBytes!,
                              fit: BoxFit.fill,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Sayfa numarası
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.brown.withOpacity(0.08)),
                      ),
                    ),
                    child: AppText(
                      '— $pageNumber —',
                      styleType: AppTextStyleType.caption,
                      color: Colors.brown.shade400,
                      styleOverride: const TextStyle(letterSpacing: 2),
                    ),
                  ),
                ],
              ),
            // Üstüne çizim varsa göster (sadece arka plan sayfalarında)
            if (hasBg && page.imageBytes != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Image.memory(
                    page.imageBytes!,
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            // Sayfa numarası (arka plan varsa altta)
            if (hasBg)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  color: Colors.black.withOpacity(0.35),
                  alignment: Alignment.center,
                  child: AppText(
                    '— $pageNumber / $totalPages —',
                    styleType: AppTextStyleType.caption,
                    color: Colors.white70,
                    styleOverride: const TextStyle(letterSpacing: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: GestureDetector(
        onDoubleTap: _onDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.8,
          maxScale: 5.0,
          // Zoom dışındayken PageView kaydırabilsin
          panEnabled: true,
          scaleEnabled: true,
          child: pageContent,
        ),
      ),
    );
  }
}

/// Bottom control bar with navigation
class _BottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onGoToPage;
  final VoidCallback onShowTOC;

  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    required this.onGoToPage,
    required this.onShowTOC,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu_book),
              tooltip: 'İçindekiler',
              color: AppColors.primary,
              onPressed: onShowTOC,
            ),
            const Spacer(),
            // Previous button
            _NavButton(
              icon: Icons.chevron_left,
              label: 'Geri',
              enabled: currentPage > 0,
              onTap: onPrevious,
            ),
            const SizedBox(width: AppSpacing.sm),
            // Page indicator (tappable to jump)
            GestureDetector(
              onTap: onGoToPage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_stories, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    AppText(
                      'Sayfa ${currentPage + 1} / $totalPages',
                      styleType: AppTextStyleType.bodyMedium,
                      styleOverride: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Next button
            _NavButton(
              icon: Icons.chevron_right,
              label: 'İleri',
              enabled: currentPage < totalPages - 1,
              onTap: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = AppColors.primary.withOpacity(0.1);
    final inactiveBg = AppColors.textMuted.withOpacity(0.03);
    final activeColor = AppColors.primary;
    final inactiveColor = AppColors.textMuted;

    final btnWidget = Material(
      color: enabled ? activeBg : inactiveBg,
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label == 'Geri') Icon(icon, size: 22, color: enabled ? activeColor : inactiveColor),
              AppText(
                label,
                styleType: AppTextStyleType.bodyMedium,
                styleOverride: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled ? activeColor : inactiveColor,
                ),
              ),
              if (label == 'İleri') Icon(icon, size: 22, color: enabled ? activeColor : inactiveColor),
            ],
          ),
        ),
      ),
    );

    if (enabled) {
      return BounceButton(
        onTap: onTap,
        child: btnWidget,
      );
    }
    return btnWidget;
  }
}
