import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../application/providers/page_provider.dart';
import '../../../application/providers/book_provider.dart';
import '../../../application/providers/pdf_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/providers/photo_note_provider.dart';
import '../../../domain/models/photo_note.dart';
import '../../../domain/models/overlay_models.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_text.dart';
import '../../widgets/floating_calculator.dart';
import '../../widgets/floating_book_shortcut.dart';
import '../../widgets/image_cropper_dialog.dart';

enum EditorMode { text, drawing, pan, questionCrop }

class PageData {
  String text;
  DrawingController controller;
  late TextEditingController textController;

  double fontSize;
  bool isBold;
  bool isItalic;
  List<Map<String, dynamic>>? deletedContentsBackup;
  List<ImageOverlay> imageOverlays;
  List<TextBoxOverlay> textBoxOverlays;
  /// PDF'ten veya görselden içe aktarılan arka plan resmi (base64)
  String? backgroundImageBase64;
  /// Kağıt tipi: 'blank' (düz), 'lined' (çizgili), 'grid' (kareli)
  String paperType;

  PageData({
    this.text = '', 
    DrawingController? controller,
    this.fontSize = 16.0,
    this.isBold = false,
    this.isItalic = false,
    List<ImageOverlay>? imageOverlays,
    List<TextBoxOverlay>? textBoxOverlays,
    this.backgroundImageBase64,
    this.paperType = 'blank',
  }) : controller = controller ?? DrawingController(),
       imageOverlays = imageOverlays ?? [],
       textBoxOverlays = textBoxOverlays ?? [] {
    textController = TextEditingController(text: text);
  }

  Map<String, dynamic> toJson() {
    text = textController.text;
    return {
      'text': text,
      'drawing': controller.getJsonList(),
      'fontSize': fontSize,
      'isBold': isBold,
      'isItalic': isItalic,
      'imageOverlays': imageOverlays.map((e) => e.toJson()).toList(),
      'textBoxOverlays': textBoxOverlays.map((e) => e.toJson()).toList(),
      'paperType': paperType,
      if (backgroundImageBase64 != null) 'backgroundImageBase64': backgroundImageBase64,
    };
  }

  factory PageData.fromJson(Map<String, dynamic> json) {
    final imgList = (json['imageOverlays'] as List<dynamic>?)?.map((e) => ImageOverlay.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    final txtList = (json['textBoxOverlays'] as List<dynamic>?)?.map((e) => TextBoxOverlay.fromJson(e as Map<String, dynamic>)).toList() ?? [];
    final pd = PageData(
      text: json['text'] as String? ?? '',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      imageOverlays: imgList,
      textBoxOverlays: txtList,
      backgroundImageBase64: json['backgroundImageBase64'] as String?,
      paperType: json['paperType'] as String? ?? 'blank',
    );
    try {
      if (json['drawing'] != null) {
        final List<dynamic> jsonList = json['drawing'];
        final contents = jsonList.map((e) => _parseJsonToContent(e)).whereType<PaintContent>().toList();
        pd.controller.addContents(contents);
      }
    } catch (e) {
      debugPrint("Error loading page drawing: $e");
    }
    return pd;
  }

  void dispose() {
    textController.dispose();
  }
}

/// Vektörel Kağıt Deseni Çizicisi: Düz, Çizgili ve Kareli Kağıt
class PaperBackgroundPainter extends CustomPainter {
  final String paperType;
  final bool isDark;

  PaperBackgroundPainter({
    required this.paperType,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFAFA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    if (paperType == 'lined') {
      final linePaint = Paint()
        ..color = isDark 
            ? const Color(0xFF334155).withValues(alpha: 0.7) 
            : const Color(0xFF94A3B8).withValues(alpha: 0.45)
        ..strokeWidth = 1.0;

      final marginPaint = Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: isDark ? 0.35 : 0.4)
        ..strokeWidth = 1.2;

      const double topMargin = 72.0;
      const double bottomMargin = 40.0;
      const double lineSpacing = 32.0;
      const double leftMargin = 50.0;

      // Sol dikey kırmızı kenar çizgisi (defter marjini)
      canvas.drawLine(
        const Offset(leftMargin, 0),
        Offset(leftMargin, size.height),
        marginPaint,
      );

      // Yatay çizgiler
      for (double y = topMargin; y <= size.height - bottomMargin; y += lineSpacing) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          linePaint,
        );
      }
    } else if (paperType == 'grid') {
      final gridPaint = Paint()
        ..color = isDark 
            ? const Color(0xFF334155).withValues(alpha: 0.6) 
            : const Color(0xFF94A3B8).withValues(alpha: 0.35)
        ..strokeWidth = 0.8;

      const double gridSize = 24.0;

      // Dikey grid çizgileri
      for (double x = 0; x <= size.width; x += gridSize) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          gridPaint,
        );
      }

      // Yatay grid çizgileri
      for (double y = 0; y <= size.height; y += gridSize) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          gridPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PaperBackgroundPainter oldDelegate) {
    return oldDelegate.paperType != paperType || oldDelegate.isDark != isDark;
  }
}

PaintContent? _parseJsonToContent(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  switch (type) {
    case 'SmoothLine': return SmoothLine.fromJson(data);
    case 'StraightLine': return StraightLine.fromJson(data);
    case 'Rectangle': return Rectangle.fromJson(data);
    case 'Circle': return Circle.fromJson(data);
    case 'Eraser': return Eraser.fromJson(data);
    case 'SimpleLine': return SimpleLine.fromJson(data);
    case 'CustomTextContent': return CustomTextContent.fromJson(data);
    case 'ArrowContent': return ArrowContent.fromJson(data);
    case 'HighlighterContent': return HighlighterContent.fromJson(data);
    default: return null;
  }
}

class OcrElementMatch {
  final String text;
  final Rect boundingBox;
  final Size imageSize;
  OcrElementMatch({
    required this.text,
    required this.boundingBox,
    required this.imageSize,
  });
}

class SearchOccurrence {
  final int pageIndex;
  final OcrElementMatch? ocrElement;
  final TextBoxOverlay? textBox;
  final int matchStartIndex;
  final int matchLength;
  final Rect? subBoundingBox;

  SearchOccurrence({
    required this.pageIndex,
    this.ocrElement,
    this.textBox,
    required this.matchStartIndex,
    required this.matchLength,
    this.subBoundingBox,
  });
}

