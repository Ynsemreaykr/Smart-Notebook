import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_drawing_board/flutter_drawing_board.dart';
import 'package:flutter_drawing_board/paint_contents.dart';
import 'package:image_picker/image_picker.dart';
import '../../../application/providers/page_provider.dart';
import '../../../application/providers/book_provider.dart';
import '../../../application/providers/pdf_provider.dart';
import '../../../application/providers/theme_provider.dart';
import '../../../domain/models/overlay_models.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/app_container.dart';
import '../../../widgets/common/app_text.dart';
import '../../widgets/bounce_button.dart';
import '../../widgets/floating_calculator.dart';

enum EditorMode { text, drawing, pan }

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
    default: return null;
  }
}

class PageEditorScreen extends StatefulWidget {
  final String pageId;
  const PageEditorScreen({super.key, required this.pageId});

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  late TextEditingController _titleCtrl;
  bool _initialized = false;
  bool _hasChanges = false;
  bool _showCalculator = false;
  
  List<PageData> _pages = [PageData()];
  EditorMode _currentMode = EditorMode.text;
  
  Color _currentColor = Colors.black;
  double _currentStrokeWidth = 3.0;

  String _activeTool = 'SmoothLine';
  int _activePageIndex = 0;
  String? _selectedTextBoxId;
  String? _selectedImageId;
  final ImagePicker _imagePicker = ImagePicker();
  
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
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
    final page = context.read<PageProvider>().getPageById(widget.pageId);
    if (page != null) {
      _titleCtrl.text = page.title;
      if (page.drawingJson != null && page.drawingJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(page.drawingJson!);
          if (decoded is Map && decoded.containsKey('pages')) {
            final List<dynamic> pagesJson = decoded['pages'];
            _pages = pagesJson.map((p) => PageData.fromJson(p)).toList();
          } else {
             // Fallback for empty or old format
             _pages = [PageData()];
          }
        } catch (e) {
          debugPrint("Error loading blocks: $e");
          _pages = [PageData()];
        }
      }
    }
    // Arka planlı sayfa varsa çizim modunda başla
    final firstPage = _pages.isNotEmpty ? _pages[0] : null;
    if (firstPage != null && firstPage.backgroundImageBase64 != null && firstPage.backgroundImageBase64!.isNotEmpty) {
      _currentMode = EditorMode.drawing;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyDrawingToolToActivePage();
      });
    }
    _initialized = true;
  }

  Future<void> _save() async {
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
    
    await context.read<PageProvider>().updatePage(
      widget.pageId,
      title: _titleCtrl.text,
      content: '',
      drawingJson: newJson,
      isAdvanced: true,
    );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _titleCtrl,
          style: TextStyle(
            color: AppColors.textPrimary, 
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          decoration: const InputDecoration(
            hintText: 'Bu bölüme isim veriniz',
            hintStyle: TextStyle(
              color: Colors.white38,
              fontSize: 16,
              fontWeight: FontWeight.normal,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          ),
          onChanged: (_) => setState(() => _hasChanges = true),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showCalculator ? Icons.calculate_rounded : Icons.calculate_outlined,
              color: _showCalculator ? AppColors.glow : null,
            ),
            tooltip: 'Hesap Makinesi',
            onPressed: () => setState(() => _showCalculator = !_showCalculator),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF Olarak Paylaş',
            onPressed: _exportAsPdf,
          ),
        ],
      ),
      body: AppContainer(
        hasGradient: true,
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopInterface(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    physics: _currentMode == EditorMode.drawing 
                        ? const NeverScrollableScrollPhysics() 
                        : const ClampingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _activePageIndex = index;
                        if (_currentMode == EditorMode.drawing) {
                           _applyDrawingToolToActivePage();
                        }
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildPageFrame(index);
                    },
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
            if (_showCalculator)
              FloatingCalculator(
                onClose: () => setState(() => _showCalculator = false),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildPageFrame(int index) {
    final pageData = _pages[index];
    final isDrawingMode = _currentMode == EditorMode.drawing;
    final isTextMode = _currentMode == EditorMode.text;
    final hasBg = pageData.backgroundImageBase64 != null && pageData.backgroundImageBase64!.isNotEmpty;
    
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5.0,
      panEnabled: true,
      scaleEnabled: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedTextBoxId = null;
            _selectedImageId = null;
          });
        },
        child: AppCard(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          backgroundColor: hasBg ? Colors.white : AppColors.surface,
          borderColor: AppColors.textMuted.withValues(alpha: 0.15),
          padding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Arka Plan: PDF/Görsel A4 oranında (Basık Değil)
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

            // 2. Text Editor — arka plan yoksa göster, varsa gizle
            if (!hasBg)
              IgnorePointer(
                ignoring: !isTextMode,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: TextField(
                    controller: pageData.textController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Metin girmek için dokunun...',
                      filled: false,
                    ),
                    style: TextStyle(
                      color: AppColors.textPrimary,
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

            // 5. Drawing Board — şeffaf arka planla arka planı kapatmaz
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
  );
}

  Widget _buildTopInterface() {
    final hasBg = _pages.isNotEmpty &&
        _pages[_activePageIndex].backgroundImageBase64 != null &&
        _pages[_activePageIndex].backgroundImageBase64!.isNotEmpty;
    
    int activePropertyIndex = 0;
    bool showProperties = true;
    
    if (_selectedTextBoxId != null) {
      activePropertyIndex = 2; // TextBox properties
    } else if (_currentMode == EditorMode.drawing) {
      activePropertyIndex = 1; // Drawing properties
    } else if (!hasBg && _currentMode == EditorMode.text) {
      activePropertyIndex = 0; // Text properties
    } else {
      showProperties = false;
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: _buildMainToolbar(hasBg: hasBg),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: showProperties ? 66 : 0,
          margin: EdgeInsets.fromLTRB(16, 0, 16, showProperties ? 10 : 0),
          child: showProperties
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      border: Border.all(color: AppColors.textMuted.withOpacity(0.12)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10)],
                    ),
                    child: IndexedStack(
                      index: activePropertyIndex,
                      children: [
                        _buildTextToolbarContent(),
                        _buildDrawingToolbarContent(),
                        _buildTextBoxToolbarContent(),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMainToolbar({bool hasBg = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.textMuted.withOpacity(0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarAction(
            icon: Icons.text_fields, 
            label: 'Metin', 
            onTap: hasBg ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Arka planı olan sayfalarda ana metin aracı kullanılamaz. Metin Kutusu ekleyebilirsiniz.'), duration: Duration(seconds: 2)),
              );
            } : () {
              setState(() {
                _selectedTextBoxId = null;
                _selectedImageId = null;
                _currentMode = EditorMode.text;
              });
            },
            active: _currentMode == EditorMode.text && !hasBg,
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
                  if (_activeTool == 'Eraser' || _activeTool == 'AreaEraser') {
                    _activeTool = 'SmoothLine';
                  }
                  _applyDrawingToolToActivePage();
               });
            },
            active: _currentMode == EditorMode.drawing && _activeTool != 'Eraser' && _activeTool != 'AreaEraser',
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
            label: 'Resim', 
            onTap: _pickImage,
          ),
          const VerticalDivider(),
          _ToolbarAction(
            icon: Icons.text_snippet, 
            label: 'Metin Kutusu', 
            onTap: _addTextBox,
          ),
        ],
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
      else if (_activeTool == 'Rectangle') controller.setPaintContent(Rectangle());
      else if (_activeTool == 'Circle') controller.setPaintContent(Circle());
      else if (_activeTool == 'StraightLine') controller.setPaintContent(StraightLine());
      else if (_activeTool == 'ArrowContent') controller.setPaintContent(ArrowContent());
      else if (_activeTool == 'Eraser') controller.setPaintContent(Eraser());
      else if (_activeTool == 'AreaEraser') controller.setPaintContent(Rectangle());
      
      if (_activeTool == 'AreaEraser') {
        controller.setStyle(color: Colors.red.withValues(alpha: 0.3), strokeWidth: 2.0);
      } else {
        controller.setStyle(color: _currentColor, strokeWidth: _currentStrokeWidth);
      }
      
      debugPrint('Tool applied successfully. Current PaintContent: ${controller.currentContent.runtimeType}');
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
              icon: const Icon(Icons.chevron_left),
              onPressed: _activePageIndex > 0 
                  ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                  : null,
            ),
            const Spacer(),
            GestureDetector(
              onTap: _showGoToPageDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.import_contacts_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    AppText(
                      'Sayfa ${_activePageIndex + 1} / ${_pages.length}',
                      styleType: AppTextStyleType.bodyMedium,
                      styleOverride: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 18),
                  ],
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _activePageIndex < _pages.length - 1 
                  ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            BounceButton(
              onTap: _addPage,
              child: ElevatedButton.icon(
                onPressed: _addPage,
                icon: const Icon(Icons.add),
                label: const AppText('Sayfa Ekle', styleType: AppTextStyleType.label, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawingToolbarContent() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ToolbarAction(
            icon: Icons.brush, 
            label: 'Kalem', 
            active: _activeTool == 'SmoothLine',
            onTap: () {
              setState(() => _activeTool = 'SmoothLine');
              _applyDrawingToolToActivePage();
            },
          ),
          _ToolbarAction(
            icon: Icons.square_outlined, 
            label: 'Kare', 
            active: _activeTool == 'Rectangle',
            onTap: () {
              setState(() => _activeTool = 'Rectangle');
              _applyDrawingToolToActivePage();
            },
          ),
          _ToolbarAction(
            icon: Icons.circle_outlined, 
            label: 'Daire', 
            active: _activeTool == 'Circle',
            onTap: () {
              setState(() => _activeTool = 'Circle');
              _applyDrawingToolToActivePage();
            },
          ),
          _ToolbarAction(
            icon: Icons.horizontal_rule, 
            label: 'Çizgi', 
            active: _activeTool == 'StraightLine',
            onTap: () {
              setState(() => _activeTool = 'StraightLine');
              _applyDrawingToolToActivePage();
            },
          ),
          _ToolbarAction(
            icon: Icons.arrow_right_alt, 
            label: 'Ok', 
            active: _activeTool == 'ArrowContent',
            onTap: () {
              setState(() => _activeTool = 'ArrowContent');
              _applyDrawingToolToActivePage();
            },
          ),
          _ToolbarAction(
            icon: Icons.auto_fix_normal, 
            label: 'Silgi', 
            active: _activeTool == 'Eraser',
            onTap: () {
              setState(() => _activeTool = 'Eraser');
              _applyDrawingToolToActivePage();
            },
          ),
          _ToolbarAction(
            icon: Icons.crop_free, 
            label: 'Alan Silgisi', 
            active: _activeTool == 'AreaEraser',
            onTap: () {
              setState(() => _activeTool = 'AreaEraser');
              _applyDrawingToolToActivePage();
            },
          ),
          const VerticalDivider(),
          _ToolbarAction(
            icon: Icons.delete_sweep, 
            label: 'Tümünü Sil', 
            onTap: () {
              final pageData = _pages[_activePageIndex];
              setState(() {
                pageData.deletedContentsBackup = pageData.controller.getJsonList();
                pageData.controller.clear();
                _hasChanges = true;
              });
            },
          ),
          _ToolbarAction(
            icon: Icons.undo, 
            label: 'Geri Al', 
            onTap: () {
              final pageData = _pages[_activePageIndex];
              if (pageData.controller.getJsonList().isEmpty && pageData.deletedContentsBackup != null) {
                setState(() {
                  final contents = pageData.deletedContentsBackup!.map((e) => _parseJsonToContent(e)).whereType<PaintContent>().toList();
                  pageData.controller.addContents(contents);
                  pageData.deletedContentsBackup = null;
                  _hasChanges = true;
                });
              } else {
                pageData.controller.undo();
              }
            },
          ),
          const VerticalDivider(),
          // Stroke Width Slider
          SizedBox(
            width: 100,
            child: Slider(
              value: _currentStrokeWidth,
              min: 1.0,
              max: 20.0,
              activeColor: Theme.of(context).primaryColor,
              onChanged: (val) {
                setState(() {
                  _currentStrokeWidth = val;
                  _applyDrawingToolToActivePage();
                });
              },
            ),
          ),
          const VerticalDivider(),
          Row(
            children: [
              _ColorDot(color: Colors.black, onSelect: _setDrawingColor, active: _currentColor == Colors.black),
              _ColorDot(color: Colors.red, onSelect: _setDrawingColor, active: _currentColor == Colors.red),
              _ColorDot(color: Colors.blue, onSelect: _setDrawingColor, active: _currentColor == Colors.blue),
              _ColorDot(color: Colors.green, onSelect: _setDrawingColor, active: _currentColor == Colors.green),
              _ColorDot(color: Colors.orange, onSelect: _setDrawingColor, active: _currentColor == Colors.orange),
              _ColorDot(color: Colors.purple, onSelect: _setDrawingColor, active: _currentColor == Colors.purple),
              _ColorDot(color: Colors.teal, onSelect: _setDrawingColor, active: _currentColor == Colors.teal),
            ],
          ),
        ],
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
