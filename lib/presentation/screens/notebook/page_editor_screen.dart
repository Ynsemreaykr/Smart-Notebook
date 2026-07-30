import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../application/providers/page_provider.dart';
import '../../../application/providers/book_provider.dart';
import '../../../application/providers/pdf_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../application/providers/photo_note_provider.dart';
import '../../../domain/models/photo_note.dart';
import '../../../domain/models/overlay_models.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_container.dart';
import '../../../widgets/common/app_text.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/floating_calculator.dart';
import '../../widgets/floating_book_shortcut.dart';

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

  PageData({
    this.text = '', 
    DrawingController? controller,
    this.fontSize = 16.0,
    this.isBold = false,
    this.isItalic = false,
    List<ImageOverlay>? imageOverlays,
    List<TextBoxOverlay>? textBoxOverlays,
    this.backgroundImageBase64,
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

class PageEditorScreen extends StatefulWidget {
  final String pageId;
  /// Optional: if provided, all pages of the book are loaded (for PDF import multi-page support).
  final String? bookId;
  const PageEditorScreen({super.key, required this.pageId, this.bookId});

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  late TextEditingController _titleCtrl;
  bool _initialized = false;
  bool _hasChanges = false;
  bool _showCalculator = false;
  bool _showShortcut = false;
  
  List<PageData> _pages = [PageData()];
  EditorMode _currentMode = EditorMode.pan;
  bool _isZoomed = false;
  bool _showUI = true;
  int _pointerCount = 0;

  
  Color _currentColor = Colors.black;
  double _currentStrokeWidth = 3.0;

  String _activeTool = 'SmoothLine';
  int _activePageIndex = 0;
  String? _selectedTextBoxId;
  String? _selectedImageId;
  final ImagePicker _imagePicker = ImagePicker();
  
  late PageController _pageController;
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;
  
  // Question crop tool state
  final GlobalKey _cropBoundaryKey = GlobalKey();
  Offset? _cropStartPoint;
  Offset? _cropEndPoint;
  
  /// When bookId is set, maps each _pages[i] to the corresponding NotePage.id
  /// so we can save each page's drawingJson back to its own NotePage record.
  List<String> _notePageIds = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
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

  void _addPage() {
    setState(() {
      _pages.add(PageData());
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yeni sayfa eklendi!'), duration: Duration(seconds: 1)),
    );
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
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        
        if (_hasChanges) {
          final shouldSave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const AppText(
                'Kaydedilsin mi?',
                styleType: AppTextStyleType.headingMedium,
                styleOverride: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const AppText('Son yaptığınız değişiklikler kaydedilsin mi?', styleType: AppTextStyleType.bodyMedium),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: AppText('Hayır', styleType: AppTextStyleType.label, color: AppColors.textSecondary),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: AppText('Evet', styleType: AppTextStyleType.label, color: Colors.white),
                ),
              ],
            ),
          );

          if (shouldSave != null) {
            if (shouldSave) {
              await _save();
            }
            if (mounted) {
              Navigator.of(context).pop();
            }
          }
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
              itemCount: _pages.length,
              physics: (_currentMode == EditorMode.drawing || _currentMode == EditorMode.questionCrop || _isZoomed) 
                  ? const NeverScrollableScrollPhysics() 
                  : const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _activePageIndex = index;
                  _isZoomed = false;
                  if (_currentMode == EditorMode.drawing) {
                     _applyDrawingToolToActivePage();
                  }
                });
              },
              itemBuilder: (context, index) {
                return _buildPageFrame(index);
              },
            ),

            // Layer 1: Floating Transparent Top Bar & Toolbars
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showUI ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_showUI,
                  child: _buildTopInterface(),
                ),
              ),
            ),

            // Layer 2: Floating Transparent Bottom Bar
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
    
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
    }
    setState(() {});
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
        clipBehavior: Clip.none,
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
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Arka Plan: PDF/Görsel tam ekran (BoxFit.contain)
                      if (hasBg)
                        Positioned.fill(
                          child: Center(
                            child: Image.memory(
                              base64Decode(pageData.backgroundImageBase64!),
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),

              // 2. Text Editor — arka plan yoksa göster
              if (!hasBg)
                Container(
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
                  child: IgnorePointer(
                    ignoring: !isTextMode,
                    child: TextField(
                      controller: pageData.textController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Metin girmek için dokunun...',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: false,
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: pageData.fontSize,
                        fontWeight: pageData.isBold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: pageData.isItalic ? FontStyle.italic : FontStyle.normal,
                        height: 1.5,
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

              // 5. Drawing Board
              IgnorePointer(
                ignoring: !isDrawingMode,
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
                      onPointerUp: (_) {
                        if (_activeTool == 'AreaEraser') {
                          final contents = pageData.controller.getJsonList();
                          if (contents.isNotEmpty) {
                            final lastItem = contents.last;
                            if (lastItem['type'] == 'Rectangle') {
                              final sp = lastItem['startPoint'];
                              final ep = lastItem['endPoint'];
                              if (sp != null && ep != null) {
                                List<Map<String, dynamic>> updatedContents = List.from(contents);
                                updatedContents.removeLast();
                                
                                Map<String, dynamic> eraserRect = Map.from(lastItem);
                                eraserRect['paint'] = {
                                  "blendMode": 0,
                                  "color": 0,
                                  "filterQuality": 0,
                                  "invertColors": false,
                                  "isAntiAlias": false,
                                  "strokeCap": 0,
                                  "strokeJoin": 0,
                                  "strokeWidth": 0.0,
                                  "style": 0
                                };
                                updatedContents.add(eraserRect);
                                
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  pageData.controller.clear();
                                  if (updatedContents.isNotEmpty) {
                                    pageData.controller.addContents(updatedContents.map((e) => _parseJsonToContent(e)).whereType<PaintContent>().toList());
                                  }
                                });
                              }
                            }
                          }
                        }
                      },
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
      // 5. Question crop rectangle overlay & gesture detector (OUTSIDE RepaintBoundary so capture is clean!)
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

                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(croppedFile, fit: BoxFit.contain),
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
                          await provider.addExtraImagesToNote(noteId, [croppedFile], isQuestion: isQuestionType);
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
                            imageFile: croppedFile,
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

  Widget _buildTopInterface() {
    final hasBg = _pages.isNotEmpty &&
        _pages[_activePageIndex].backgroundImageBase64 != null &&
        _pages[_activePageIndex].backgroundImageBase64!.isNotEmpty;
    
    int activePropertyIndex = 0;
    
    if (_selectedTextBoxId != null) {
      activePropertyIndex = 2; // TextBox properties
    } else if (_currentMode == EditorMode.drawing) {
      activePropertyIndex = 1; // Drawing properties
    } else if (_currentMode == EditorMode.pan) {
      activePropertyIndex = 3; // Pan / Move mode status toolbar
    } else if (!hasBg && _currentMode == EditorMode.text) {
      activePropertyIndex = 0; // Text properties
    } else {
      activePropertyIndex = 3;
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Header Row matching PhotoNoteViewerScreen style
        Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Sayfa Başlığı...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      ),
                      onChanged: (_) => setState(() => _hasChanges = true),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showShortcut ? Icons.style_rounded : Icons.style_outlined,
                      color: _showShortcut ? const Color(0xFF14B8A6) : Colors.white70,
                      size: 22,
                    ),
                    tooltip: 'Görsel & Bilgi Kartları',
                    onPressed: () => setState(() => _showShortcut = !_showShortcut),
                  ),
                  IconButton(
                    icon: Icon(
                      _showCalculator ? Icons.calculate_rounded : Icons.calculate_outlined,
                      color: _showCalculator ? const Color(0xFF14B8A6) : Colors.white70,
                      size: 22,
                    ),
                    tooltip: 'Hesap Makinesi',
                    onPressed: () => setState(() => _showCalculator = !_showCalculator),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white70, size: 22),
                    tooltip: 'PDF Olarak Paylaş',
                    onPressed: _exportAsPdf,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Main Tools Toolbar (Hareket, Kalem, Fosforlu, Silgi, +Resim)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: _buildMainToolbar(hasBg: hasBg),
        ),

        // Secondary Property Bar
        if (activePropertyIndex != 3)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 60,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                ),
                child: IndexedStack(
                  index: activePropertyIndex,
                  children: [
                    _buildTextToolbarContent(),
                    _buildDrawingToolbarContent(),
                    _buildTextBoxToolbarContent(),
                    _buildPanToolbarContent(),
                  ],
                ),
              ),
            ),
          ),

      ],
    );
  }


  Widget _buildPanToolbarContent() {
    return const SizedBox.shrink();
  }

  Widget _buildMainToolbar({bool hasBg = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5), width: 1.2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 1)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
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
            const VerticalDivider(),
            _ToolbarAction(
              icon: Icons.brush, 
              label: 'Kalem', 
              onTap: () {
                 setState(() {
                    _selectedTextBoxId = null;
                    _selectedImageId = null;
                    _currentMode = EditorMode.drawing;
                    _activeTool = 'SmoothLine';
                    _applyDrawingToolToActivePage();
                 });
              },
              active: _currentMode == EditorMode.drawing && _activeTool == 'SmoothLine',
            ),
            const VerticalDivider(),
            _ToolbarAction(
              icon: Icons.border_color_rounded, 
              label: 'Fosforlu', 
              onTap: () {
                 setState(() {
                    _selectedTextBoxId = null;
                    _selectedImageId = null;
                    _currentMode = EditorMode.drawing;
                    _activeTool = 'Highlighter';
                    _applyDrawingToolToActivePage();
                 });
              },
              active: _currentMode == EditorMode.drawing && _activeTool == 'Highlighter',
            ),
            const VerticalDivider(),
            _ToolbarAction(
              icon: Icons.auto_fix_normal, 
              label: 'Silgi', 
              onTap: () {
                 setState(() {
                    _selectedTextBoxId = null;
                    _selectedImageId = null;
                    _currentMode = EditorMode.drawing;
                    _activeTool = 'Eraser';
                    _applyDrawingToolToActivePage();
                 });
              },
              active: _currentMode == EditorMode.drawing && (_activeTool == 'Eraser' || _activeTool == 'AreaEraser'),
            ),
            const VerticalDivider(),
            _ToolbarAction(
              icon: Icons.add_photo_alternate, 
              label: '+Resim', 
              onTap: _pickImage,
            ),
            const VerticalDivider(),
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
      else if (_activeTool == 'AreaEraser') controller.setPaintContent(Rectangle());
      
      if (_activeTool == 'AreaEraser') {
        controller.setStyle(color: Colors.red.withValues(alpha: 0.3), strokeWidth: 2.0);
      } else if (_activeTool == 'Highlighter') {
        final highlighterWidth = (_currentStrokeWidth * 3.5).clamp(8.0, 60.0);
        controller.setStyle(color: _currentColor.withValues(alpha: 0.38), strokeWidth: highlighterWidth);
      } else if (_activeTool == 'Eraser') {
        final eraserWidth = (_currentStrokeWidth * 2.5).clamp(4.0, 80.0);
        controller.setStyle(color: Colors.white, strokeWidth: eraserWidth);
      } else {
        controller.setStyle(color: _currentColor, strokeWidth: _currentStrokeWidth);
      }
      
      debugPrint('Tool applied successfully. Current PaintContent: ${controller.currentContent.runtimeType}');
  }

  Widget _buildDrawingToolbarContent() {
    final isEraser = _activeTool == 'Eraser' || _activeTool == 'AreaEraser';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEraser ? Icons.auto_fix_normal : Icons.line_weight_rounded,
                color: const Color(0xFF14B8A6),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                isEraser ? 'Silgi Boyutu:' : 'Uç Boyutu:',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              SizedBox(
                width: 120,
                child: Slider(
                  value: _currentStrokeWidth.clamp(1.0, 40.0),
                  min: 1.0,
                  max: 40.0,
                  activeColor: const Color(0xFF14B8A6),
                  inactiveColor: Colors.white24,
                  onChanged: (val) {
                    setState(() {
                      _currentStrokeWidth = val;
                      _applyDrawingToolToActivePage();
                    });
                  },
                ),
              ),
              Text(
                isEraser ? '${(_currentStrokeWidth * 2.5).toInt()}px' : '${_currentStrokeWidth.toInt()}px',
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
                  color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.4),
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(AppRadius.small),
                color: AppColors.surfaceLighter.withOpacity(0.9),
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
      color: Colors.black.withValues(alpha: 0.6),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF14B8A6), width: 0.5)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 28),
                  onPressed: _activePageIndex > 0 
                      ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                      : null,
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showGoToPageDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.import_contacts_rounded, size: 18, color: Color(0xFF14B8A6)),
                        const SizedBox(width: 6),
                        Text(
                          'Sayfa ${_activePageIndex + 1} / ${_pages.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14B8A6), fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: Color(0xFF14B8A6), size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 28),
                  onPressed: _activePageIndex < _pages.length - 1 
                      ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                      : null,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _addPage,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Sayfa Ekle', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }





  void _setDrawingColor(Color color) {
    setState(() {
      _currentColor = color;
      _applyDrawingToolToActivePage();
    });
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