class PageEditorScreen extends StatefulWidget {
  final String pageId;
  /// Optional: if provided, all pages of the book are loaded (for PDF import multi-page support).
  final String? bookId;
  const PageEditorScreen({super.key, required this.pageId, this.bookId});

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> with WidgetsBindingObserver {
  late TextEditingController _titleCtrl;
  bool _initialized = false;
  bool _hasChanges = false;
  bool _showCalculator = false;
  static bool _showShortcut = false;
  
  List<PageData> _pages = [PageData()];
  EditorMode _currentMode = EditorMode.pan;
  bool _isZoomed = false;
  bool _showUI = true;
  int _pointerCount = 0;

  // Toolbar
  bool _toolbarVisible = true;
  bool _toolbarPinned = true; // User can pin toolbar to always show
  
  Color _currentColor = Colors.black;

  // Per-tool stroke widths — each tool remembers its own size independently
  double _penStrokeWidth = 3.0;
  double _eraserStrokeWidth = 8.0;
  double _highlighterStrokeWidth = 14.0;

  /// Returns the active tool's own stroke width
  double get _currentStrokeWidth {
    if (_activeTool == 'Eraser') return _eraserStrokeWidth;
    if (_activeTool == 'Highlighter') return _highlighterStrokeWidth;
    return _penStrokeWidth;
  }

  /// Sets the active tool's own stroke width
  set _currentStrokeWidth(double value) {
    if (_activeTool == 'Eraser') {
      _eraserStrokeWidth = value;
    } else if (_activeTool == 'Highlighter') {
      _highlighterStrokeWidth = value;
    } else {
      _penStrokeWidth = value;
    }
  }

  String _activeTool = 'SmoothLine';
  String? _previousToolBeforeStylus;
  int _activePageIndex = 0;
  String? _selectedTextBoxId;
  String? _selectedImageId;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Eraser cursor tracking
  Offset? _eraserCursorPosition;
  
  // Area eraser selection
  Offset? _areaEraserStart;
  Offset? _areaEraserEnd;

  // Floating Draggable Drawing Bar
  Offset _floatingBarOffset = const Offset(14, 180);
  bool _isFloatingBarExpanded = false;

  late PageController _pageController;
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  
  // Question crop tool state
  final GlobalKey _cropBoundaryKey = GlobalKey();
  Offset? _cropStartPoint;
  Offset? _cropEndPoint;

  // In-book search state (Ctrl+F with OCR)
  bool _isSearching = false;
  bool _isOcrScanning = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SearchOccurrence> _allSearchMatches = [];
  int _currentSearchMatchIndex = 0;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final Map<int, String> _pageOcrTextCache = {};
  final Map<int, List<OcrElementMatch>> _pageOcrElementsCache = {};
  
  /// When bookId is set, maps each _pages[i] to the corresponding NotePage.id
  /// so we can save each page's drawingJson back to its own NotePage record.
  List<String> _notePageIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleCtrl = TextEditingController();
    _pageController = PageController(initialPage: 0);
    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _save();
    }
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.05;
    if (zoomed != _isZoomed) {
      setState(() {
        _isZoomed = zoomed;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _save();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    _textRecognizer.close();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _init();
  }

  void _init() {
    if (_initialized) return;
    _initialized = true;
    
    final pageProvider = context.read<PageProvider>();
    
    // If bookId is provided, load ALL pages of the book (for multi-page PDF support)
    if (widget.bookId != null) {
      final allPages = pageProvider.getPagesByBookId(widget.bookId!);
      if (allPages.isNotEmpty) {
        _titleCtrl.text = allPages.first.title;
        _pages = [];
        _notePageIds = [];
        for (final notePage in allPages) {
          _notePageIds.add(notePage.id);
          if (notePage.drawingJson != null && notePage.drawingJson!.isNotEmpty) {
            try {
              final decoded = jsonDecode(notePage.drawingJson!);
              if (decoded is Map && decoded.containsKey('pages')) {
                final List<dynamic> pagesJson = decoded['pages'];
                // Each NotePage contributes its first internal page as one editor page
                if (pagesJson.isNotEmpty) {
                  _pages.add(PageData.fromJson(pagesJson.first as Map<String, dynamic>));
                } else {
                  _pages.add(PageData());
                }
              } else {
                _pages.add(PageData());
              }
            } catch (e) {
              debugPrint("Error loading page ${notePage.id}: $e");
              _pages.add(PageData());
            }
          } else {
            _pages.add(PageData());
          }
        }
        if (_pages.isEmpty) _pages = [PageData()];
      } else {
        _pages = [PageData()];
      }
    } else {
      // Single-page mode: load only the specified pageId
      final page = pageProvider.getPageById(widget.pageId);
      if (page != null) {
        _titleCtrl.text = page.title;
        if (page.drawingJson != null && page.drawingJson!.isNotEmpty) {
          try {
            final decoded = jsonDecode(page.drawingJson!);
            if (decoded is Map && decoded.containsKey('pages')) {
              final List<dynamic> pagesJson = decoded['pages'];
              _pages = pagesJson.map((p) => PageData.fromJson(p as Map<String, dynamic>)).toList();
            } else {
              _pages = [PageData()];
            }
          } catch (e) {
            debugPrint("Error loading blocks: $e");
            _pages = [PageData()];
          }
        }
      }
    }
    
    // Arka planlı sayfa varsa çizim modunda başla
    final firstPage = _pages.isNotEmpty ? _pages[0] : null;
    if (firstPage != null && firstPage.backgroundImageBase64 != null && firstPage.backgroundImageBase64!.isNotEmpty) {
      _currentMode = EditorMode.pan;
    }
  }

  Future<void> _save() async {
    final pageProvider = context.read<PageProvider>();
    
    if (widget.bookId != null && _notePageIds.isNotEmpty) {
      // Multi-page mode: save each editor page back to its own NotePage record
      for (int i = 0; i < _pages.length && i < _notePageIds.length; i++) {
        final page = _pages[i];
        final pdJson = page.toJson();
        try {
          final imgData = await page.controller.getImageData();
          if (imgData != null) {
            final base64Image = base64Encode(imgData.buffer.asUint8List());
            pdJson['imageData'] = base64Image;
          }
        } catch (e) {
          debugPrint("Error generating image for pdf page $i: $e");
        }
        final newJson = jsonEncode({'pages': [pdJson]});
        await pageProvider.updatePage(
          _notePageIds[i],
          title: i == 0 ? _titleCtrl.text : 'Sayfa ${i + 1}',
          content: '',
          drawingJson: newJson,
          isAdvanced: true,
        );
      }
    } else {
      // Single-page mode: save all internal pages to the single NotePage
      final List<Map<String, dynamic>> pagesJson = [];
      for (var page in _pages) {
        final pdJson = page.toJson();
        try {
          final imgData = await page.controller.getImageData();
          if (imgData != null) {
            final base64Image = base64Encode(imgData.buffer.asUint8List());
            pdJson['imageData'] = base64Image;
          }
        } catch (e) {
          debugPrint("Error generating image for pdf: $e");
        }
        pagesJson.add(pdJson);
      }
      final newJson = jsonEncode({'pages': pagesJson});
      await pageProvider.updatePage(
        widget.pageId,
        title: _titleCtrl.text,
        content: '',
        drawingJson: newJson,
        isAdvanced: true,
      );
    }
    setState(() => _hasChanges = false);
  }

  Future<void> _exportAsPdf() async {
    // Save first to make sure content is up to date
    await _save();
    if (!mounted) return;

    final pageProvider = context.read<PageProvider>();
    final notePage = pageProvider.getPageById(widget.pageId);
    if (notePage == null) return;

    // Get book title
    final bookProvider = context.read<BookProvider>();
    final book = bookProvider.getBookById(notePage.bookId);
    final bookTitle = book?.title ?? 'Not Defteri';

    final pdfProvider = context.read<PdfProvider>();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('PDF formatına dönüştürülüyor...'), 
        duration: const Duration(minutes: 5),
        action: SnackBarAction(
          label: '❌',
          onPressed: () {
            pdfProvider.cancelPdfGeneration();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );

    final pdf = await pdfProvider.generateBookPdf(bookTitle, [notePage]);

    if (pdf != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF formatına dönüştürüldü!'),
          action: SnackBarAction(
            label: 'Paylaş',
            onPressed: () => pdfProvider.sharePdf(subject: _titleCtrl.text),
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (pdfProvider.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF oluşturma iptal edildi.')),
        );
      } else if (pdfProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(pdfProvider.error!)),
        );
      }
    }
  }

  Future<bool> _onBackPressed() async {
    if (!_hasChanges) {
      return true;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 20, 20),
        title: const Text(
          'Kaydedilsin mi?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: const Text(
          'Son yaptığınız değişiklikler kaydedilsin mi?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.35,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Hayır',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7DD3FC),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text(
              'Evet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _save();
      return true;
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  void _addPage() {
    _showAddPageOptionsSheet();
  }

  void _showAddPageOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF14B8A6), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Yeni Sayfa Ekle',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPageTemplateOption(
                      icon: Icons.note_outlined,
                      label: 'Boş Sayfa',
                      sublabel: 'Düz Beyaz',
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _addNewPageWithTemplate(paperType: 'blank');
                      },
                    ),
                    _buildPageTemplateOption(
                      icon: Icons.format_align_left_rounded,
                      label: 'Çizgili',
                      sublabel: 'Satırlı Defter',
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _addNewPageWithTemplate(paperType: 'lined');
                      },
                    ),
                    _buildPageTemplateOption(
                      icon: Icons.grid_on_rounded,
                      label: 'Kareli',
                      sublabel: 'Matematik',
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _addNewPageWithTemplate(paperType: 'grid');
                      },
                    ),
                    _buildPageTemplateOption(
                      icon: Icons.add_photo_alternate_rounded,
                      label: 'Görsel / Belge',
                      sublabel: 'Galeriden',
                      onTap: () {
                        Navigator.pop(ctx);
                        _addNewPageFromGallery();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Change the paper type of the currently-active page
  void _showChangePaperTypeSheet() {
    if (_pages.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF14B8A6), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Colors.black87, blurRadius: 20, spreadRadius: 2),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Sayfa Seçenekleri',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sayfa ${_activePageIndex + 1}/${_pages.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPageTemplateOption(
                      icon: Icons.note_outlined,
                      label: 'Boş',
                      sublabel: 'Düz Beyaz',
                      onTap: () {
                        Navigator.pop(ctx);
                        _changePaperType('blank');
                      },
                    ),
                    _buildPageTemplateOption(
                      icon: Icons.format_align_left_rounded,
                      label: 'Çizgili',
                      sublabel: 'Satırlı Defter',
                      onTap: () {
                        Navigator.pop(ctx);
                        _changePaperType('lined');
                      },
                    ),
                    _buildPageTemplateOption(
                      icon: Icons.grid_on_rounded,
                      label: 'Kareli',
                      sublabel: 'Matematik',
                      onTap: () {
                        Navigator.pop(ctx);
                        _changePaperType('grid');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDeletePage();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Bu Sayfayı Sil',
                            style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _changePaperType(String newType) {
    if (_pages.isEmpty) return;
    setState(() {
      _pages[_activePageIndex].paperType = newType;
      _hasChanges = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sayfa ${_activePageIndex + 1} kağıt tipi ${newType == 'lined' ? 'Çizgili' : newType == 'grid' ? 'Kareli' : 'Boş'} olarak değiştirildi.',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF14B8A6),
      ),
    );
  }

  Widget _buildPageTemplateOption({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: const Color(0xFF14B8A6), size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNewPageWithTemplate({required String paperType}) async {
    // In multi-page / book mode, create a real NotePage in Hive immediately
    // so the page is persisted and synced on next backup.
    if (widget.bookId != null) {
      final pageProvider = context.read<PageProvider>();
      // First save current state so existing pages are up-to-date
      await _save();
      // Create the new NotePage record with the chosen paperType
      final newPageJson = jsonEncode({
        'pages': [
          {
            'text': '',
            'drawing': [],
            'fontSize': 16.0,
            'isBold': false,
            'isItalic': false,
            'imageOverlays': [],
            'textBoxOverlays': [],
            'paperType': paperType,
          }
        ]
      });
      final newNotePage = await pageProvider.addPage(
        widget.bookId!,
        'Sayfa ${_pages.length + 1}',
        content: '',
        isAdvanced: true,
      );
      // Persist the paperType inside drawingJson immediately
      await pageProvider.updatePage(
        newNotePage.id,
        drawingJson: newPageJson,
        isAdvanced: true,
      );
      setState(() {
        _pages.add(PageData(paperType: paperType));
        _notePageIds.add(newNotePage.id);
        _activePageIndex = _pages.length - 1;
        _hasChanges = false; // just saved
      });
    } else {
      // Single-page mode: just append locally; _save() will persist all pages
      setState(() {
        _pages.add(PageData(paperType: paperType));
        _activePageIndex = _pages.length - 1;
        _hasChanges = true;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _activePageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yeni ${paperType == "lined" ? "çizgili" : paperType == "grid" ? "kareli" : "boş"} sayfa eklendi!'), 
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _confirmDeletePage() {
    if (_pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Kitaptaki tek sayfa silinemez.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final currentPageNum = _activePageIndex + 1;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            const SizedBox(width: 8),
            Text(
              'Sayfa $currentPageNum Silinsin mi?',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          '$currentPageNum. sayfayı ve üzerindeki tüm çizimleri silmek istediğinizden emin misiniz?\n\nBu işlem geri alınamaz.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteCurrentPage();
            },
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCurrentPage() async {
    final indexToDelete = _activePageIndex;

    // 1. Delete from Hive database if multi-page book
    if (widget.bookId != null && indexToDelete < _notePageIds.length) {
      final pageIdToDelete = _notePageIds[indexToDelete];
      try {
        final pageProvider = context.read<PageProvider>();
        await pageProvider.deletePage(pageIdToDelete);
        _notePageIds.removeAt(indexToDelete);
      } catch (e) {
        debugPrint('Error deleting page from Hive: $e');
      }
    }

    // 2. Remove locally from state
    setState(() {
      _pages.removeAt(indexToDelete);
      if (_activePageIndex >= _pages.length) {
        _activePageIndex = _pages.length - 1;
      }
      _hasChanges = true;
    });

    // 3. Update PageController position
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_activePageIndex);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ Sayfa ${indexToDelete + 1} silindi.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }


  Future<void> _addNewPageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await File(image.path).readAsBytes();
      final base64Str = base64Encode(bytes);

      setState(() {
        _pages.add(PageData(
          backgroundImageBase64: base64Str,
          paperType: 'blank',
        ));
        _activePageIndex = _pages.length - 1;
        _hasChanges = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _activePageIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Galeriden yeni sayfa eklendi!'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugPrint('Error adding page from gallery: $e');
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    final b64 = base64Encode(bytes);
    setState(() {
      _pages[_activePageIndex].imageOverlays.add(ImageOverlay(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        base64Data: b64,
        position: const Offset(30, 80),
        size: const Size(220, 170),
      ));
      _hasChanges = true;
    });
  }

  void _addTextBox() {
    setState(() {
      _pages[_activePageIndex].textBoxOverlays.add(TextBoxOverlay(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        position: const Offset(40, 120),
        size: const Size(200, 100),
      ));
      _hasChanges = true;
      _selectedTextBoxId = _pages[_activePageIndex].textBoxOverlays.last.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onBackPressed();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Layer 0: Full-screen PageView
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              allowImplicitScrolling: true,
              clipBehavior: Clip.hardEdge,
              itemCount: _pages.length,
              physics: (_currentMode == EditorMode.drawing || _currentMode == EditorMode.questionCrop || _isZoomed) 
                  ? const NeverScrollableScrollPhysics() 
                  : const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _activePageIndex = index;
                  _isZoomed = false;
                  _transformationController.value = Matrix4.identity();
                  if (_currentMode == EditorMode.drawing) {
                     _applyDrawingToolToActivePage();
                  }
                });
              },
              itemBuilder: (context, index) {
                return _buildPageFrame(index);
              },
            ),

            // Layer 1: Slim Top AppBar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showUI ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showUI,
                  child: _buildTopAppBar(),
                ),
              ),
            ),



            // Layer 3: Floating Transparent Bottom Bar (Integrated Tools + Compact Navigation)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showUI ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showUI,
                  child: _buildBottomBar(),
                ),
              ),
            ),

            // Layer 4: Floating Draggable Mini Bubble & Vertical Toolbar (Kalem / Silgi Baloncuğu)
            if (_showUI)
              _buildFloatingDrawingBar(),

            // Fullscreen Restore Floating Button (When _showUI is false - Icon Only)
            if (!_showUI)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 12,
                child: GestureDetector(
                  onTap: () => setState(() => _showUI = true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.6)),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                    ),
                    child: const Icon(Icons.fullscreen_exit_rounded, color: Color(0xFF14B8A6), size: 20),
                  ),
                ),
              ),

            if (_showCalculator)
              FloatingCalculator(
                onClose: () => setState(() => _showCalculator = false),
              ),
            if (_showShortcut)
              FloatingBookShortcut(
                bookTitle: _titleCtrl.text.isEmpty ? 'Görsel & Bilgi Kartları' : _titleCtrl.text,
                onClose: () => setState(() => _showShortcut = false),
              ),
          ],
        ),
      ),
    );

  }

  void _handleDoubleTap() {
    if (_currentMode != EditorMode.pan) return;
    
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 1.05) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
  }

  Widget _buildPageFrame(int index) {
    final pageData = _pages[index];
    final isDrawingMode = _currentMode == EditorMode.drawing;
    final isTextMode = _currentMode == EditorMode.text;
    final hasBg = pageData.backgroundImageBase64 != null && pageData.backgroundImageBase64!.isNotEmpty;
    final isPanMode = _currentMode == EditorMode.pan;
    
    return Listener(
      onPointerDown: (event) {
        _pointerCount++;
        if (_pointerCount >= 2 && !_isZoomed) {
          setState(() => _isZoomed = true);
        }
      },
      onPointerUp: (event) {
        _pointerCount = (_pointerCount > 1) ? _pointerCount - 1 : 0;
        if (_pointerCount == 0) {
          final scale = _transformationController.value.getMaxScaleOnAxis();
          if (scale <= 1.05 && _isZoomed) {
            setState(() => _isZoomed = false);
          }
        }
      },
      onPointerCancel: (event) {
        _pointerCount = 0;
        final scale = _transformationController.value.getMaxScaleOnAxis();
        if (scale <= 1.05 && _isZoomed) {
          setState(() => _isZoomed = false);
        }
      },
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.8,
        maxScale: 5.0,
        clipBehavior: Clip.hardEdge,
        panEnabled: isPanMode,
        scaleEnabled: isPanMode,
        onInteractionUpdate: (details) {
          final scale = _transformationController.value.getMaxScaleOnAxis();
          final zoomed = scale > 1.05;
          if (zoomed != _isZoomed) {
            setState(() => _isZoomed = zoomed);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) => _doubleTapDetails = details,
          onDoubleTap: _handleDoubleTap,
          onTap: () {
            if (_currentMode == EditorMode.pan) {
              setState(() {
                _showUI = !_showUI;
                _selectedTextBoxId = null;
                _selectedImageId = null;
              });
            } else {
              setState(() {
                _selectedTextBoxId = null;
                _selectedImageId = null;
              });
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                key: index == _activePageIndex ? _cropBoundaryKey : null,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.white,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Arka Plan: PDF/Görsel tam ekran (BoxFit.contain) veya Vektörel Kağıt Deseni (Düz, Çizgili, Kareli)
                      if (hasBg)
                        Positioned.fill(
                          child: Container(
                            color: Colors.white,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
                                final highlightBoxes = <Widget>[];

                                final pageMatches = _isSearching
                                    ? _allSearchMatches.where((m) => m.pageIndex == index && m.ocrElement != null).toList()
                                    : <SearchOccurrence>[];

                                if (pageMatches.isNotEmpty) {
                                  final firstElement = pageMatches.first.ocrElement!;
                                  final imgSize = firstElement.imageSize;
                                  if (imgSize.width > 0 && imgSize.height > 0) {
                                    final scaleX = containerSize.width / imgSize.width;
                                    final scaleY = containerSize.height / imgSize.height;
                                    final scale = math.min(scaleX, scaleY);

                                    final fittedWidth = imgSize.width * scale;
                                    final fittedHeight = imgSize.height * scale;
                                    final dx = (containerSize.width - fittedWidth) / 2;
                                    final dy = (containerSize.height - fittedHeight) / 2;

                                    for (final match in pageMatches) {
                                      final box = match.subBoundingBox ?? match.ocrElement!.boundingBox;
                                      final left = dx + box.left * scale - 1;
                                      final top = dy + box.top * scale - 1;
                                      final width = box.width * scale + 2;
                                      final height = box.height * scale + 2;

                                      final matchGlobalIdx = _allSearchMatches.indexOf(match);
                                      final isCurrentActiveMatch = (matchGlobalIdx == _currentSearchMatchIndex);

                                      final bgColor = isCurrentActiveMatch
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.55)
                                          : const Color(0xFFFFE600).withValues(alpha: 0.45);

                                      final borderColor = isCurrentActiveMatch
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFF59E0B);

                                      final glowColor = isCurrentActiveMatch
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                          : const Color(0xFFFFE600).withValues(alpha: 0.35);

                                      highlightBoxes.add(
                                        Positioned(
                                          left: left,
                                          top: top,
                                          width: width,
                                          height: height,
                                          child: IgnorePointer(
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: borderColor,
                                                  width: isCurrentActiveMatch ? 2.5 : 1.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: glowColor,
                                                    blurRadius: isCurrentActiveMatch ? 10 : 6,
                                                    spreadRadius: isCurrentActiveMatch ? 2 : 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }

                                return Stack(
                                  children: [
                                    Center(
                                      child: Image.memory(
                                        base64Decode(pageData.backgroundImageBase64!),
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                    ...highlightBoxes,
                                  ],
                                );
                              },
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: CustomPaint(
                            painter: PaperBackgroundPainter(
                              paperType: pageData.paperType,
                              isDark: false,
                            ),
                          ),
                        ),

                      // 2. Text Editor — arka plan yoksa göster
                      if (!hasBg)
                        Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.fromLTRB(55, 75, 20, 40),
                          child: IgnorePointer(
                            ignoring: !isTextMode,
                            child: TextField(
                              controller: pageData.textController,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: isTextMode ? 'Metin girmek için dokunun...' : '',
                                hintStyle: const TextStyle(color: Colors.black26),
                                filled: false,
                              ),
                              style: TextStyle(
                                color: const Color(0xFF0F172A),
                                fontSize: pageData.fontSize,
                                fontWeight: pageData.isBold ? FontWeight.bold : FontWeight.normal,
                                fontStyle: pageData.isItalic ? FontStyle.italic : FontStyle.normal,
                                height: pageData.paperType == 'lined' ? (32.0 / pageData.fontSize) : 1.5,
                              ),
                              onChanged: (val) {
                                pageData.text = val;
                                if (!_hasChanges) setState(() => _hasChanges = true);
                              },
                            ),
                          ),
                        ),
              
              // 3. Image Overlays
              ...pageData.imageOverlays.map((img) => _buildImageOverlay(img, pageData)),
              
              // 4. TextBox Overlays
              ...pageData.textBoxOverlays.map((tb) => _buildTextBoxOverlay(tb, pageData)),

              // 5. Drawing Board with stylus button eraser, eraser cursor & area eraser tracking
              Listener(
                onPointerHover: (event) {
                  if (_currentMode == EditorMode.drawing && index == _activePageIndex) {
                    final isStylusButton = (event.buttons > 1) ||
                                           (event.buttons & kSecondaryButton != 0) ||
                                           (event.buttons & kSecondaryMouseButton != 0) ||
                                           (event.buttons & kPrimaryStylusButton != 0) ||
                                           (event.buttons & kSecondaryStylusButton != 0) ||
                                           (event.buttons & kTertiaryButton != 0) ||
                                           (event.kind == ui.PointerDeviceKind.invertedStylus) ||
                                           (event.kind == ui.PointerDeviceKind.stylus && event.buttons != kPrimaryButton && event.buttons != 0);
                    if (isStylusButton && _activeTool != 'Eraser') {
                      _previousToolBeforeStylus = _activeTool;
                      setState(() {
                        _activeTool = 'Eraser';
                        _applyDrawingToolToActivePage();
                      });
                    }
                  }
                },
                onPointerMove: (event) {
                  if (_currentMode == EditorMode.drawing && index == _activePageIndex) {
                    final isStylusButton = (event.buttons > 1) ||
                                           (event.buttons & kSecondaryButton != 0) ||
                                           (event.buttons & kSecondaryMouseButton != 0) ||
                                           (event.buttons & kPrimaryStylusButton != 0) ||
                                           (event.buttons & kSecondaryStylusButton != 0) ||
                                           (event.buttons & kTertiaryButton != 0) ||
                                           (event.kind == ui.PointerDeviceKind.invertedStylus) ||
                                           (event.kind == ui.PointerDeviceKind.stylus && event.buttons != kPrimaryButton && event.buttons != 0);
                    if (isStylusButton && _activeTool != 'Eraser') {
                      _previousToolBeforeStylus = _activeTool;
                      setState(() {
                        _activeTool = 'Eraser';
                        _applyDrawingToolToActivePage();
                      });
                    }
                    if (_activeTool == 'Eraser') {
                      setState(() => _eraserCursorPosition = event.localPosition);
                    }
                  }
                },
                onPointerDown: (event) {
                  if (_currentMode == EditorMode.drawing && index == _activePageIndex) {
                    final isStylusButton = (event.buttons > 1) ||
                                           (event.buttons & kSecondaryButton != 0) ||
                                           (event.buttons & kSecondaryMouseButton != 0) ||
                                           (event.buttons & kPrimaryStylusButton != 0) ||
                                           (event.buttons & kSecondaryStylusButton != 0) ||
                                           (event.buttons & kTertiaryButton != 0) ||
                                           (event.kind == ui.PointerDeviceKind.invertedStylus) ||
                                           (event.kind == ui.PointerDeviceKind.stylus && event.buttons != kPrimaryButton && event.buttons != 0);
                    if (isStylusButton && _activeTool != 'Eraser') {
                      _previousToolBeforeStylus = _activeTool;
                      setState(() {
                        _activeTool = 'Eraser';
                        _applyDrawingToolToActivePage();
                      });
                    }
                    if (!_toolbarPinned && _toolbarVisible) {
                      setState(() => _toolbarVisible = false);
                    }
                    if (_activeTool == 'Eraser') {
                      setState(() => _eraserCursorPosition = event.localPosition);
                    }
                  }
                },
                onPointerUp: (event) {
                  if (_currentMode == EditorMode.drawing && index == _activePageIndex) {
                    if (_activeTool == 'Eraser') {
                      setState(() => _eraserCursorPosition = null);
                    }
                    if (_previousToolBeforeStylus != null) {
                      final revertTo = _previousToolBeforeStylus!;
                      _previousToolBeforeStylus = null;
                      setState(() {
                        _activeTool = revertTo;
                        _applyDrawingToolToActivePage();
                      });
                    }
                  }
                  if (!_toolbarPinned && !_toolbarVisible) {
                    Future.delayed(const Duration(milliseconds: 1500), () {
                      if (mounted && !_toolbarPinned) {
                        setState(() => _toolbarVisible = true);
                      }
                    });
                  }
                },
                child: IgnorePointer(
                  ignoring: !isDrawingMode || _activeTool == 'AreaEraser',
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return DrawingBoard(
                        controller: pageData.controller,
                        background: Container(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          color: Colors.transparent,
                        ),
                        boardConstrained: true,
                        onPointerDown: (_) {
                          if (!_hasChanges) setState(() => _hasChanges = true);
                        },
                      );
                    }
                  ),
                ),
              ),

              // 6. Dedicated Area Eraser Gesture Capture & Real-time Red Selection Box
              if (_currentMode == EditorMode.drawing && _activeTool == 'AreaEraser' && index == _activePageIndex)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      setState(() {
                        _areaEraserStart = details.localPosition;
                        _areaEraserEnd = details.localPosition;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _areaEraserEnd = details.localPosition;
                      });
                    },
                    onPanEnd: (details) {
                      if (_areaEraserStart != null && _areaEraserEnd != null) {
                        final selRect = Rect.fromPoints(_areaEraserStart!, _areaEraserEnd!);
                        if (selRect.width > 2 || selRect.height > 2) {
                          final history = List<PaintContent>.from(pageData.controller.getHistory);
                          final List<PaintContent> survivingContents = [];
                          
                          for (final content in history) {
                            if (content is SmoothLine) {
                              final pts = content.points;
                              final widths = content.strokeWidthList;
                              List<Offset> currentChunk = [];
                              List<double> currentWidths = [];
                              
                              for (int i = 0; i < pts.length; i++) {
                                final pt = pts[i];
                                final w = i < widths.length ? widths[i] : content.paint.strokeWidth;
                                
                                if (!selRect.contains(pt)) {
                                  currentChunk.add(pt);
                                  currentWidths.add(w);
                                } else {
                                  if (currentChunk.isNotEmpty) {
                                    final segPts = currentChunk.length == 1 
                                        ? [currentChunk.first, currentChunk.first] 
                                        : List<Offset>.from(currentChunk);
                                    final segWidths = currentWidths.length == 1 
                                        ? [currentWidths.first, currentWidths.first] 
                                        : List<double>.from(currentWidths);
                                    
                                    survivingContents.add(
                                      SmoothLine.data(
                                        brushPrecision: content.brushPrecision,
                                        minPointDistance: content.minPointDistance,
                                        useBezierCurve: content.useBezierCurve,
                                        smoothLevel: content.smoothLevel,
                                        points: segPts,
                                        strokeWidthList: segWidths,
                                        paint: Paint()
                                          ..color = content.paint.color
                                          ..strokeWidth = content.paint.strokeWidth
                                          ..style = content.paint.style
                                          ..strokeCap = content.paint.strokeCap
                                          ..strokeJoin = content.paint.strokeJoin,
                                      ),
                                    );
                                    currentChunk = [];
                                    currentWidths = [];
                                  }
                                }
                              }
                              
                              if (currentChunk.isNotEmpty) {
                                final segPts = currentChunk.length == 1 
                                    ? [currentChunk.first, currentChunk.first] 
                                    : List<Offset>.from(currentChunk);
                                final segWidths = currentWidths.length == 1 
                                    ? [currentWidths.first, currentWidths.first] 
                                    : List<double>.from(currentWidths);
                                
                                survivingContents.add(
                                  SmoothLine.data(
                                    brushPrecision: content.brushPrecision,
                                    minPointDistance: content.minPointDistance,
                                    useBezierCurve: content.useBezierCurve,
                                    smoothLevel: content.smoothLevel,
                                    points: segPts,
                                    strokeWidthList: segWidths,
                                    paint: Paint()
                                      ..color = content.paint.color
                                      ..strokeWidth = content.paint.strokeWidth
                                      ..style = content.paint.style
                                      ..strokeCap = content.paint.strokeCap
                                      ..strokeJoin = content.paint.strokeJoin,
                                  ),
                                );
                              }
                            } else if (content is HighlighterContent) {
                              final pts = content.points;
                              List<Offset> currentChunk = [];
                              
                              for (int i = 0; i < pts.length; i++) {
                                final pt = pts[i];
                                if (!selRect.contains(pt)) {
                                  currentChunk.add(pt);
                                } else {
                                  if (currentChunk.isNotEmpty) {
                                    final newHl = HighlighterContent();
                                    newHl.points.addAll(currentChunk);
                                    newHl.paint.color = content.paint.color;
                                    newHl.paint.strokeWidth = content.paint.strokeWidth;
                                    survivingContents.add(newHl);
                                    currentChunk = [];
                                  }
                                }
                              }
                              if (currentChunk.isNotEmpty) {
                                final newHl = HighlighterContent();
                                newHl.points.addAll(currentChunk);
                                newHl.paint.color = content.paint.color;
                                newHl.paint.strokeWidth = content.paint.strokeWidth;
                                survivingContents.add(newHl);
                              }
                            } else if (content is SimpleLine) {
                              final pts = content.points;
                              if (pts != null && pts.isNotEmpty) {
                                List<Offset> currentChunk = [];
                                for (int i = 0; i < pts.length; i++) {
                                  final pt = pts[i];
                                  if (!selRect.contains(pt)) {
                                    currentChunk.add(pt);
                                  } else {
                                    if (currentChunk.isNotEmpty) {
                                      final segPts = currentChunk.length == 1 
                                          ? [currentChunk.first, currentChunk.first] 
                                          : List<Offset>.from(currentChunk);
                                      survivingContents.add(
                                        SimpleLine.data(
                                          points: segPts,
                                          paint: Paint()
                                            ..color = content.paint.color
                                            ..strokeWidth = content.paint.strokeWidth,
                                        ),
                                      );
                                      currentChunk = [];
                                    }
                                  }
                                }
                                if (currentChunk.isNotEmpty) {
                                  final segPts = currentChunk.length == 1 
                                      ? [currentChunk.first, currentChunk.first] 
                                      : List<Offset>.from(currentChunk);
                                  survivingContents.add(
                                    SimpleLine.data(
                                      points: segPts,
                                      paint: Paint()
                                        ..color = content.paint.color
                                        ..strokeWidth = content.paint.strokeWidth,
                                    ),
                                  );
                                }
                              }
                            } else if (content is StraightLine) {
                              final sp = content.startPoint;
                              final ep = content.endPoint;
                              if (sp != null && ep != null) {
                                final dist = (ep - sp).distance;
                                if (dist <= 2) {
                                  if (!selRect.contains(sp)) survivingContents.add(content);
                                } else {
                                  final int steps = (dist / 2.0).ceil().clamp(2, 500);
                                  List<Offset> currentChunk = [];
                                  for (int i = 0; i <= steps; i++) {
                                    final t = i / steps;
                                    final pt = Offset(sp.dx + (ep.dx - sp.dx) * t, sp.dy + (ep.dy - sp.dy) * t);
                                    if (!selRect.contains(pt)) {
                                      currentChunk.add(pt);
                                    } else {
                                      if (currentChunk.length >= 2) {
                                        final sl = StraightLine();
                                        sl.paint = Paint()
                                          ..color = content.paint.color
                                          ..strokeWidth = content.paint.strokeWidth;
                                        sl.startPoint = currentChunk.first;
                                        sl.endPoint = currentChunk.last;
                                        survivingContents.add(sl);
                                      }
                                      currentChunk = [];
                                    }
                                  }
                                  if (currentChunk.length >= 2) {
                                    final sl = StraightLine();
                                    sl.paint = Paint()
                                      ..color = content.paint.color
                                      ..strokeWidth = content.paint.strokeWidth;
                                    sl.startPoint = currentChunk.first;
                                    sl.endPoint = currentChunk.last;
                                    survivingContents.add(sl);
                                  }
                                }
                              }
                            } else if (content is Rectangle) {
                              final sp = content.startPoint;
                              final ep = content.endPoint;
                              if (sp != null && ep != null) {
                                final bothInside = selRect.contains(sp) && selRect.contains(ep);
                                if (!bothInside) survivingContents.add(content);
                              }
                            } else if (content is Circle) {
                              final sp = content.startPoint;
                              final ep = content.endPoint;
                              final bothInside = selRect.contains(sp) && selRect.contains(ep);
                              if (!bothInside) survivingContents.add(content);
                            } else if (content is ArrowContent) {
                              final sp = content.start;
                              final ep = content.end;
                              if (sp != null && ep != null) {
                                final bothInside = selRect.contains(sp) && selRect.contains(ep);
                                if (!bothInside) survivingContents.add(content);
                              }
                            } else if (content is CustomTextContent) {
                              if (content.offset != null && !selRect.contains(content.offset!)) {
                                survivingContents.add(content);
                              }
                            } else if (content is Eraser) {
                              // Eraser strokes don't need to be kept if erased
                            } else {
                              survivingContents.add(content);
                            }
                          }
                          
                          pageData.controller.clear();
                          if (survivingContents.isNotEmpty) {
                            pageData.controller.addContents(survivingContents);
                          }
                          _hasChanges = true;
                        }
                      }
                      setState(() {
                        _areaEraserStart = null;
                        _areaEraserEnd = null;
                      });
                    },
                    onPanCancel: () {
                      setState(() {
                        _areaEraserStart = null;
                        _areaEraserEnd = null;
                      });
                    },
                    child: (_areaEraserStart != null && _areaEraserEnd != null)
                        ? CustomPaint(
                            painter: _AreaEraserPainter(
                              start: _areaEraserStart!,
                              end: _areaEraserEnd!,
                            ),
                            child: Container(color: Colors.transparent),
                          )
                        : Container(color: Colors.transparent),
                  ),
                ),
            ],
          ),
        ),
      ),

      // 7. Eraser cursor overlay (shown inside page frame with exact page alignment)
      if (_activeTool == 'Eraser' && _currentMode == EditorMode.drawing && _eraserCursorPosition != null && index == _activePageIndex)
        Builder(builder: (context) {
          final eraserDiameter = _eraserStrokeWidth.clamp(8.0, 100.0);
          final eraserRadius = eraserDiameter / 2;
          return Positioned(
            left: _eraserCursorPosition!.dx - eraserRadius,
            top: _eraserCursorPosition!.dy - eraserRadius,
            child: IgnorePointer(
              child: Container(
                width: eraserDiameter,
                height: eraserDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.8),
                  color: Colors.black.withValues(alpha: 0.04),
                ),
              ),
            ),
          );
        }),

      // 8. Question crop rectangle overlay & gesture detector (OUTSIDE RepaintBoundary so capture is clean!)
      if (_currentMode == EditorMode.questionCrop)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              final RenderBox? box = _cropBoundaryKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null) {
                final localPos = box.globalToLocal(details.globalPosition);
                setState(() {
                  _cropStartPoint = localPos;
                  _cropEndPoint = localPos;
                });
              }
            },
            onPanUpdate: (details) {
              if (_cropStartPoint != null) {
                final RenderBox? box = _cropBoundaryKey.currentContext?.findRenderObject() as RenderBox?;
                if (box != null) {
                  final localPos = box.globalToLocal(details.globalPosition);
                  setState(() {
                    _cropEndPoint = localPos;
                  });
                }
              }
            },
            onPanEnd: (details) async {
              if (_cropStartPoint != null && _cropEndPoint != null) {
                final start = _cropStartPoint!;
                final end = _cropEndPoint!;
                setState(() {
                  _cropStartPoint = null;
                  _cropEndPoint = null;
                });
                await _cropAndOpenSaveQuestionModal(start, end);
              }
            },
            child: Container(
              color: Colors.transparent,
              child: Builder(
                builder: (context) {
                  if (_cropStartPoint == null || _cropEndPoint == null) {
                    return const SizedBox();
                  }
                  final left = math.min(_cropStartPoint!.dx, _cropEndPoint!.dx);
                  final top = math.min(_cropStartPoint!.dy, _cropEndPoint!.dy);
                  final width = (_cropStartPoint!.dx - _cropEndPoint!.dx).abs();
                  final height = (_cropStartPoint!.dy - _cropEndPoint!.dy).abs();

                  return Stack(
                    children: [
                      Positioned(
                        left: left,
                        top: top,
                        width: width,
                        height: height,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                            border: Border.all(color: const Color(0xFFF59E0B), width: 2.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Center(
                            child: Icon(Icons.content_cut_rounded, color: Color(0xFFF59E0B), size: 28),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
    ],
  ),
),
),
);
}

  Future<void> _cropAndOpenSaveQuestionModal(Offset start, Offset end) async {
    try {
      final RenderRepaintBoundary? boundary = _cropBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final double pRatio = 2.5;
      final ui.Image fullImg = await boundary.toImage(pixelRatio: pRatio);

      final RenderBox box = _cropBoundaryKey.currentContext!.findRenderObject() as RenderBox;
      final double scaleX = fullImg.width / box.size.width;
      final double scaleY = fullImg.height / box.size.height;

      final left = (math.min(start.dx, end.dx) * scaleX).clamp(0.0, fullImg.width.toDouble());
      final top = (math.min(start.dy, end.dy) * scaleY).clamp(0.0, fullImg.height.toDouble());
      final right = (math.max(start.dx, end.dx) * scaleX).clamp(0.0, fullImg.width.toDouble());
      final bottom = (math.max(start.dy, end.dy) * scaleY).clamp(0.0, fullImg.height.toDouble());

      final width = right - left;
      final height = bottom - top;

      if (width < 25 || height < 25) {
        setState(() => _currentMode = EditorMode.pan);
        return;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final srcRect = Rect.fromLTWH(left, top, width, height);
      final destRect = Rect.fromLTWH(0, 0, width, height);

      canvas.drawImageRect(fullImg, srcRect, destRect, Paint());
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(width.toInt(), height.toInt());

      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${dir.path}/question_crop_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      setState(() => _currentMode = EditorMode.pan);

      if (mounted) {
        _showSaveQuestionModal(context, file);
      }
    } catch (e) {
      debugPrint('Error cropping question image: $e');
      setState(() => _currentMode = EditorMode.pan);
    }
  }

  void _showSaveQuestionModal(BuildContext context, File croppedFile) {
    final provider = context.read<PhotoNoteProvider>();
    final categories = provider.customCategories;

    File activeCroppedFile = croppedFile;
    String selectedCategory = categories.isNotEmpty ? categories.first : 'Tümü';
    String? selectedSubUnit;
    PhotoNote? selectedNote;
    bool isQuestionType = true;
    final noteTextCtrl = TextEditingController();
    final newCardTitleCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final subCategories = provider.getSubCategories(selectedCategory);
            final categoryFilter = selectedSubUnit != null ? '$selectedCategory / $selectedSubUnit' : selectedCategory;

            final availableNotes = selectedCategory == 'Tümü'
                ? provider.photoNotes
                : provider.photoNotes.where((n) => n.category.trim() == categoryFilter.trim() || n.category.startsWith('$categoryFilter / ')).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.content_cut_rounded, color: Color(0xFFF59E0B), size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Kırpılan Soruyu Görsel Karta Kaydet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: () async {
                        final fineCropped = await showImageCropper(context, imageFile: activeCroppedFile);
                        if (fineCropped != null) {
                          setModalState(() {
                            activeCroppedFile = fineCropped;
                          });
                        }
                      },
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(activeCroppedFile, fit: BoxFit.contain, width: double.infinity, height: double.infinity),
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.crop_rounded, color: Color(0xFFF59E0B), size: 14),
                                    SizedBox(width: 4),
                                    Text('Kırp / İnce Ayar Yap ✂️', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Icon(Icons.folder_open_rounded, color: Color(0xFF0EA5E9), size: 18),
                        const SizedBox(width: 8),
                        const Text('Ders / Klasör:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<String>(
                            value: categories.contains(selectedCategory) ? selectedCategory : (categories.isNotEmpty ? categories.first : 'Tümü'),
                            dropdownColor: const Color(0xFF0F172A),
                            isExpanded: true,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: (categories.isEmpty ? ['Tümü'] : categories).map((cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  selectedCategory = val;
                                  selectedSubUnit = null;
                                  selectedNote = null;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    if (subCategories.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.bookmark_rounded, color: Color(0xFF14B8A6), size: 18),
                          const SizedBox(width: 8),
                          const Text('Ünite:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButton<String?>(
                              value: selectedSubUnit,
                              dropdownColor: const Color(0xFF0F172A),
                              isExpanded: true,
                              hint: const Text('Tüm Üniteler', style: TextStyle(color: Colors.white38, fontSize: 13)),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: [
                                const DropdownMenuItem<String?>(value: null, child: Text('Tüm Üniteler')),
                                ...subCategories.map((sub) => DropdownMenuItem<String?>(value: sub, child: Text(sub))),
                              ],
                              onChanged: (val) {
                                setModalState(() {
                                  selectedSubUnit = val;
                                  selectedNote = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(Icons.style_rounded, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 8),
                        const Text('Görsel Kart:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButton<PhotoNote?>(
                            value: selectedNote,
                            dropdownColor: const Color(0xFF0F172A),
                            isExpanded: true,
                            hint: const Text('+ Yeni Görsel Kart Oluştur', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.bold)),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: [
                              const DropdownMenuItem<PhotoNote?>(
                                value: null,
                                child: Text('+ Yeni Görsel Kart Oluştur', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                              ),
                              ...availableNotes.map((n) => DropdownMenuItem<PhotoNote?>(value: n, child: Text(n.title))),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                selectedNote = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    if (selectedNote == null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: newCardTitleCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Yeni Kart Başlığı (Örn: Dağlar Soru Bankası)',
                          labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    TextField(
                      controller: noteTextCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Çözüm / Püf Nokta Notu (Opsiyonel)',
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    const SizedBox(height: 14),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: const Text('Soruyu Görsel Karta Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final cat = selectedSubUnit != null ? '$selectedCategory / $selectedSubUnit' : selectedCategory;
                        final noteText = noteTextCtrl.text.trim();

                        if (selectedNote != null) {
                          final noteId = selectedNote!.id;
                          await provider.addExtraImagesToNote(noteId, [activeCroppedFile], isQuestion: isQuestionType);
                          final reloadedNote = provider.photoNotes.firstWhere((n) => n.id == noteId);
                          if (noteText.isNotEmpty) {
                            final newImgIndex = reloadedNote.imagePaths.length - 1;
                            await provider.updateImageNote(noteId, newImgIndex, noteText);
                          }
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✂️ Soru "${reloadedNote.title}" kartına eklendi! ✅'),
                                backgroundColor: const Color(0xFF10B981),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          final title = newCardTitleCtrl.text.trim().isEmpty ? 'Soru Notu (${DateTime.now().day}/${DateTime.now().month})' : newCardTitleCtrl.text.trim();
                          final newNote = await provider.addPhotoNote(
                            title: title,
                            imageFile: activeCroppedFile,
                            category: cat,
                            color: '#1E3A8A',
                            note: noteText,
                          );
                          await provider.toggleQuestionFlag(newNote.id, 0);
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✂️ Yeni soru kartı "$title" oluşturuldu! ✅'),
                                backgroundColor: const Color(0xFF10B981),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _normalizeSearchText(String s) {
    return s
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase();
  }

  Future<String> _getPageOcrText(int index) async {
    if (_pageOcrTextCache.containsKey(index)) {
      return _pageOcrTextCache[index]!;
    }

    if (index < 0 || index >= _pages.length) return '';
    final page = _pages[index];
    final b64 = page.backgroundImageBase64;

    File? imageFile;

    try {
      if (b64 != null && b64.isNotEmpty) {
        final bytes = base64Decode(b64);

        Size imgSize = Size.zero;
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final frameInfo = await codec.getNextFrame();
          imgSize = Size(frameInfo.image.width.toDouble(), frameInfo.image.height.toDouble());
        } catch (_) {}

        final tmpDir = await getTemporaryDirectory();
        final tmpFile = File('${tmpDir.path}/ocr_page_${index}_${DateTime.now().millisecondsSinceEpoch}.png');
        await tmpFile.writeAsBytes(bytes);
        imageFile = tmpFile;

        final inputImage = InputImage.fromFile(imageFile);
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
        final extracted = _normalizeSearchText(recognizedText.text);

        final List<OcrElementMatch> elements = [];
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            for (final element in line.elements) {
              final normText = _normalizeSearchText(element.text);
              if (normText.isNotEmpty) {
                elements.add(OcrElementMatch(
                  text: normText,
                  boundingBox: element.boundingBox,
                  imageSize: imgSize,
                ));
              }
            }
          }
        }

        _pageOcrTextCache[index] = extracted;
        _pageOcrElementsCache[index] = elements;

        try { await imageFile.delete(); } catch (_) {}
        return extracted;
      }
    } catch (e) {
      debugPrint('OCR error on page $index: $e');
      if (imageFile != null) {
        try { await imageFile.delete(); } catch (_) {}
      }
    }

    _pageOcrTextCache[index] = '';
    _pageOcrElementsCache[index] = [];
    return '';
  }

  Future<void> _performSearch(String query) async {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) {
      setState(() {
        _allSearchMatches = [];
        _currentSearchMatchIndex = 0;
        _isOcrScanning = false;
      });
      return;
    }

    final q = _normalizeSearchText(rawQuery);

    List<SearchOccurrence> collectMatchesForPage(int i) {
      final p = _pages[i];
      final List<SearchOccurrence> list = [];

      // 1. Text Box Overlays
      for (final tb in p.textBoxOverlays) {
        final normText = _normalizeSearchText(tb.text);
        if (normText.isNotEmpty) {
          int start = 0;
          while (start < normText.length) {
            final foundIdx = normText.indexOf(q, start);
            if (foundIdx == -1) break;
            list.add(SearchOccurrence(
              pageIndex: i,
              textBox: tb,
              matchStartIndex: foundIdx,
              matchLength: q.length,
            ));
            start = foundIdx + math.max(1, q.length);
          }
        }
      }

      // 2. OCR Elements (Image Text Bounding Boxes)
      final elements = _pageOcrElementsCache[i] ?? [];
      for (final el in elements) {
        final normText = _normalizeSearchText(el.text);
        if (normText.isNotEmpty) {
          int start = 0;
          while (start < normText.length) {
            final foundIdx = normText.indexOf(q, start);
            if (foundIdx == -1) break;

            final box = el.boundingBox;
            final len = el.text.length > 0 ? el.text.length : 1;
            final charW = box.width / len;
            final subLeft = box.left + (foundIdx * charW);
            final subW = q.length * charW;
            final subBox = Rect.fromLTWH(subLeft, box.top, subW, box.height);

            list.add(SearchOccurrence(
              pageIndex: i,
              ocrElement: el,
              matchStartIndex: foundIdx,
              matchLength: q.length,
              subBoundingBox: subBox,
            ));
            start = foundIdx + math.max(1, q.length);
          }
        }
      }

      // 3. Regular Page Text / Notes
      final pageText = _normalizeSearchText(p.textController.text);
      if (pageText.isNotEmpty) {
        int start = 0;
        while (start < pageText.length) {
          final foundIdx = pageText.indexOf(q, start);
          if (foundIdx == -1) break;
          list.add(SearchOccurrence(
            pageIndex: i,
            matchStartIndex: foundIdx,
            matchLength: q.length,
          ));
          start = foundIdx + math.max(1, q.length);
        }
      }

      return list;
    }

    final matches = <SearchOccurrence>[];
    for (int i = 0; i < _pages.length; i++) {
      matches.addAll(collectMatchesForPage(i));
    }

    setState(() {
      _allSearchMatches = matches;
      _currentSearchMatchIndex = 0;
    });

    if (_allSearchMatches.isNotEmpty && _pageController.hasClients) {
      _pageController.animateToPage(
        _allSearchMatches.first.pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    final uncachedIndices = <int>[];
    for (int i = 0; i < _pages.length; i++) {
      if (!_pageOcrTextCache.containsKey(i)) {
        uncachedIndices.add(i);
      }
    }

    if (uncachedIndices.isNotEmpty) {
      setState(() => _isOcrScanning = true);
      for (final idx in uncachedIndices) {
        if (!_isSearching || _normalizeSearchText(_searchCtrl.text.trim()) != q) {
          break;
        }
        await _getPageOcrText(idx);
        if (mounted && _isSearching && _normalizeSearchText(_searchCtrl.text.trim()) == q) {
          final updatedMatches = <SearchOccurrence>[];
          for (int i = 0; i < _pages.length; i++) {
            updatedMatches.addAll(collectMatchesForPage(i));
          }
          setState(() {
            _allSearchMatches = updatedMatches;
          });
        }
      }
      if (mounted) {
        setState(() => _isOcrScanning = false);
      }
    }
  }

  void _nextSearchResult() {
    if (_allSearchMatches.isEmpty) return;
    setState(() {
      _currentSearchMatchIndex = (_currentSearchMatchIndex + 1) % _allSearchMatches.length;
    });
    final match = _allSearchMatches[_currentSearchMatchIndex];
    if (_pageController.hasClients && _activePageIndex != match.pageIndex) {
      _pageController.animateToPage(
        match.pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevSearchResult() {
    if (_allSearchMatches.isEmpty) return;
    setState(() {
      _currentSearchMatchIndex = (_currentSearchMatchIndex - 1 + _allSearchMatches.length) % _allSearchMatches.length;
    });
    final match = _allSearchMatches[_currentSearchMatchIndex];
    if (_pageController.hasClients && _activePageIndex != match.pageIndex) {
      _pageController.animateToPage(
        match.pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildTopSearchBar() {
    final matchCount = _allSearchMatches.length;
    final currentMatchDisplay = matchCount > 0 ? '${_currentSearchMatchIndex + 1}/$matchCount' : '0/0';

    return Row(
      children: [
        const Icon(Icons.search_rounded, color: Color(0xFF14B8A6), size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'Kitap içinde kelime ara...',
              hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: _performSearch,
          ),
        ),
        if (_isOcrScanning) ...[
          const SizedBox(width: 6),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: Color(0xFF14B8A6),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
          ),
          child: Text(
            currentMatchDisplay,
            style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70, size: 26),
          tooltip: 'Önceki Eşleşme',
          onPressed: matchCount > 0 ? _prevSearchResult : null,
        ),
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 26),
          tooltip: 'Sonraki Eşleşme',
          onPressed: matchCount > 0 ? _nextSearchResult : null,
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 25),
          tooltip: 'Aramayı Kapat',
          onPressed: () {
            setState(() {
              _isSearching = false;
              _allSearchMatches = [];
              _isOcrScanning = false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      color: const Color(0xFF0F172A).withValues(alpha: 0.55),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: _isSearching
              ? _buildTopSearchBar()
              : Row(
                  children: [
                    // 1. < (Geri Dön)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                      tooltip: 'Geri Dön',
                      onPressed: () async {
                        final shouldPop = await _onBackPressed();
                        if (shouldPop && mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),

                    // 2. Geri Alma (Undo)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: const Icon(Icons.undo_rounded, color: Colors.white70, size: 23),
                      tooltip: 'Geri Al',
                      onPressed: () {
                        _pages[_activePageIndex].controller.undo();
                        if (!_hasChanges) setState(() => _hasChanges = true);
                      },
                    ),

                    // 3. İleri Alma (Redo)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: const Icon(Icons.redo_rounded, color: Colors.white70, size: 23),
                      tooltip: 'İleri Al',
                      onPressed: () {
                        _pages[_activePageIndex].controller.redo();
                        if (!_hasChanges) setState(() => _hasChanges = true);
                      },
                    ),

                    // 4. Büyüteç (Kelime Ara)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: const Icon(Icons.search_rounded, color: Color(0xFF14B8A6), size: 24),
                      tooltip: 'Kelime Ara (Ctrl+F)',
                      onPressed: () {
                        setState(() {
                          _isSearching = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _searchFocusNode.requestFocus();
                          if (_searchCtrl.text.isNotEmpty) {
                            _searchCtrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _searchCtrl.text.length,
                            );
                            _performSearch(_searchCtrl.text);
                          }
                        });
                      },
                    ),

                    const Spacer(),

                    // 5. Kartlar (Görsel & Bilgi Kartları)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: Icon(
                        _showShortcut ? Icons.style_rounded : Icons.style_outlined,
                        color: _showShortcut ? const Color(0xFF14B8A6) : Colors.white70,
                        size: 23,
                      ),
                      tooltip: 'Görsel & Bilgi Kartları',
                      onPressed: () => setState(() => _showShortcut = !_showShortcut),
                    ),

                    // 6. Hesap Makinesi
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: Icon(
                        _showCalculator ? Icons.calculate_rounded : Icons.calculate_outlined,
                        color: _showCalculator ? const Color(0xFF14B8A6) : Colors.white70,
                        size: 23,
                      ),
                      tooltip: 'Hesap Makinesi',
                      onPressed: () => setState(() => _showCalculator = !_showCalculator),
                    ),

                    // 7. PDF Olarak Paylaş
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white70, size: 23),
                      tooltip: 'PDF Olarak Paylaş',
                      onPressed: _exportAsPdf,
                    ),

                    // 8. Tam Ekran Yapma (Tüm Barları Gizle)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      icon: const Icon(Icons.fullscreen_rounded, color: Color(0xFF14B8A6), size: 25),
                      tooltip: 'Tam Ekran (Barları Gizle)',
                      onPressed: () => setState(() => _showUI = false),
                    ),
                  ],
                ),
        ),
      ),
    );
  }


  
  void _applyDrawingToolToActivePage() {
      final controller = _pages[_activePageIndex].controller;
      
      debugPrint('--- DRAWING DEBUG ---');
      debugPrint('Active Page Index: $_activePageIndex');
      debugPrint('Active Tool: $_activeTool');
      debugPrint('Color: $_currentColor');
      
      if (_activeTool == 'SmoothLine') controller.setPaintContent(SmoothLine());
      else if (_activeTool == 'Highlighter') controller.setPaintContent(HighlighterContent());
      else if (_activeTool == 'Rectangle') controller.setPaintContent(Rectangle());
      else if (_activeTool == 'Circle') controller.setPaintContent(Circle());
      else if (_activeTool == 'StraightLine') controller.setPaintContent(StraightLine());
      else if (_activeTool == 'ArrowContent') controller.setPaintContent(ArrowContent());
      else if (_activeTool == 'Eraser') controller.setPaintContent(Eraser());
      // For AreaEraser, no PaintContent is added so DrawingBoard does not draw shapes
      
      if (_activeTool == 'Highlighter') {
        controller.setStyle(color: _currentColor.withValues(alpha: 0.38), strokeWidth: _highlighterStrokeWidth);
      } else if (_activeTool == 'Eraser') {
        controller.setStyle(color: Colors.white, strokeWidth: _eraserStrokeWidth);
      } else if (_activeTool != 'AreaEraser') {
        controller.setStyle(color: _currentColor, strokeWidth: _penStrokeWidth);
      }
      
      debugPrint('Tool applied successfully. Current PaintContent: ${controller.currentContent.runtimeType}');
  }

  Widget _buildDrawingToolbarContent() {
    if (_activeTool == 'AreaEraser') {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.crop_free_rounded, color: Color(0xFF14B8A6), size: 18),
          SizedBox(width: 8),
          Text(
            'Silmek istediğiniz alanın etrafına parmağınızla kutu çizin',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
        ],
      );
    }

    final isEraser = _activeTool == 'Eraser';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEraser ? Icons.auto_fix_normal 
                    : (_activeTool == 'Highlighter' ? Icons.border_color_rounded : Icons.line_weight_rounded),
                color: const Color(0xFF14B8A6),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isEraser ? 'Silgi Boyutu:'
                    : (_activeTool == 'Highlighter' ? 'Fosforlu Boyutu:' : 'Kalem Boyutu:'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              SizedBox(
                width: 120,
                child: Slider(
                  value: isEraser
                      ? _eraserStrokeWidth.clamp(4.0, 80.0)
                      : (_activeTool == 'Highlighter'
                          ? _highlighterStrokeWidth.clamp(8.0, 60.0)
                          : _penStrokeWidth.clamp(1.0, 40.0)),
                  min: isEraser ? 4.0 : (_activeTool == 'Highlighter' ? 8.0 : 1.0),
                  max: isEraser ? 80.0 : (_activeTool == 'Highlighter' ? 60.0 : 40.0),
                  activeColor: const Color(0xFF14B8A6),
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    setState(() {
                      if (isEraser) {
                        _eraserStrokeWidth = val;
                      } else if (_activeTool == 'Highlighter') {
                        _highlighterStrokeWidth = val;
                      } else {
                        _penStrokeWidth = val;
                      }
                      _applyDrawingToolToActivePage();
                    });
                  },
                ),
              ),
              Text(
                '${_currentStrokeWidth.toInt()}px',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF14B8A6)),
              ),
            ],
          ),
          if (!isEraser) ...[
            const VerticalDivider(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Colors.white,
                Colors.black,
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.amber,
                Colors.orange,
                Colors.purple,
                const Color(0xFF14B8A6),
              ].map((c) {
                final isSelected = _currentColor.value == c.value;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentColor = c;
                      _applyDrawingToolToActivePage();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.white24,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                    child: isSelected ? Icon(Icons.check_rounded, size: 12, color: c == Colors.white ? Colors.black : Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextToolbarContent() {
    final pageData = _pages[_activePageIndex];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ToolbarAction(
            icon: Icons.format_bold, 
            label: 'Kalın', 
            active: pageData.isBold,
            onTap: () {
              setState(() => pageData.isBold = !pageData.isBold);
              _hasChanges = true;
            },
          ),
          _ToolbarAction(
            icon: Icons.format_italic, 
            label: 'İtalik', 
            active: pageData.isItalic,
            onTap: () {
              setState(() => pageData.isItalic = !pageData.isItalic);
              _hasChanges = true;
            },
          ),
          const VerticalDivider(),
          const Padding(
            padding: EdgeInsets.only(left: 8.0, right: 4.0),
            child: Text('Boyut:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<double>(
              value: (pageData.fontSize >= 6 && pageData.fontSize <= 20) ? pageData.fontSize.floorToDouble() : 16.0,
              isDense: true,
              items: List.generate(15, (index) => (index + 6).toDouble()).map((size) {
                return DropdownMenuItem<double>(
                  value: size,
                  child: Text('${size.toInt()}', style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    pageData.fontSize = val;
                    _hasChanges = true;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageOverlay(ImageOverlay img, PageData pageData) {
    final bytes = base64Decode(img.base64Data);
    final isSelected = _selectedImageId == img.id;
    return Positioned(
      left: img.position.dx,
      top: img.position.dy,
      width: img.size.width,
      height: img.size.height,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedImageId = img.id;
            _selectedTextBoxId = null;
          });
        },
        onPanUpdate: _currentMode != EditorMode.drawing ? (d) {
          setState(() {
            img.position = Offset(
              img.position.dx + d.delta.dx,
              img.position.dy + d.delta.dy,
            );
            _hasChanges = true;
          });
        } : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  width: isSelected ? 2 : 0,
                ),
              ),
              child: Image.memory(bytes, fit: BoxFit.cover, width: img.size.width, height: img.size.height),
            ),
            // Resize handle
            if (isSelected && _currentMode != EditorMode.drawing)
              Positioned(
                right: -10, bottom: -10,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() {
                      img.size = Size(
                        (img.size.width + d.delta.dx).clamp(60, 800),
                        (img.size.height + d.delta.dy).clamp(60, 800),
                      );
                      _hasChanges = true;
                    });
                  },
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.open_in_full, size: 12, color: Colors.white),
                  ),
                ),
              ),
            // Delete button
            if (isSelected && _currentMode != EditorMode.drawing)
              Positioned(
                right: -10, top: -10,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      pageData.imageOverlays.remove(img);
                      _selectedImageId = null;
                      _hasChanges = true;
                    });
                  },
                  child: Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBoxOverlay(TextBoxOverlay tb, PageData pageData) {
    final isSelected = _selectedTextBoxId == tb.id;
    final matchesForThisBox = _isSearching && _searchCtrl.text.trim().isNotEmpty
        ? _allSearchMatches.where((m) => m.textBox == tb).toList()
        : <SearchOccurrence>[];

    final hasMatch = matchesForThisBox.isNotEmpty;
    final isCurrentActiveMatch = hasMatch && matchesForThisBox.any((m) => _allSearchMatches.indexOf(m) == _currentSearchMatchIndex);

    Color borderColor;
    Color bgColor;
    List<BoxShadow>? boxShadow;

    if (isCurrentActiveMatch) {
      borderColor = const Color(0xFFDC2626);
      bgColor = const Color(0xFFEF4444).withValues(alpha: 0.45);
      boxShadow = [
        BoxShadow(
          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ];
    } else if (hasMatch) {
      borderColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFFE600).withValues(alpha: 0.35);
      boxShadow = [
        BoxShadow(
          color: const Color(0xFFFFE600).withValues(alpha: 0.3),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    } else {
      borderColor = isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.4);
      bgColor = AppColors.surfaceLighter.withOpacity(0.9);
      boxShadow = null;
    }

    return Positioned(
      left: tb.position.dx,
      top: tb.position.dy,
      width: tb.size.width,
      height: tb.size.height,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTextBoxId = tb.id;
            _selectedImageId = null;
          });
        },
        onPanUpdate: _currentMode != EditorMode.drawing ? (d) {
          setState(() {
            tb.position = Offset(
              tb.position.dx + d.delta.dx,
              tb.position.dy + d.delta.dy,
            );
            _hasChanges = true;
          });
        } : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: tb.size.width,
              height: tb.size.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: borderColor,
                  width: (isCurrentActiveMatch || hasMatch) ? 2.5 : (isSelected ? 2 : 1),
                ),
                borderRadius: BorderRadius.circular(AppRadius.small),
                color: bgColor,
                boxShadow: boxShadow,
              ),
              padding: const EdgeInsets.all(4),
              child: IgnorePointer(
                ignoring: _currentMode == EditorMode.drawing,
                child: TextField(
                  controller: TextEditingController(text: tb.text),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Yazı...',
                    isDense: true,
                    contentPadding: EdgeInsets.all(2),
                  ),
                  style: TextStyle(
                    fontSize: tb.fontSize,
                    fontFamily: tb.fontFamily,
                    color: tb.textColor,
                    fontWeight: tb.isBold ? FontWeight.bold : FontWeight.normal,
                    fontStyle: tb.isItalic ? FontStyle.italic : FontStyle.normal,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedTextBoxId = tb.id;
                      _selectedImageId = null;
                    });
                  },
                  onChanged: (val) {
                    tb.text = val;
                    _hasChanges = true;
                  },
                ),
              ),
            ),
            // Resize handle
            if (isSelected && _currentMode != EditorMode.drawing)
              Positioned(
                right: -4, bottom: -4,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() {
                      tb.size = Size(
                        (tb.size.width + d.delta.dx).clamp(80, 600),
                        (tb.size.height + d.delta.dy).clamp(40, 600),
                      );
                      _hasChanges = true;
                    });
                  },
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.open_in_full, size: 12, color: Colors.white),
                  ),
                ),
              ),
            // Delete button
            if (isSelected && _currentMode != EditorMode.drawing)
              Positioned(
                right: -8, top: -8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      pageData.textBoxOverlays.remove(tb);
                      _selectedTextBoxId = null;
                      _hasChanges = true;
                    });
                  },
                  child: Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBoxToolbarContent() {
    final pageData = _pages[_activePageIndex];
    final tb = pageData.textBoxOverlays.cast<TextBoxOverlay?>().firstWhere(
      (t) => t!.id == _selectedTextBoxId, orElse: () => null,
    );
    if (tb == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedTextBoxId = null);
      });
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Text('Kutu:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          // Font size
          DropdownButtonHideUnderline(
            child: DropdownButton<double>(
              value: [8,10,12,14,16,18,20,24,28,32,36,40,48,56,64,72].contains(tb.fontSize.toInt()) 
                  ? tb.fontSize : 16.0,
              isDense: true,
              items: [8,10,12,14,16,18,20,24,28,32,36,40,48,56,64,72].map((s) {
                return DropdownMenuItem<double>(value: s.toDouble(), child: Text('$s', style: const TextStyle(fontSize: 13)));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() { tb.fontSize = val; _hasChanges = true; });
              },
            ),
          ),
          const SizedBox(width: 4),
          // Font family
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: tb.fontFamily,
              isDense: true,
              items: ['Roboto', 'Serif', 'Monospace', 'Cursive'].map((f) {
                return DropdownMenuItem<String>(value: f, child: Text(f, style: TextStyle(fontSize: 12, fontFamily: f)));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() { tb.fontFamily = val; _hasChanges = true; });
              },
            ),
          ),
          const VerticalDivider(),
          _ToolbarAction(
            icon: Icons.format_bold, label: 'B',
            active: tb.isBold,
            onTap: () => setState(() { tb.isBold = !tb.isBold; _hasChanges = true; }),
          ),
          _ToolbarAction(
            icon: Icons.format_italic, label: 'I',
            active: tb.isItalic,
            onTap: () => setState(() { tb.isItalic = !tb.isItalic; _hasChanges = true; }),
          ),
          const VerticalDivider(),
          // Text colors
          _ColorDot(color: Colors.black, onSelect: (c) => setState(() { tb.textColorValue = c.toARGB32(); _hasChanges = true; }), active: tb.textColorValue == Colors.black.toARGB32()),
          _ColorDot(color: Colors.red, onSelect: (c) => setState(() { tb.textColorValue = c.toARGB32(); _hasChanges = true; }), active: tb.textColorValue == Colors.red.toARGB32()),
          _ColorDot(color: Colors.blue, onSelect: (c) => setState(() { tb.textColorValue = c.toARGB32(); _hasChanges = true; }), active: tb.textColorValue == Colors.blue.toARGB32()),
          _ColorDot(color: Colors.green, onSelect: (c) => setState(() { tb.textColorValue = c.toARGB32(); _hasChanges = true; }), active: tb.textColorValue == Colors.green.toARGB32()),
          const VerticalDivider(),
          _ToolbarAction(
            icon: Icons.deselect, label: 'Kapat',
            onTap: () => setState(() => _selectedTextBoxId = null),
          ),
        ],
      ),
    );
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
            hintText: '1 - ${_pages.length} arası sayfa numarası',
            prefixIcon: const Icon(Icons.numbers),
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
          onSubmitted: (value) {
            final pageNum = int.tryParse(value);
            if (pageNum != null && pageNum >= 1 && pageNum <= _pages.length) {
              Navigator.pop(ctx, pageNum - 1);
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
              final pageNum = int.tryParse(ctrl.text);
              if (pageNum != null && pageNum >= 1 && pageNum <= _pages.length) {
                Navigator.pop(ctx, pageNum - 1);
              }
            },
            child: const AppText('Git', styleType: AppTextStyleType.label, color: Colors.white),
          ),
        ],
      ),
    ).then((pageIndex) {
      if (pageIndex != null && _pageController.hasClients) {
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xFF0F172A).withValues(alpha: 0.55),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF14B8A6), width: 0.8)),
          ),
          child: Row(
            children: [
              // 1. Sabit 4 Temel Buton (Kaydırma gerektirmez)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ToolbarAction(
                      icon: Icons.pan_tool_rounded, 
                      label: 'Hareket', 
                      active: _currentMode == EditorMode.pan,
                      onTap: () {
                        setState(() {
                          _selectedTextBoxId = null;
                          _selectedImageId = null;
                          _currentMode = EditorMode.pan;
                        });
                      },
                    ),
                    _ToolbarAction(
                      icon: Icons.add_photo_alternate, 
                      label: '+Resim', 
                      onTap: _pickImage,
                    ),
                    _ToolbarAction(
                      icon: Icons.content_cut_rounded,
                      label: 'Soru Kırp',
                      active: _currentMode == EditorMode.questionCrop,
                      onTap: () {
                        setState(() {
                          _selectedTextBoxId = null;
                          _selectedImageId = null;
                          _currentMode = EditorMode.questionCrop;
                          _cropStartPoint = null;
                          _cropEndPoint = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✂️ Ekranda kaydetmek istediğiniz sorunun etrafına parmağınızla kutu çizin.'),
                            backgroundColor: Color(0xFFF59E0B),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Dikey Ayırıcı Çizgi
              Container(
                width: 1,
                height: 28,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 2),
              ),

              // 2. Kompakt Sayfa Gezintisi: < 3/4 > +
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 28),
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 22),
                    onPressed: _activePageIndex > 0 
                        ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                        : null,
                  ),
                  GestureDetector(
                    onTap: _showGoToPageDialog,
                    onLongPress: _showChangePaperTypeSheet,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            '${_activePageIndex + 1}/${_pages.length}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14B8A6), fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _pages.isNotEmpty
                              ? (_pages[_activePageIndex].paperType == 'lined'
                                  ? '≡ çizgili'
                                  : _pages[_activePageIndex].paperType == 'grid'
                                      ? '# kareli'
                                      : '')
                              : '',
                          style: const TextStyle(color: Colors.white38, fontSize: 8),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 28),
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 22),
                    onPressed: _activePageIndex < _pages.length - 1 
                        ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                        : null,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF14B8A6), size: 24),
                    tooltip: 'Sayfa Ekle',
                    onPressed: _addPage,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingDrawingBar() {
    final isDrawing = _currentMode == EditorMode.drawing;
    
    return Positioned(
      left: _floatingBarOffset.dx,
      top: _floatingBarOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          final size = MediaQuery.of(context).size;
          setState(() {
            final newX = (_floatingBarOffset.dx + details.delta.dx).clamp(8.0, size.width - 64.0);
            final newY = (_floatingBarOffset.dy + details.delta.dy).clamp(MediaQuery.of(context).padding.top + 40.0, size.height - 280.0);
            _floatingBarOffset = Offset(newX, newY);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(_isFloatingBarExpanded ? 24 : 26),
            border: Border.all(
              color: isDrawing ? const Color(0xFF14B8A6) : Colors.white24,
              width: isDrawing ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDrawing 
                    ? const Color(0xFF14B8A6).withValues(alpha: 0.35) 
                    : Colors.black54,
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: _isFloatingBarExpanded 
              ? _buildExpandedVerticalBar()
              : _buildMiniBubble(),
        ),
      ),
    );
  }

  Widget _buildMiniBubble() {
    final isDrawing = _currentMode == EditorMode.drawing;
    IconData currentIcon = Icons.brush_rounded;
    if (_activeTool == 'Highlighter') {
      currentIcon = Icons.border_color_rounded;
    } else if (_activeTool == 'Eraser') {
      currentIcon = Icons.auto_fix_normal_rounded;
    } else if (_activeTool == 'AreaEraser') {
      currentIcon = Icons.crop_free_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: () {
          setState(() {
            _isFloatingBarExpanded = true;
          });
        },
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                currentIcon, 
                color: isDrawing ? const Color(0xFF14B8A6) : Colors.white, 
                size: 24,
              ),
              if (isDrawing && (_activeTool == 'SmoothLine' || _activeTool == 'Highlighter'))
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedVerticalBar() {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Kalem İkonu / Kapat Butonu (Baloncuk Toggle)
          GestureDetector(
            onTap: () => setState(() => _isFloatingBarExpanded = false),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
              ),
              child: const Icon(Icons.close_rounded, color: Color(0xFF14B8A6), size: 20),
            ),
          ),
          const SizedBox(height: 6),
          Container(width: 32, height: 1, color: Colors.white12),
          const SizedBox(height: 6),

          // 2. Kalem
          _buildVerticalToolItem(
            icon: Icons.brush_rounded,
            label: 'Kalem',
            active: _currentMode == EditorMode.drawing && _activeTool == 'SmoothLine',
            onTap: () {
              if (_currentMode == EditorMode.drawing && _activeTool == 'SmoothLine') {
                _showSettingsBottomSheet();
              } else {
                setState(() {
                  _selectedTextBoxId = null;
                  _selectedImageId = null;
                  _currentMode = EditorMode.drawing;
                  _activeTool = 'SmoothLine';
                  _applyDrawingToolToActivePage();
                });
              }
            },
          ),
          const SizedBox(height: 6),

          // 3. Silgi
          _buildVerticalToolItem(
            icon: Icons.auto_fix_normal_rounded,
            label: 'Silgi',
            active: _currentMode == EditorMode.drawing && _activeTool == 'Eraser',
            onTap: () {
              if (_currentMode == EditorMode.drawing && _activeTool == 'Eraser') {
                _showSettingsBottomSheet();
              } else {
                setState(() {
                  _selectedTextBoxId = null;
                  _selectedImageId = null;
                  _currentMode = EditorMode.drawing;
                  _activeTool = 'Eraser';
                  _applyDrawingToolToActivePage();
                });
              }
            },
          ),
          const SizedBox(height: 6),

          // 4. Alan Silgisi
          _buildVerticalToolItem(
            icon: Icons.crop_free_rounded,
            label: 'Alan Sil',
            active: _currentMode == EditorMode.drawing && _activeTool == 'AreaEraser',
            onTap: () {
              setState(() {
                _selectedTextBoxId = null;
                _selectedImageId = null;
                _currentMode = EditorMode.drawing;
                _activeTool = 'AreaEraser';
                _applyDrawingToolToActivePage();
              });
            },
          ),
          const SizedBox(height: 6),

          // 5. Fosforlu Kalem
          _buildVerticalToolItem(
            icon: Icons.border_color_rounded,
            label: 'Fosforlu',
            active: _currentMode == EditorMode.drawing && _activeTool == 'Highlighter',
            onTap: () {
              if (_currentMode == EditorMode.drawing && _activeTool == 'Highlighter') {
                _showSettingsBottomSheet();
              } else {
                setState(() {
                  _selectedTextBoxId = null;
                  _selectedImageId = null;
                  _currentMode = EditorMode.drawing;
                  _activeTool = 'Highlighter';
                  _applyDrawingToolToActivePage();
                });
              }
            },
          ),
          const SizedBox(height: 6),

          // 6. Ayar ⚙️
          _buildVerticalToolItem(
            icon: Icons.tune_rounded,
            label: 'Ayar',
            active: false,
            onTap: _showSettingsBottomSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalToolItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF14B8A6) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: active ? Colors.black : Colors.white70,
            size: 22,
          ),
        ),
      ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final isEraser = _activeTool == 'Eraser';
            final isHighlighter = _activeTool == 'Highlighter';
            final currentWidth = isEraser 
                ? (_currentStrokeWidth * 2.5).clamp(4.0, 80.0) 
                : _currentStrokeWidth.clamp(1.0, 40.0);

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF14B8A6), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Colors.black87, blurRadius: 20, spreadRadius: 2),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isEraser 
                                  ? Icons.auto_fix_normal 
                                  : isHighlighter 
                                      ? Icons.border_color_rounded 
                                      : Icons.brush,
                              color: const Color(0xFF14B8A6),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEraser 
                                  ? 'Silgi Ayarları' 
                                  : isHighlighter 
                                      ? 'Fosforlu Kalem Ayarları' 
                                      : 'Kalem Ayarları',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 1: Stroke Width / Size
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEraser ? 'Silgi Kalınlığı' : 'Uç Kalınlığı',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            '${currentWidth.toInt()} px',
                            style: const TextStyle(color: Color(0xFF14B8A6), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Row(
                      children: [
                        // Live Preview Circle
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: Container(
                            width: (currentWidth * 0.8).clamp(3.0, 32.0),
                            height: (currentWidth * 0.8).clamp(3.0, 32.0),
                            decoration: BoxDecoration(
                              color: isEraser ? Colors.white : _currentColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white38, width: 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF14B8A6),
                              inactiveTrackColor: Colors.white12,
                              thumbColor: const Color(0xFF14B8A6),
                              overlayColor: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: isEraser 
                                  ? currentWidth.clamp(4.0, 80.0) 
                                  : _currentStrokeWidth.clamp(1.0, 40.0),
                              min: isEraser ? 4.0 : 1.0,
                              max: isEraser ? 80.0 : 40.0,
                              onChanged: (val) {
                                setModalState(() {
                                  if (isEraser) {
                                    _currentStrokeWidth = val / 2.5;
                                  } else {
                                    _currentStrokeWidth = val;
                                  }
                                });
                                setState(() {
                                  _applyDrawingToolToActivePage();
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Section 2: Colors (Only for Pen & Highlighter)
                    if (!isEraser) ...[
                      const Text(
                        'Renk Seçimi',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Colors.black,
                          Colors.white,
                          const Color(0xFFEF4444), // Red
                          const Color(0xFF3B82F6), // Blue
                          const Color(0xFF10B981), // Green
                          const Color(0xFFF59E0B), // Amber / Yellow
                          const Color(0xFFF97316), // Orange
                          const Color(0xFF8B5CF6), // Purple
                          const Color(0xFFEC4899), // Pink
                          const Color(0xFF14B8A6), // Teal
                        ].map((c) {
                          final isSelected = _currentColor.toARGB32() == c.toARGB32();
                          return GestureDetector(
                            onTap: () {
                              setModalState(() => _currentColor = c);
                              setState(() {
                                _currentColor = c;
                                _applyDrawingToolToActivePage();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF14B8A6) : Colors.white24,
                                  width: isSelected ? 3.0 : 1.5,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  )
                                ] : null,
                              ),
                              child: isSelected 
                                  ? Icon(
                                      Icons.check_rounded, 
                                      size: 20, 
                                      color: c == Colors.white ? Colors.black : Colors.white,
                                    ) 
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ToolbarAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_ToolbarAction> createState() => _ToolbarActionState();
}

class _ToolbarActionState extends State<_ToolbarAction> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBg = theme.colorScheme.primary.withOpacity(0.12);
    final inactiveBg = Colors.transparent;
    final activeBorder = Border.all(color: theme.colorScheme.primary.withOpacity(0.4), width: 1.5);
    final inactiveBorder = Border.all(color: Colors.transparent, width: 1.5);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.65);

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: widget.active ? activeBg : inactiveBg,
              borderRadius: BorderRadius.circular(10),
              border: widget.active ? activeBorder : inactiveBorder,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: widget.active ? activeColor : inactiveColor, size: 20),
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: widget.active ? FontWeight.bold : FontWeight.normal,
                    color: widget.active ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatefulWidget {
  final Color color;
  final Function(Color) onSelect;
  final bool active;
  const _ColorDot({required this.color, required this.onSelect, this.active = false});

  @override
  State<_ColorDot> createState() => _ColorDotState();
}

class _ColorDotState extends State<_ColorDot> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onSelect(widget.color);
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              border: Border.all(
                color: widget.active 
                    ? Theme.of(context).primaryColor 
                    : Colors.white.withOpacity(0.4), 
                width: widget.active ? 2.5 : 1.5,
              ),
              boxShadow: widget.active 
                  ? [BoxShadow(color: widget.color.withOpacity(0.35), blurRadius: 8, spreadRadius: 0.5)] 
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class CustomTextContent extends PaintContent {
  String text;
  Offset? offset;
  double fontSize;
  Color color;

  CustomTextContent(this.text, {this.fontSize = 20, this.color = Colors.black}) : super.paint(Paint());

  CustomTextContent.fromJson(Map<String, dynamic> data) 
    : text = data['text'] as String,
      fontSize = data['fontSize'] as double? ?? 20,
      color = Color(data['color'] as int? ?? Colors.black.value),
      super.paint(Paint());

  @override
  void draw(Canvas canvas, Size size, bool deeper) {
    if (offset == null) return;
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset!);
  }

  @override
  void drawing(Offset nowPoint) => offset = nowPoint;

  @override
  void startDraw(Offset startPoint) => offset = startPoint;

  @override
  Map<String, dynamic> toContentJson() => toJson();

  @override
  Map<String, dynamic> toJson() => {
    'type': 'CustomTextContent', 
    'text': text,
    'fontSize': fontSize,
    'color': color.value,
  };

  @override
  CustomTextContent copy() => CustomTextContent(text, fontSize: fontSize, color: color);
}

class ArrowContent extends PaintContent {
  Offset? start;
  Offset? end;

  ArrowContent() : super.paint(Paint());
  
  ArrowContent.fromJson(Map<String, dynamic> data) : super.paint(Paint()) {
    if (data['startX'] != null && data['startY'] != null) {
      start = Offset(data['startX'] as double, data['startY'] as double);
    }
    if (data['endX'] != null && data['endY'] != null) {
      end = Offset(data['endX'] as double, data['endY'] as double);
    }
    if (data['color'] != null) {
      paint.color = Color(data['color'] as int);
    }
    if (data['strokeWidth'] != null) {
      paint.strokeWidth = (data['strokeWidth'] as num).toDouble();
    }
  }

  @override
  void draw(Canvas canvas, Size size, bool deeper) {
    if (start == null || end == null) return;
    
    // Set paint properties
    paint.style = PaintingStyle.stroke;
    paint.strokeCap = StrokeCap.round;
    paint.strokeJoin = StrokeJoin.round;
    
    // Draw the main line of the arrow
    canvas.drawLine(start!, end!, paint);
    
    // Draw the arrow head
    final dX = end!.dx - start!.dx;
    final dY = end!.dy - start!.dy;
    final angle = math.atan2(dY, dX);
    
    final arrowSize = (paint.strokeWidth * 3).clamp(12.0, 30.0); // Size of arrow head proportional to stroke
    final arrowAngle = 0.5; // Angle of arrow head sides relative to line (approx 30 deg)
    
    final path = Path();
    path.moveTo(end!.dx, end!.dy);
    path.lineTo(
      end!.dx - arrowSize * math.cos(angle - arrowAngle),
      end!.dy - arrowSize * math.sin(angle - arrowAngle),
    );
    path.moveTo(end!.dx, end!.dy);
    path.lineTo(
      end!.dx - arrowSize * math.cos(angle + arrowAngle),
      end!.dy - arrowSize * math.sin(angle + arrowAngle),
    );
    
    final headPaint = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    canvas.drawPath(path, headPaint);
  }

  @override
  void drawing(Offset nowPoint) => end = nowPoint;

  @override
  void startDraw(Offset startPoint) => start = startPoint;

  @override
  Map<String, dynamic> toContentJson() => toJson();

  @override
  Map<String, dynamic> toJson() => {
    'type': 'ArrowContent',
    'startX': start?.dx,
    'startY': start?.dy,
    'endX': end?.dx,
    'endY': end?.dy,
    'color': paint.color.value,
    'strokeWidth': paint.strokeWidth,
  };

  @override
  ArrowContent copy() => ArrowContent()
    ..start = start
    ..end = end
    ..paint.color = paint.color
    ..paint.strokeWidth = paint.strokeWidth;
}

class HighlighterContent extends PaintContent {
  final List<Offset> points = [];

  HighlighterContent() : super.paint(Paint());

  HighlighterContent.fromJson(Map<String, dynamic> data) : super.paint(Paint()) {
    if (data['points'] is List) {
      for (final p in data['points']) {
        if (p is Map && p['x'] != null && p['y'] != null) {
          points.add(Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()));
        }
      }
    }
    if (data['color'] != null) {
      paint.color = Color(data['color'] as int);
    }
    if (data['strokeWidth'] != null) {
      paint.strokeWidth = (data['strokeWidth'] as num).toDouble();
    }
  }

  @override
  void draw(Canvas canvas, Size size, bool deeper) {
    if (points.isEmpty) return;

    final drawWidth = paint.strokeWidth > 0 ? paint.strokeWidth : 18.0;
    final drawPaint = Paint()
      ..color = paint.color.withValues(alpha: 0.38)
      ..strokeWidth = drawWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.bevel;

    if (points.length == 1) {
      canvas.drawCircle(points.first, drawWidth / 2, drawPaint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      path.quadraticBezierTo(p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
    }

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawPath(path, drawPaint);
    canvas.restore();
  }

  @override
  void drawing(Offset nowPoint) => points.add(nowPoint);

  @override
  void startDraw(Offset startPoint) => points.add(startPoint);

  @override
  Map<String, dynamic> toContentJson() => toJson();

  @override
  Map<String, dynamic> toJson() => {
    'type': 'HighlighterContent',
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'color': paint.color.value,
    'strokeWidth': paint.strokeWidth,
  };

  @override
  HighlighterContent copy() {
    final newContent = HighlighterContent();
    newContent.points.addAll(points);
    newContent.paint.color = paint.color;
    newContent.paint.strokeWidth = paint.strokeWidth;
    return newContent;
  }
}

class _AreaEraserPainter extends CustomPainter {
  final Offset start;
  final Offset end;

  _AreaEraserPainter({required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);
    
    // 1. Semi-transparent red fill
    final fillPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fillPaint);

    // 2. Bold red border
    final borderPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, borderPaint);

    // 3. Corner accent handles
    final handlePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    const handleSize = 6.0;
    canvas.drawCircle(rect.topLeft, handleSize / 2, handlePaint);
    canvas.drawCircle(rect.topRight, handleSize / 2, handlePaint);
    canvas.drawCircle(rect.bottomLeft, handleSize / 2, handlePaint);
    canvas.drawCircle(rect.bottomRight, handleSize / 2, handlePaint);
  }

  @override
  bool shouldRepaint(covariant _AreaEraserPainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end;
  }
}
